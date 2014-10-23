Continuity-Activation-Tool
=========================

This tool does the system related modifications necessary to enable OS X 10.10 Continuity features on compatible hardware. Continuity features activated by this tool include Application Handoff, Instant Hotspot, and Airdrop iOS<->OSX.
The tool has no influence over the Call/SMS Handoff feature.

## Features
* Activate continuity: Does a Continuity compatibility check, backups the original Systems kexts, disables a Mac-model blacklist in the Buetooth kext, adds the current Mac board-id to the Wi-Fi Broadcom kext plugin. 
* System diagnostic: Produces a description of the current system parameters influencing Continuity with an "OK" and "NOT OK", added with a recommendation.

## Compatibility list
The tool should work with the following Mac models:

* mid-2010 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
* early-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
* late-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
* mid-2011 MacBook Airs (no hardware modification required)
* mid-2011 Mac Minis (no hardware modification required)

Other Macs will be prompted with a warning.

Please note that this tool does not work with BT 4.0 LE USB Dongles, it only works with the right internal Apple wireless hardware.

### Credits:
* Lem3ssie
* UncleSchnitty
* Skvo
* TealShark
* Manic Harmonic
* rob3r7o