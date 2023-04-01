#!/usr/bin/env oksh

echo -n "backup repo password (input is not shown): "
stty -echo 2>/dev/null
read -s backup_pw
stty echo 2>/dev/null
echo
echo -n "data pool password (input is not shown): "
stty -echo 2>/dev/null
read -s data_pw
stty echo 2>/dev/null
echo
echo -n "notification recipient's email (leave empty to disable): "
read notification_recipient
echo 
echo "Installing PragNAStic with this config:"
echo "  backup repo password: ****"
echo "  data RAID password: ****"
echo "  notification recipient: $notification_recipient"
echo -n "Proceed? [y/N] "
read proceed
echo
if [ "`echo $proceed | tr "[:upper:]" "[:lower:]"`" != "y" ]; then
    echo "install aborted"
    exit 1
fi

set -e

install -m 0755 -d /etc/pragnastic
install -m 0400 etc/pragnastic/backup_repo.pw etc/pragnastic/storage_pool.pw /etc/pragnastic
install -m 0640 etc/pragnastic/backup.exclude etc/pragnastic/pragnastic.conf /etc/pragnastic
install -m 0644 etc/pragnastic/pragnastic.subr /etc/pragnastic

install -m 0754 usr/local/libexec/pragnastic-backup /usr/local/libexec
install -m 0754 usr/local/libexec/pragnastic-mount /usr/local/libexec/pragnastic-mount
install -m 0754 usr/local/libexec/pragnastic-show /usr/local/libexec/pragnastic-show
install -m 0754 usr/local/libexec/pragnastic-check /usr/local/libexec/pragnastic-check
install -m 0754 usr/local/libexec/pragnastic-unmount /usr/local/libexec/pragnastic-unmount

install -m 0754 usr/local/sbin/pragnastic /usr/local/sbin/pragnastic

[ ! -e /var/log/pragnastic ] && install -m 0664 /dev/null /var/log/pragnastic

sed -i "" s/alice@example.com/$notification_recipient/ /etc/pragnastic/pragnastic.conf

echo $backup_pw >/etc/pragnastic/backup_repo.pw
echo $data_pw >/etc/pragnastic/storage_pool.pw

echo "done"