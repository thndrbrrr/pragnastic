#!/usr/bin/env oksh
# TODO: use this instead? #!/usr/bin/env ksh
# echo -n "backup0 disk id: "
# read backup0_disk_id
# echo -n "backup1 disk id: "
# read backup1_disk_id
echo -n "backup repo password (input is not shown): "
stty -echo 2>/dev/null
read -s backup_pw
stty echo 2>/dev/null
echo
# echo -n "data0 disk id: "
# read data0_disk_id
# echo -n "data1 disk id: "
# read data1_disk_id
echo -n "data pool password (input is not shown): "
stty -echo 2>/dev/null
read -s data_pw
stty echo 2>/dev/null
echo
echo -n "notification recipient's email (leave empty to disable): "
read notification_recipient
echo 
echo "Installing PragNAStic with this config:"
# echo "  backup0 disk id: $backup0_disk_id"
# echo "  backup1 disk id: $backup1_disk_id"
echo "  backup repo password: ****"
# echo "  data0 disk id: $data0_disk_id"
# echo "  data1 disk id: $data1_disk_id"
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
install -m 0600 etc/pragnastic/backup_repo.pw etc/pragnastic/storage_pool.pw /etc/pragnastic
install -m 0640 etc/pragnastic/backup.exclude etc/pragnastic/pragnastic.conf /etc/pragnastic
install -m 0644 etc/pragnastic/pragnastic.subr /etc/pragnastic

install -m 0754 usr/local/libexec/pragnastic-backup /usr/local/libexec
install -m 0754 usr/local/libexec/pragnastic-mount /usr/local/libexec/pragnastic-mount
install -m 0754 usr/local/libexec/pragnastic-show /usr/local/libexec/pragnastic-show
# install -m 0754 usr/local/libexec/pragnastic-raidcheck /usr/local/libexec/pragnastic-raidcheck
install -m 0754 usr/local/libexec/pragnastic-unmount /usr/local/libexec/pragnastic-unmount

install -m 0754 usr/local/sbin/pragnastic /usr/local/sbin/pragnastic

# install -o root -g wheel -d /vol
# install -o root -g wheel -d /vol/backup0
# install -o root -g wheel -d /vol/backup1
# install -o root -g wheel -d /vol/data

[ ! -e /var/log/pragnastic ] && install -m 0664 /dev/null /var/log/pragnastic

sed -i "" s/alice@example.com/$notification_recipient/ /etc/pragnastic/pragnastic.conf
# sed -i "" s/your_backup0_disk_id/$backup0_disk_id/ /etc/pragnastic/pragnastic.conf
# sed -i "" s/your_backup1_disk_id/$backup1_disk_id/ /etc/pragnastic/pragnastic.conf
# sed -i "" s/your_data0_disk_id/$data0_disk_id/ /etc/pragnastic/pragnastic.conf
# sed -i "" s/your_data1_disk_id/$data1_disk_id/ /etc/pragnastic/pragnastic.conf

echo $backup_pw >/etc/pragnastic/backup_repo.pw
echo $data_pw >/etc/pragnastic/data_pool.pw

echo "done"