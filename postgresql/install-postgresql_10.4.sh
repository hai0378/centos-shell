#!/bin/bash
#
# postgresql 10.4

# 解决相对路径问题
cd `dirname $0`

# 定义全局变量
POSTGRESQL_URL=https://get.enterprisedb.com/postgresql/postgresql-10.4-1-linux-x64-binaries.tar.gz
POSTGRESQL_FILE=postgresql-10.4-1-linux-x64-binaries.tar.gz
POSTGRESQL_FILE_PATH=pgsql
POSTGRESQL_PATH=/data/service/postgresql
POSTGRESQL_PROFILE_D=/etc/profile.d/postgresql.sh
POSTGRESQL_INIT_D=/etc/init.d/postgres

POSTGRESQL_USER=postgres
POSTGRESQL_PASSWORD=postgres
POSTGRESQL_DATABASE_DIR=/data/postgresdatabase
POSTGRESQL_DATABASE_LOG=/data/postgreslog

# 检查是否为root用户，脚本必须在root权限下运行
bash ../common/util.sh
util::check_root

# 下载并解压
wget $POSTGRESQL_URL -O $POSTGRESQL_FILE && tar zxvf $POSTGRESQL_FILE

# 移动
mv $POSTGRESQL_FILE_PATH/* $POSTGRESQL_PATH

# 设置环境变量
cat <<EOF > $POSTGRESQL_PROFILE_D
export PATH=$POSTGRESQL_PATH/bin:\$PATH
EOF

# 更新环境变量
# . /etc/profile #此方法只能在当前Shell文件以及子Shell中生效
export PATH=$POSTGRESQL_PATH/bin:$PATH

# 初始化数据库
mkdir -p $POSTGRESQL_DATABASE_DIR
mkdir -p $POSTGRESQL_DATABASE_LOG
useradd $POSTGRESQL_USER
chown -R $POSTGRESQL_USER. $POSTGRESQL_DATABASE_DIR
chown -R $POSTGRESQL_USER. $POSTGRESQL_DATABASE_LOG
# 不设置密码
# passwd $POSTGRESQL_USER
su - $POSTGRESQL_USER -s /bin/sh -c "initdb -D "$POSTGRESQL_DATABASE_DIR" -U postgres -W"

# 设置开机启动服务
cat > $POSTGRESQL_INIT_D <<EOF
#! /bin/sh

# chkconfig: 2345 98 02
# description: PostgreSQL RDBMS

# This is an example of a start/stop script for SysV-style init, such
# as is used on Linux systems.  You should edit some of the variables
# and maybe the 'echo' commands.
#
# Place this file at /etc/init.d/postgresql (or
# /etc/rc.d/init.d/postgresql) and make symlinks to
#   /etc/rc.d/rc0.d/K02postgresql
#   /etc/rc.d/rc1.d/K02postgresql
#   /etc/rc.d/rc2.d/K02postgresql
#   /etc/rc.d/rc3.d/S98postgresql
#   /etc/rc.d/rc4.d/S98postgresql
#   /etc/rc.d/rc5.d/S98postgresql
# Or, if you have chkconfig, simply:
# chkconfig --add postgresql
#
# Proper init scripts on Linux systems normally require setting lock
# and pid files under /var/run as well as reacting to network
# settings, so you should treat this with care.

# Original author:  Ryan Kirkpatrick <pgsql@rkirkpat.net>

# contrib/start-scripts/linux

## EDIT FROM HERE

# Installation prefix
prefix=$POSTGRESQL_PATH

# Data directory
PGDATA="$POSTGRESQL_DATABASE_DIR"

# Who to run the postmaster as, usually "postgres".  (NOT "root")
PGUSER=$POSTGRESQL_USER

# Where to keep a log file
PGLOG="\$PGDATA/serverlog"

# It's often a good idea to protect the postmaster from being killed by the
# OOM killer (which will tend to preferentially kill the postmaster because
# of the way it accounts for shared memory).  To do that, uncomment these
# three lines:
#PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj
#PG_MASTER_OOM_SCORE_ADJ=-1000
#PG_CHILD_OOM_SCORE_ADJ=0
# Older Linux kernels may not have /proc/self/oom_score_adj, but instead
# /proc/self/oom_adj, which works similarly except for having a different
# range of scores.  For such a system, uncomment these three lines instead:
#PG_OOM_ADJUST_FILE=/proc/self/oom_adj
#PG_MASTER_OOM_SCORE_ADJ=-17
#PG_CHILD_OOM_SCORE_ADJ=0

## STOP EDITING HERE

# The path that is to be used for the script
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# What to use to start up the postmaster.  (If you want the script to wait
# until the server has started, you could use "pg_ctl start" here.)
DAEMON="\$prefix/bin/postmaster"

# What to use to shut down the postmaster
PGCTL="\$prefix/bin/pg_ctl"

set -e

# Only start if we can find the postmaster.
test -x \$DAEMON ||
{
    echo "\$DAEMON not found"
    if [ "\$1" = "stop" ]
    then exit 0
    else exit 5
    fi
}

# If we want to tell child processes to adjust their OOM scores, set up the
# necessary environment variables.  Can't just export them through the "su".
if [ -e "\$PG_OOM_ADJUST_FILE" -a -n "\$PG_CHILD_OOM_SCORE_ADJ" ]
then
    DAEMON_ENV="PG_OOM_ADJUST_FILE=\$PG_OOM_ADJUST_FILE PG_OOM_ADJUST_VALUE=\$PG_CHILD_OOM_SCORE_ADJ"
fi


# Parse command line parameters.
case \$1 in
  start)
    echo -n "Starting PostgreSQL: "
    test -e "\$PG_OOM_ADJUST_FILE" && echo "\$PG_MASTER_OOM_SCORE_ADJ" > "\$PG_OOM_ADJUST_FILE"
    su - \$PGUSER -c "\$DAEMON_ENV \$DAEMON -D '\$PGDATA' >>\$PGLOG 2>&1 &"
    echo "ok"
    ;;
  stop)
    echo -n "Stopping PostgreSQL: "
    su - \$PGUSER -c "\$PGCTL stop -D '\$PGDATA' -s"
    echo "ok"
    ;;
  restart)
    echo -n "Restarting PostgreSQL: "
    su - \$PGUSER -c "\$PGCTL stop -D '\$PGDATA' -s"
    test -e "\$PG_OOM_ADJUST_FILE" && echo "\$PG_MASTER_OOM_SCORE_ADJ" > "\$PG_OOM_ADJUST_FILE"
    su - \$PGUSER -c "\$DAEMON_ENV \$DAEMON -D '\$PGDATA' >>\$PGLOG 2>&1 &"
    echo "ok"
    ;;
  reload)
    echo -n "Reload PostgreSQL: "
    su - \$PGUSER -c "\$PGCTL reload -D '\$PGDATA' -s"
    echo "ok"
    ;;
  status)
    su - \$PGUSER -c "\$PGCTL status -D '\$PGDATA'"
    ;;
  *)
    # Print help
    echo "Usage: \$0 {start|stop|restart|reload|status}" 1>&2
    exit 1
    ;;
esac

exit 0

EOF
chmod a+x $POSTGRESQL_INIT_D

# 设置开机启动
chkconfig postgres on

# 启动
service postgres start
