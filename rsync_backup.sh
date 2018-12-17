#!/bin/sh
#
# This maintains a one week rotating backup. This will normalize permissions on
# all files and directories on backups. It has happened that someone removed
# owner write permissions on some files, thus breaking the backup process. This
# prevents that from happening. All this permission changing it tedious, but it
# eliminates any doubts. I could have done this with "chmod -R +X", but I
# wanted to explicitly set the permission bits.
#
# Pass two arguments: rsync_backup SOURCE_PATH BACKUP_PATH
#
# $Id: rsync_backup 222 2008-02-21 22:05:30Z noah $

usage() {
    echo "usage: rsync_backup [-v] [-n] SOURCE_PATH BACKUP_PATH"
    echo "    SOURCE_PATH and BACKUP_PATH may be ssh-style remote paths; although,"
    echo "    BACKUP_PATH is usually a local directory where you want the"
    echo "    backup set stored."
    echo "    -v : set verbose mode"
}

VERBOSE=0
while getopts ":vnh" options; do
    case $options in
        v ) VERBOSE=1;;
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
PERMS_DIR=755
PERMS_FILE=644
if [ $VERBOSE ]; then
    RSYNC_OPTS="-a --delete -v"
    date
else
    RSYNC_OPTS="-a --delete -q"
fi

# Create the rotation directories if they don't exist.
if [ ! -d $BACKUP_PATH ] ; then
    mkdir $BACKUP_PATH
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.0 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.0
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.1 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.1
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.2 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.2
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.3 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.3
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.4 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.4
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.5 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.5
fi
if [ ! -d $BACKUP_PATH/$SOURCE_BASE.6 ] ; then
    mkdir $BACKUP_PATH/$SOURCE_BASE.6
fi


# Rotate backups.
rm -rf $BACKUP_PATH/$SOURCE_BASE.6
mv     $BACKUP_PATH/$SOURCE_BASE.5 $BACKUP_PATH/$SOURCE_BASE.6
mv     $BACKUP_PATH/$SOURCE_BASE.4 $BACKUP_PATH/$SOURCE_BASE.5
mv     $BACKUP_PATH/$SOURCE_BASE.3 $BACKUP_PATH/$SOURCE_BASE.4
mv     $BACKUP_PATH/$SOURCE_BASE.2 $BACKUP_PATH/$SOURCE_BASE.3
mv     $BACKUP_PATH/$SOURCE_BASE.1 $BACKUP_PATH/$SOURCE_BASE.2
cp -al $BACKUP_PATH/$SOURCE_BASE.0 $BACKUP_PATH/$SOURCE_BASE.1

# Backup.
rsync $RSYNC_OPTS $SOURCE_PATH/. $BACKUP_PATH/$SOURCE_BASE.0/.
RSYNC_EXIT_STATUS=$?

# Ignore error code 24, "rsync warning: some files vanished before they could be transferred".
if [ $RSYNC_EXIT_STATUS = 24 ] ; then
    RSYNC_EXIT_STATUS=0
fi

# Create a timestamp file to show when backup process completed successfully.
if [ $RSYNC_EXIT_STATUS = 0 ] ; then
    rm -f $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_ERROR
    date > $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_TIMESTAMP
else # Create a timestamp if there was an error.
    rm -f $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_TIMESTAMP
    echo "rsync failed" > $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_ERROR
    date >> $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_ERROR
    echo $RSYNC_EXIT_STATUS >> $BACKUP_PATH/$SOURCE_BASE.0/BACKUP_ERROR
fi

if [ $VERBOSE ]; then
    date
fi

exit $RSYNC_EXIT_STATUS
