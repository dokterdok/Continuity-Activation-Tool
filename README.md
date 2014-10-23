Continuity-Activation-Tool
=========================

This tool makes the necessary changes to enable OS X 10.10 Continuity on compatible hardware. Continuity features activated by this tool include Application Handoff, Instant Hotspot, and Airdrop iOS<->OSX.

## Features
* Activate continuity: Does a Continuity compatibility check, backups the original Systems kexts, disables a Mac-model blacklist in the Buetooth kext, whitelists the Mac board-id in the Wi-Fi kext.
* System diagnostic: Produces a report of the current system parameters influencing Continuity.

## Compatibility list
The tool should work with the following Mac models:

Mac Model | Hardware change required first
---|:---:
MacBook Air 2008-2010 | New wireless card: BCM94360CS2
MacBook Air mid-2011 | no
Mac mini 2009-2010 | New wireless card
Mac mini mid-2011 | no
MacBook Pro mid 2009 to late 2011 | New wireless card: BCM94331PCIEBT4CAX
iMac 2008-2011 | Wi-Fi + Bluetooth card upgrade
MacBook Pro late-2011 | New wireless card: BCM94331PCIEBT4CAX

Macs that are unlisted above have no use of this tool but might still need a hardware upgrade. Table source and more info:[UncleSchnitty's guide](http://forums.macrumors.com/showpost.php?p=20124161) for an up-to-date table and more info.
**The tool is not compatible with BT4 USB Dongles**, it only works with the right internal Apple wireless hardware.

### Sources
[Full guide to enable Continuity manually (MacRumors Forum Thread)](http://forums.macrumors.com/showpost.php?p=20124161)
[Get help using Continuity with iOS 8 and OS X (Apple Support KB)](http://support.apple.com/kb/TS5458)


### Thanks
* Lem3ssie
* UncleSchnitty
* Skvo
* TealShark
* Manic Harmonic
* rob3r7o