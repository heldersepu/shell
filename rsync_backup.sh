#!/bin/sh
#
# This maintains a one week rotating backup.
#
# Pass two arguments: rsync_backup SOURCE_PATH BACKUP_PATH
#
# $Id: rsync_backup 222 2008-02-21 22:05:30Z noah $

usage() {
    echo "usage: rsync_backup [-v] [-n] SOURCE_PATH BACKUP_PATH"
    echo "    SOURCE_PATH and BACKUP_PATH may be ssh-style remote paths; although,"
    echo "    BACKUP_PATH is usually a local directory where you want the"
    echo "    backup set stored."
}

while getopts ":vnh" options; do
    case $options in
        h ) usage
            exit 1;;
        \? ) usage
            exit 1;;
        * ) usage
            exit 1;;
    esac
done
shift $(($OPTIND - 1))
SOURCE_PATH=$1
BACKUP_PATH=$2
if [ -z $SOURCE_PATH ] ; then
    echo "Missing argument. Give source path and backup path."
    usage
    exit 1
fi
if [ -z $BACKUP_PATH ] ; then
    echo "Missing argument. Give source path and backup path."
    usage
    exit 1
fi

SOURCE_BASE=`basename $SOURCE_PATH`
RSYNC_OPTS="-a --delete"
TIMESTAMP=$(date '+%F-%T')
echo "START == $(date)"

# Create the directories if they don't exist.
if [ ! -d $BACKUP_PATH ] ; then
    mkdir $BACKUP_PATH
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP
fi

# Backup.
echo " Backup == $(date)"
_thread_count=$(($(nproc --all) * 16))
fpsync -n $_thread_count -v -o "-a --stats --numeric-ids --log-file=/tmp/efs-backup.log" $SOURCE_PATH/. $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/. 1>/tmp/efs-fpsync.log
RSYNC_EXIT_STATUS=$?

# Ignore error code 24, "rsync warning: some files vanished before they could be transferred".
if [ $RSYNC_EXIT_STATUS = 24 ] ; then
    RSYNC_EXIT_STATUS=0
fi

# Create a timestamp file to show when backup process completed successfully.
if [ $RSYNC_EXIT_STATUS = 0 ] ; then
    rm -f $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_ERROR
    date > $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_TIMESTAMP
else # Create a timestamp if there was an error.
    rm -f $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_TIMESTAMP
    echo "rsync failed" > $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_ERROR
    date >> $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_ERROR
    echo $RSYNC_EXIT_STATUS >> $BACKUP_PATH/$SOURCE_BASE.$TIMESTAMP/BACKUP_ERROR
fi

#Delete old backups
echo " Cleanup == $(date)"
mkdir EMPTYDIR.$TIMESTAMP
oldFolders=($(find $BACKUP_PATH -maxdepth 1 -mtime +7))
for dFolder in "${oldFolders[@]}" ; do
    echo "   Removing ($dFolder) === $(date)"
    rsync $RSYNC_OPTS EMPTYDIR.$TIMESTAMP/ $dFolder
done
rmdir EMPTYDIR.$TIMESTAMP

echo "END == $(date)"
echo ""

exit $RSYNC_EXIT_STATUS
