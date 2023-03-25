#!/bin/ksh

REMOTE_URL=$1
[ -n "$REMOTE_URL" ] || { echo "ERROR: missing remote URL"; exit 1; }
LOCAL_MOUNTPOINT=$2
[ -n "$LOCAL_MOUNTPOINT" ] || { echo "ERROR: missing local mountpoint"; exit 1; }
MOUNT_OPTS="$3"

log() {
    echo `date "+%Y-%m-%d %H:%M:%S "` $1
}

is_running() { # params: pid
	ps -p $1 >/dev/null
}

run_with_timeout() { # params: cmd timeout
    # echo 1
	$1 &
	CMD_PID=$!
    # echo 2
	for i in {1..$2} ; do
        # echo -n "."
        # echo 3
		is_running $CMD_PID &&  sleep 1 || return $?
	done
    # echo 4
	kill $CMD_PID
	is_running $CMD_PID && kill -9 $CMD_PID 
	# is_running $CMD_PID && echo "Failed to kill [$CMD_PID] $1" && return $TIMEOUT_ERROR
	is_running $CMD_PID && echo "Failed to kill [$CMD_PID] $1, aborting" && exit 999
	return 0
}

mount_sshfs() { # params: remote_url local_mountpoint
    _REMOTE_URL=$1
    _LOCAL_MOUNTPOINT=$2
    set -A _LOCAL_PATH_SEGMENTS `echo "$_LOCAL_MOUNTPOINT" | cut -b2- | sed s/\\\//\ /g`
    LOCAL_DIR_NAME=${_LOCAL_PATH_SEGMENTS[${#_LOCAL_PATH_SEGMENTS[*]}-1]}

    log "Mounting $_REMOTE_URL at $_LOCAL_MOUNTPOINT using SSHFS"
    sshfs $_REMOTE_URL $_LOCAL_MOUNTPOINT -o volname=$LOCAL_DIR_NAME -o noappledouble $MOUNT_OPTS
}

_chk_mnt() { # params: local_mountpoint
    mount | grep $1 >/dev/null && log "$1 is mounted"
}

# check_mounted() { # params: local_mountpoint
#     run_with_timeout "_mnt_chk $LOCAL_MOUNTPOINT" 5
#     # mount | grep $1 >/dev/null && log "$1 is mounted"
#     # sleep 10 && false && log "$1 is mounted"
# }

check_readable() {
    ls $LOCAL_MOUNTPOINT >/dev/null
}

# Mount netdrive if it's not mounted
log "Checking if $LOCAL_MOUNTPOINT is mounted"
# run_with_timeout "check_mounted $LOCAL_MOUNTPOINT" 5
_chk_mnt $LOCAL_MOUNTPOINT
if [[ $? -gt 0 ]] ; then
    log "$LOCAL_MOUNTPOINT is not mounted"
    mount_sshfs $REMOTE_URL $LOCAL_MOUNTPOINT && log "$_REMOTE_URL mounted on $_LOCAL_MOUNTPOINT OK"
else
    # Check if netdrive is readable
    log "Checking if $LOCAL_MOUNTPOINT is readable"
    run_with_timeout "check_readable $LOCAL_MOUNTPOINT" 5 && log "$LOCAL_MOUNTPOINT is readable OK"
    if [[ $? -gt 0 ]] ; then
        log "$LOCAL_MOUNTPOINT is mounted but not readable"
        log "Attempting to unmount $LOCAL_MOUNTPOINT"
        umount $LOCAL_MOUNTPOINT && log "$LOCAL_MOUNTPOINT unmounted OK"
        if [[ $? -gt 0 ]] ; then
            log "Unmounting $LOCAL_MOUNTPOINT failed. Aborting."
            exit 1
        fi
        mount_sshfs $REMOTE_URL $LOCAL_MOUNTPOINT && log "$_REMOTE_URL mounted on $_LOCAL_MOUNTPOINT OK"
    fi
fi