Continuity Activation Tool
==========================

This tool makes the necessary changes to enable OS X 10.10 Continuity on compatible hardware. Continuity features activated by this tool include Application Handoff, Instant Hotspot, and Airdrop iOS<->OSX. 

## Features
* Activate continuity: Does a Continuity compatibility check, backups the original Systems kexts, disables a Mac-model blacklist in the Buetooth kext, whitelists the Mac board-id in the Wi-Fi kext.
* System diagnostic: Produces a report of the current system parameters influencing Continuity.

**Warning:** Users should exercise caution when using the Continuity Activation Tool, as it moves around low level files and there's a possibility it could cause problems. A backup is recommended before attempting to use the tool.

## Compatibility list
Your Mac might need a hardware upgrade in addition to the software patch to be able to work with Continuity. The table below is based on this [guide (forum thread)](http://forums.macrumors.com/showpost.php?p=20124161). If you notice inaccuracies, please open an issue or report it to the guide author.

Mac Model | Hardware change required | Software patch required (e.g. via this tool)
:---|:---|:---
MacBook Air 2008-2010 | Yes, new wireless card BCM94360CS2 | Yes
MacBook Air mid-2011 | No | Yes
MacBook Air 2012-2014 | No (works OTB) | No (works OTB)
MacBook Pro mid-2010 (15" only) | Yes, new wireless card BCM94331PCIEBT4CAX | Yes
MacBook Pro early 2011 to late 2011 (all models) | Yes, new wireless card BCM94331PCIEBT4CAX | Yes
MacBook Pro mid-2012 (non-retina) | No (works OTB)| No (works OTB)
MacBook Pro Retina (all models) | No (works OTB) | No (works OTB)
Mac mini 2009-2010 | Yes, new wireless card BCM94331PCIEBT4CAX | Yes
Mac mini mid-2011 | No | Yes
Mac mini 2012-2014 | No (works OTB) | No (works OTB)
Mac Pro early 2008-2012 | Yes, new wireless card BCM94360CD + adapter | No
Mac Pro 2013-2014 | No (works OTB) | No (works OTB)
iMac 2007-2011 | Yes, new wireless card BCM94360CD + adapter | No
iMac 2012-2014 | No (works OTB) | No (works OTB)

*The tool is currently not compatible with BT4 USB dongles available on the market*, it only works with the right Apple wireless hardware.

## How to use it

**From Finder**

1. Download the ZIP (link on the right) and extract it.
2. Run the app. _Note_: The current user must have admin privileges.
3. Follow the instructions on the screen. Ignore or deny any "Access to accessibility features" prompt.

**From the command line**
The script can also be run right from the command line. It is located in Continuity Activation Tool.app/Contents/MacOS/contitool.sh

Usage example: "./contitool.sh activate"

Script arguments: 
* activate : Starts the activation procedure and does compatibility checks.
* diagnostic : Starts the system compatibility diagnostic.
* forceHack : Starts the activation procedure and skips compatibility checks.

When using the script from the command line, make sure you have the strings binary in the same directory as the script OR, if you have Apple's Command Line Tools installed, edit contitool.sh and set stringsPath="strings".


### Sources
* [Full guide to enable Continuity manually (MacRumors Forum Thread)](http://forums.macrumors.com/showpost.php?p=20124161)
* [Get help using Continuity with iOS 8 and OS X (Apple Support KB)](http://support.apple.com/kb/TS5458)

### Changelog
**v.1.0.1 -  2014.10.24**

* Fixed a boot arguments overwriting bug, that could lead to a system failure in specific cases
* Fixed a kext-dev-mode bug that prevented the OS to disable its drivers protection
* Fixed the strings utility presence check when the script is run from the command line
* Added a disk reparation step at the start of the patching procedure, lowering failure risks on disks with permissions issues
* Added a verification that sudo is still active before patching

**v.1.0.0 - 2014.10.23**

* Initial release

### Thanks
* Lem3ssie (LAUTRU Mehdi)
* UncleSchnitty
* Skvo
* TealShark
* Manic Harmonic
* rob3r7o

This tool took me many days and nights of research and coding. A small PayPal donation would be much appreciated to help with the maintenance and evolution of the app. Thanks!
[Donate](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=dokterdok%40gmail%2ecom&lc=CH&item_name=Continuity%20Activation%20Tool&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted)
