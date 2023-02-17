<a name="readme-top"></a>

<div align="center">
 <img width="200px" src="docs/images/pragnastic_tmp_logo_3.png"/>
<h3>PragNAStic</h3>
<p><b>Network-attached storage with integrated backup</b><br/>
Safe • Secure • Flexible</p>
</div>

## Overview

PragNAStic is a network-attached storage solution (NAS) for home or small office use with an emphasis on safety and security – while keeping it simple. Simple as in: off-the-shelf hardware and straightforward operation.

<p align="center"><img src="docs/images/overview_diagram_simple.png"/></p>

Users have access to their own network drive, a shared network drive, and a *SyncDrive*, which, similar to Google Drive, synchronizes files between a local directory and the server for offline availability:

<p align="center"><img src="docs/images/syncdrive_2.png"/></p>

## Features

- **Flexibility** - three "types" of drives:
  - **SyncDrive:** local directory that's synced every minute with the server and is available offline (pretty much like Google Drive), also supports syncing with multiple computers (Windows and macOS supported)
  - **NetDrive:** classic network drive (only available when connected)
  - **SharedDrive:** like NetDrive, but shared between all users
- **Safety through redundancy and backups**
    - two powered USB hubs, each connecting one data disk and one backup disk
    - two data disks operating as an encrypted RAID 1 (mirroring)
    - two backup disks, each containing an independant encrypted backup repo
        <!-- - makes it easy to create multiple copies of a backup: just copy the repo directory -->
    - backups repos are synced
- **Security**
  - all connections secured through SSH
  - server scripts written for OpenBSD
  - backup repos are encrypted
  - data disks are encrypted
- **Email notifications**
  - when backups fail
  - when data RAID is degraded
- **Pragmatic**
  - no frills, bells, or whistles, but gets the job done
  
### Backups

- scope
    - all data (NetDrives, SyncDrives, SharedDrive)
    - select server directories
- data backups run every 10 minutes
    - backup to primary, fallback to secondary
    - prune backup repos
    - sync backup repos
- saving space (and time)
    - backups are incremental
    - backup repos are pruned after every backup run
- backup retention for data
    - all 10 min snapshots within the last hour
    - all hourly snapshots within the last 24h
    - all daily snapshots within the last week
    - all weekly snapshots within the last month
    - all monthly snapshots within the last year
    - all yearly snapshots
- backup retention for server directories: last 30 daily backups

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Installation

While operation is supposed to be straightforward, the installation still involves a few non-trivial steps. Knowledge of Unix-like operating systems and network configuration is required.

<!-- 2BContinued -->

### Server configuration

A few general notes:

- Give the server that runs PragNAStic a fixed IP address. It avoids headaches.
- A server connected to your router or gateway via an ethernet cable will be faster and won't compete for wifi bandwidth.
- If you want to receive email notifications then you will need to configure your server's primary mail system accordingly. On OpenBSD that's by default `smtpd`, but any alternative system that allows PragNAStic to send email via the `mail` command is fine.

From here on the instructions assume that you are the `root` user on an OpenBSD system.

```sh
# Install required packages
pkg_add restic
pkg_add unison--no_x11
```

### Prepare disks

<!-- All disks will need to be formatted, some will be encrypted -->

**Data disks**

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

**Data softraid**

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

**Backup disks**

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

### Install PragNAStic

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

**Cron jobs**

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

PragNAStic provides scripts for macOS and Windows to:

- mount and unmount NetDrive and SharedDrive
- synchronize SyncDrive

macOS and Windows only (for now) ... all you others on different operating systems will probably know what to do. :-P

The scripts make use of Unison and SSHFS. The [installation instructions for Unison](https://github.com/bcpierce00/unison/wiki/Downloading-Unison) will tell you what you need to do, depending on whether you are on macOS or Windows. Instructions for installing SSHFS for your operating system are given below in the respective OS section.

### macOS

All macOS scripts read what they need to know from a config file `~/.pragnastic.conf` in your home directory. Here's the sample from `client/macos/pragnastic.conf`:

```
netdrive_remote=alice@example.com:/vol/data/alice/netdrive
netdrive_local=~/NetDrive
shareddrive_remote=alice@example.com:/vol/data/shared
shareddrive_local=~/SharedDrive

syncdrive_lockfile=~/.pragnastic.syncdrive.lock
unison_executable=/usr/local/bin/unison
unison_profile=alice
lockfile_age_notification_threshold=120  # 2 mins (notifications currently only work on macOS)
```

You might notice that the location of a user's SyncDrive is not configured in there: that is because SyncDrive uses [Unison](https://github.com/bcpierce00/unison) to synchronize remote and local directories, and Unison reads that kind of information from a Unison profile. The config file above will have Unison use profile `alice`, which means it expects to find the file `~/.unison/alice.prf`.

Look at some sample profiles in `client/conf/unison` as well as [Unison's excellent documentation](https://www.cis.upenn.edu/~bcpierce/unison/download/releases/stable/unison-manual.html) to create your Unison profile, then copy the file to `~/.unison` and don't forget to update the `unison_profile` variable in `~/.pragnastic.conf` accordingly.

**Prerequisites: local directories, Unison configuration, SSHFS**

The commands below will create directories for SyncDrive, NetDrive, and SharedDrive as well as copy the `common` configuration for Unison:

```sh
$ cd ~
$ mkdir {SyncDrive,SharedDrive,NetDrive}
$ mkdir .unison
$ cp location/of/pragnastic/client/conf/unison/common .unison
# ... and don't forget to add your Unison profile to ~/.unison
```

Next, download macFUSE and SSHFS from the [macFUSE homepage](https://osxfuse.github.io/) and install both.

**SyncDrive**

On macOS, SyncDrive is run via `cron`. There is a sample `crontab` in `client/macos/crontab`:

```text
PRAGNASTIC_CLIENT_DIR=/some/path/to/pragnastic/client/macos
* * * * * $PRAGNASTIC_CLIENT_DIR/pragnastic-syncdrive.sh >>$HOME/.pragnastic.syncdrive.log 2>&1
```

Adjust `PRAGNASTIC_CLIENT_DIR` variable as needed and use `crontab -e` to install it.

Setting it up like this will have SyncDrive keep a log file in `~/.pragnastic.syncdrive.log`.

SyncDrive will skip synchronization if the lock file already exists. Sometimes synchronization runs can last longer than a minute, therefore this will happen occasionally. After a certain amount of time, per default 2 minutes, SyncDrive will display a notification on the desktop though, just so you know that something is slightly out of the ordinary. You can change how long to wait before showing a notification with variable  `lockfile_age_notification_threshold` in `~/.pragnastic.conf`.

**NetDrive and SharedDrive**

Since you configured the remote and local locations of those drives in `~/.pragnastic.conf` you can simply run the following to mount NetDrive and SharedDrive:

```sh
$ client/macos/pragnastic-mount-drives.sh
```

Unmount both drives:

```sh
$ client/macos/pragnastic-unmount-drives.sh
```

Two things to note here:

- You could add `pragnastic/client/macos` to your `PATH` environment variable if you mount and unmount drives frequently.
- You could run these scripts at login and logout / restart / shutdown.

### Windows

Open Command Prompt as administrator and checkout PragNAStic's GitHub repository into your `C:\Program Files` directory:

```
C:\...> cd "\Program Files"
C:\...> git clone https://github.com/thndrbrrr/pragnastic.git
```

Now open Command Prompt as a regular user to create PragNAStic's configuration directory, place the `pragnastic-conf.bat` configuration file in there, and then open Notepad to edit the file:

```
C:\...> mkdir %HOMEPATH%\AppData\Local\PragNAStic
C:\...> copy "\Program Files\PragNAStic\client\windows\pragnastic-conf.bat" %HOMEPATH%\AppData\Local\PragNAStic
C:\...> notepad %HOMEPATH%\AppData\Local\PragNAStic\pragnastic-conf.bat
```

All Windows scripts read what they need to know from this very config file `%HOMEPATH%\AppData\Local\PragNAStic\pragnastic-conf.bat`, which, when copied from the repository, looks like this:

```
@ECHO OFF

SET NETDRIVE_LOCAL=N:
SET NETDRIVE_REMOTE=\sshfs.kr\alice@example.com/vol/data/alice/netdrive

SET SHAREDDRIVE_LOCAL=S:
SET SHARDEDDRIVE_REMOTE=\sshfs.kr\alice@example.com/vol/shared

SET UNISON_EXECUTABLE=C:\"Program Files"\Unison\bin\unison.exe
SET UNISON_PROFILE=alice
```

Change the user names and paths to match your user name on the PragNAStic server.

**Prerequisites: local directories, Unison configuration, SSHFS**

Download the latest SSHFS release from the [SSHFS-Win](https://github.com/winfsp/sshfs-win) homepage and install it.

Create a `SyncDrive` and a `.unison` directory in your home folder:

```
C:\...> mkdir %HOMEPATH%\SyncDrive
C:\...> mkdir %HOMEPATH%\.unison
```

**SyncDrive**

Create a Unison profile (`client\con\unison\alice.prf` is an example for Windows) and put it, along with `client\conf\unison\common`, into your `%HOMEPATH%\.unison` folder.

Update the Unison profile name in variable `UNISON_PROFILE` in `%HOMEPATH%\AppData\Local\PragNAStic\pragnastic-conf.bat`, and possibly also where the Unison executable is located in case you didn't install it in `C:\Program Files\Unison`.

Launch Task Scheduler and create a task that runs `C:\Program Files\PragNAStic\client\windows\pragnastic-syncdrive.bat` once every minute. (Note: screenshots to follow)

... 2BContinued ...

**NetDrive and SharedDrive**

Mount NetDrive and SharedDrive, which should show up as volumes `N:` and `S:` in File Explorer, respectively:

```sh
client\windows\pragnastic-mount-drives.bat
```

Unmount NetDrive and SharedDrive:

```sh
client\windows\pragnastic-unmount-drives.bat
```

> 👉 You can change the drive letters used by NetDrive and SharedDrive in your PragNAStic configuration file (`%HOMEPATH%\AppData\Local\PragNAStic\pragnastic-conf.bat`).

Windows with SSHFS-Win is pretty good at restoring server connections to remote drives after a reboot. However, if you are running into issues then you could use Task Scheduler to create a task that calls the above scripts to mount the drives when logging in and unmount them when logging out, rebooting, or shutting down.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**. If you have a suggestion that would make this better, please fork the repo and create a pull request. Thank you!

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Adding some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a pull request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## License

Distributed under the ISC license. See [`LICENSE`](LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact

Mail: thndrbrrr@gmail.com

Mastodon: [@torben@mastodon.sdf.org](https://mastodon.sdf.org/@torben)

<p align="right">(<a href="#readme-top">back to top</a>)</p>


## Acknowledgments

In the end, everyone stands on the shoulders of giants.

* [Unison File Synchronizer](https://github.com/bcpierce00/unison)
* [Restic](https://restic.net/)
* [OpenSSH](https://www.openssh.com/)
* [macFUSE](https://osxfuse.github.io/)
* [SSHFS](https://github.com/osxfuse/sshfs)
* [SSHFS-Win](https://github.com/winfsp/sshfs-win)
* [OpenBSD](https://www.openbsd.org/)
* [Stack Overflow](https://stackoverflow.com/)
* Readme based on a template by [Othneil Drew](https://github.com/othneildrew)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

--------

<div align="center">
Copyright (c) 2023 <a href="mailto:thndrbrrr@gmail.com">thndrbrrr</a>
</div>
