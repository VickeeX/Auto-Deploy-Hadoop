#!/bin/bash
# Hadoop Deployment on Each Node
# Test system version: Ubuntu 16.0.4 TLS
#
# PARAMETERS:
# 1> Essential
# num, master_ip, slaves_ip
# 2> Optional
# JAVA_VERSION, HADOOP_VERSION, HADOOP CONFIG (eg, replication_factor)
# ...

NODES=$1
REPLICATION_FACTOR=$2
BUFFER_SIZE=$3

WORK_DIR=/root
# shellcheck disable=SC2206
NODES=(${NODES//,/ })
MASTER=${NODES[0]}
unset 'NODES[0]'



# apt-get
apt-get update

# stop ufw
ufw disable

# date sync
apt-get install ntp -y
apt-get install ntpdate -y
ntpdate -u ntp1.aliyun.com

# install java and configure sys path
apt-get install openjdk-8-jre openjdk-8-jdk -y
# shellcheck disable=SC2006
JAVA_HOME=`dpkg -L openjdk-8-jdk | grep '/bin' | head -1 | sed 's/\/bin//'`
printf "export JAVA_HOME=%s\nexport PATH=\$JAVA_HOME/bin:\$PATH\nexport CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar\n" "$JAVA_HOME" >> ~/.profile

# install pdsh and set default connection way
apt-get install pdsh -y
printf "ssh" > /etc/pdsh/rcmd_default

# install hadoop
wget http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-3.1.3/hadoop-3.1.3.tar.gz
tar -zxvf hadoop-3.1.3.tar.gz

# system env config for hadoop
printf "export HADOOP_HOME=%s/hadoop-3.1.3\nexport PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin\n" "$WORK_DIR" >> $WORK_DIR/.profile

# hadoop env config
printf "export JAVA_HOME=%s\n" "$JAVA_HOME" >> $WORK_DIR/hadoop-3.1.3/etc/hadoop/hadoop-env.sh
printf "export JAVA_HOME=%s\n" "$JAVA_HOME" >> $WORK_DIR/hadoop-3.1.3/etc/hadoop/yarn-env.sh

printf '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>fs.defaultFS</name>
                <value>hdfs://%s:9000</value>
        </property>
        <property>
                <name>io.file.buffer.size</name>
                <value>%s</value>
        </property>
        <property>
                <name>hadoop.tmp.dir</name>
                <value>file:/usr/local/hadoop/tmp</value>
        </property>
</configuration>' "$MASTER" "$BUFFER_SIZE"> $WORK_DIR/hadoop-3.1.3/etc/hadoop/core-site.xml

printf '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>dfs.namenode.secondary.http-address</name>
                <value>%s:9001</value>
        </property>
        <property>
                <name>dfs.namenode.name.dir</name>
                <value>file:/usr/local/hadoop/dfs/namenode</value>
        </property>
        <property>
                <name>dfs.datanode.data.dir</name>
                <value>file:/usr/local/hadoop/dfs/datanode</value>
        </property>
        <property>
                <name>dfs.replication</name>
                <value>%s</value>
        </property>
        <property>
                <name>dfs.webhdfs.enabled</name>
                <value>true</value>
        </property>
        <property>
                <name>dfs.permissions</name>
                <value>false</value>
        </property>
        <property>
                <name>dfs.web.ugi</name>
                <value>supergroup</value>
        </property>
</configuration>' "$MASTER" "$REPLICATION_FACTOR"> $WORK_DIR/hadoop-3.1.3/etc/hadoop/hdfs-site.xml

printf '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>mapreduce.framework.name</name>
                <value>yarn</value>
        </property>
        <property>
                <name>mapreduce.jobhistory.address</name>
                <value>%s:10020</value>
        </property>
        <property>
                <name>mapreduce.jobhistory.webapp.address</name>
                <value>%s:19888</value>
        </property>
                <property>
                <name>yarn.app.mapreduce.am.env</name>
                <value>HADOOP_MAPRED_HOME=%s/hadoop-3.1.3</value>
        </property>
        <property>
                <name>mapreduce.map.env</name>
                <value>HADOOP_MAPRED_HOME=%s/hadoop-3.1.3</value>
        </property>
        <property>
                <name>mapreduce.reduce.env</name>
                <value>HADOOP_MAPRED_HOME=%s/hadoop-3.1.3</value>
        </property>
</configuration>' "$MASTER" "$MASTER" "$WORK_DIR" "$WORK_DIR" "$WORK_DIR"> $WORK_DIR/hadoop-3.1.3/etc/hadoop/mapred-site.xml

printf '<?xml version="1.0"?>
<configuration>
        <property>
                <name>yarn.nodemanager.aux-services</name>
                <value>mapreduce_shuffle</value>
        </property>
        <property>
                <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
                <value>org.apache.hadoop.mapred.ShuffleHandler</value>
        </property>
        <property>
                <name>yarn.resourcemanager.address</name>
                <value>%s:8032</value>
        </property>
        <property>
                <name>yarn.resourcemanager.scheduler.address</name>
                <value>%s:8030</value>
        </property>
        <property>
                <name>yarn.resourcemanager.resource-tracker.address</name>
                <value>%s:8031</value>
        </property>
        <property>
                <name>yarn.resourcemanager.admin.address</name>
                <value>%s:8033</value>
        </property>
        <property>
                <name>yarn.resourcemanager.webapp.address</name>
                <value>%s:8088</value>
        </property>
</configuration>' "$MASTER" "$MASTER" "$MASTER" "$MASTER" "$MASTER" > $WORK_DIR/hadoop-3.1.3/etc/hadoop/yarn-site.xml

for var in ${NODES[@]}
do
   printf '%s\n' "$var" >> $WORK_DIR/hadoop-3.1.3/etc/hadoop/workers
done

sed -i "2i HDFS_DATANODE_USER=root\nHDFS_DATANODE_SECURE_USER=hdfs\nHDFS_NAMENODE_USER=root\nHDFS_SECONDARYNAMENODE_USER=root" $WORK_DIR/hadoop-3.1.3/sbin/start-dfs.sh $WORK_DIR/hadoop-3.1.3/sbin/stop-dfs.sh
sed -i "2i YARN_RESOURCEMANAGER_USER=root\nHADOOP_SECURE_DN_USER=yarn\nYARN_NODEMANAGER_USER=root" $WORK_DIR/hadoop-3.1.3/sbin/start-yarn.sh $WORK_DIR/hadoop-3.1.3/sbin/stop-yarn.sh

# use `$source {shell_name}.sh {params}` to enable source
source $WORK_DIR/.profile
