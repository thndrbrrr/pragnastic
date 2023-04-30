<a name="readme-top"></a>

<div align="center">
 <img width="200px" src="docs/images/pragnastic_tmp_logo_4.png"/>
<h3>PragNAStic</h3>
<p><b>Network-attached storage with integrated backup</b><br/>
Safe • Secure • Flexible</p>
</div>

## Configuring PragNAStic on OpenBSD

<!-- - If you want to receive email notifications then you will need to configure your server's primary mail system accordingly. On OpenBSD that's by default `smtpd`, but any alternative system that allows PragNAStic to send email via the `mail` command is fine. -->

These instructions assume that you are the `root` user on an OpenBSD system.

```sh
# Install required packages
pkg_add restic
pkg_add unison--no_x11
```

## Prepare disks

<!-- All disks will need to be formatted, some will be encrypted -->

### Data disks

The instructions below create one single RAID partition on each data disk. So for each data disk (`sdX` being the disk's device):

```sh
# erase traces of any previous softraid
dd if=/dev/zero of=/dev/rsdXc bs=1m count=8 

# write GPT
fdisk -g sdX

# write disklabel
echo 'RAID 1M-* 100%' >disklabel_raid_template
disklabel -wAT disklabel_raid_template sdX
```

### Data softraid

The two data disks now need to be setup to become a single, encrypted RAID 1 volume. RAID 1 means that all data is mirrored between both disks, therefore if one should fail you'll be able to continue using PragNAStic without service interruption.

Use a good password to encrypt your data RAID. Something long like `x21VJiDZMcDUtq5TGPyBQsCdwYGrc89uxGp0X2HY` is a great password, something like `abc123` is not.

In the steps below `sdX` stands for the first data disk, `sdY` for the second data disk, and `sdZ` for the new device that is your RAID (which you'll know after running the `bioctl` command below):

```sh
# create softraid device (bioctl will ask for your password)
bioctl -c 1C -l /dev/sdXa,/dev/sdYa softraid0
# > softraid0: RAID 1C volume attached as sdZ

# clear RAID's first sector
dd if=/dev/zero of=/dev/rsdZc bs=1m count=1

# write GPT
fdisk -g sdZ

# create RAID partition
printf "a\n\n\n\n4.2BSD\nw\nq\n" | disklabel -E sdZ

# format RAID with file system FFS
newfs /dev/rsdZa
```

### Backup disks

The instructions below create one large partition on each backup disk. Of course you may choose any other layout, but keep in mind that the partition used for backups should be sizeable. A good rule of thumb could be to have your backup disks twice as large as your data disks.

Prepare each backup disk (`sdX` being the disk's device) as follows:

```sh
# write GPT
fdisk -g sdX

# create partition labels
disklabel -Eh sdX
  sdX> z             # delete all partitions
  sdX*> a a          # add partition "a"
  offset: [...]      # min sector
  size: [...]        # max sector
  FS type: [4.2BSD]  # file system
  sdX*> q            # quit and write disk labels

# format disk with FFS
newfs /dev/rsdXa
```

## Install PragNAStic

The easiest way to install PragNAStic is to use the `install.sh` script. It will ask you some configuration questions, put all scripts and config files in the right locations, and setup your `/vol` directory.

```sh
# get PragNAStic
git clone https://github.com/thndrbrrr/pragnastic
cd pragnastic/server

# find out ids of each disk
sysctl hw.disknames
# > hw.disknames=sd0:0e9ff5fd5a57d42c,sd1:af86c1eb22937213,sd2:48c10d87b7518288,
# > sd3:a8277f65926ca1e8,sd5:b02ae07832e96c3b,sd4:f4dca823fb31f14e

# Run install
./install.sh
# > backup0 disk id: a8277f65926ca1e8
# > backup1 disk id: b02ae07832e96c3b
# > backup repo password (input is not shown): 
# > data0 disk id: af86c1eb22937213
# > data1 disk id: 48c10d87b7518288
# > data RAID password (input is not shown): 
# > notification recipient's email (leave empty to disable): alice@example.com
# > 
# > Installing PragNAStic with this config:
# >   backup0 disk id: a8277f65926ca1e8
# >   backup1 disk id: b02ae07832e96c3b
# >   backup repo password: ****
# >   data0 disk id: af86c1eb22937213
# >   data1 disk id: 48c10d87b7518288
# >   data RAID password: ****
# >   notification recipient: alice@example.com
# > Proceed? [y/N] y
# > done
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
$ doas crontab tmp_crontab
```

**Note:** It is recommended to install the cron jobs only once you've verified that things are working as expected. Therefore read on through the usage section below, mount the drives, perform a backup as well as a RAID check using the `pragnastic` command, and *then* install the cron jobs.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Adding users

For PragNAStic users, it is necessary to create a directory with the user's name under `/vol/data`. The created directory should be owned by the user and the user's group:

```sh
adduser alice
mkdir /vol/data/alice
chown alice:alice /vol/data/alice
```

### Shared data

`/vol/data/shared` serves as a place where shared data between users can be kept. In the example below we create a Unix group called `shared` that users `bob` and `alice` are members of, and then update the permissions of `/vol/data/shared` so that both users can read and write to it, but others cannot:

```sh
groupadd shared
usermod -G shared bob
usermod -G shared alice
mkdir /vol/data/shared
chgrp shared /vol/data/shared
chmod 770 /vol/data/shared
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

Backup data directories:

```sh
$ doas pragnastic backup "/vol/data /vol/data/shared"
# > 2023-04-02 10:17:00 [57232] backing up /vol/data /vol/data/shared
# > repository 04d13d32 opened (repository version 2) successfully, password is correct
# > using parent snapshot 88f32be3
# > [...]
# > snapshot 2a32ef52 saved
# > 2023-04-02 10:17:21 [57232] primary backup of /vol/data /vol/data/shared completed OK
# > 2023-04-02 10:17:21 [57232] skipped pruning: no pruning options were provided
# > 2023-04-02 10:17:21 [57232] syncing backup repos /vol/backup0/restic-repo and /vol/backup1/restic-repo
# > 2023-04-02 10:17:27 [57232] primary to secondary backup sync OK
# > 2023-04-02 10:17:30 [57232] secondary to primary backup sync OK
# > 2023-04-02 10:17:30 [57232] pragnastic-backup completed OK, done
```

Show status of the data RAID:

```sh
$ pragnastic show softraid
# > 2023-04-02 10:17:21 [57232] data softraid status: online (sda4), OK
```

The `raidcheck` subcommand does pretty much the same, but if email notifications have been configured, this command will automatically send an alert email in the event of any issues - but only if the status has changed since the last check. Duplicate emails are thereby prevented:

```sh
$ pragnastic raidcheck
# > 2023-04-02 10:17:21 [57232] data softraid status: online (sda4), OK
```

Show the PragNAStic log:

```sh
$ pragnastic show log
# > showing last 100 lines of /var/log/pragnastic:
# > [...]
# > 2023-04-02 10:10:47 [57097] pragnastic-backup completed OK, done
# > 2023-04-02 10:20:00 [57276] backing up /vol/data /vol/data/shared
# > using parent snapshot 2a32ef52
# > [...]
# > snapshot b7b333ee saved
# > 2023-04-02 10:20:21 [57276] primary backup of /vol/data /vol/data/shared completed OK
# > 2023-04-02 10:20:21 [57276] pruning previous snapshots of /vol/data /vol/data/shared with policy "--keep-last 6 --keep-within-hourly 1d --keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 100y"
# > 2023-04-02 10:20:28 [57276] primary backup pruned OK
# > 2023-04-02 10:20:36 [57276] secondary backup pruned OK
# > 2023-04-02 10:20:36 [57276] syncing backup repos /vol/backup0/restic-repo and /vol/backup1/restic-repo
# > 2023-04-02 10:20:41 [57276] primary to secondary backup sync OK
# > 2023-04-02 10:20:46 [57276] secondary to primary backup sync OK
# > 2023-04-02 10:20:46 [57276] pragnastic-backup completed OK, done
```

Show all available backup snapshots (use `pragnastic show snapshots secondary` to show snapshots in the secondary backup repository):

```sh
$ doas pragnastic show snapshots
# > showing snapshots of primary backup repository at /vol/backup0/restic-repo
# > repository 04d13d32 opened (repository version 2) successfully, password is correct
# > ID        Time                 Host            Tags        Paths
# > -----------------------------------------------------------------------------------
# > [...]
# > b79740a4  2023-04-02 02:50:00  xyz.foogoo.net              /vol/data
# >                                                            /vol/data/shared
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
# > cacee42a  2023-04-02 03:50:00  xyz.foogoo.net              /vol/data
# >                                                            /vol/data/shared
# > [...]
# > b7b333ee  2023-04-02 10:20:00  xyz.foogoo.net              /vol/data
# >                                                            /vol/data/shared
# > 
# > 8c8204a4  2023-04-02 10:30:00  xyz.foogoo.net              /vol/data
# >                                                            /vol/data/shared
# > -----------------------------------------------------------------------------------
# > 73 snapshots
```

Inspect a specific snapshot:

```sh
$ doas pragnastic show snapshot 8c8204a4
# > snapshot 8c8204a4 of [/vol/data /vol/data/shared] filtered by [] at 2023-04-02 10:30:00.044766738 -0700 PDT):
# > /vol
# > /vol/data
# > /vol/data/bob
# > /vol/data/bob/netdrive
# > /vol/data/bob/netdrive/somefile.txt
# > [...]
```
Unmount all drives:

```sh
$ doas pragnastic unmount all
# > /vol/data unmounted OK
# > softraid sd4 detached OK
# > /vol/backup0 unmounted OK
# > /vol/backup1 unmounted OK
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

--------

<div align="center">
Copyright (c) 2023 <a href="mailto:thndrbrrr@gmail.com">thndrbrrr</a>
</div>
