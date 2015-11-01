#!/bin/bash

#---- INTRO ---------------
#
# Continuity Activation Tool 2 - built by dokterdok
#
# Description: This script enables OS X 10.10 and 10.11 Continuity features when compatible hardware is detected.
# Continuity features activated by this tool include Application Handoff, Instant Hotspot, and New Airdrop.
# The tool has no influence over Call/SMS Handoff.
#
# Before the actual patching happens, a system compatibility test is made, 
# as well as a backup of the bluetooth and wifi kexts. A backup of the patched kexts is also made.
# The System Diagnostic produces a report of typical parameters influencing Continuity.
# An uninstaller is available as well, which restores the original drivers, or, if not present, the drivers from the OS X recovery disk.
#
# 

hackVersion="2.2.2"

#---- PATH VARIABLES ------

#APP PATHS
appDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
continuityCheckUtilPath="$appDir/continuityCheck.app/Contents/MacOS/continuityCheck"
backupFolderNameBeforePatch="KextsBackupBeforePatch" #kexts backup folder name, where the original untouched kexts should be placed
backupFolderNameAfterPatch="KextsBackupAfterPatch" #kexts backup folder name, where the patched kexts should be placed, after a successful backup
backupFolderBeforePatch="" #the full path to this backup folder is initialized by the initializeBackupFolders function
backupFolderAfterPatch="" #the full path to this backup folder is initialized by the initializeBackupFolders
driverPath="/System/Library/Extensions"
wifiKextFilename="IO80211Family.kext"
wifiKextPath="$driverPath/$wifiKextFilename"
wifiBrcmKextFilename="AirPortBrcm4360.kext"
wifiBrcmBinFilename="AirPortBrcm4360"
wifiBrcmBinPath="$driverPath/$wifiKextFilename/Contents/PlugIns/$wifiBrcmKextFilename/Contents/MacOS/$wifiBrcmBinFilename"
wifiObsoleteBrcmKextFilename="AirPortBrcm4331.kext"
wifiObsoleteBrcmKextPath="$driverPath/$wifiKextFilename/Contents/PlugIns/$wifiObsoleteBrcmKextFilename"
btKextFilename="IOBluetoothFamily.kext"
btKextPath="$driverPath/$btKextFilename"
btBinFilename="IOBluetoothFamily"
btBinPath="$driverPath/$btKextFilename/Contents/MacOS/$btBinFilename"
recoveryHdName="Recovery HD"
recoveryDmgPath="/Volumes/Recovery HD/com.apple.recovery.boot/BaseSystem.dmg"
osxBaseSystemPath="/Volumes/OS X Base System"
systemParameters="/System/Library/Frameworks/IOBluetooth.framework/Versions/A/Resources/SystemParameters.plist"

#UTILITIES PATHS
awkPath="/usr/bin/awk"
chmodPath="/bin/chmod"
chownPath="/usr/sbin/chown"
cpPath="/bin/cp"
cutPath="/usr/bin/cut"
diskutilPath="/usr/sbin/diskutil"
duPath="/usr/bin/du"
findPath="/usr/bin/find"
grepPath="/usr/bin/grep"
hdiutilPath="/usr/bin/hdiutil"
headPath="/usr/bin/head"
hexdumpPath="/usr/bin/hexdump"
ifconfigPath="/sbin/ifconfig"
ioregPath="/usr/sbin/ioreg -d 14" #limited to a depth of 14 levels to avoid crashes in rare cases
kextcachePath="/usr/sbin/kextcache"
kextstatPath="/usr/sbin/kextstat"
killallPath="/usr/bin/killall"
mkdirPath="/bin/mkdir"
mvPath="/bin/mv"
nvramPath="/usr/sbin/nvram"
perlPath="/usr/bin/perl"
plistBuddyPath="/usr/libexec/PlistBuddy"
readPath="/usr/bin/read"
revPath="/usr/bin/rev"
rmPath="/bin/rm"
sedPath="/usr/bin/sed"
sleepPath="/bin/sleep"
shutdownPath="/sbin/shutdown"
statPath="/usr/bin/stat"
stringsPath="$appDir/findString"
trPath="/usr/bin/tr"
wcPath="/usr/bin/wc"
xxdPath="/usr/bin/xxd"
csrutilPath="/usr/bin/csrutil"
plistBuddy="/usr/libexec/PlistBuddy"
tailPath="/usr/bin/tail"

#---- CONFIG VARIABLES ----
forceHack="0" #default is 0. when set to 1, skips all compatibility checks and forces the hack to be applied (WARNING: may corrupt your system)
doDonglePatch="" #set to 1 or 0 if the hardware is fit to enable USB BT4 dongle
myMacIdPattern="" #Mac board id, detected later. Can be manually set here for debugging purposes. E.g.: Mac-00BE6ED71E35EB86.
myMacModel="" #Mac model nb, automatically detected later. Can be manually set here for debugging purposes. E.g.: MacBookAir4,1
myMacIdPattern=$($ioregPath -l | $grepPath "board-id" | $awkPath -F\" '{print $4}') #Get macIdPattern

whitelistAlreadyPatched="0" #automatically set to 1 when detected that the current board-id is whitelisted in the Wi-Fi drivers.
myMacIsBlacklisted="0" #automatically set to 1 when detected that the Mac model is blacklisted in the Bluetooth drivers.
legacyWifiKextsRemoved="0" #automatically set to 1 when the older Broadcom 4331 Wi-Fi kext plugin can't be found in the Wi-Fi drivers
forceRecoveryDiskBackup="0" #automatically set to 1 when backups made by the Continuity Activation Tool can't be found. It's a flag used to determine if kext from the Recovery Disk are to be used during the uninstallation process.
nbOfInvalidKexts=""
macCompatibilityList=("iMac10,1" "iMac11,1" "iMac11,2" "iMac11,3" "iMac12,1" "iMac12,2" "iMac13,2" "iMac14,2" "iMac7,1" "iMac9,1" "MacPro5,1" "MacBook5,1" "MacBook5,2" "MacBook6,1" "MacBook7,1" "MacBookAir3,1" "MacBookAir3,2" "MacBookAir4,1" "MacBookAir6,1" "MacBookPro11,1" "MacBookPro5,1" "MacBookPro5,2" "MacBookPro5,3" "MacBookPro5,4" "MacBookPro5,5" "MacBookPro6,1" "MacBookPro6,2" "MacBookPro7,1" "MacBookPro8,1" "MacBookPro8,2" "MacBookPro8,3" "MacBookPro9,2" "Macmini3,1" "Macmini4,1" "MacPro3,1" "MacPro4,1") #Macs that were tested successfully (may require a hardware upgrade) 
blacklistedMacs=("MacBookAir4,1" "MacBookAir4,2" "Macmini5,1" "Macmini5,2" "Macmini5,3") #compatible without hardware changes. This list is used during the diagnostic only. The patch actually gets an up-to-date list in the kext.
legacyBrcmCardIds=("pci14e4,432b") #includes the legacy broadcom AirPort card pci identifiers from the Brcm4331 kext. Additional brcm pci identifiers can be injected in this array for compatibility tests.
autoCheckAppEnabled="0" #automatically set to 1 if the login item for the Continuity Check app is present.
subVersion="0"
subVersion=$(sw_vers -productVersion | $cutPath -d '.' -f 2) #Get subversion e.g. 11 for OS X 10.11.1

#---- CAT 2 Binary patches ----
#3rd party BT 4.0 patchfor IOBluetoothFamily, working with OS X 10.10.0 and 10.10.1
#usbBinaryPatchFindEscaped="\x8B\x87\x8C\x01\x00\x00" #replacement hexadecimal sequence for the IOBluetoothFamily binary. Warning: old patch not working in OS X 10.10.2 and higher
#usbBinaryPatchReplaceWithEscaped="\xB8\x0F\x00\x00\x00\x90" #replacement hexadecimal sequence for the IOBluetoothFamily binary. Warning: old patch not working in OS X 10.10.2 and higher

#3rd party BT 4.0 patch for IOBluetoothFamily, working with OS X 10.10.0 and above
#usbBinaryPatchFindEscaped="\x48\x85\xC0\x74\x5C\x0F\xB7\x48" #hexadecimal sequence to replace in the the IOBluetoothFamily binary
#usbBinaryPatchReplaceWithEscaped="\x41\xBE\x0F\x00\x00\x00\xEB\x59" #replacement hexadecimal sequence for the IOBluetoothFamily binary

#3rd party BT 4.0 patch for IOBluetoothFamily, working with OS X 10.10.0 and above (isofunctional to the original driver besides compatibility checks)
usbBinaryPatchFindEscaped10="\x48\x85\xC0\x74\x5C\x0F\xB7\x48\x10\x83\xC9\x04\x83\xF9\x06\x75\x50\x48\x8B" #hexadecimal sequence to replace in the the IOBluetoothFamily binary
usbBinaryPatchReplaceWithEscaped10="\x3E\xC6\x83\xBC\x02\x00\x00\x02\x41\xBE\x0F\x00\x00\x00\xE9\x4E\x00\x00\x00" #replacement hexadecimal sequence for the IOBluetoothFamily binary

#3rd party BT 4.0 patch for IOBluetoothFamily, working with OS X 10.11 and above, thanks to RehabMan for the updated patch
usbBinaryPatchFindEscaped11="\x48\x85\xFF\x74\x47\x48\x8B\x07" #hexadecimal sequence to replace in the the IOBluetoothFamily binary
usbBinaryPatchReplaceWithEscaped11="\x41\xBE\x0F\x00\x00\x00\xEB\x44" #replacement hexadecimal sequence for the IOBluetoothFamily binary

usbBinaryPatchFindEscaped=""
usbBinaryPatchReplaceWithEscaped=""

usbBinaryPatchFind=$(echo ${usbBinaryPatchFindEscaped} | $trPath -d '\\x' | $trPath -d ' ')
usbBinaryPatchReplaceWith=$(echo ${usbBinaryPatchReplaceWithEscaped} | $trPath -d '\\x' | $trPath -d ' ')


#---- FUNCTIONS -----------
#Verifies the presence of the strings binary, necessary to run many checks and patches
#The 'strings' binutil used with the tool comes from the 'Apple Command Line Utilities' package
function verifyStringsUtilPresence() {
	if [ ! -f "${stringsPath}" ]; then
		
		tput clear
		echo ""
		echo "Error: the 'findString' command line utility was not found and is necessary to run the script."
		echo ""
		echo "It is expected to be bundled with the app and located at :"
		echo "'${appDir}/'"
		echo ""
		echo "Aborting."
		echo ""
		exit;
	fi
}

#Prompts to reboot your system, e.g. after patching
function rebootPrompt(){
	echo ""
	$readPath -n 1 -p "Press any key to reboot or CTRL-C to cancel..."
	echo ""
	osascript -e 'tell app "System Events" to restart'
	$killallPath "Terminal"
	exit;
}

#Quits the script if the OS X version is lower than 10.10, displays warning if higher
function isMyMacOSCompatible() {	
	echo -n "Verifying OS X version...               "
	local osVersion=$(sw_vers -productVersion)
	local buildVersion=$(sw_vers -buildVersion)
	local minVersion=10
	subVersion=$(echo "$osVersion" | $cutPath -d '.' -f 2)
	
	if [ "$subVersion" -lt "$minVersion" ]; then 
		if [ "$1" != "verbose" ]; then echo "NOT OK. Your OS X version is too old to work with this hack. Aborting."; exit;
		else echo "NOT OK. Your OS X version is too old to work with this hack. Version detected: ${osVersion}"; fi
		exit;
	else
		if [ "$subVersion" -eq "$minVersion" ]; then 
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Mac OS X ${osVersion} (${buildVersion}) detected"; fi
		else
			if [ "$subVersion" -eq "11" ]; then
				if [ "$1" != "verbose" ]; then 
					echo "Warning: This version of Mac OS X (${osVersion}) is Experimental! Only partially tested on El Capitan"
					echo "Are you sure you want to continue?"
					select yn in "Yes" "No"; do
						case $yn in
							Yes) #continue
								break;;
							No) echo "Aborting.";
								backToMainMenu;;
							*) echo "Invalid option, enter a number";;
						esac
					done
				else
					echo "Warning: This version of Mac OS X (${osVersion}) is Experimental! Only partially tested on El Capitan"
				fi
			else 
				if [ "$subVersion" -gt "$minVersion" ]; then
					if [ "$1" != "verbose" ]; then 
						echo "Warning: This tool wasn't tested on OS X versions higher than 10.10. Detected OS version: ${osVersion}"
						echo "Are you sure you want to continue?"
						select yn in "Yes" "No"; do
							case $yn in
								Yes) #continue
									break;;
								No) echo "Aborting.";
									backToMainMenu;;
								*) echo "Invalid option, enter a number";;
							esac
						done
					else
						echo "Warning: This tool wasn't tested with OS X versions higher than 10.10. Detected OS version: ${osVersion}"
					fi
				fi
			fi
		fi
	fi
}

#Verifies that the kexts don't have a 0 bytes size and that they can be found. Failed hack attempts are known to mess this up.
function canMyKextsBeModded(){
		echo -n "Verifying kexts readability...          "
		$duPath -hs "${btKextPath}" >> /dev/null 2>&1
		btPermissionsError=$?
		$duPath -hs "${wifiKextPath}" >> /dev/null 2>&1
		wifiPermissionsError=$?
		permissionsError=$((btPermissionsError + wifiPermissionsError))
		if [ "${permissionsError}" -gt "0" ]; then
			if [ "$1" != "verbose" ]; then echo "NOT OK. ${btKextFilename} and/or ${wifiKextFilename} are missing or corrupt in ${driverPath}"; echo ""; echo "   To fix this:"; echo "1) delete these files in ${driverPath}"; echo "2) find the original untouched kext backups (check in ${backupFolderBeforePatch})"; echo "3) reinstall them using the Kext Drop app (search online for it)"; echo "4) reboot."; echo ""; backToMainMenu
			else echo "NOT OK. ${btKextFilename} and/or ${wifiKextFilename} are missing or corrupt in ${driverPath}."; echo ""; echo "   To fix this:"; echo "1) delete these files in ${driverPath}"; echo "2) find the original untouched kext backups (check in ${backupFolderBeforePatch})"; echo "3) reinstall them using the Kext Drop app (search online for it)"; echo "4) reboot."; echo ""; fi 
		else
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Wi-Fi and Bluetooth kexts were found and could be read"; fi
		fi
}

#Verifies the status of the ContinuitySupport bool for the given mac 
function checkContinuitySupport(){
	if [ "$1" == "verbose" ]; then
		echo -n "Verifying ContinuitySupport...          "
	fi
	local contiSupport=$($plistBuddy -c "Print :${myMacIdPattern}:ContinuitySupport" "${systemParameters}")
	if [[ "${contiSupport}" == "true" ]]; then
		if [ "$1" != "verbose" ]; then echo "1";
		else echo "OK. Already patched.";
		fi
	else 
		if [[ "${contiSupport}" == "false" ]]; then
			if [ "$1" != "verbose" ]; then echo "0";
			else echo "OK. This tool can fix this.";
			fi
		else 
			echo "NOT OK. Unknown state. Your Mac might not be compatible."
		fi
	fi
}

#Patches the ContinuitySupport bool to true for the given Mac boad-id
function patchContinuitySupport(){
	local action="$1"
	echo -n "Patching ContinuitySupport...           "
	if [[ "${action}" == "enable" ]]; then
		$plistBuddy -c "Set :${myMacIdPattern}:ContinuitySupport true" "${systemParameters}";
	else 
		if [[ "${action}" == "disable" ]]; then
			$plistBuddy -c "Set :${myMacIdPattern}:ContinuitySupport false" "${systemParameters}";
		else
			echo "Internal error. Unknown patch action."
		fi
	fi
	echo "OK."
}

#Verifies that the board-id has an acceptable length
function isMyMacBoardIdCompatible(){
	echo -n "Verifying Mac board-id...               "
	#echo -n "Verifying Mac board-id compatibility... "
	if [ ! -z "{$myMacIdPattern}" ] ; then
		myMacIdPattern=$($ioregPath -l | $grepPath "board-id" | $awkPath -F\" '{print $4}')
	fi
	if [ ! -z "{$myMacIdPattern}" ] ; then
		if [ ${#myMacIdPattern} -eq 12 ] ; then
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Short board id detected: ${myMacIdPattern}"; fi #e.g. short board-id are used in pre-2011 MacBookPros
		else
			if [ ${#myMacIdPattern} -eq 20 ] ; then
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "OK. Long board id detected: ${myMacIdPattern}"; fi
			else
				if [ "$1" != "verbose" ]; then echo "NOT OK. Board id length is not compatible. Expected 12 or 20 characters. Board id:${myMacIdPattern}. Aborting."; backToMainMenu;
				else echo "NOT OK. Board id length is not compatible. Expected 12 or 20 characters. Board id:${myMacIdPattern}"; fi
			fi
		fi
	else
		if [ "$1" != "verbose" ]; then echo "NOT OK. Board-id could not be detected. You may try to set manually in the script. Aborting."; backToMainMenu;
		else echo "NOT OK. Board-id could not be detected. You may try to set it manually in the script."; fi
	fi
}

#Verifies that at least 1 known Broadcom Wi-Fi kext is currently in use.
#The long branching was done only for verbose reporting.
function areMyActiveWifiDriversOk(){

	echo -n "Verifying Wi-Fi hardware...             "

	#Get the short name(s) of the active Wi-Fi kext(s) plugins.
	loadedWifiDrivers=($($kextstatPath | $grepPath "AirPort" | $awkPath -F' ' '{print $6}' | $awkPath -F'.' '{print $5}'))
	#case 1: no driver loaded at all
	if [ -z "${loadedWifiDrivers}" ]; then

		#case 1b: com.apple.driver.AirPortBrcm43224
		loadedWifiDrivers=($($kextstatPath | $grepPath "AirPort" | $awkPath -F' ' '{print $6}'))
		if [ -z "${loadedWifiDrivers}" ]; then
			if [ "$1" != "verbose" ]; then echo "NOT OK. No active AirPort card was detected. Continuity will not work. Aborting."; backToMainMenu;
			else echo "NOT OK. No active AirPort card was detected. Continuity will not work.";
			fi
		else
			if [ "$1" != "verbose" ]; then echo "OK"; 
			else echo "OK. AirPort driver ${loadedWifiDrivers[*]} was detected. The tool will try to fix this.";
			fi
		fi
	else
		#case 2: one AirPort driver is loaded
		if [ "${#loadedWifiDrivers[@]}" -eq "1" ]; then

			#case 2A: an Atheros driver is loaded
			if [ "$loadedWifiDrivers" == "Atheros40" ]; then
				if [ "$1" != "verbose" ]; then echo "NOT OK. An Atheros AirPort card is used. An upgrade to a Broadcom one is required to make Continuity work."; backToMainMenu;
				else echo "NOT OK. An Atheros AirPort card is used, Continuity will not work. An upgrade to a compatible Broadcom card is necessary."; 
				fi
			else
				if [ "$loadedWifiDrivers" == "Brcm4360" ]; then
					if [ "$1" != "verbose" ]; then echo "OK";
					else echo "OK. A Broadcom AirPort card is active, and is using the Continuity compatible Brcm4360 kext";
					fi
				else
					if [ "$loadedWifiDrivers" == "Brcm4331" ]; then
						if [ "$1" != "verbose" ]; then echo "OK";
						else echo "OK. A Broadcom AirPort card is active, and uses the legacy Brcm4331 kext. This tool can fix this.";
						fi
					else
						if [ "$1" != "verbose" ]; then echo "WARNING. An unknown/untested AirPort card using the '$loadedWifiDrivers' kext is active.";
						echo "Do you want to proceed anyways?"
						select yn in "Yes" "No"; do
							case $yn in
								Yes) #continue
									break;;
								No) echo "Aborting."; backToMainMenu;;
								*) echo "Invalid option, enter a number";;
							esac
						done
						else echo "WARNING. An unknown/untested AirPort card using the '$loadedWifiDrivers' kext is active. This tool can't fix this.";
						fi
					fi
				fi
			fi
		else 

			#More than 1 driver is active, see if there's a compatible Broadcom one
			local element
			local activeCards=()
			for element in "${loadedWifiDrivers[@]}";
				do 
				if [ "${element}" == "Brcm4331" ]; then
					activeCards+=($(echo "${element}")) #store the kext name
				else
					if [ "${element}" == "Brcm4360" ]; then
					activeCards+=($(echo "${element}")) #store the kext name
					fi
				fi
			done

			#Verify if multiple Broadcom drivers loaded
			if [ "${#activeCards[@]}" -gt 1 ]; then
				if [ "$1" != "verbose" ]; then echo "OK"
				else echo "OK. Compatible Broadcom AirPort drivers ${activeCards[*]} are active"; fi
			else 
				#Verify if at least one usable Broadcom driver is running
				if [ "${#activeCards[@]}" -eq 1 ]; then
					if [ "$1" != "verbose" ]; then echo "OK"
					else echo "OK. ${activeCards[0]} Airport driver is active"; fi
				else
					#Multiple Wi-Fi drivers loaded, but none are of the Broadcom brand
					if [ "$1" != "verbose" ]; then echo "NOT OK. No Broadcom AirPort card is active. Aborting."; backToMainMenu;
					else echo "NOT OK. No compatible Broadcom AirPort card is active, Continuity won't work. Active kexts: ${activeCards[*]}."; fi
				fi
			fi
		fi
	fi
}


#Verifies if an array contains a value. Usage: containsElement "blabla" "${array[@]}"; echo $?
function containsElement () {
	local element
	for element in "${@:2}"; 
		do [[ "$element" == "$1" ]] && return 1; 
	done
	return 0
}

#Verifies the Mac model number and whether the mod is known to work for it
function isMyMacModelCompatible(){
	echo -n "Verifying Mac model reference...        "

	modelsList=("${macCompatibilityList[@]}" "${blacklistedMacs[@]}")
	myMacModel=$($ioregPath -l | $grepPath "model" | $awkPath -F\" '{print $4;exit;}')
	myResult=$(containsElement "${myMacModel}" "${modelsList[@]}"; echo $?)
	if [ "${myResult}" -eq 1 ] ; then
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Known compatible Mac Model detected: ${myMacModel}"; fi
	else
		#Set prompt in case user wants to try with iMacs / Mac Pro's etc.
		if [ "$1" != "verbose" ]; then 
			echo "WARNING. The compatibility of this Mac Model (${myMacModel}) with this mod is unknown and may have unpredictable results"; 
			echo "Do you want to proceed anyways?"
					select yn in "Yes" "No"; do
						case $yn in
							Yes) #continue
								break;;
							No) echo "Aborting."; backToMainMenu;;
							*) echo "Invalid option, enter a number";;
						esac
					done
		else echo "WARNING. The compatibility of this Mac Model (${myMacModel}) with this mod is unknown and may have unpredictable results"; fi
	fi
}

#Verifies if the active Bluetooth chip is compatible, by checking if the LMP version is 6
function isMyBluetoothVersionCompatible(){
	echo -n "Verifying Bluetooth version...          "
	local lmpVersion=$($ioregPath -l | $grepPath "LMPVersion" | $awkPath -F' = ' '{print $2}' | $tailPath -1)

	if [ ! "${lmpVersion}" == "" ]; then
		if [ "${lmpVersion}" == "6" ]; then
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Bluetooth 4.0 detected"; fi
		else
			if [ "${lmpVersion}" == "7" ]; then
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "WARNING. Bluetooth 4.1 detected, compatibility with this tool is unconfirmed"; fi
			else
				if [ "${lmpVersion}" -gt "7" ]; then
					if [ "$1" != "verbose" ]; then echo "OK";
					else echo "WARNING. New Bluetooth version detected (LMP Version ${lmpVersion}), compatibility with this tool is unconfirmed"; fi
				else
					if [ "$1" != "verbose" ]; then echo "NOT OK. Your hardware doesn't support Bluetooth 4.0, necessary for Continuity Current LMP Version=${lmpVersion}, expected 6. Aborting."; backToMainMenu;
					else echo "NOT OK. Your hardware doesn't support Bluetooth 4.0, necessary for Continuity. Current LMP Version=${lmpVersion}, expected 6."; fi
				fi
			fi
		fi
	else
		if [ "$1" != "verbose" ]; then echo "NOT OK. No active Bluetooth hardware detected. Aborting."; backToMainMenu;
		else echo "NOT OK. No active Bluetooth hardware detected."; fi
	fi
}

#Counts all kexts in the given folder that either have no signature or that don't pass signature validation
#This function is used during the uninstallation to make sure that the OS Kext Protection doesn't get re-activated and blocks potentially vital kexts from loading
#Negative values indicate an error.
#Usage: countInvalidKexts "${kextFolderPath}"
function countInvalidKexts(){
	folderToVerify=$1
	if [ -z "$folderToVerify" ]; then echo "-1"; #no argument given
    else 
    	if [ ! -d "$folderToVerify" ]; then echo "-2"; #folder not found
    	else
    		if [ $(ls -1 "${folderToVerify}"/*.kext 2>/dev/null | $wcPath -l) -eq 0 ]; then echo "-3"; #no kexts were found in this directory
    		else
    			cd $folderToVerify
    		 	echo "$($findPath $folderToVerify/*.kext -prune -type d | while read kext; do
    			codesign -v "$kext" 2>&1 | grep -E 'invalid signature|not signed at all'
    			done | $wcPath -l | $trPath -d ' ')"
			fi
		fi
	fi
}


#Enables or disables the kext developer mode in the PRAM. If activated, a reboot prompt is displayed.
#Arguments: disableDevMode or enableDevMode
#Warning: this function relies entirely on the PRAM, not on the boot plist.
function modifyKextDevMode(){
	
	local modificationAction="$1"
	local sedRegEx #regex that can be used to remove the "kext-dev-mode" variable from the boot-args
	local longSedRegEx #regex that can be used to remove the "-kext-dev-mode" variable from the boot-args. It includes a dash at the beginning.
	local okToDisable="0" #flag set to 1 when no unsigned kexts were found in the extensions folder

	#Sanitize the inputs and display the relevent the info message
	if [ -z "$1" ]; then
    	echo "Internal error: no OS Kext Protection input argument given. Aborting."; backToMainMenu;
    else
		if [ "${modificationAction}" == "disableDevMode" ]; then 

			#first we need to be sure that no other unsigned kexts are found in the Extensions folder
			#otherwise, disabling dev mode might prevent the system from booting.
			$(nbOfInvalidKexts=$(countInvalidKexts "${driverPath}")) >> /dev/null 2>&1 & spinner "Verifying system kexts signatures...    "

			if [ "${nbOfInvalidKexts}" != "0" ]; then
				echo -e "\rVerifying system kexts signatures...    OK. 1 or more unsigned drivers were found. OS kext security protection won't be changed to prevent issues."; return;
			else
				#the system folder doesn't contain unclean kexts, proceed
				echo  "\rVerifying system kexts signatures...    OK"
				echo -n "Activating OS kext protection...        "
				longSedRegEx="s#\-kext-dev-mode=1##g" #this kext-dev-mode string will be removed. A dash might have been used if there are more than 1 boot-args.
				sedRegEx="s#\kext-dev-mode=1##g" #this kext-dev-mode string will be removed if it exists
				okToDisable="1"
			fi
		else 
			if [ "${modificationAction}" == "enableDevMode" ]; then 
				echo -n "Disabling OS kext protection...         "
				longSedRegEx="s#\-kext-dev-mode=0##g"
				sedRegEx="s#\kext-dev-mode=0##g" #this kext-dev-mode string will be removed if it exists
			else echo "Internal error: unknown OS Kext Protection input argument given. Aborting."; backToMainMenu;
			fi
		fi
	fi

	#Check if boot-args variable is set
	sudo $nvramPath boot-args >> /dev/null 2>&1
	local bootArgsResult=$?
	if [ $bootArgsResult -eq 0 ]; then #Yes, boot-args exists

		#Get the boot-args variable value(s)
		bootArgsResult=$(sudo $nvramPath boot-args)
		bootArgsResult=${bootArgsResult:10} #remove boot-args declaration, necessary later

		#Verify if the kext-dev-mode is declared as active
		sudo $nvramPath boot-args | $grepPath -F "kext-dev-mode=1" >> /dev/null 2>&1
		local devModeResult=$?
		if [ $devModeResult -eq 0 ]; then 

			if [ "${modificationAction}" == "disableDevMode" ]; then
				if [ "${okToDisable}" == "1" ]; then #re-activate the OS kext protection, because no irregular kexts were found

					#Dev mode will be removed from the boot-args.
					local strippedBootArgs=$(echo "${bootArgsResult}" | $sedPath "${longSedRegEx}")
					strippedBootArgs=$(echo "${strippedBootArgs}" | $sedPath "${sedRegEx}")
					sudo $nvramPath boot-args="${strippedBootArgs}"
					echo "OK. The OS kext protection was re-activated"
				else
					echo "OK. Unsigned drivers are used by your system. OS kext security protection won't be changed to avoid potential issues." #do nothing, unsigned kexts were found, the kext-dev-mode won't be disabled
				fi
			else
				echo "OK" #do nothing, dev mode was already active, as wanted
			fi
		else
			#Verify if the kext-dev-mode is declared as disabled (rare, by default this variable is not set by OS X)
			sudo $nvramPath boot-args | $grepPath -F "kext-dev-mode=0" >> /dev/null 2>&1
			devModeResult=$?
			if [ $devModeResult -eq 0 ]; then 

				#Dev mode is declared as unset
				if [ "${modificationAction}" == "enableDevMode" ]; then

					#Dev mode will be activated, previous kext-dev-mode variable is stripped first
					local strippedBootArgs=$(echo "${bootArgsResult}" | $sedPath "${longSedRegEx}")
					strippedBootArgs=$(echo "${strippedBootArgs}" | $sedPath "${sedRegEx}")
					sudo $nvramPath boot-args="${strippedBootArgs} kext-dev-mode=1"

					#Prompt to reboot now
					echo "OK"
				else
					echo "OK. The OS kext protection was already disabled." #dev mode was already disabled, as wanted
				fi
			else
				#No kext-dev-mode boot-args are set.
				if [ "${modificationAction}" == "enableDevMode" ]; then
					
					#Activate the kext-dev-mode
					sudo $nvramPath boot-args="${bootArgsResult} kext-dev-mode=1"
					
					#Prompt to reboot now
					echo "OK"
				else
					#Do nothing, dev mode is already disabled, as wanted
					echo "OK. The OS kext protection was already active"
				fi
			fi
		fi
	else
		#No boot-args are set at all. Only set them in the PRAM if it needs to be activated.
		if [ "${modificationAction}" == "enableDevMode" ]; then
			sudo $nvramPath boot-args="kext-dev-mode=1"
			echo "OK"
		else
			echo "OK. The OS kext protection was already active" #do nothing, dev mode is disabled, as wanted
		fi
	fi
}

#Verifies if the kext developer mode is active. No changes are applied to the PRAM here.
function verifyOsKextDevMode(){
	echo -n "Verifying OS kext protection...         "

	#Check if boot-args variable is set
	$nvramPath boot-args >> /dev/null 2>&1
	local bootArgsResult=$?
	if [ $bootArgsResult -eq 0 ]; then #Yes, boot-args exists

		#Verify if kext-dev-mode=1 is set
		$nvramPath boot-args | $grepPath -F "kext-dev-mode=1" >> /dev/null 2>&1
		local devModeResult=$?
		if [ $devModeResult -eq 0 ]; then #Dev mode is active
			if [ "$1" != "verbose" ]; then echo "OK"; 
			else echo "OK. Kext developer mode is already active"; fi
		else
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Kext developer mode is not active. This tool can fix this."; fi
		fi
	else

		#No boot-args are set at all
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Kext developer mode is not active. This tool can fix this."; fi
	fi
}

#Verifies the current status of the System Integrity Protection.
#This is only needed in OS X 10.11 and can be reenabled after the patching is done.
function verifySIP(){
	echo -n "Verifying SIP...                        "
	#Check csrutil status
	$csrutilPath status | $grepPath -F "status: disabled" >> /dev/null 2>&1
	local SIPresult=$?
	
	if [ $SIPresult -eq 0 ]; then #SIP is disabled
			if [ "$1" != "verbose" ]; then echo "OK"; 
			else echo "Ok. System Integrity Protection is already disabled"; 
			fi
			return 1
	else
			#Extra check needed, csrutil lists that SIP is enabled and all of it's options are disabled instead of just labeling it as disabled.
			local SIPresult=$($csrutilPath status | $grepPath -c ": disabled")
			if [ "${SIPresult}" -eq 6 ]; then
				if [ "$1" != "verbose" ]; then echo "OK"; 
				else echo "Ok. System Integrity Protection is already disabled"; 
				fi
			return 1
			else 	
				$csrutilPath status | $grepPath -F "status: enabled" >> /dev/null 2>&1
				local SIPresult=$?
				if [ $SIPresult -eq 0 ]; then #SIP is enabled
					if [ "$1" != "verbose" ]; then echo "NOT OK."; 
					else echo "NOT OK. System Integrity Protection is still enabled"; 
					return 0
				fi
				else 
					echo "NOT OK. Unknown System Integrity Protection state."
					return 0
				fi
			fi	
	fi	
}

#Verifies if the Mac board id is correctly whitelisted in the Wi-Fi drivers
function isMyMacWhitelisted(){
	echo -n "Verifying Wi-Fi whitelist status...     "
	#verify if the Brcm4360 binary exists
	if [ ! -f "${wifiBrcmBinPath}" ]; then
    	if [ "$1" != "verbose" ]; then echo "NOT OK. Wi-Fi drivers not found. Please use the uninstaller and run the tool again. Aborting."; backToMainMenu;
    	else echo "NOT OK. Wi-Fi drivers not found. Please use the uninstaller and run the tool again."; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; #Continue the verification. A brcm AirPort driver was found.
    	fi
     	local whitelist=($("${stringsPath}" ${wifiBrcmBinPath} "Mac-" | $awkPath -F" " '{print $2}'))
		myMacIdPattern=$($ioregPath -l | $grepPath "board-id" | $awkPath -F\" '{print $4}')
    	local foundCount=0
    	local element
    	if [[ $whitelist ]]; then
			for element in "${whitelist[@]}";
				do 
				if [ "${myMacIdPattern}" == "${element}" ]; then
					((foundCount+=1))
				fi
			done
			if [ "${foundCount}" -gt "0" -a "${foundCount}" -lt "${#whitelist[@]}" ]; then
				if [ "$1" != "verbose" ]; then echo "OK";
				else 
					firstWhitelistedBoardId=$("${stringsPath}" ${wifiBrcmBinPath} "Mac-" | $awkPath -F" " '{print $2;exit;}')
					lastWhitelistedBoardId=$("${stringsPath}" ${wifiBrcmBinPath} "Mac-" | $awkPath -F" " '{a=$0} END{print $2;exit;}')
					#Increase checks if the Mac is blacklisted (2011 MacBook Airs, Minis). Purely for reporting info.
					if [ "${myMacIsBlacklisted}" == "1" ]; then
						if [ "${myMacIdPattern}" == "${firstWhitelistedBoardId}" -a "${myMacIdPattern}" == "${lastWhitelistedBoardId}" ]; then
							if [ "$1" != "verbose" ]; then echo "OK";
							else echo "OK. The whitelist is manually patched with your board-id at the first and last location"; fi
						else
							if [ "$1" != "verbose" ]; then echo "OK";
							else echo "OK. The whitelist is incorrectly patched, your board-id wasn't found at the right places. This tool can try to fix this."; fi
						fi
					else
						if [ "${myMacIdPattern}" == "${firstWhitelistedBoardId}" ]; then
							if [ "$1" != "verbose" ]; then echo "OK";
							else echo "OK. The whitelist is manually patched with your board-id as expected at the first location"; fi
						else
							if [ "$1" != "verbose" ]; then echo "OK";
							else echo "OK. The whitelist is incorrectly patched, your board-id wasn't found at the right place. This tool can try to fix this."; fi
						fi
					fi
				fi
			else
		    #check if it needs patching: will do it if the whitelist is not full of own board id
				if [ "${foundCount}" == "${#whitelist[@]}" ]; then
					if [ "$1" != "verbose" ]; then echo "OK"; whitelistAlreadyPatched="1";
					else echo "OK. The whitelist is correctly patched with your board-id"; fi
				else
					if [ "$1" != "verbose" ]; then echo "OK";
					else echo "OK. Your board-id is not yet whitelisted. This tool can fix this."; fi
				fi
			fi
		else
			if [ "$1" != "verbose" ]; then echo "NOT OK. No whitelist detected in the Wi-Fi drivers, this tool won't be able to patch it. Aborting."; backToMainMenu
			else echo "NOT OK. No whitelist detected in the Wi-Fi drivers, this tool won't be able to patch it"; fi			
		fi
	fi
}

#Verifies if the Mac model is blacklisted in the Bluetooth drivers
function isMyMacBlacklisted(){
	echo -n "Verifying Bluetooth blacklist status... "
	if [ ! -f "${btBinPath}" ]; then
		if [ "$1" != "verbose" ]; then echo "NOT OK. Bluetooth drivers not found. Please use the uninstaller and run the tool again. Aborting."; backToMainMenu;
    	else echo "NOT OK. Bluetooth drivers not found. Please use the uninstaller and run the tool again."; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; fi #Continue, the bluetooth binary was found
    	local blacklist=($("${stringsPath}" ${btBinPath} "Mac" | $awkPath -F"'" '{print $2}'))
		local myMacModel=$($ioregPath -l | $grepPath "model" | $awkPath -F\" '{print $4;exit;}')
    	local foundCount=0
    	local element
    	if [[ $blacklist ]]; then
    		for element in "${blacklist[@]}";
				do 
				if [ "${myMacModel}" == "${element}" ]; then
					((foundCount+=1))
				fi
			done
			if [ "${foundCount}" -gt "0" ]; then
				myMacIsBlacklisted="1";
				if [ "$1" != "verbose" ]; then echo "OK"
				else echo "OK. Your Mac model is blacklisted. This tool can fix this."; 
				fi
			else
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "OK. Your Mac model is not blacklisted"; fi
			fi
		else
			#no blacklist found - find out if that's a problem for the user's Mac
			local originallyBlacklistedMac
			for originallyBlacklistedMac in "{blacklistedMacs[@]}"; 
				do
				if [ "${myMacModel}" == "${originallyBlacklistedMac}" ]; then
					((foundCount+=1))
				fi
			done
			if [ "${foundCount}" -gt "0" ]; then
				myMacIsBlacklisted="1";
				if [ "$1" != "verbose" ]; then 
				echo "NOT OK. Blacklist not found, and your Mac model is known to be blacklisted. Aborting."; backToMainMenu;
				else echo "NOT OK. Blacklist not found (OSX update breaking the hack?), and your Mac model is known to be blacklisted"; fi
			else
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "OK. Warning: Blacklist not found in the Bluetooth drivers. An OS X update might have made this hack useless."
					 echo "                                        However, your Mac model shouldn't need to be removed from that blacklist."; fi					
			fi
		fi
    fi
}

#------------ BT USB Specific Procedures Start  ----------------

#Call to action prompt to plug in an Bluetooth 4.0 dongle, in case no dongle is plugged in
#The function returns when either : a dongle is plugged in (auto detection), or when the user presses any key
function displayBluetoothDonglePrompt(){
	displaySplash

	echo ""
	echo "If you want to activate Continuity using a USB Bluetooth 4.0 dongle,"
	echo "then unplug it and plug it in now. The script will continue once it is detected."
	echo ""

	if [ -t 0 ]; then stty -echo -icanon -icrnl time 0 min 0; fi
	
	#detect the dongle presence 
	local donglePluggedIn=$(isABluetoothDongleActive)
	local keypress=''
	while [ "$keypress" = '' -a "$donglePluggedIn" -eq "0" ]; do
  		echo -ne "\rPress any key to continue without a USB Bluetooth 4.0 dongle..."
  		IFS= read keypress
  		donglePluggedIn=$(isABluetoothDongleActive)
	done
	if [ -t 0 ]; then stty sane; fi
	echo ""
}

#Verifies if a USB Bluetooth dongle is active by comparing the internal Bluetooth controller info with the active Bluetooth controller info. This info is retrieved from the PRAM.
#The function returns 1 if different internal and external Bluetooth controllers are detected (as expeted when a Dongle is plugged), 0 if it's the same (e.g. MacBook without a dongle).
#This function temporally sets the nvram bluetoothHostControllerSwitchBehavior to always, forcing plugged in dongles to be detected, then sets it back to its original state after the status check.
#Optional parameter: "verbose", which displays a status message for the diagnostic.
function isABluetoothDongleActive(){

	if [ "$1" == "verbose" ]; then
		echo -n "Verifying Bluetooth hardware...         "
	fi

	local internalBtControllerId=$($nvramPath -p | $grepPath "bluetoothInternalControllerInfo" | $awkPath -F' ' '{print $2}' | $trPath -d "%" | $headPath -c7)
	local activeBtControllerId=$($nvramPath -p | $grepPath "bluetoothActiveControllerInfo" | $awkPath -F' ' '{print $2}' | $trPath -d "%" | $headPath -c7)

	local currentSwitchSetting=""

	#temporarily set the agressive dongle detection
	if [[ $($nvramPath -p | $grepPath bluetoothHostControllerSwitchBehavior) == "" ]]; then
		sudo $nvramPath bluetoothHostControllerSwitchBehavior="always"
	else 
		#save the current switch behavior
		currentSwitchSetting=$($nvramPath -p | $grepPath bluetoothHostControllerSwitchBehavior | $awkPath -F' ' '{print $2}')
		sudo $nvramPath bluetoothHostControllerSwitchBehavior="always"
	fi

	#return the dongle status
	if [ ! -z "${internalBtControllerId}" -a ! -z "${activeBtControllerId}" ]; then
		if [ "${internalBtControllerId}" != "${activeBtControllerId}" ]; then
			
			#found a 3rd party dongle, different from the internal controller
			if [ "$1" != "verbose" ]; then echo "1";
			else 
				echo "OK. 3rd party Bluetooth hardware detected"; 
			fi
		else

			#the active bluetooth controller is the internal one
			if [ "$1" != "verbose" ]; then echo "0";
			else echo "OK. The internal Bluetooth card is active"; fi
		fi
	else
		#error: at least one of the Bluetooth Host Controller's info variable wasn't set in the PRAM
		if [ "$1" != "verbose" ]; then echo "0";
		else echo "WARNING. No Bluetooth controller references were found in the PRAM, dongles can't be detected."; fi
	fi

	#rollback the controllerSwitchBehavior to the initial state
	if [ -z "$currentSwitchSetting" ]; then
		#the switch behavior was not set before, go back to that state
		sudo $nvramPath -d bluetoothHostControllerSwitchBehavior
	else 
		#the switch behavior was set before, go back to whatever was set
		sudo $nvramPath bluetoothHostControllerSwitchBehavior="$currentSwitchSetting"
	fi	

}


#Silent helper funcition that determines whether patching the file is appropriate
#Returns: 1 if the patch should happen, 0 if not
function shouldDoDonglePatch(){
	#check the if the patching should be forced
	if [ "${forceHack}" == "1" ]; then
		echo "1"
	else 
		local featureFlags=$($ioregPath -l | $grepPath "FeatureFlags" | $awkPath -F' = ' '{print $2}' | $tailPath -1)
		local lmpVersion=$($ioregPath -l | $grepPath "LMPVersion" | $awkPath -F' = ' '{print $2}' | $tailPath -1)
		local internalBtControllerId=$($nvramPath -p | $grepPath "bluetoothInternalControllerInfo" | $awkPath -F' ' '{print $2}' | $trPath -d "%" | $headPath -c7)
		local activeBtControllerId=$($nvramPath -p | $grepPath "bluetoothActiveControllerInfo" | $awkPath -F' ' '{print $2}' | $trPath -d "%" | $headPath -c7)
		local brcmKext=$($kextstatPath | $grepPath "Brcm")
		local patchableFileOutput=$($hexdumpPath -ve '1/1 "%.2X"' "${btBinPath}" | $grepPath "${usbBinaryPatchFind}")
		local donglePresent="0"

		if [ ! -z "${internalBtControllerId}" -a ! -z "${activeBtControllerId}" -a ! -z "${activeBtControllerId}" -a ! -z "${internalBtControllerId}" -a "${activeBtControllerId}" != "${internalBtControllerId}" ]; 
			then donglePresent="1"; 
		fi

		if [ "${lmpVersion}" == "6" -a "${donglePresent}" == "1" -a ! -z "${brcmKext}" -a ! -z "${patchableFileOutput}" ]; then
			#check ok, go ahead with the patching
			echo "1"
		else
			#check didn't pass, patching would not be effective
			echo "0"
		fi
	fi	
}

#Checks if the dongle patch should be done, then proceeds with the patching
#The dongle patch enables older Broadcom AirPort cards, and tricks the system into thinking
#that the active Bluetooth device has the right features to work with Continuity
function initiateDonglePatch(){

	echo -n "Verifying BT4 dongle patch status...    "
	
	#detect OS version and choose correct hex sequence
	if [ $subVersion -eq 10 ]; then
		usbBinaryPatchFindEscaped=$usbBinaryPatchFindEscaped10
		usbBinaryPatchReplaceWithEscaped=$usbBinaryPatchReplaceWithEscaped10
	else
		if [ $subVersion -eq 11 ];then
			usbBinaryPatchFindEscaped=$usbBinaryPatchFindEscaped11
			usbBinaryPatchReplaceWithEscaped=$usbBinaryPatchReplaceWithEscaped11
		fi
	fi

	if [ -z "${doDonglePatch}" ]; then 
		doDonglePatch=$(shouldDoDonglePatch)
	fi
	if [ "${doDonglePatch}" == "1" ]; then
		echo "OK"
		setBthcSwitchBehaviorToAlways
		activateContinuityFeatureFlags
		enableLegacyWifi
	else
		echo -e "\rSkipping BT4 USB dongle patch...        OK"
	fi
}

#Sets the Bluetooth host controller switch behavior is set to always
function setBthcSwitchBehaviorToAlways()
{
	echo -n "Setting HCI switch behavior...          "
	sudo $nvramPath bluetoothHostControllerSwitchBehavior="always"
	echo "OK"
}

#Deletes the Bluetooth host controller switch behavior boot-arg (default OS X)
function disableBthcSwitchBehavior()
{
	echo -n "Disabling any HCI switch behavior...    "
	sudo $nvramPath -d bluetoothHostControllerSwitchBehavior
	echo "OK"
}

#Verifies if the Bluetooth features support Continuity (Feature Flags)
function areMyBtFeatureFlagsCompatible(){
	echo -n "Verifying Bluetooth features...         "

	local featureFlags=$($ioregPath -l | $grepPath "FeatureFlags" | $awkPath -F' = ' '{print $2}' | $tailPath -1)

	if [ ! "${featureFlags}" == "" ]; then
		if [ "${featureFlags}" == "15" ]; then
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Bluetooth features are Continuity compliant"; fi
		else
			if [ "${featureFlags}" == "7" ]; then
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "OK. Bluetooth features are currently not compatible with Continuity. This tool can try to fix this."; fi
			else
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "WARNING. Unknown Bluetooth features have been detected (code:${featureFlags}). This tool can try to fix this."; fi
			fi
		fi
	else
		if [ "$1" != "verbose" ]; then echo "NOT OK. No Bluetooth features could be detected. Aborting."; backToMainMenu;
		else echo "NOT OK. No Bluetooth features could be detected"; fi
	fi
}


#Verifies if the Wi-Fi features support Continuity (AWDL)
function isAwdlActive(){

	echo -n "Verifying AWDL status...                "	
	local awdlOutput=$($ifconfigPath -u | $grepPath awdl)

	if [ ! -z "${awdlOutput}" ]; then
		#an AWDL interface is up
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. An AWDL interface is up, Wi-Fi is ready for Continuity"; fi
	else
		#no AWDL interface is up 
		#verify if the right driver is in use, as the hardware might still be compatible
		local wifiDriverOutput=$($kextstatPath | $grepPath "Brcm4360")
		if [ ! -z "${wifiDriverOutput}" ]; then
			if [ "$1" != "verbose" ]; then echo "NOT OK"; #good driver, but no interface
			else echo "OK. Wi-Fi hardware is compatible with AWDL, but no such interface is up. This tool can try to fix this."; fi
		else
			wifiDriverOutput=$($kextstatPath | $grepPath "Brcm4331")
			if [ ! -z "${wifiDriverOutput}" ]; then
				if [ "$1" != "verbose" ]; then echo "OK"; #old driver, need to upgrade
				else echo "OK. No AWDL is active, but the hardware seems to be able to support it. This tool can try to fix this."; fi
			else
				if [ "$1" != "verbose" ]; then echo "NOT OK"; #unknown driver, not upgradable
				else echo "NOT OK. Your Wi-Fi card doesn't support AWDL, and therefore doesn't work with Continuity."; fi	
			fi	
		fi
	fi
}

#Displays the Bluetooth firmware version
function verifyFwVersion(){

	echo -n "Verifying Bluetooth firmware...         "
	fwVersion=$($ioregPath -l | $grepPath "FirmwareVersionString" | $awkPath -F' = ' 'END {print $2}' | $trPath -d '"')

	if [ ! -z "${fwVersion}" ]; then
		#a bluetooth firmware version was found
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Bluetooth firmware version: ${fwVersion}"; fi
	else
		#no Bluetooth firmware was found
		if [ "$1" != "verbose" ]; then echo "WARNING. No Bluetooth Firmware version could be found";
		else echo "WARNING. No Bluetooth Firmware version could be found"; fi
	fi
}

#Verifies if the USB Dongle patch has already been applied
function verifyFeatureFlagsPatch(){
	
	echo -n "Verifying BT4 dongles compatibility...  "

	#verify if the Bluetooth binary can be found
	if [ -f "$btBinPath" ]; then

		#verify if the file contains the pattern to replace
		local output=$($hexdumpPath -ve '1/1 "%.2X"' "${btBinPath}" | $grepPath "${usbBinaryPatchFind}")

		if [ -z "${output}" ]; then
		
			#the file doesn't contain the pattern to replace
			#verify if the file was already patched
			local output=$($hexdumpPath -ve '1/1 "%.2X"' "${btBinPath}" | $grepPath "${usbBinaryPatchReplaceWith}")

			if [ -z "${output}" ]; then
				if [ "$1" != "verbose" ]; then echo "WARNING. Unpatchable drivers found. They are either already patched or don't support CAT.";
				else echo "WARNING. Unpatchable drivers found. They are either already patched or don't support CAT."; fi
			else
				#already patched (patched pattern found)
				if [ "$1" != "verbose" ]; then echo "OK";
				else echo "OK. The patch that enables BT4 USB dongles compatibility has already been applied"; fi
				fi
		else
			#not yet patched (non-patched pattern found)
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Compatibility with BT4 USB dongles is not enabled, this tool can fix this if a dongle is plugged in"; fi
			
		fi
	else
		echo "NOT OK. Bluetooth drivers not found. Please use the uninstaller to restore drivers."
	fi
}


#Sets the IOBluetoothHCIController::FeatureFlags getter to always return 0xf, compatible with Continuity
function activateContinuityFeatureFlags(){

	echo -n "Patching Bluetooth feature flags...     "
			
	sudo $perlPath -i.bak -pe "s|${usbBinaryPatchFindEscaped}|${usbBinaryPatchReplaceWithEscaped}|sg" "${btBinPath}"
	#echo "$perlPath -i.bak -pe 's|${usbBinaryPatchFindEscaped}|${usbBinaryPatchReplaceWithEscaped}|sg' '${btBinPath}'"
	sudo $rmPath "${btBinPath}.bak"
	
	#Confirm if the patching was done
	local output=$($hexdumpPath -ve '1/1 "%.2X"' "${btBinPath}" | $grepPath "${usbBinaryPatchReplaceWith}")

	if [ -z "${output}" ]; then
		echo "NOT OK. The patch that enables BT4 USB dongles compatibility failed"
	else
		echo "OK"
	fi
}


#Injects the legacy Broadcom device-id(s) (declared in the global variable legacyBrcmCardIds) in the AirPortBrcm4360.kext plugin. Those cards are found in older MacBooks for example.
function enableLegacyWifi(){

	echo -n "Applying legacy Wi-Fi card patch...     "

	if [ -f "$wifiKextPath/Contents/PlugIns/$wifiBrcmKextFilename/Contents/Info.plist" ]; then 
		
		#verify if the card is already whitelisted (only checks the first entry, where it is set by CAT)
		#gets the card on top of the IOPersonalities list of the Brcm4360 driver. e.g. pci14e4,43ba
		local output=$("$plistBuddyPath" -c "Print IOKitPersonalities:'Broadcom 802.11 PCI':IONameMatch:0" "$wifiKextPath/Contents/PlugIns/$wifiBrcmKextFilename/Contents/Info.plist") >> /dev/null 2>&1
		legacyWifiAlreadyEnabled=$(containsElement "$output" "${legacyBrcmCardIds[@]}"; echo $?;)

		if [ "$legacyWifiAlreadyEnabled" == "1" -a "$forceHack" == "0" ]; then
		
			#entry found
			echo -e "\rSkipping legacy Wi-Fi cards patch...    OK";
		else
			#dump the legacy card ids in the new driver
			for cardId in "${legacyBrcmCardIds[@]}";
			do
				output=$("$plistBuddyPath" -c "Add IOKitPersonalities:'Broadcom 802.11 PCI':IONameMatch:0 string $cardId" "$wifiKextPath/Contents/PlugIns/$wifiBrcmKextFilename/Contents/Info.plist") >> /dev/null 2>&1
			done
			if [ "$?" ==  "0" ]; then
				echo "OK"; legacyWifiPatchApplied="1";
			else
				echo "WARNING: There was an error while whitelisting the legacy Broadcom Wi-Fi cards"
			fi
		fi
	else
		echo "NOT OK. Wi-Fi drivers not found. Please use the uninstaller to restore drivers."
	fi
}

#Detects if the legacy Broadcom BCM94322 device-id is set in the AirPortBrcm4360.kext plugin. Those cards are found in older MacBooks for example.
#Returns 1 if true, 0 if false. In verbose mode, prints an explanation.
function hasTheLegacyWifiPatchBeenApplied(){

	echo -n "Verifying legacy Wi-Fi card patch...    "

	#verify if the card is already whitelisted (only checks the first entry, where it is set by CAT)
	
	#verify if the Wi-Fi driver is present
	if [ -f "$wifiKextPath/Contents/PlugIns/$wifiBrcmKextFilename/Contents/Info.plist" ]; then

		local output=$("$plistBuddyPath" -c "Print IOKitPersonalities:'Broadcom 802.11 PCI':IONameMatch:0" "$wifiKextPath/Contents/PlugIns/$wifiBrcmKextFilename/Contents/Info.plist") >> /dev/null 2>&1

		local legacyBrcmCardId=${legacyBrcmCardIds[${#legacyBrcmCardIds[@]} - 1]}

		if [ ! -z "$output" -a "$output" == "$legacyBrcmCardId" ]; then
			#entry found
			if [ "$1" == "verbose" ]; then echo "OK. The patch is already done. Old Broadcom Wi-Fi cards may work."; legacyWifiPatchApplied="1"; else echo "OK"; legacyWifiPatchApplied="1"; fi
		else
			if [ "$1" == "verbose" ]; then echo "OK. The legacy Wi-Fi patch is not present. This tool can fix this."; else echo "OK"; fi
		fi
	else
		if [ "$1" == "verbose" ]; then echo "NOT OK. Wi-Fi drivers not found. Please use the uninstaller to fix this."; else echo "NOT OK. Wi-Fi drivers not found. Please use the uninstaller to fix this. Aborting."; backToMainMenu; fi
	fi
}

#------------ BT USB Specific Procedures End ------------------

#Uses a app that checks the SFDeviceSupportsContinuity flag, used in Apple's Sharing private framework
#This is indicator is used by System Report to determine whether Handoff and Instant Hotspot are active,
#meaning that it should be a reliable indicator of Continuity's status system wide
#This function return 1 if Continuity is active, 0 if not, -1 if there's an error
function verifySystemWideContinuityStatus(){
	#verify utility file presence
	$duPath -hs "$continuityCheckUtilPath" >> /dev/null 2>&1
	local error=$?
	if [ "$error" == "0" ]; then #ok, utility was found
		if [ "$1" == "verbose" ]; then echo -n "Verifying Continuity status...          "; fi

		#call the utility to check system wide Continuity status
		"$continuityCheckUtilPath" -silent >> /dev/null 2>&1
		local result=$?
		if [ "$result" == "1" ]; then
			if [ "$1" == "verbose" ]; then echo "OK. OS X reports Continuity as active"; else echo "1"; fi
		else
			if [ "$1" == "verbose" ]; then echo "OK. OS X reports Continuity as inactive"; else echo "0"; fi
		fi
	else
		if [ "$1" == "verbose" ]; then echo "NOT OK. The utility necessary for the check was not found"; else echo "-1"; fi
	fi
}

#Makes a backup of the Wifi kext and Bluetooth kext, in a "Backup" folder located in the directory declared as argument
#Any existing copies of these kexts in the backup dir will be silently replaced
function backupKexts(){

	local backupType=""
	local backupFolder=$1

	#set a relevant backup message
	if [ ! -z "$backupFolder" -a "${backupFolder}" == "${backupFolderBeforePatch}" ]; then backupType="original "; fi
	if [ ! -z "$backupFolder" -a "${backupFolder}" == "${backupFolderAfterPatch}" ]; then backupType="patched "; fi
	local prettySpacing=""

	#ensures the OK / NOT ok are nicely aligned with the other steps results
	if [ "${backupType}" == "patched " ]; then
		prettySpacing=" "
	fi
	echo -n "Backing up ${backupType}drivers...          ${prettySpacing}"


	#verify if args were passed
	if [ -z "$backupFolder" ]; then
		echo "NOT OK. No backup folder was given. Skipping drivers backup."
	else

		sudo echo "" >> /dev/null 2>&1 #make sure sudo is still active
		local skipBackup="0" #set to "1" if the user requests the backup to be skipped

		#Verify if the system kexts are there
		if [ ! -d "${btKextPath}" -o ! -d "${wifiKextPath}" ]; then 
			echo "NOT OK. ${btKextFilename} or ${wifiKextFilename} could not be found. Aborting."
			backToMainMenu
		else
			#verify if the backup folder already exists
			if [ -d "${backupFolder}" ]; then #it does exist

				#verify existence of kext backups
				if [ -d "${backupFolder}/${wifiKextFilename}" -o -d "${backupFolder}/${btKextFilename}" ];
					then
					echo "Would you like to overwrite the existing backup found in ${backupFolder}? "
					select yn in "Yes, overwrite" "No, skip this backup"; do
						case $yn in
							'Yes, overwrite') #continue
								#remove any existing previous kext backups.
								$rmPath -rf "${backupFolder}/${wifiKextFilename}"; $rmPath -rf "${backupFolder}/${btKextFilename}"; break;;
							'No, skip this backup') skipBackup="1"; break;;
							*) echo "Invalid option, enter a number";;
						esac
					done
				fi
			else
				$mkdirPath -p "${backupFolder}"
			fi

			if [ "${skipBackup}" == "0" ]; then
				local backupOk=0
				local errorOutput=""

				if $cpPath -R "${btKextPath}/" "${backupFolder}/${btKextFilename}"; then ((backupOk+=1)); else errorOutput="${btKextFilename} backup failed."; fi
				if $cpPath -R "${wifiKextPath}/" "${backupFolder}/${wifiKextFilename}"; then ((backupOk+=1)); else errorOutput="${errorOutput} ${wifiKextFilename} backup failed."; fi
				if [ "${backupOk}" -eq "2" ]; then
				echo "OK. Wi-Fi and Bluetooth kexts were backed up in '${backupFolder}'"
				else
				echo "NOT OK. ${errorOutput}"
				fi
			else
				#skip backup. no changes were applied.
				echo "Skipping backup...                      OK"
			fi
		fi
	fi
}

#Replaces a string in a binary file by the one given. Usage : patchStringsInFile foo "old_string" "new_string"
#Used to replace strings in a file, used for patching the kext.
function patchStringsInFile() {
    local FILE="$1"
    local PATTERN="$2"
    local REPLACEMENT="$3"
    #Find all unique strings in FILE that contain the pattern 
    STRINGS=$("${stringsPath}" "${FILE}" "${PATTERN}" | awk -F" " '{print $1}' | sort -u -r)

    if [ "${STRINGS}" != "" ] ; then
        #echo "File '${FILE}' contain strings with '${PATTERN}' in them:"
        for OFFSET in ${STRINGS} ; do
            # Create the new string with a simple bash-replacement
            printf '\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' | dd of="$FILE" bs=1 seek="0x""$OFFSET" conv=notrunc >> /dev/null 2>&1
            printf "%s" $REPLACEMENT | dd of="$FILE" bs=1 seek="0x""$OFFSET" conv=notrunc >> /dev/null 2>&1
        done
    else
    	echo "NOT OK. No filepath given for the hacking. Aborting."
    	backToMainMenu
    fi
}


#Detects the presence of an obsolete Broadcom 4331 Wi-Fi kext.
#That driver can in some cases override the Continuity enabled 4360 kext (not wanted).
function detectLegacyWifiDriver(){
	
	echo -n "Verifying old Wi-Fi kext presence...    "

		#detect the presence of the legacy Broadcom 4331 driver
	if [ -d "${wifiObsoleteBrcmKextPath}" ]; then
		#kext exists 
		if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Legacy Brcm4331 Wi-Fi driver is present. This tool can fix this."; fi
	else
		#kext not found - consider it patched
		legacyWifiKextsRemoved="1";
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Legacy Wi-Fi driver Brcm4331 was already removed"; fi
	fi
}

#Removes the AirPortBrcm4331 and AppleAirPortBrcm43224 legacy Wi-Fi kext that could load and override the Continuity enabled Brcm4360 driver
#Note: it's important to backup the Wi-Fi kext before doing this
function removeObsoleteWifiDriver(){
	
	#verify if the Brcm4331 kext needs to be removed
	#detect the presence of the legacy 4331 driver
	if [ -d "${wifiObsoleteBrcmKextPath}" ]; then
		echo -n "Cleaning up old Wi-Fi kext...           "

		#kext exist
		#remove any existing previous kext backups
		sudo $rmPath -rf "${wifiObsoleteBrcmKextPath}" >> /dev/null 2>&1
		local result=$?

		if [ "${result}" == "1" ]; then
			echo "WARNING. Failed to delete the legacy Brcm4331 Wi-Fi kext. Continuing." #Continuity might still work (as in v.1.0.0 and v.1.0.1 of the script)
		else
			legacyWifiKextsRemoved="1"
			echo "OK"; #removal successful
		fi
	else
		echo "Skipping old Wi-Fi driver clean up...   OK" #obsolete kext has already been removed
	fi
}

#Disables the blacklist in the bluetooth drivers, only if the current Mac Model is blacklisted.
#A prerequisite is to run the isMyMacBlacklisted function, as it
#will determine whether the Mac is blacklisted. If not done, no patching happens.
# e.g. MacBookAir4,2 will be turned into MacBookAir1,1
function patchBluetoothKext(){

	#verify if mac is blacklisted, if not skip
	if [ "${myMacIsBlacklisted}" == "1" ]; then
		echo -n "Patching blacklist..."
		
		#(re)populate blacklist
		blacklistedMacs=($("${stringsPath}" ${btBinPath} "Mac" | $awkPath -F"'" '{print $2}'))

    	#build a disabled blacklist
    	local disabledBlacklist=()
    	local blacklistedMac
    	for blacklistedMac in "${blacklistedMacs[@]}";
    	do
    		#replace the last three chars of the mac model with "1,1", e.g. MacBookAir4,2 -> MacBookAir1,1
    		disabledBlacklist+=($(echo $blacklistedMac | $revPath | $cutPath -c 4- | $revPath | $awkPath '{print $1"1,1"}'))
    	done

    	#verify that the disabled blacklist is correctly built (last chance before applying the hack)
    	if [ "${#disabledBlacklist[@]}" -gt "0" -a "${#disabledBlacklist[@]}" -eq "${#blacklistedMacs[@]}" ]; then

    		#use the helper function to apply the hack
    		for (( i = 0; i < ${#blacklistedMacs[@]}; i++ )); do
    			#patchStringsInFile foo "old string" "new string"
    			patchStringsInFile "${btBinPath}" "${blacklistedMacs[i]}" "${disabledBlacklist[i]}"
    			echo -n "."
    		done
    		echo "              OK"
    	else
    		echo "NOT OK. Failed to disable the blacklist - no changes were applied. Aborting."; backToMainMenu
    	fi
	else
		echo "Skipping blacklist patch...             OK"
	fi
}

#Puts the current Mac board-id in the Brcm 4360 whitelist, the only driver that works with Continuity
#All board-ids are replaced with the current system's own board id
#Patching is skipped if the whitelist is already filled with own board id
function patchWifiKext(){

	#get the current board id
	if [ -z "${myMacIdPattern}" ]; then
		myMacIdPattern=$($ioregPath -l | $grepPath "board-id" | $awkPath -F\" '{print $4}')
	fi

	#populate whitelist
	local whitelist=($("${stringsPath}" ${wifiBrcmBinPath} "Mac-" | $awkPath -F" " '{print $2}'))

	#check if it needs patching: will do it if the whitelist is not full of own board id
	local occurence=0
	local whitelistedBoardId
	for whitelistedBoardId in "${whitelist[@]}"; do
  		if [ "${whitelistedBoardId}" == "${myMacIdPattern}" ]; then ((occurence+=1)); fi
	done
	#only skip the wifi patching if the wifi kext is not exactly patched as this script does: with all board-ids replaced by own board-id
	if [ "${occurence}" -eq "${#whitelist[@]}" ]; then
		whitelistAlreadyPatched="1"
		echo "Skipping whitelist patch...             OK"
	else
		echo -n "Patching whitelist..."
		local whitelistedBoardId
		for whitelistedBoardId in "${whitelist[@]}"; do
			#do the patch, one by one
			patchStringsInFile "${wifiBrcmBinPath}" "${whitelistedBoardId}" "${myMacIdPattern}"
			echo -n "."
		done
		echo "     OK"
	fi
}

#Applies permissions known to work for the Wi-Fi and Bluetooth Kexts.
function applyPermissions(){
	echo -n "Applying correct permissions...         "
	
	sudo $chownPath -R root:wheel "${btKextPath}"
	sudo $chownPath -R root:wheel "${wifiKextPath}"
	sudo $chmodPath -R 755 "${btKextPath}"
	sudo $chmodPath -R 755 "${wifiKextPath}"

	echo "OK"
}

#Displays a spinner for long activities
function spinner(){
	pid=$! # Process Id of the previous running command

	spin='-\|/'

	i=0
	while kill -0 "$pid" 2>/dev/null
	do
  		i=$(( (i+1) %4 ))
  		printf "\r$1${spin:$i:1}"
  		sleep .1
	done
}

#Avoids having OS X reuse unpatched cached kexts at system startup
function updatePrelinkedKernelCache(){
	sudo $kextcachePath -system-prelinked-kernel >> /dev/null 2>&1 & spinner "Updating kext caches...                 "
	echo -e "\rUpdating kext caches...                 OK"
}

#Avoids having OS X reuse unpatched cached kexts at late system startup and beyond
function updateSystemCache(){
	sudo $kextcachePath -system-caches >> /dev/null 2>&1 & spinner "Updating system caches...               "
	echo -e "\rUpdating system caches...               OK"
}

#Silently repairs the disk permissions using the Disk Utility. Takes a few minutes.
function repairDiskPermissions(){
	$diskutilPath repairpermissions / >> /dev/null 2>&1 & spinner "Fixing disk permissions (~5min wait)... "
	echo -e "\rFixing disk permissions...              OK"
}

#A utility to check for the System Continuity and kext-dev-mode status. 
#Will warn the user after logging in if Continuity is not active.
function autoCheckApp(){
	if [ -z "$1" ]; then
    	echo "Internal error: No login item argument given."; backToMainMenu;
    else
    	if [ "$1" == "enable" ]; then
			echo "Do you want to enable a Automatic check for Continuity each boot?";
			select yn in "Yes" "No"; do
				case $yn in
					Yes) #continue
						break;;
					No) echo "OK.";
						return;;
					*) echo "Invalid option, enter a number";;
				esac
			done
			osascript -e 'tell application "System Events" to make login item at end with properties {path:"'"$appDir"'/continuityCheck.app", hidden:false}'  > /dev/null
			echo "OK. Automatic continuity check enabled."
		else
			if [ "$1" == "disable" ]; then
				osascript -e 'tell application "System Events" to delete login item "continuityCheck"' > /dev/null
				echo "OK. Automatic continuity check disabled."	
			else 
				echo "Internal error: Wrong login item argument given."
			fi
		fi
	fi				
}

#Verfies if autoCheckApp is already installed.
function checkLoginItem(){
	echo -n "Verifying Login Item...                 "
	result="$(osascript -e 'tell application "System Events" to return the name of every login item')" >> /dev/null 2>&1
	if [[ $result == *"continuityCheck"* ]]; then
		autoCheckAppEnabled="1"
		if [ "$1" != "verbose" ]; then echo "OK. Auto Continuity Check on";
		else echo "OK. Login item for Auto Continuity Check is set."; 
		fi
	else 
		autoCheckAppEnabled="0"
		if [ "$1" != "verbose" ]; then echo "OK. Auto Continuity Check off";
		else echo "OK. Login item for Auto Continuity Check is not set."; 
		fi
	fi
}

#Verifies if the kexts from a previous backup can be restored, otherwise use those from the Recovery Disk
function startTheKextsReplacement(){

	echo -n "Restoring kexts...                      "

	#verify CAT 1.0.2 backup directory presence
	if [ "${forceRecoveryDiskBackup}" == "1" ]; then
		echo "OK. Using Recovery Disk backups."
		mountRecoveryBaseSystem
		replaceKextsWithRecoveryDiskOnes
	else

		#check the presence of CAT >=1.0.2 backups
		$duPath -hs "${backupFolderBeforePatch}/${btKextFilename}" >> /dev/null 2>&1
		local btPermissionsError=$?
		$duPath -hs "${backupFolderBeforePatch}/${wifiKextFilename}"  >> /dev/null 2>&1
		local wifiPermissionsError=$?
		local permissionsError=$((btPermissionsError + wifiPermissionsError))

		#presence detection of CAT <=1.0.1 backups is deprecacted
		
		if [ "${permissionsError}" -eq "0" ]; then
			#a kext backup made with a recent CAT version exists, recover those
			#silently remove any existing previous kext backups (doesn't care if the old kexts were found or not)
			sudo $rmPath -rf "${wifiKextPath}" >> /dev/null 2>&1
			sudo $rmPath -rf "${btKextPath}" >> /dev/null 2>&1

			#create the kexts directories in the System Extensions folder
			sudo $mkdirPath -p "${wifiKextPath}"
			sudo $mkdirPath -p "${btKextPath}"

			#now copy the clean kexts
			local uninstallOk=0
			local errorOutput=""

			if sudo $cpPath -R "${backupFolderBeforePatch}/${wifiKextFilename}/" "${driverPath}/${wifiKextFilename}"; then ((uninstallOk+=1)); else errorOutput="Failed to restore ${wifiKextFilename} from ${backupFolderBeforePatch}."; fi
			if sudo $cpPath -R "${backupFolderBeforePatch}/${btKextFilename}/" "${driverPath}/${btKextFilename}"; then ((uninstallOk+=1)); else errorOutput="${errorOutput} Failed to restore ${btKextFilename} from ${backupFolderBeforePatch}."; fi
		
			if [ "${uninstallOk}" -eq "2" ]; then
				echo "OK. Restored backup drivers found in '${backupFolderBeforePatch}'"
			else
				echo "NOT OK. ${errorOutput}."; backToMainMenu;
			fi
		else
			#no backups made with CAT were found. Use the OSX recovery disk
			echo "OK. No backups made with the tool were found, using the OS X Recovery Disk backups."
			mountRecoveryBaseSystem
			replaceKextsWithRecoveryDiskOnes
		fi
	fi

}

#Mounts the Recovery disk and OS X's Base System image, where the original drivers should be located
function mountRecoveryBaseSystem(){

	$diskutilPath mount "${recoveryHdName}" >> /dev/null 2>&1

	if [ $? == "1" ]; then
		echo "Mounting Recovery HD...                 NOT OK. Error mounting '${recoveryHdName}'"; backToMainMenu
	else
		#disk mounted
		if [ -f "${recoveryDmgPath}" ]; then

				#attach the OS X Base System DMG without opening a Finder window
				$hdiutilPath attach -nobrowse "${recoveryDmgPath}"  >> /dev/null 2>&1 & spinner "Mounting Recovery HD...                 "
			if [ $? == "1" ]; then
				echo -e "\rMounting Recovery HD...                 NOT OK. Error attaching '${recoveryDmgPath}'"; backToMainMenu
			else

				echo -e "\rMounting Recovery HD...                 OK"
			fi
		else
			echo "Mounting Recovery HD...                 NOT OK. The recovery DMG could not be found at ${recoveryDmgPath}"; backToMainMenu
		fi
	fi
}

#Replaces the Wi-Fi and Bluetooth kexts with clean ones, directly from the OS X Recovery drive
function replaceKextsWithRecoveryDiskOnes(){

	echo -n "Reinstalling original Apple drivers...  "

	#detect the presence of the base system kexts files
	if [ -d "${osxBaseSystemPath}/${wifiKextPath}" -a -d "${osxBaseSystemPath}/${btKextPath}" ]; then

		#silently remove any existing previous kext backups (doesn't care if the old kexts were found or not)
		sudo $rmPath -rf "${wifiKextPath}" >> /dev/null 2>&1
		sudo $rmPath -rf "${btKextPath}" >> /dev/null 2>&1

		#create the kexts directories in the System Extensions folder
		sudo $mkdirPath -p "${wifiKextPath}"
		sudo $mkdirPath -p "${btKextPath}"

		#now copy the clean kexts
		local uninstallOk=0
		local errorOutput=""

		if sudo $cpPath -R "${osxBaseSystemPath}/${wifiKextPath}/" "${driverPath}/${wifiKextFilename}"; then ((uninstallOk+=1)); else errorOutput="${wifiKextFilename} uninstallation failed."; fi
		if sudo $cpPath -R "${osxBaseSystemPath}/${btKextPath}/" "${driverPath}/${btKextFilename}"; then ((uninstallOk+=1)); else errorOutput="${errorOutput} ${btKextFilename} uninstallation failed."; fi
		
		if [ "${uninstallOk}" -eq "2" ]; then
			$hdiutilPath detach -force -quiet "/Volumes/Recovery HD"
			echo "OK"
		else
			echo "NOT OK. ${errorOutput}."; backToMainMenu;
		fi
	else
		echo "NOT OK" #obsolete kext has already been removed
	fi
}

#Sets the backup folders paths in the current user dir
#If it can't find the user dir, if puts them in the root folder of the .app
#If it can't find the .app container (e.g. script is run stripped of its app wrapper) then the backup folder will be at the root folder of the script
function initializeBackupFolders {

	if [[ "$appDir" == *.app/Contents/Resources* ]]; then #the script is run from within its .app wrapper

		if [[ "$appDir" == /Users/* ]]; then
			currentUserName=$(echo "$appDir" | awk -F'/' '{print $3}') #dirty trick to get the current user name, since the script is normally run as root. It gets the username from the app's path.
			backupFolderBeforePatch="/Users/$currentUserName/$backupFolderNameBeforePatch"
			backupFolderAfterPatch="/Users/$currentUserName/$backupFolderNameAfterPatch"
		else
			cd "$appDir"
			cd ../../..
			backupFolderBeforePatch="$PWD/$backupFolderNameBeforePatch"
			backupFolderAfterPatch="$PWD/$backupFolderNameAfterPatch"
		fi
	else #the script is run outside its .app wrapper
		cd "$appDir"
		cd ../../..
		backupFolderBeforePatch="$PWD/$backupFolderNameBeforePatch"
		backupFolderAfterPatch="$PWD/$backupFolderNameAfterPatch"
	fi

}

#Prompts to go back to the main menu
function backToMainMenu(){
	echo ""
	$readPath -n 1 -p "Press any key to go back to the main menu..."
	displayMainMenu
}

#Initiates the compatibility checks, aborts the script if an uncompatible configuration is detected.
#In case of error, an interpretation of it is displayed.
function compatibilityPrecautions(){
	displaySplash
	echo '--- Initiating system compatibility check ---'
	echo ''
	if [ "$subVersion" -eq 11 ]; then
		verifySIP
	fi
	initializeBackupFolders
	isMyMacModelCompatible
	isMyMacBoardIdCompatible
	isMyMacOSCompatible
	areMyActiveWifiDriversOk
	isMyBluetoothVersionCompatible
	areMyBtFeatureFlagsCompatible
	if [ "$subVersion" -eq 11 ]; then
		checkContinuitySupport "verbose"
		verifySIP
		if [ $? -eq 0 ]; then
			echo "To continue you need to disable System Integrity Protection and come back here."
			echo "1. Reboot and hold CMD + R"
			echo "2. Utilities - Terminal"
			echo "3. enter 'csrutil disable'"
			echo "4. reboot"
			exit;
		fi
	fi
	canMyKextsBeModded
	if [ "$subVersion" -ne 11 ]; then
		isMyMacBlacklisted "verbose"
	fi
	isMyMacWhitelisted
	hasTheLegacyWifiPatchBeenApplied
	detectLegacyWifiDriver
	checkLoginItem
}

#Initiates the system compatibility checks, displays detailed interpretations of each test's result.
#The goal is to understand if and why the system is compatible with this mod.
function verboseCompatibilityCheck(){
	displaySplash
	echo '--- Initiating system compatiblity check ---'
	echo ''
	echo '--- Hardware/OS checks ---'
	initializeBackupFolders
	verifySystemWideContinuityStatus "verbose"
	isMyMacModelCompatible "verbose"
	isMyMacBoardIdCompatible "verbose"
	isMyMacOSCompatible "verbose"
	areMyActiveWifiDriversOk "verbose"
	isAwdlActive "verbose"
	isABluetoothDongleActive "verbose"
	isMyBluetoothVersionCompatible "verbose"
	areMyBtFeatureFlagsCompatible "verbose"
	verifyFwVersion "verbose"
	checkLoginItem "verbose"
	echo ''
	echo '--- Modifications check ---'
	verifyOsKextDevMode "verbose"
	if [ "$subVersion" -eq 11 ]; then
		verifySIP "verbose"
		checkContinuitySupport "verbose"
	fi
	canMyKextsBeModded "verbose"
	isMyMacWhitelisted "verbose"
	if [ "$subVersion" -ne 11 ]; then
		isMyMacBlacklisted "verbose"
	fi
	verifyFeatureFlagsPatch "verbose"
	detectLegacyWifiDriver "verbose"
	hasTheLegacyWifiPatchBeenApplied "verbose"
	echo '--- Modifications check ---'
}

#Initiates the backup, patching and clean-up.
function checkAndHack(){
	
	if [ "${forceHack}" != "1" ]; then
		
		#reset the patching flags in case they were set in a previous hack/diagnostic in the same session. They will be set again.
		whitelistAlreadyPatched=0
		myMacIsBlacklisted=0
		legacyWifiKextsRemoved=0
		doDonglePatch=0
		legacyWifiPatchApplied=0

		#run the checks
		compatibilityPrecautions 
	else
		doDonglePatch="1"
		if [ $subVersion -ne 11 ]; then
			myMacIsBlacklisted="1"
		fi
	fi

	echo ""
	echo '--- Initiating Continuity mod ---'
	echo ""

	#prevent patching if all the patches were detected to be already applied
	if [ "${doDonglePatch}" == "0" ]; then
		doDonglePatch=$(shouldDoDonglePatch)
	fi

	#echo "whitelistAlreadyPatched=$whitelistAlreadyPatched myMacIsBlacklisted=$myMacIsBlacklisted doDonglePatch=$doDonglePatch"
	if [ "${whitelistAlreadyPatched}" == "1" -a "${myMacIsBlacklisted}" == "0" -a "${legacyWifiKextsRemoved}" == "1" -a "${doDonglePatch}" == "0" -a "${legacyWifiPatchApplied}" == "1" ]; then
		echo "No changes were applied, your system seems to be already OK for Continuity"
		backToMainMenu
	fi

	initializeBackupFolders
	modifyKextDevMode "enableDevMode"
	repairDiskPermissions
	backupKexts "${backupFolderBeforePatch}"
	
	if [ "$subVersion" -ne 11 ]; then
		patchBluetoothKext
	fi
	
	initiateDonglePatch
		
	patchWifiKext
	removeObsoleteWifiDriver
	enableLegacyWifi
	
	if [ "$subVersion" -eq 11 ]; then 
		patchContinuitySupport "enable"
	fi
	
	updatePrelinkedKernelCache
	updateSystemCache
	backupKexts "${backupFolderAfterPatch}"
	
	if [ "${autoCheckAppEnabled}" == 0 ]; then
		autoCheckApp "enable"
	fi
	
	echo ""
	echo "ALMOST DONE! After rebooting:"
	echo "1) Make sure that both your Mac and iOS device have Bluetooth turned on, and are on the same Wi-Fi network."
	echo "2) On OS X go to SYSTEM PREFERENCES> GENERAL> and ENABLE HANDOFF."
	echo "3) On iOS go to SETTINGS> GENERAL> HANDOFF & SUGGESTED APPS> and ENABLE HANDOFF."
	echo "4) On OS X, sign out and then sign in again to your iCloud account."
	echo "Troubleshooting: support.apple.com/kb/TS5458"
	echo "After verifying that Continuity works, you can reenable SIP via the Recovery OS";
	displayThanks
	rebootPrompt
}

#Puts back a clean OS X wireless drivers stack, and attempts to disable the kext-dev-mode
function uninstall(){
	displaySplash
	echo '--- Initiating uninstallation ---'
	echo ''
	
	if [ "$subVersion" -eq 11 ]; then
		verifySIP
		if [ $? -eq 0 ]; then
			echo "To continue you need to disable System Integrity Protection and come back here."
			echo "1. Reboot and hold CMD + R"
			echo "2. Utilities - Terminal"
			echo "3. enter 'csrutil disable'"
			echo "4. reboot"
			exit;
		fi
	fi
	
	initializeBackupFolders
	startTheKextsReplacement
	applyPermissions
	updatePrelinkedKernelCache
	updateSystemCache
	disableBthcSwitchBehavior
	modifyKextDevMode "disableDevMode"
	patchContinuitySupport "disable"
	autoCheckApp "disable"
	echo ""
	echo ""
	echo "DONE. Please reboot now to complete the uninstallation."	
	if [ "$subVersion" -eq 11 ]; then
		echo "You can reenable the SIP if you want to."
		echo "1. Reboot and hold CMD + R"
		echo "2. Utilities - Terminal"
		echo "3. enter 'csrutil enable'"
		echo "4. reboot"
	fi	
	echo ""
	rebootPrompt
}
#Displays the application splash at the top of the Terminal screen
function displaySplash(){
	tput clear
	echo "--- OS X Continuity Activation Tool ${hackVersion} ---"
	echo "                 by dokterdok                 "
	echo "                                              "
	echo ""	
}

#Displays credits, people who helped make it happen
function displayThanks(){
	echo ""
	echo "Thanks to Lem3ssie, UncleSchnitty, Skvo, toleda, TealShark, Manic Harmonic, rob3r7o, RehabMan, kramsee and the many beta testers for their support."
	echo "Updated for El Capitan by sysfloat"
	echo ""
	echo ""
}

#Resizes the Terminal Window and recolors the font/background, puts the Terminal window in the foreground
function applyTerminalTheme(){
	tput setab 0
	tput setaf 10
	printf '\e[8;30;158t'
	printf '\e[3;0;0t'
	tput clear
	osascript -e 'tell application "Terminal" to activate'
}

#Verifies if the script is run with sudo privileges otherwise warns the user and quits the script. Clears the screen after execution
function verifySudoPrivileges(){
	if [[ -z "$SUDO_COMMAND" ]]; then
		echo ""
		echo "You must run this script with admin privileges, please re-run the script with sudo. Aborting."
		echo ""
		exit;
	fi
}

#Shows arguments help if the tool when used from the command line
function showUsage(){
	echo "usage: contitool.sh -a | -d | -f | -h | -r | -z"
	echo ""
	echo "Options:"
	echo "  -a               run the compatibility checks and activation procedure"
	echo "  -d               run the system diagnostic procedure and quit"
	echo "  -f               force the activation procedure without compatibility checks"
	echo "  -h               display a help message and quit"
	echo "  -r               uninstall Continuity mods by directly using OS X recovery disk files"
	echo "  -z               uninstall Continuity mods"
}

function launchedFromApp() {
	GPPID=$(ps -fp $PPID | awk "/$PPID/"' { print $3 } ')
	GGPPID=$(ps -fp $GPPID | awk "/$GPPID/"' { print $3 } ')
	GGParent=$(ps -ocommand= -p $GGPPID | awk -F/ '{print $NF}' | awk '{print $1}')
	return $([[ $GGParent =~ .*contitool\.sh.* ]])
}

#Displays the main menu and asks the user to select an option
function displayMainMenu(){
	displaySplash
	echo "Select an option:"
	echo ""
	options=("Activate Continuity" "System Diagnostic" "Uninstall" "Uninstall with Recovery" "Disable Auto Check App" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			'Activate Continuity') 
				if [[ $(verifySystemWideContinuityStatus) != "1" ]]; then 
					displayBluetoothDonglePrompt
					checkAndHack
				else
					displaySplash
					echo ""
					echo "OS X reports Continuity as active."
					if [ "$subVersion" -eq 11 ] && [[ $(checkContinuitySupport) != "1" ]]; then
						patchContinuitySupport "enable"
						rebootPrompt
					else
						echo "No changes were applied."
					fi
					backToMainMenu
				fi
				;;
			'System Diagnostic')
				verboseCompatibilityCheck
				backToMainMenu
				;;
			'Uninstall') 
				uninstall
				;;
			'Uninstall with Recovery')
				verifySudoPrivileges
				verifyStringsUtilPresence
				forceRecoveryDiskBackup=1
				uninstall
				;;
			'Disable Auto Check App')
				autoCheckApp "disable"
				;;
			'Quit')
				displayThanks
				if launchedFromApp; then
					osascript -e 'tell application "Terminal" to quit'
				fi
				exit;;
			*)
		 		echo "Invalid option, enter a number"
		 		;;
		esac
	done
}

if [ $# -eq 0 ]; then 
	applyTerminalTheme
	verifySudoPrivileges
	verifyStringsUtilPresence
	displayMainMenu
else
	while [ "$1" != "" ]; do
	    case $1 in
	        -a | --activate )       		verifySudoPrivileges
											verifyStringsUtilPresence
											checkAndHack
	                                		;;
	        -d | --diagnostic )     		verifyStringsUtilPresence
											verboseCompatibilityCheck
	                                		;;
	        -f | --forceHack )				verifySudoPrivileges
											verifyStringsUtilPresence
											forceHack=1
											checkAndHack
											;;
	        -h | --help )           		showUsage
	                                		exit
	                                		;;
			-r | --uninstallWithRecovery )  verifySudoPrivileges
											verifyStringsUtilPresence
											forceRecoveryDiskBackup=1
											uninstall
											;;
	        -z | --uninstall )				verifySudoPrivileges
											verifyStringsUtilPresence
											uninstall
											;;
	        * )                     		showUsage
	                                		exit 1
	    esac
	    shift
	done
fi

echo ""
echo ""
