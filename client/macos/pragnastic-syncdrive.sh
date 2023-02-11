#!/bin/ksh

. ~/.pragnastic.conf

log() {
    echo `date "+%Y-%m-%d %H:%M:%S "` $1
}

notify() {
    log "$1"": ""$2"
    osascript -e "display notification \"$2\" with title \"PragNAStic SyncDrive\" subtitle \"$1\" sound name \"Submarine\""
}

if [ ! -e $syncdrive_lockfile ] ; then
    touch $syncdrive_lockfile
    log "Starting sync with unison profile $unison_profile"
    $unison_executable $unison_profile -ui text -batch -terse && log "Sync with unison profile $unison_profile completed OK"
    EXIT_CODE=$?
    if [ $EXIT_CODE != 0 ] ; then
        notify "ERROR" "Sync failed (unison exit code: $EXIT_CODE)"
        rm -f $syncdrive_lockfile
        exit 3
    fi
    rm -f $syncdrive_lockfile
else
    lockfile_age=$((`date +%s` - `stat -f %SB -t%s $syncdrive_lockfile`))
    if [[ $lockfile_age -gt $lockfile_age_notification_threshold ]] ; then
        notify "WARNING" "Sync skipped, lockfile already exists (age: $(($lockfile_age / 60))m)"
    else
        log "WARNING: Sync skipped, lockfile already exists"
    fi
fi
