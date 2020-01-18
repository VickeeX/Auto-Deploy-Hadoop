# Auto-Deploy-Hadoop
# use fabric execute on master 
# 
$ apt-get install python-pip -y
$ pip install fabric==1.14.0
$ wget https://github.com/VickeeX/Auto-Deploy-Hadoop/archive/master.zip
$ apt install unzip -y
$ unzip master.zip
$ python Auto-Deploy-Hadoop-master/auto_deploy_with_install.py -u 'root' -su 'root' -p 'password' -sp 'password' -m 1.x.x.x -s 2.x.x.x 3.x.x.x
