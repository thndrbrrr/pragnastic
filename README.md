<a name="readme-top"></a>

<div align="center">
<h3>PragNAStic<h3>
<p>**Network-attached storage with integrated backup**</p>
<p>Safe • Secure • Flexible</p>
</div>

<p align="center"><img src="docs/images/overview.png"/></p>

## Features

- **Flexibility** - three "types" of drives:
  - **SyncDrive:** local directory that's synced every minute with the server and is available offline (pretty much like Google Drive), also supports syncing with multiple computers (Windows and macOS supported)
  - **NetDrive:** classic network drive (only available when connected)
  - **SharedDrive:** like NetDrive, but shared between all users
- **Safety through redundancy**
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

TBDocumented

### Prepare disks

This assumes you're doing this with OpenBSD.

**Backup disks**

For each backup disk:

```sh
fdisk -g sdX

disklabel -Eh sdX
  sdX> z # delete all partitions
  sdX*> a a
  offset: [...]
  size: [...]
  FS type: [4.2BSD]
  sdX*> q

newfs /dev/rsdXa
```

**Data disks**

For each data disk:

```sh
# Erase any previous softraid params
dd if=/dev/zero of=/dev/rsdXc bs=1m count=8 

# Write GPT
fdisk -g sdX

echo 'RAID 1M-* 100%' >disklabel_raid_template
disklabel -wAT disklabel_raid_template sdX
```

**Data softraid**

```sh
bioctl -c 1C -l /dev/sdXa,/dev/sdYa softraid0

# Assuming softraid is now on /dev/sdZ
dd if=/dev/zero of=/dev/rsdZc bs=1m count=1
fdisk -g sdZ
printf "a\n\n\n\n4.2BSD\nw\nq\n" | disklabel -E sdZ
newfs /dev/rsdZa
```

### Server

TBDocumented

```sh
install.sh
```

### macOS

TBDocumented

### Windows

TBDocumented

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
Copyright (c) 2023 <a href="mailto:thndrbrrr@gmail.com">thndrbrrr@gmail.com</a>
</div>
