#!/bin/sh
#
# jvm       Start/stop jvm
#
# chkconfig: - 99 99
# description: jvm init script
#

STACK_BASE_DIR="${STACK_PATH:-/home/jelastic}"

if [ -x /etc/rc.d/init.d/functions ]; then
. /etc/rc.d/init.d/functions
fi
. /etc/profile 2>/dev/null

# the name of the project, will also be used for the war file, log file, ...
PROJECT_NAME=jvm
# the user which should run the service
SERVICE_USER=jelastic

# base directory for the JVM jar
STACK_APP_HOME=${STACK_BASE_DIR}/release
export STACK_APP_HOME

STACK_APP_LIBS=${STACK_BASE_DIR}/libs
export STACK_APP_LIBS

STACK_APP_SERVER=${STACK_BASE_DIR}/server
export STACK_APP_SERVER

LOG_DIR="/var/log/"
LOG="${LOG_DIR}/run.log"
LOCK="${STACK_BASE_DIR}/lock/jvm.lock"
[ -f /etc/sysconfig/jvm.conf ] && . /etc/sysconfig/jvm.conf

#FATJAR_FILE
JARFILE_NAME=$( cd $STACK_APP_SERVER && find . -name '*.jar')

[ -z "$JARFILE_NAME" ] && echo "Error: Nothing to run" && exit 1

JARFILE_FULLPATH=${STACK_APP_HOME}/$JARFILE_NAME

JAVA_LIBS=${STACK_APP_LIBS}/$( cd $STACK_APP_LIBS && find . -name '*.jar')

POSTBOOT=${STACK_APP_SERVER}/postboot

JAVA_ARGS="--port 80 --sslport 443 --postbootcommandfile $POSTBOOT --addlibs $JAVA_LIBS $JAVA_WARS"

JAVA_WARS=$(basename "$(ls $STACK_APP_HOME/*.{j,w,e}ar 2>/dev/null | grep -v payara)" 2>/dev/null );

# java executable for app, change if you have multiple jdks installed
APP_JAVA=/usr/bin/java

printenv 

mkdir -p "${STACK_BASE_DIR}/lock/"

RETVAL=0

pid_of_java_boot() {
    pgrep -f "java." -u jelastic
}
#[ -d "$LOG_DIR" ] || mkdir -p ${LOG_DIR}
[ -f "$LOG" ] || { touch $LOG; }
chmod a+w $LOG &>/dev/null

start() {
    [ -z "$JARFILE_NAME" ] && echo "Error: Nothing to run" && exit 1
    pid=$(pid_of_java_boot)

    if [ -n "$pid" ]; then
        echo $"java (pid $pid) is running..."
        return 0
    fi

    echo -n $"Starting $PROJECT_NAME: "

# TODO: add check already running
    [ ! -f "$JARFILE_FULLPATH" -a ! -L "$JARFILE_FULLPATH" ] && { echo -n "No application deployed"; echo " [  FAIL  ]"; RETVAL=1; return 1; }
    cd $STACK_APP_HOME && runuser jelastic -c ". $HOME_DIR/.bashrc; $APP_JAVA \$JAVA_OPTS -jar ${JARFILE_NAME// /\\ } $JAVA_ARGS $JAVA_WARS >>$LOG 2>&1 &"
    sleep 0.5
    
    while { pid_of_java_boot > /dev/null ; } &&
    ! pgrep java > $LOCK ; do
        sleep 1
    done

    pid_of_java_boot > /dev/null
    RETVAL=$?
    [[ $RETVAL = 0 ]] && touch "$LOCK" && echo " [  OK  ]" || echo " [  FAIL  ]" ;
}

stop() {
    echo -n "Stopping $PROJECT_NAME: "

    pid=$(pid_of_java_boot)
    [ -n "$pid" ] && { kill -13 $pid ; kill $pid 2>/dev/null; }
    RETVAL=0
    cnt=10
    while [ $RETVAL = 0 -a $cnt -gt 0 ] &&
        { pid_of_java_boot > /dev/null ; } ; do
            sleep 1
            ((cnt--))
    done
    pid=$(pid_of_java_boot)
    [ -n "$pid" ] && { kill -9 $pid 2>/dev/null; }

    [ $RETVAL = 0 ] && { rm -f "$LOCK" && echo " [  OK  ]" ; } || echo " [  FAIL  ]"
    return $RETVAL
}

status() {
    pid=$(pid_of_java_boot)
    if [ -n "$pid" ]; then
        echo "$PROJECT_NAME (pid $pid) is running..."
        return 0
    fi
    if [ -f "$LOCK" ]; then
        echo $"${base} dead but subsys locked"
        return 2
    fi
    echo "$PROJECT_NAME is stopped"
    return 3
}

# See how we were called.
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        stop
        start
        ;;
    *)
        exit 0
esac

exit $RETVAL
