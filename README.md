Continuity Activation Tool
==========================

This tool makes the necessary changes to enable OS X 10.10 Continuity on compatible hardware. Continuity features activated by this tool include Application Handoff, Instant Hotspot, and Airdrop iOS<->OSX. 

## News - 2014.11.24

* **OS X 10.10.1 update**: It is safe to upgrade, but the tool must be re-applied after the upgrade to get Continuity working again. More info and discussion [here](https://github.com/dokterdok/Continuity-Activation-Tool/issues/44).
* **Continuity Activation Tool 2.0** will include experimental support for 3rd party USB BT4.0 dongles. A solution has been identified to enable Continuity on Macs as far back as 2008. Beta enrollment is closed until further notice - No ETA: I will get back in touch with those who signed up if/when I find a stable enough solution. Many thanks for your support!

## Features
* Activate Continuity: Does a Continuity compatibility check, backups the Systems kexts before and after patching, disables a Mac-model blacklist in the Bluetooth kext, whitelists the Mac board-id in the Wi-Fi kext, removes a legacy Wi-Fi kext plugin.
* System Diagnostic: Produces a report of the current system parameters influencing Continuity.
* Uninstall: Rolls back changes applied by the tool. It firsts looks for previous backups made with the tool, and if it can't find any, kexts from the OS X Recovery Disk are reinstalled. It will only reactivate OS kext signature protection if it is sure that all system kexts installed are signed and valid, to prevent potential booting issues with 3rd party tools or hardware.

##Warning
* You should exercise caution when using the Continuity Activation Tool, as it moves around low level files and there's a possibility it could cause problems. Using this tool is at your own risk.
* Always use the latest version of the tool to avoid issues. See the changelog at the bottom to understand what was changed.
* The tool disables the verification of original Apple drivers in order to work, which lowers the overall system security.

## Compatibility list
Your Mac might need a hardware upgrade as well to be able to work with Continuity. The table below is based on this [guide (forum thread)](http://forums.macrumors.com/showpost.php?p=20124161). If you notice inaccuracies, please report them to the guide author and open an issue.

Mac Model | Hardware change required | Software patch required (e.g. via this tool)
:---|:---|:---
MacBook Air late 2010 | Yes, new wireless card BCM943224PCIEBT2BX, see [here](https://github.com/dokterdok/Continuity-Activation-Tool/issues/41#issuecomment-63767699) | Yes
MacBook Air mid 2011 | No | Yes
MacBook Air 2012-2014 | No (works OTB) | No (works OTB)
MacBook Pro mid 2010 (15" only) | Yes, new wireless card BCM94331PCIEBT4CAX, see [guide](http://forums.macrumors.com/showpost.php?p=20269421&postcount=639) | Yes
MacBook Pro early 2011 to late 2011 (all models) | Yes, new wireless card BCM94331PCIEBT4CAX | Yes
MacBook Pro mid 2012 (non-retina) | No (works OTB)| No (works OTB)
MacBook Pro Retina (all models) | No (works OTB) | No (works OTB)
Mac mini mid 2011 | No | Yes
Mac mini 2012-2014 | No (works OTB) | No (works OTB)
Mac Pro early 2008-2012 | Yes, new wireless card BCM94360CD + adapter | No
Mac Pro 2013-2014 | No (works OTB) | No (works OTB)
iMac 2007-2011 | Yes, new wireless card BCM94360CD + adapter | No
iMac 2012-2014 | No (works OTB) | No (works OTB)

**The tool is currently not compatible with BT4 USB Dongles available on the market**, it only works with the right Apple wireless hardware.

## How to use it

**From Finder**

1. Download the zip (link on the right) and extract it.
2. Double-click on the app.
3. Follow instructions on the screen. Ignore or deny any "Access to accessibility features" prompt.

**From the command line**

The script can also be run right from the command line. It is located in Continuity Activation Tool.app/Contents/MacOS/contitool.sh

Usage example: "sudo ./contitool.sh activate"

Script arguments: 
* activate : Starts the activation procedure and does compatibility checks.
* diagnostic : Starts the system compatibility diagnostic.
* forceHack : Starts the activation procedure and skips compatibility checks.
* uninstall : Starts the uninstallation
* uninstallWithRecoveryDisk : Starts the uninstallation, but directly recovers kexts from the OS X Recovery Image

When using the script from the command line, make sure you have the strings binary in the same directory as the script OR, if you have Apple's Command Line Tools installed, edit contitool.sh and set stringsPath="strings".


### Sources
* [Full guide to enable Continuity manually (MacRumors Forum Thread)](http://forums.macrumors.com/showpost.php?p=20124161)
* [Article on the disabling OS security features and related risks (Cindori.org)](http://www.cindori.org/trim-enabler-and-yosemite)
* [Get help using Continuity with iOS 8 and OS X (Apple Support KB)](http://support.apple.com/kb/TS5458)

This tool is taking me many days and nights of research and coding. A small PayPal donation would be much appreciated to help with the maintenance and evolution of the app. Thanks!
[![Donate](https://www.paypalobjects.com/webstatic/en_US/btn/btn_donate_92x26.png)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=dokterdok%40gmail%2ecom&lc=CH&item_name=Continuity%20Activation%20Tool&currency_code=USD&bn=PP%2dDonationsBF%3abtn_donate_LG%2egif%3aNonHosted)

### Changelog

**v.1.1.2 - 2014.11.16**
* Improved uninstallation reliability. It fixes a bug where the uninstaller could in some cases re-activate OS kext signature protection even if unsigned kexts are installed. Trim Enabler users should not use the uninstallation feature from prior versions to avoid risks of issues at boot-time.

**v.1.1.1 - 2014.11.12**
* Further improved reliability with systems that can't find utilities due to an irregular PATH ([#9](https://github.com/dokterdok/Continuity-Activation-Tool/issues/9))

**v.1.1.0 - 2014.11.11**

* **New uninstallation feature**: new option to rollback all system changes applied by the tool. It firsts looks for previous backups made with the tool, and if it can't find any, kexts from the OS X Recovery Disk are used. It will only reactivate OS kext signature protection if it is sure that all system kexts installed are signed. The uninstallation can be also be called from the command line. ([#15](https://github.com/dokterdok/Continuity-Activation-Tool/issues/15), [#21](https://github.com/dokterdok/Continuity-Activation-Tool/issues/21), [#36](https://github.com/dokterdok/Continuity-Activation-Tool/issues/36), [#40](https://github.com/dokterdok/Continuity-Activation-Tool/issues/40), [#45](https://github.com/dokterdok/Continuity-Activation-Tool/issues/45))
* **Speed improvements**: activating Continuity is now twice as fast compared to the last version: only 1 reboot at the end and 1 permissions repair are necessary.
* **Reliability improvements:**
* The diagnostic no longer applies boot-args changes ([#1](https://github.com/dokterdok/Continuity-Activation-Tool/issues/1))
* Fewer risks of issues with systems that use third party utilities ([#9](https://github.com/dokterdok/Continuity-Activation-Tool/issues/9))
* Activation will now abort if 1 of the two mandatory kexts are missing
* Incorrect or inaccurate messages
* Many other small optimizations


**v.1.0.2 - 2014.10.27**

* Fixed a bug that prevented Handoff to be enabled in the System Preferences, even after a successful patch ([#21](https://github.com/dokterdok/Continuity-Activation-Tool/issues/21), [#22](https://github.com/dokterdok/Continuity-Activation-Tool/issues/22), [#31](https://github.com/dokterdok/Continuity-Activation-Tool/issues/31))
* Added a backup step for freshly patched drivers, potentially useful if a future OS X update disables the patching methods ([#16](https://github.com/dokterdok/Continuity-Activation-Tool/issues/16))
* Added a prompt in case existing backups are found, asking whether to overwrite the files or skip. Previous behaviour was to silently overwrite.
* Removed the 13" MacBook Pro 2010 from the compatibility list ([#28](https://github.com/dokterdok/Continuity-Activation-Tool/issues/28), pull [#29](https://github.com/dokterdok/Continuity-Activation-Tool/pull/29))
* Minor optimisations


**v.1.0.1 -  2014.10.24**

* Fixed a boot arguments overwriting bug, that could lead to a system failure in specific cases ([#1](https://github.com/dokterdok/Continuity-Activation-Tool/issues/1), [#15](https://github.com/dokterdok/Continuity-Activation-Tool/issues/15))
* Fixed a kext-dev-mode bug that prevented the OS to disable its drivers protection
* Fixed the strings utility presence check when the script is run from the command line
* Added a disk reparation step at the start of the patching procedure, lowering failure risks on disks with permissions issues
* Added a verification that sudo is still active before patching

**v.1.0.0 - 2014.10.23**

* Initial release

### Thanks
* Lem3ssie (LAUTRU Mehdi)
* UncleSchnitty
* Skvo
* TealShark
* Manic Harmonic
* rob3r7o
