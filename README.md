Continuity Activation Tool
==========================

This tool makes the necessary changes to enable OS X 10.10 and 10.11 Continuity features on compatible hardware. Continuity features activated by this tool include Handoff, Instant Hotspot, and New Airdrop.
OS X 10.11 (El Capitan) dongle support is not stable yet!

Please check the [Wiki](https://github.com/dokterdok/Continuity-Activation-Tool/wiki) before using this tool and opening any issues that are already referenced in the Wiki!

Use the latest beta if you are on **macOS Sierra**. [Download latest beta](https://github.com/dokterdok/Continuity-Activation-Tool/archive/beta.zip)

## News
2016-06-13: **macOS Sierra** ~~The work on the newest version of macOS will begin as soon a possible.~~ CAT mostly works fine with Sierra! (New Features like auto-unlock still need to be tested). New updates will be released on the beta branch while macOS Sierra is in beta!

2016-06-13: **wiki page** A wiki page has been erstablished and will be used to suggest fixes for the most common issues. A issue template was added to help the users provide more details.

2015-10-09 : **Version 2.1.3** Merged with the beta version. Should now work on 10.10 - 10.11

2015-08-13 : **New active lead** : I (sysfloat) will now be the main contributer and manager of the project, since dokterdok is not able to support this project anymore. He supported me with a lot of stuff and his research into enabling Continuity with dongles. I will contact some old beta testers and will do my best to get the dongles working on El Capitan and merge my fork with the beta branch.

Dec. 14 2014 : **Continuity Activation Tool 2.0 released** : Adds compatibility with Bluetooth 4.0 USB dongles, allowing many Macs from 2008 and later to easily upgrade to Continuity. See the chart below to verify available upgrade options.

**[Download link](https://github.com/dokterdok/Continuity-Activation-Tool/archive/master.zip)**
=======

## Features
* Activate Continuity: Does a Continuity compatibility check, makes a backup of the Systems kexts before and after patching, applies patches relevant to the current configuration.
* System Diagnostic: Produces a report of the current system parameters influencing Continuity.
* Uninstall: Rolls back any changes applied by the tool. It firsts looks for previous backups made with the tool, and if it can't find any, kexts from the OS X Recovery Disk are reinstalled. It will only reactivate OS kext signature protection if it is sure that all system kexts installed are signed and valid, to prevent potential boot time issues with 3rd party tools or hardware.

## Issues

Before submitting a new issue please check the Wiki for common issues! When submitting a new issue please check if there's already an issue open.

Please fill out the template as detailed as possible.

Issues that do not follow the rules and are unclear on the issue might get deleted without help!

## Warning
* You should exercise caution when using the Continuity Activation Tool, as it moves around low level files and there's a possibility it could cause problems. Using this tool is at your own risk. Always use the latest version of the tool to avoid issues.
* The tool disables the verification of original Apple drivers in order to work, which lowers the overall system security.

## How to use it

**From Finder**

1. Download the zip (link on the right) and extract it.
2. Double-click on the app.
3. Follow instructions on the screen. Ignore or deny any "Access to accessibility features" prompt.

**From the command line**

Script location: ```Continuity Activation Tool.app/Contents/Resources/contitool.sh```

Usage: ```sudo contitool.sh -a | -d | -f | -h | -r | -z```

Options:
```
-a               run the compatibility checks and activation procedure
-d               run the system diagnostic procedure and quit
-f               force the activation procedure without compatibility checks
-h               display a help message and quit
-r               uninstall Continuity mods by directly using OS X recovery disk files
-z               uninstall Continuity mods
```
### Troubleshooting

If you run into issues:

1. Make sure you understand the known limitations by reading the sections above carefully
2. Go through the official Continuity [troubleshooting steps](http://support.apple.com/kb/TS5458)
3. Search for similar issues in the [issues section](https://github.com/dokterdok/Continuity-Activation-Tool/issues?q=is%3Aissue) or on [forums](http://forums.macrumors.com/showpost.php?p=20124161), a solution to your problem might exist already
4. Create a [new issue](https://github.com/dokterdok/Continuity-Activation-Tool/issues/new) and include a description of the problem, the steps to reproduce it, and a System Diagnostic copy/paste from the latest version of the tool.

Developers are more than welcome to contribute with bug fixes or improvements. In that case please upload changes to the [beta branch](https://github.com/dokterdok/Continuity-Activation-Tool/tree/beta).
=======
4. Create a [new issue](https://github.com/dokterdok/Continuity-Activation-Tool/issues/new) and include a description of the problem, the steps to reproduce it, and a System Diagnostic copy/paste from the latest version of the tool

### Sources
* [Get help using Continuity with iOS 8 and OS X (Apple Support KB)](http://support.apple.com/kb/TS5458)
* [Guide to enable Continuity manually (MacRumors Forum Thread)](http://forums.macrumors.com/showpost.php?p=20124161)
* [Article on the disabling OS security features and related risks (Cindori.org)](http://www.cindori.org/trim-enabler-and-yosemite)

### Changelog

**v2.3 - 2016-06-15**
* Fixed Handoff on Sierra

**v2.2.4 - 2016-06-13**
* Fixed LMPVersion detection. This should fix #303 #303 #286 #278 and possibly more.

**v2.2.3 - 2015-12-07**
* fixed an issue where to wrong window would get closed on exit.([#248](https://github.com/dokterdok/Continuity-Activation-Tool/issues/248))

**v2.2.2 - 2015-10-31**
* fixed an issue where SIP wouldn't get detected correctly on 10.11.2+([#250](https://github.com/dokterdok/Continuity-Activation-Tool/issues/250))

**v2.2.1 - 2015-10-22**
* fixed an issue where the SystemParameters would not get patched correctly([#242](https://github.com/dokterdok/Continuity-Activation-Tool/issues/242))

**v2.2 - 2015-10-18**
* Support for dongles with El Capitan
* Added uninstall via Recovery disk menu option
* Improved uninstallation

**v2.1.4 - 2015-10-11**
* Fix for some models where some patches would not apply correctly([#229](https://github.com/dokterdok/Continuity-Activation-Tool/issues/229), [#222](https://github.com/dokterdok/Continuity-Activation-Tool/issues/222))

**v2.1.3 - 2015-10-09**
* Fixed a bug where CAT would not work on some models and disable WiFi.
* Fixed a bug where "Space bar" would not be recognized in the dongle detection promt.

**v2.1.2**
* Minor improvemnts with El Capitan final

**v2.1.1 - 2015-09-16**
* Adds compability with El Capitan.

**v2.1 - 2015-06-20**
* Works with El Capitan DP1
* New AppleScript, allows renaming the app
* switched from apples strings utility to a new selfmade app that does pretty much the same job for this purpose, but does not use any apple code.
* speed up some parts of the code

**v.2.0.1 - 2014.12.21**
* Improved USB Bluetooth dongle detection([#103](https://github.com/dokterdok/Continuity-Activation-Tool/issues/103))
* Fixed an OS X version check bug, which affected execution on case sensitive file systems ([#96](https://github.com/dokterdok/Continuity-Activation-Tool/issues/96))
* Fixed a rare ioreg crash issue ([#100](https://github.com/dokterdok/Continuity-Activation-Tool/issues/100))
* Fixed a command line issue which quit the Terminal when quitting the script ([#101](https://github.com/dokterdok/Continuity-Activation-Tool/pull/101))
* Fixed: the ```-f | --forceHack``` command line option now correctly skips the Wi-Fi card device-id(s) injection check and Bluetooth blacklist check
* Minor optimisations and bug fixes

**v.2.0.0 - 2014.12.14**
* Added compatibility with many older Macs when using a USB Bluetooth 4.0 dongle (see chart).
* Added the ability to choose the admin user executing the tool ([#14](https://github.com/dokterdok/Continuity-Activation-Tool/issues/14))
* Added new diagnostics, including a system wide Continuity activation check.
* Added the ability to run the System Diagnostic from the command line without admin privileges.
* Improved the command line execution with new options.
* Improved the diagnostic messages accuracy.
* Fixed Gatekeeper issues preventing the app to be launched, by codesigning the app
* Fixed an issue where OS X kext protection wasn’t disabled is some cases, leading to a loss of Wi-Fi / Bluetooth connectivity.
* Optimisations and bug fixes.

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
* Added a prompt in case existing backups are found, asking whether to overwrite the files or skip. Previous behavior was to silently overwrite.
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
* To the >150 CAT 2.0 beta testers
* Skvo
* toleda
* Lem3ssie (LAUTRU Mehdi)
* UncleSchnitty
* TealShark
* Manic Harmonic
* rob3r7o


David Dudok de Wit (dokterdok)
