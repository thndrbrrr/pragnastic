#!/bin/ksh

. ~/.pragnastic.conf

if [ "$netdrive_local" != "" ]; then
    umount $netdrive_local && echo "$netdrive_local unmounted OK"
fi
if [ "$shareddrive_local" != "" ]; then
    umount $shareddrive_local && echo "$shareddrive_local unmounted OK"
fi
