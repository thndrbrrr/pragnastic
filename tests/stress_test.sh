#!/bin/ksh

usage() {
    echo "usage: `basename $1` local_netdrive_path local_syncdrive_path log_file"
}

NETDRIVE_PATH=$1
SYNCDRIVE_PATH=$2
LOG_FILE=$3
[ -n "$NETDRIVE_PATH" ] || { usage $0; exit 1; }
[ -n "$SYNCDRIVE_PATH" ] || { usage $0; exit 1; }
[ -n "$LOG_FILE" ] || { usage $0; exit 1; }

log() { # params: msg
    echo `date "+%Y-%m-%d %H:%M:%S "` $1
}

random_sleep() { # params: min_sleep max_sleep log_prefix
    MIN_SLEEP=$1
    MAX_SLEEP=$2
    LOG_PREFIX=$3
    RAND_SLEEP=$(($MIN_SLEEP + RANDOM % ($MAX_SLEEP - $MIN_SLEEP))) # sec
    log "$LOG_PREFIX Sleeping $RAND_SLEEP seconds"
    sleep $RAND_SLEEP
}

random_write_file() { # params: test_name target_dir [calc_min_rm_sleep_flag=false]
    TARGET_DIR=$2
    LOG_PREFIX="[$1 $TARGET_DIR]"
    CALC_MIN_RM_SLEEP_FLAG=$3
    RAND_FNAME="stress_test-"`openssl rand -hex 12`"-"`hostname`
    RAND_SIZE=$((RANDOM % 1024)) # MB

    log "$LOG_PREFIX Sleeping before writing to $TARGET_DIR/$RAND_FNAME"
    random_sleep 0 10 "$LOG_PREFIX"
    log "$LOG_PREFIX Writing $RAND_SIZE MB to $TARGET_DIR/$RAND_FNAME"
    dd if=/dev/zero of=$TARGET_DIR/$RAND_FNAME bs=1m count=$RAND_SIZE

    if [ $CALC_MIN_RM_SLEEP_FLAG ] ; then MIN_RM_SLEEP=$((65 + $RAND_SIZE / 5)) ; else MIN_RM_SLEEP=0 ; fi
    log "$LOG_PREFIX Sleeping at least $MIN_RM_SLEEP seconds before removing $TARGET_DIR/$RAND_FNAME"
    random_sleep $MIN_RM_SLEEP $(($MIN_RM_SLEEP + 10)) "$LOG_PREFIX"
    rm $TARGET_DIR/$RAND_FNAME

    if [[ $MIN_RM_SLEEP -gt 0 ]] ; then
        log "$LOG_PREFIX Sleeping at least 65 seconds before continuing"
        random_sleep 65 80 "$LOG_PREFIX"
    fi
}

random_write_copy_read_file() { # params: test_name target_dir
    TARGET_DIR=$2
    LOG_PREFIX="[$1 $TARGET_DIR]"
    RAND_FNAME="stress_test-"`openssl rand -hex 12`"-"`hostname`
    RAND_SIZE=$((RANDOM % 1024)) # MB
    RAND_READ_SIZE=$((RANDOM % $RAND_SIZE)) # MB

    log "$LOG_PREFIX Sleeping before writing to $TARGET_DIR/$RAND_FNAME"
    random_sleep 0 10 "$LOG_PREFIX"
    log "$LOG_PREFIX Writing $RAND_SIZE MB to $TARGET_DIR/$RAND_FNAME"
    dd if=/dev/zero of=$TARGET_DIR/$RAND_FNAME bs=1m count=$RAND_SIZE

    log "$LOG_PREFIX Sleeping before copying $TARGET_DIR/$RAND_FNAME to $TARGET_DIR/$RAND_FNAME.1"
    random_sleep 0 10 "$LOG_PREFIX"
    cp $TARGET_DIR/$RAND_FNAME $TARGET_DIR/$RAND_FNAME.1

    log "$LOG_PREFIX Sleeping before reading $TARGET_DIR/$RAND_FNAME.1"
    random_sleep 0 10 "$LOG_PREFIX"
    log "$LOG_PREFIX Reading $RAND_READ_SIZE MB from $TARGET_DIR/$RAND_FNAME.1"
    dd if=$TARGET_DIR/$RAND_FNAME.1 of=/dev/null bs=1m count=$RAND_READ_SIZE

    log "$LOG_PREFIX Sleeping before removing $TARGET_DIR/$RAND_FNAME and $TARGET_DIR/$RAND_FNAME.1"
    random_sleep 0 10 "$LOG_PREFIX"
    rm $TARGET_DIR/$RAND_FNAME
    rm $TARGET_DIR/$RAND_FNAME.1
}

random_write() { # params: test_name target_dir [calc_min_rm_sleep_flag=false]
    while true ; do
        random_write_file $1 $2 $3
    done
}

random_write_copy_read() { # params: test_name target_dir
    while true ; do
        random_write_copy_read_file $1 $2
    done
}

# netdrive ops
random_write netdrive_random_write $NETDRIVE_PATH >>$LOG_FILE 2>&1 &
random_write_copy_read netdrive_random_write_copy_read $NETDRIVE_PATH >>$LOG_FILE 2>&1 &

# syncdrive ops
random_write syncdrive_random_write $SYNCDRIVE_PATH true >>$LOG_FILE 2>&1 &

echo "stress test is running in background, stop with 'pkill -f stress_test.sh'"