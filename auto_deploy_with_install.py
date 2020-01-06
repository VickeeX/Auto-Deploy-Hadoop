# -*- coding: utf-8 -*-

"""
    @File name    :    auto_deploy_with_install.py
    @Date         :    2020-01-05 14:53
    @Description  :    {TODO}
    @Author       :    VickeeX
"""

import os
import argparse
from fabric.api import *


def get_arg_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-P', '--port', default='22', type=str,
                        help='Connection port for Fabric', dest='port')
    parser.add_argument('-u', '--user', default='root', type=str,
                        help='User while connection', dest='user')
    parser.add_argument('-su', '--sudo_user', default='root', type=str,
                        help='Sudo user while connection', dest='sudo_user')
    parser.add_argument('-p', '--password', type=str,
                        help='Password of user', dest='password')
    parser.add_argument('-sp', '--sudo_password', type=str,
                        help='Password of sudo user', dest='sudo_password')
    parser.add_argument('-m', '--master', type=str, nargs='+',
                        help='Ip and hostname of master', dest='master')
    parser.add_argument('-s', '--slaves', type=str, nargs='+',
                        help='Ip and hostname of slaves', dest='slaves')
    parser.add_argument('-ca', '--connection_attempts', default=2, type=int,
                        help='Connection attempts num, default is 2.', dest='connection_attempts')
    parser.add_argument('-r', '--replica_factor', default=1, type=int,
                        help='Replication factor, default is 1.', dest='replica_factor')
    return parser


@roles('slaves')
def put_install_shell():
    with settings(warn_only=False):
        put(work_dir + '/install_lib.sh', work_dir + '/install_lib.sh', use_sudo=True)


@roles('all')
def install_lib():
    sudo('sh install_lib.sh ' + work_dir)
    sudo('source ~/.profile')


@task
def get_ip_host(ip):
    with settings(host_string=ip, warn_only=False):
        run('s=`cat /etc/hostname` && echo "' + ip + ' "$s >> /etc/hosts.tmp')


@roles('slaves')
def scan_slaves_hostname():
    with settings(warn_only=False):
        get('/etc/hosts.tmp', '/etc/hosts.tmp0', use_sudo=True)
        local('cat /etc/hosts.tmp0 >> /etc/hosts.tmp && rm -f /etc/hosts.tmp0')


@roles('slaves')
def put_hosts():
    with settings(warn_only=False):
        put('/etc/hosts.tmp', '/etc/hosts.tmp', use_sudo=True)
        sudo('cat /etc/hosts.tmp >> /etc/hosts && rm /etc/hosts.tmp')


@roles('all')
def inject_admin_ssh_public_key():
    """ delete old ssh keys, generate new keys
    """
    with settings(warn_only=False):
        sudo('rm -rf ' + work_dir + '/.ssh/', shell=False)
        sudo('yes | ssh-keygen -N "" -f ' + work_dir + '/.ssh/id_rsa', shell=False)


@roles('slaves')
def scan_host_ssh_public_key():
    """ collect pubulic keys of all nodes to master's authorized_keys
    """
    with settings(warn_only=False):
        get(work_dir + '/.ssh/id_rsa.pub', work_dir + '/.ssh/id_rsa.temp', use_sudo=True)
        local(
            'cat ' + work_dir + '/.ssh/id_rsa.temp >> ' + work_dir + '/.ssh/authorized_keys && rm -f ' + work_dir + '/.ssh/id_rsa.temp')


@roles('slaves')
def put_authorized_keys():
    """ distribute the authorized_keys to each slave
    """
    with settings(warn_only=False):
        put(work_dir + '/.ssh/authorized_keys', work_dir + '/.ssh/authorized_keys', use_sudo=True)


@task
def first_authorized_ssh(all_hosts):
    """ the first ssh connection needs confirmation, auto confirm to avoid future waiting while users or scripts uses
    """
    prompts = {args.user + '@' + host + ':~# ': 'exit' for host in all_hosts.values()}
    prompts['Are you sure you want to continue connecting (yes/no)? '] = 'yes'
    with settings(host_string=args.master[0], prompts=prompts, warn_only=False):
        for host in env.roledefs['slaves']:
            run('ssh ' + host)


@roles('all')
def local_hadoop_config(master, s):
    # TODO: config tmp.dir, name.dir, data.dir, dfs.replication as specifid
    with settings(warn_only=False):
        run(
            'sed -i "s/blockchain-001/' + master + '/g" ' +
            work_dir + '/bigData/hadoop-3.1.3/etc/hadoop/core-site.xml ' +
            work_dir + '/bigData/hadoop-3.1.3/etc/hadoop/hdfs-site.xml ' +
            work_dir + '/bigData/hadoop-3.1.3/etc/hadoop/mapred-site.xml ' +
            work_dir + '/bigData/hadoop-3.1.3/etc/hadoop/yarn-site.xml')
        run('echo "' + s + '" > ' + work_dir + '/bigData/hadoop-3.1.3/etc/hadoop/workers')


@task
def auto_deploy():
    # install libs
    # local('wget install.sh')  # TODO: put into github for wget
    execute(put_install_shell)
    execute(install_lib)

    # hosts config
    for ip in all_nodes:
        get_ip_host(ip)
    execute(scan_slaves_hostname)
    all_hosts = {}
    with open('/etc/hosts.tmp', 'r') as f:
        for line in f:
            ip, host = line.strip().split(' ')
            all_hosts[ip] = host
    local('cat /etc/hosts.tmp >> /etc/hosts')
    execute(put_hosts)

    # ssh free password automatic deployment
    execute(inject_admin_ssh_public_key)
    local(
        'rm -f ' + work_dir + '/.ssh/authorized_keys && cat ' + work_dir + '/.ssh/id_rsa.pub > ' + work_dir + '/.ssh/authorized_keys')
    execute(scan_host_ssh_public_key)
    execute(put_authorized_keys)
    first_authorized_ssh(all_hosts)

    # hadoop configure modification
    execute(local_hadoop_config, all_hosts[args.master[0]], '\n'.join([all_hosts[ip] for ip in args.slaves]))
    if env.user == 'sudo':
        local(
            'sed -i "2i HDFS_DATANODE_USER=root\nHDFS_DATANODE_SECURE_USER=hdfs\nHDFS_NAMENODE_USER=root\nHDFS_SECONDARYNAMENODE_USER=root" start-dfs.sh stop-dfs.sh')
        local(
            'sed -i "2i YARN_RESOURCEMANAGER_USER=root\nHADOOP_SECURE_DN_USER=yarn\nYARN_NODEMANAGER_USER=root" start-yarn.sh stop-yarn.sh')

    # format
    local('hadoop namenode -format')

    # # start hadoop
    # local('.' + work_dir+'/bigData/hadoop-3.1.3/sbin/start-all.sh')
    # # stop hadoop
    # local('.' + work_dir+'/bigData/hadoop-3.1.3/sbin/stop-all.sh')


def execute_fab_deploy(func):
    command = "fab -f %s %s" % (__file__, func)
    os.system(command)


if __name__ == '__main__':
    args = get_arg_parser().parse_args()
    work_dir = "/root" if args.user == 'root' else "/home/" + args.user
    all_nodes = args.master + args.slaves
    env.roledefs = {
        'all': all_nodes,
        'master': args.master,
        'slaves': args.slaves
    }
    env.port = args.port
    env.user = args.user
    env.sudo_user = args.sudo_user
    env.passwords = {args.user + '@' + ip + ':' + str(args.port): args.password for ip in all_nodes}
    env.sudo_passwords = {args.sudo_user + '@' + ip + ':' + str(args.port): args.sudo_password for ip in all_nodes}
    env.connection_attempts = args.connection_attempts
    execute_fab_deploy(auto_deploy())
