#!/bin/bash
# if execute in fab command, too many unnecessary connections
# use shell to install libs locally for each node first

# install java
sudo apt-get update
sudo apt-get install openjdk-8-jre openjdk-8-jdk -y
java_home=`dpkg -L openjdk-8-jdk | grep '/bin' | head -1 | sed 's/\/bin//'`
echo "export JAVA_HOME=\$java_home" >> ~/.profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> ~/.profile
echo "export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar" >> ~/.profile

# install pdsh
sudo apt-get install pdsh -y
sudo echo "ssh" > /etc/pdsh/rcmd_default

# install hadoop
mkdir bigData
cd bigData
wget http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-3.1.3/hadoop-3.1.3.tar.gz
tar -zxvf hadoop-3.1.3.tar.gz
cd ..

# system env config for hadoop
echo "export HADOOP_HOME=/root/bigData/hadoop-3.1.3" >> ~/.profile
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> ~/.profile

# haddoop env config
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /root/bigData/hadoop-3.1.3/etc/hadoop/hadoop-env.sh
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /root/bigData/hadoop-3.1.3/etc/hadoop/yarn-env.sh

echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>fs.defaultFS</name>
                <value>hdfs://blockchain-001:9000</value>
        </property>
        <property>
                <name>io.file.buffer.size</name>
                <value>131072</value>
        </property>
        <property>
                <name>hadoop.tmp.dir</name>
                <value>file:/usr/local/hadoop/tmp</value>
        </property>
</configuration>' > /root/bigData/hadoop-3.1.3/etc/hadoop/core-site.xml

echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>dfs.namenode.secondary.http-address</name>
                <value>blockchain-001:9001</value>
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
                <value>2</value>
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
</configuration>' > /root/bigData/hadoop-3.1.3/etc/hadoop/hdfs-site.xml

echo '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
        <property>
                <name>mapreduce.framework.name</name>
                <value>yarn</value>
        </property>
        <property>
                <name>mapreduce.jobhistory.address</name>
                <value>blockchain-001:10020</value>
        </property>
        <property>
                <name>mapreduce.jobhistory.webapp.address</name>
                <value>blockchain-001:19888</value>
        </property>
</configuration>' > /root/bigData/hadoop-3.1.3/etc/hadoop/mapred-site.xml

echo '<?xml version="1.0"?>
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
                <value>blockchain-001:8032</value>
        </property>
        <property>
                <name>yarn.resourcemanager.scheduler.address</name>
                <value>blockchain-001:8030</value>
        </property>
        <property>
                <name>yarn.resourcemanager.resource-tracker.address</name>
                <value>blockchain-001:8031</value>
        </property>
        <property>
                <name>yarn.resourcemanager.admin.address</name>
                <value>blockchain-001:8033</value>
        </property>
        <property>
                <name>yarn.resourcemanager.webapp.address</name>
                <value>blockchain-001:8088</value>
        </property>
</configuration>' > /root/bigData/hadoop-3.1.3/etc/hadoop/yarn-site.xml


# stop ufw
ufw disable

# date sync
apt-get install ntp -y
apt-get install ntpdate -y
ntpdate -u ntp1.aliyun.com

# 'source ~/.profile'
# source cannot be recognized in dash shell (default)
# execute in fab commands
