<a name="readme-top"></a>

<div align="center">
 <img width="200px" src="docs/images/pragnastic_tmp_logo_4.png"/>
<h3>PragNAStic</h3>
<p><b>Network-attached storage with integrated backup</b><br/>
Safe • Secure • Flexible</p>
</div>

## Configuring PragNAStic on FreeBSD

These instructions assume that you are the `root` user on a FreeBSD system.

```sh
# Install required packages
pkg install unison-nox11
pkg install restic
pkg install msmtp
pkg install oksh
```

## Mail setup

PragNAStic sends notifications when things misbehave. On FreeBSD the scripts use `msmtp` rather than `sendmail`, because `msmtp` is much simpler to use and configure.

## System config

SSH is needed so that Windows and MacOS clients can mount file systems, and Unison uses SSH as well for transport. `ntpd` should also be running for accurate timekeeping and reliable file server operations. It helps ensure that file modification times are correct, logging and auditing are accurate, and synchronization tasks are on time. The services `zfs` service and `zfskeys` (provides encryption support) need to be runnning for everything ZFS:

```sh
service sshd enable
service ntpd enable
service zfs enable
service zfskeys enable
```


## Disk management with ZFS

The FreeBSD version of PragNAStic uses ZFS. In fact, this FreeBSD version only exists because OpenBSD doesn't support ZFS. However, the advantages of ZFS are hard to ignore when building a NAS: ZFS is designed to ensure data integrity, even in the face of hardware failures or other types of corruption. It uses checksums to detect and correct errors in data, and can automatically repair corrupted data using redundant copies of data stored on other disks. This little extra layer of protection can help ensure that your data remains secure and usable even when using external USB drives, which often lack SMART diagnostics.

Another reason is data compression: ZFS includes built-in data compression, which will help save disk space and improve performance by reducing the amount of data that needs to be read from or written to disk.


<!-- All disks will need to be formatted, some will be encrypted -->



<!-- ### Data disks -->
### Data RAID

Create a new partition table on the each data disk (`daX`) using the GPT (GUID Partition Table) scheme and add a new partition of type `freebsd-zfs`:

```sh
gpart destroy -F daX
gpart create -s GPT daX
gpart add -t freebsd-zfs -l dataX daX
```

Below, we create a ZFS pool `storage` on the two disk drives in a mirror configuration (RAID 1) and encrypt it with a passphrase. The pool itself is configured to not have a default mount point so that only the volumes themselves are automatically mounted.  Two ZFS datasets ("file systems") are created in the `storage` pool: `data` and `data/shared`. The shared dataset is configured with a quota of 500 GB, but this is optional. (`/dev/daXp1` and `/dev/daYp1` are the partitions we created above.)

```sh
zpool create -O encryption=aes-256-gcm -O keylocation=file:///etc/pragnastic/storage_pool.pw -O keyformat=passphrase -O compression=zstd -O mountpoint=none storage mirror /dev/daXp1 /dev/daYp1
zfs create -o mountpoint=/vol/storage/data storage/data
zfs create -o quota=500G -o mountpoint=/vol/storage/data/shared storage/data/shared
```

If one is not careful it's possible to destroy ZFS datasets or pools without any chance of recovery. Luckily, there's a simple way to prevent accidental deletion: snapshots with holds. In ZFS, *snapshots* are point-in-time read-only copies of a dataset or pool and *holds* are used to prevent snapshots from being deleted. Below we're creating snaphots of the just created data pool and datasets:

```sh
zfs snapshot storage@empty
zfs snapshot storage/data@empty
zfs snapshot storage/data/shared@empty
zfs hold safety_hold storage@empty
zfs hold safety_hold storage/data@empty
zfs hold safety_hold storage/data/shared@empty
```

### Backup volumes

Similar to the data diska above, we create a new partition table on the each backup disk with a GUID partition table and add a partition of type `freebsd-zfs`:

```sh
gpart destroy -F daX
gpart create -s GPT daX
gpart add -t freebsd-zfs -l backupY daX
```

This command creates a new ZFS pool named backupY

This command creates a new ZFS dataset named restic-repo inside the backupY pool. The -o flag sets the mountpoint property for the new dataset to /vol/backup/backupY/restic-repo, meaning that the dataset will be mounted at that location in the file system.

```sh
zpool create -O compression=zstd -O mountpoint=none backupY /dev/daXp1
zfs create -o mountpoint=/vol/backup/backupY/restic-repo backupY/restic-repo
```

The instructions below create one large partition on each backup disk. .......

...



## Install PragNAStic

The easiest way to install PragNAStic is to use the `install.sh` script. 

...... It will ask you some configuration questions, put all scripts and config files in the right locations, and setup your `/vol` directory. .....

...

```sh
# get PragNAStic
git clone https://github.com/thndrbrrr/pragnastic
cd ........

```

### Cron jobs

Three cron jobs are needed to run PragNAStic:

- data backup job, running every 10 minutes
- server backup job, running once nightly
- RAID status check, running every minute

Sample entries can be found in `server/conf/crontab`, and if you've installed PragNAStic in the default location and are using the default location `/vol` for mounting drives then you can just copy-paste that into `root`'s `crontab`, or append it like so:

```sh
# pipe current crontab into a temporary file
$ doas crontab -l >tmp_crontab

# append PragNAStic cron jobs
$ cat server/conf/crontab >>tmp_crontab

# install updated crontab
$ doas cronab tmp_crontab
```

**Note:** It is recommended to install the cron jobs only once you've verified that things are working as expected. Therefore read on through the usage section below, mount the drives, perform a backup as well as a RAID check using the `pragnastic` command, and *then* install the cron jobs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

It's a good idea to provide a non-root user with permissions to run `pragnastic` using `doas`:

```sh
echo "permit persist alice as root cmd pragnastic" >>/etc/doas.conf
```

The `pragnastic` command can be used to:

- backup a directory and optionally prune backup repo
- check status of data softraid
- mount and unmount drives
- display various information such as:
  - PragNAStic log
  - remaining free space on disks 
  - list of snapshots in a backup repo
  - contents of a snapshot

```sh
$ pragnastic
# > usage: pragnastic backup backup_path [unison_pruning_opts]
# >        pragnastic mount all|backup|data
# >        pragnastic raidcheck
# >        pragnastic show log|softraid|volumes
# >        pragnastic show snapshot snapshot_id
# >        pragnastic show snapshots [primary|secondary]
# >        pragnastic unmount all|backup|data
```

Mount data drive and backup drives:

```sh
$ doas pragnastic mount all
# > disk backup0 found at /dev/sd3a
# > disk backup1 found at /dev/sd5a
# > /dev/sd3a mounted on /vol/backup0 OK
# > /dev/sd5a mounted on /vol/backup1 OK
# > disk data0 found at /dev/sd1a
# > disk data1 found at /dev/sd2a
# > softraid /dev/sd4a created with chunks /dev/sd1a and /dev/sd2a
# > /dev/sd4a mounted on /vol/data OK
```

Unmount all drives:

```sh
$ doas pragnastic unmount all
# > /vol/data unmounted OK
# > softraid sd4 detached OK
# > /vol/backup0 unmounted OK
# > /vol/backup1 unmounted OK
```
... 2BContinued ...

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Setting up clients

SEE HERE

<p align="right">(<a href="#readme-top">back to top</a>)</p>

--------

<div align="center">
Copyright (c) 2023 <a href="mailto:thndrbrrr@gmail.com">thndrbrrr</a>
</div>