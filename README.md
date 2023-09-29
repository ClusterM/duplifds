# DupliFDS
Famicom Disk System copier. Just an open source alternative for Disk Hacker/Disk Keeper. Also, it's optimized for usage with [FDSKey](https://github.com/ClusterM/fdskey) and has nice interface.

![image](https://github.com/ClusterM/duplifds/assets/4236181/9f52a426-2f7d-4f4e-a05d-eb1aad8ef14d)

## How to use
1. Start this application from disk or FDSKey.
2. Insert source disk (physical or emulated).
3. Insert target disk (physical or emulated).
4. Repeat steps 2-3 until the copy operation is completed.

## Important notes
* While ROM transferring between FDSKey and TwinFamicom there can be problems with disk detection when Port C is not connected to anything, because there is no pull-up resistor inside Twin Famicom. You can press **select** button to activate "confirm disk insertion" mode. In this mode DupliFDS will prompt you to press **start** after the disk is inserted.
* Sometimes when transferring large files, screen can go blank. It's because DupliFDS is using video memory as additional storage for data. You will be warned in such case.
Work in progress.
* Please note that if you want to write physical disks, you need to remove the copy protection on your physical drive if it has any. In most cases, it's not such a difficult process.

## Where to download
You can always download the latest version at https://github.com/ClusterM/duplifds/releases.

Also, you can download automatic interim builds at http://clusterm.github.io/duplifds/.

## Donate
* [Buy Me A Coffee](https://www.buymeacoffee.com/cluster)
* [Donation Alerts](https://www.donationalerts.com/r/clustermeerkat)
* [Boosty](https://boosty.to/cluster)
* BTC: 1MBYsGczwCypXhMBocoDQWxx7KZT2iiwzJ
* PayPal is not available in Armenia :(
