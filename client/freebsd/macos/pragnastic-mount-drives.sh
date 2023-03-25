#!/bin/ksh

. ~/.pragnastic.conf

if [[ "$netdrive_remote" != "" && "$netdrive_local" != "" ]]; then
    `dirname $0`/pragnastic-mount-drive.sh $netdrive_remote $netdrive_local
fi
if [[ "$shareddrive_remote" != "" && "$shareddrive_local" != "" ]]; then
    `dirname $0`/pragnastic-mount-drive.sh $shareddrive_remote $shareddrive_local
fi
