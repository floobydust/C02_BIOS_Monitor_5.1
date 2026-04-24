# C02_BIOS_Monitor_5.1
Updated BIOS and Monitor for C02 Pocket Prototype V3

This is a minor update to my 5.0 BIOS and Monitor code to support a 3.3-volt prototype system.
 - full support of my DOS/65 Version 3.21 release

Some changes/fixes have been made to the Disk BIOS support:
 - handles disk errors and performs a software reset of the Microdrive.
 - provides a 5-second timeout to allow invoking the Monitor when booting from the disk.

The Partition Block code is unchanged, but does work with this BIOS version.
 - BIOS will load and verify the partition block when booting up, provided a Disk is found.
 - user timeout will be shown is the partition block is valid, else the Monitor is invoked.
 - the Boot Block code still needs work and will also require an updated MD_Utility for Disk setup.

Also provided is an updated MD_Utiliity v0.91
 - handles errors in block calculations if out of range.
 - fixed some hard-coded memory locations to the assigned variables
 - increased benchmarking size to 32KB block transfers and 1024 blocks (32MB read or write).

A new RTC_Utility will be provided at a later date.
 - this will handle EPOCH time reading and writing for the DS1318 RTC device.
 - sensing for the DS1318 is currently in the BIOS 5.1

As always, I'm still using the WDC Assembler/Linker. The source can be easily modified to use a different Assembler/Linker if desired.

Regards, KM
