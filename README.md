tinycorelinux-packer-image
==========================

This script will create a remastered
[tinycorelinux](http://distro.ibiblio.org/tinycorelinux/) image that can be
used in [Packer](http://www.packer.io/).


Why would I want this?
----------------------

You want this if you need a mean and lean Linux that starts in RAM. This is
useful to create Packer images from distributions that don't provide an
installation medium that can be directly used by Packer. 


Packer Configuration
--------------------

  * A user `packer` with password `packer` is added
  * Autologin is disabled
  * Configures and starts opensshd
  * Installs Bash
  * Adds SCSI drivers and loads them during boot
  

Customization
-------------

It's easily possible to add additional
[extensions](http://distro.ibiblio.org/tinycorelinux/5.x/x86/tcz/) to the
image. Just add the names of the extensions to the `EXTENSIONS` array in the
script. 

Adding additional changes to configurations in the image can be added to the 
`customize*` functions.


Preconditions
-------------

You need a few tools to run this script. It was developed on RHEL but should run
on any linux that has the following tools available:

  * unsquashfs (squashfs-tools)
  * advdef (advancecomp) 
  * mkisofs (mkisofs)


Packer Example
--------------

```
{
  "builders": [
    {
      "type": "vmware-iso",
      "iso_url": "tinycore-packer.iso",
      "iso_checksum_type": "md5",
      "iso_checksum": "d3253d19bcf9da61cbb44cf76db118c6",
      "boot_wait": "3s",
      "disk_size": 40960,
      "disk_type_id": 0,
      "boot_command": [ "<enter>" ],
      "ssh_username": "packer",
      "ssh_password": "packer",
      "skip_compaction": false
    }
  ]
}
```
