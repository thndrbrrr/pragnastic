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

The `oksh` package in FreeBSD is an implementation of the OpenBSD Korn shell. Since PragNAStic was originally conceived for OpenBSD, rather than rewriting the scripts to work with the different shell, using the `oksh` package allows the scripts to continue running on FreeBSD with minimal modification. This is because oksh is an implementation of the OpenBSD Korn shell, which is similar enough to the original shell used in the scripts to maintain compatibility.

## Mail setup

PragNAStic sends notifications when things misbehave. On FreeBSD the scripts use `msmtp` rather than `sendmail`, because `msmtp` is much simpler to use and configure.

## System config

SSH is needed so that Windows and MacOS clients can mount file systems, and Unison uses SSH as well for transport. `ntpd` should also be running for accurate timekeeping and reliable file server operations. It helps ensure that file modification times are correct, logging and auditing are accurate, and that cron jobs are on time. The services `zfs` service and `zfskeys` (provides encryption support) need to be runnning for everything ZFS:

```sh
service sshd enable
service ntpd enable
service zfs enable
service zfskeys enable
```

## Install PragNAStic

The easiest way to install PragNAStic is to use the `install.sh` script. It will ask for the backup repository password, the `storage` pool password, and where to send email notifications to, and will then put all scripts and config files in the right locations.

```sh
git clone https://github.com/thndrbrrr/pragnastic
cd pragnastic/server/freebsd
./install.sh
```

### Cron jobs

Three cron jobs are needed to run PragNAStic:

- data backup job, running every 10 minutes
- server backup job, running once nightly
- ZFS pool status check, running every minute

Sample entries can be found in `server/freebsd/conf/crontab`, and if you've installed PragNAStic in the default location and are using PragNAStic's default location `/vol` for mounting drives then you can just copy-paste that into `root`'s `crontab`, or append it like so:

```sh
# pipe current crontab into a temporary file
$ doas crontab -l >tmp_crontab

# append PragNAStic cron jobs
$ cat server/conf/crontab >>tmp_crontab

# install updated crontab
$ doas cronab tmp_crontab
```

**Note:** It is recommended to install the cron jobs only once you've verified that things are working as expected. Therefore read on through the usage section below, mount the drives, perform a backup as well as a status check using the `pragnastic` command, and *then* install the cron jobs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Disk management with ZFS

Initially, PragNAStic was developed for OpenBSD, but later it was updated to work with FreeBSD, primarily to leverage the benefits of ZFS, which is not supported by OpenBSD.

ZFS offers numerous benefits that make it an ideal choice for building a robust NAS: ZFS is designed to ensure data integrity, even in the face of hardware failures or other types of corruption. It uses checksums to detect and correct errors in data, and can automatically repair corrupted data using redundant copies of data stored on other disks. This little extra layer of protection can help ensure that your data remains secure and usable even when using external USB drives, which often lack SMART diagnostics. Another advantage is data compression: ZFS includes built-in data compression, which helps save disk space and improves performance by reducing the amount of data that needs to be read from or written to disk.

Let's assume that your two data disks are `da1` and `da2`, and your backup disks are `da3` and `da4`. When you follow the instructions below you should end up a disk setup such as this:

| Devices | ZFS pool[/dataset] | Mountpoint |
|---|---|---|
| `/dev/da1p1` and `/dev/da2p1` | `storage` | N/A |
|  | `storage/data` | `/vol/storage/data` |
|  | `storage/data/shared` | `/vol/storage/data/shared` |
| `/dev/d3p1` | `backup0` | N/A |
|  | `backup0/restic-repo` | `/vol/backup/backup0/restic-repo` |
| `/dev/d4p1` | `backup1` | N/A |
|  | `backup1/restic-repo` | `/vol/backup/backup1/restic-repo` |

Note that your actual device numbers might be different and that, even if device names should change between reboots, ZFS will still recognize all pools and datasets.

### Data RAID

Create a new partition table on the each data disk (`daX`, e.g. `da1` or `da2`) using the GPT (GUID Partition Table) scheme and add a new partition of type `freebsd-zfs`:

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

The backup part of PragNAStic uses two unencrypted single device ZFS pools to store backup data. Despite using single drive pools, backups are still kept redundant by maintaining two independent backup pools and syncing their data using Restic. The advantage of using unencrypted single drive ZFS pools is that they are easy to remove and attach to another system, making them easily accessible for recovery purposes, while allowing for efficient copying of the backup repository without having to copy the entire disk or needing to decrypt the disk.

Similar to the data disk above, we create a new partition table on each backup disk with a GUID partition table and add a partition of type `freebsd-zfs`:

```sh
gpart destroy -F daX
gpart create -s GPT daX
gpart add -t freebsd-zfs -l backupY daX
```

We now create a ZFS pool named `backupY` in partition `daXp1`, and then a dataset named `restic-repo` in pool `backupY`. Like above, the mountpoint flags are set in a way that the pool itself is not mounted automatically, but the dataset will be mounted at `/vol/backup/backupY/restic-repo`.

```sh
zpool create -O compression=zstd -O mountpoint=none backupY /dev/daXp1
zfs create -o mountpoint=/vol/backup/backupY/restic-repo backupY/restic-repo
```

Add snapshots and holds to prevent accidental deletion:

```sh
zfs snapshot backup0@empty
zfs snapshot backup1@empty
zfs snapshot backup0/restic-repo@empty
zfs snapshot backup1/restic-repo@empty
zfs hold safety_hold backup0@empty
zfs hold safety_hold backup1@empty
zfs hold safety_hold backup0/restic-repo@empty
zfs hold safety_hold backup1/restic-repo@empty
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Adding users

For PragNAStic users, it is necessary to create a directory with the user's name under `/vol/storage/data`. The created directory should be owned by the user and the user's group:

```sh
adduser alice
mkdir /vol/storage/data/alice
chown alice:alice /vol/storage/data/alice
```

### Shared data

`/vol/storage/data/shared` serves as a place where shared data between users can be kept. In the example below we create a Unix group called `shared` that users `bob` and `alice` are members of, and then update the permissions of `/vol/storage/data/shared` so that both users can read and write to it, but others cannot:

```sh
pw groupadd shared
pw groupmod shared -m bob
pw groupmod shared -m alice
chgrp shared /vol/storage/data/shared
chmod 770 /vol/storage/data/shared
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

It's a good idea to provide a non-root user with permissions to run `pragnastic` using `doas`:

```sh
echo "permit persist alice as root cmd pragnastic" >>/etc/doas.conf
```

The `pragnastic` command focuses on ease of use and convenience and can be used to:

- backup a directory and optionally prune backup repo
- check status of data softraid
- mount and unmount drives
- display various information such as:
  - PragNAStic log
  - remaining free space on disks 
  - list of snapshots in a backup repo
  - contents of a snapshot

Subcommands `backup`, `mount`, `show snapshots`, `show snapshot` and `unmount` require superuser privileges and should therefore be run with `doas`. Mounting and unmounting shouldn't be necessary as that's handled by ZFS at startup time.

```sh
$ pragnastic
# > usage: pragnastic backup backup_path [restic_pruning_opts]
# >        pragnastic mount all|backup|data
# >        pragnastic check
# >        pragnastic show log|volumes
# >        pragnastic show snapshot snapshot_id [primary|secondary]
# >        pragnastic show snapshots [primary|secondary]
# >        pragnastic unmount all|backup|data
```

Backup data directories:

```sh
$ doas pragnastic backup "/vol/storage/data /vol/storage/data/shared"
# > 2023-04-02 10:17:00 [57232] backing up /vol/storage/data /vol/storage/data/shared
# > repository 04d13d32 opened (repository version 2) successfully, password is correct
# > using parent snapshot 88f32be3
# > [...]
# > snapshot 2a32ef52 saved
# > 2023-04-02 10:17:21 [57232] primary backup of /vol/storage/data /vol/storage/data/shared completed OK
# > 2023-04-02 10:17:21 [57232] skipped pruning: no pruning options were provided
# > 2023-04-02 10:17:21 [57232] syncing backup repos /vol/backup/backup0/restic-repo and /vol/backup/backup1/restic-repo
# > 2023-04-02 10:17:27 [57232] primary to secondary backup sync OK
# > 2023-04-02 10:17:30 [57232] secondary to primary backup sync OK
# > 2023-04-02 10:17:30 [57232] pragnastic-backup completed OK, done
```

You can check the status of all volumes. If email notifications have been configured, this command will automatically send an alert email in the event of any issues, but only if the status has changed since the last check. Duplicate emails are thereby prevented:

```sh
$ pragnastic check
# > 2023-04-02 10:26:25 ZFS pool status: all pools are healthy
```

Show the PragNAStic log:

```sh
$ pragnastic show log
# > showing last 100 lines of /var/log/pragnastic:
# > [...]
# > 2023-04-02 10:10:47 [57097] pragnastic-backup completed OK, done
# > 2023-04-02 10:20:00 [57276] backing up /vol/storage/data /vol/storage/data/shared
# > using parent snapshot 2a32ef52
# > [...]
# > snapshot b7b333ee saved
# > 2023-04-02 10:20:21 [57276] primary backup of /vol/storage/data /vol/storage/data/shared completed OK
# > 2023-04-02 10:20:21 [57276] pruning previous snapshots of /vol/storage/data /vol/storage/data/shared with policy "--keep-last 6 --keep-within-hourly 1d --keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 100y"
# > 2023-04-02 10:20:28 [57276] primary backup pruned OK
# > 2023-04-02 10:20:36 [57276] secondary backup pruned OK
# > 2023-04-02 10:20:36 [57276] syncing backup repos /vol/backup/backup0/restic-repo and /vol/backup/backup1/restic-repo
# > 2023-04-02 10:20:41 [57276] primary to secondary backup sync OK
# > 2023-04-02 10:20:46 [57276] secondary to primary backup sync OK
# > 2023-04-02 10:20:46 [57276] pragnastic-backup completed OK, done
```

`pragnastic show volumes` shows status information about the capacity and health of all relevant ZFS pools:

```sh
$ pragnastic show volumes
# > Filesystem             Size    Used   Avail Capacity  Mounted on
# > backup1/restic-repo    3.5T    591G    2.9T    16%    /vol/backup/backup1/restic-repo
# > backup0/restic-repo    3.5T    591G    2.9T    16%    /vol/backup/backup0/restic-repo
# > storage/data           1.7T    568G    1.2T    32%    /vol/storage/data
# > storage/data/shared    500G     42G    458G     8%    /vol/storage/data/shared
# > 
# > NAME      SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
# > backup0  3.62T   591G  3.05T        -         -     0%    15%  1.00x    ONLINE  -
# > backup1  3.62T   591G  3.05T        -         -     0%    15%  1.00x    ONLINE  -
# > storage  1.81T   612G  1.22T        -         -     0%    32%  1.00x    ONLINE  -
# > 
# >   pool: backup0
# >  state: ONLINE
# >   scan: scrub repaired 0B in 02:06:17 with 0 errors on Sun Apr  2 05:11:54 2023
# > config:
# > 
# > 	NAME        STATE     READ WRITE CKSUM  SLOW
# > 	backup0     ONLINE       0     0     0     -
# > 	  da2       ONLINE       0     0     0     0
# > 
# > errors: No known data errors
# > 
# >   pool: backup1
# >  state: ONLINE
# >   scan: scrub repaired 0B in 02:01:56 with 0 errors on Sat Apr  1 05:03:26 2023
# > config:
# > 
# > 	NAME        STATE     READ WRITE CKSUM  SLOW
# > 	backup1     ONLINE       0     0     0     -
# > 	  da0       ONLINE       0     0     0     0
# > 
# > errors: No known data errors
# > 
# >   pool: storage
# >  state: ONLINE
# >   scan: scrub repaired 0B in 02:42:12 with 0 errors on Fri Mar 31 05:43:30 2023
# > config:
# > 
# > 	NAME        STATE     READ WRITE CKSUM  SLOW
# > 	storage     ONLINE       0     0     0     -
# > 	  mirror-0  ONLINE       0     0     0     -
# > 	    da3     ONLINE       0     0     0     0
# > 	    da1     ONLINE       0     0     0     0
# > 
# > errors: No known data errors
```

Show all available backup snapshots (use `pragnastic show snapshots secondary` to show snapshots in the secondary backup repository):

```sh
$ doas pragnastic show snapshots
# > showing snapshots of primary backup repository at /vol/backup/backup0/restic-repo
# > repository 04d13d32 opened (repository version 2) successfully, password is correct
# > ID        Time                 Host            Tags        Paths
# > -----------------------------------------------------------------------------------
# > [...]
# > b79740a4  2023-04-02 02:50:00  xyz.foogoo.net              /vol/storage/data
# >                                                            /vol/storage/data/shared
# > 
# > 555ca64e  2023-04-02 03:05:00  xyz.foogoo.net              /etc
# >                                                            /home
# >                                                            /root
# >                                                            /usr/local/bin
# >                                                            /usr/local/etc
# >                                                            /usr/local/libexec
# >                                                            /usr/local/sbin
# >                                                            /var
# > 
# > cacee42a  2023-04-02 03:50:00  xyz.foogoo.net              /vol/storage/data
# >                                                            /vol/storage/data/shared
# > [...]
# > b7b333ee  2023-04-02 10:20:00  xyz.foogoo.net              /vol/storage/data
# >                                                            /vol/storage/data/shared
# > 
# > 8c8204a4  2023-04-02 10:30:00  xyz.foogoo.net              /vol/storage/data
# >                                                            /vol/storage/data/shared
# > -----------------------------------------------------------------------------------
# > 73 snapshots
```

Inspect a specific snapshot:

```sh
$ doas pragnastic show snapshot 8c8204a4
# > snapshot 8c8204a4 of [/vol/storage/data /vol/storage/data/shared] filtered by [] at 2023-04-02 10:30:00.044766738 -0700 PDT):
# > /vol
# > /vol/storage
# > /vol/storage/data
# > /vol/storage/data/bob
# > /vol/storage/data/bob/netdrive
# > /vol/storage/data/bob/netdrive/somefile.txt
# > [...]
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

--------

<div align="center">
Copyright (c) 2023 <a href="mailto:thndrbrrr@gmail.com">thndrbrrr</a>
</div>
