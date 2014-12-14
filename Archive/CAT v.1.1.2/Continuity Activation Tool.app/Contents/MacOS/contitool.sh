#!/bin/bash

#---- INTRO ---------------
#
# Continuity Activation Tool - built by dokterdok
#
# Description: This script enables OS X 10.10 Continuity features when compatible hardware is detected.
# Continuity features activated by this tool include Application Handoff, Instant Hotspot, and Airdrop iOS<->OSX.
# The tool has no influence over Call/SMS Handoff.
#
# Before the actual hacking happens, a system compatibility test is made, 
# as well as a backup of the bluetooth and wifi kexts, before and after patching.
# The system check produces a report of typical parameters influencing.
# An uninstaller is available as well.
#
# This hack should work with:
# * mid-2010 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * early-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * late-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * mid-2011 MacBook Airs (no hardware modification required)
# * mid-2011 Mac Minis (no hardware modification required)
# Other Mac models are untested and will be prompted with a warning before applying the hack.
# 

hackVersion="1.1.2"

#---- CONFIG VARIABLES ----
forceHack="0" #default is 0. when set to 1, skips all compatibility checks and forces the hack to be applied (WARNING: may corrupt your system)
myMacIdPattern="" #Mac board id, detected later. Can be manually set here for debugging purposes. E.g.: Mac-00BE6ED71E35EB86.
myMacModel="" #Mac model nb, automatically detected later. Can be manually set here for debugging purposes. E.g.: MacBookAir4,1

whitelistAlreadyPatched="0" #automatically set to 1 when detected that the current board-id is whitelisted in the Wi-Fi drivers.
myMacIsBlacklisted="0" #automatically set to 1 when detected that the Mac model is blacklisted in the Bluetooth drivers.
legacyWifiAlreadyPatched="0" #automatically set to 1 when the older Broadcom 4331 Wi-Fi kext plugin can't be found in the Wi-Fi drivers
forceRecoveryDiskBackup="0" #automatically set to 1 when backups made by the Continuity Activation Tool can't be found. It's a flag used to determine if kext from the Recovery Disk are to be used during the uninstallation process.
nbOfInvalidKexts="0"

mbpCompatibilityList=("MacBookPro6,2" "MacBookPro8,1" "MacBookPro8,2") #compatible with wireless card upgrade BCM94331PCIEBT4CAX. This list is used during the diagnostic only. The patch actually gets an up-to-date list in the kext.
blacklistedMacs=("MacBookAir4,1" "MacBookAir4,2" "Macmini5,1" "Macmini5,2" "Macmini5,3") #compatible without hardware changes. This list is used during the diagnostic only. The patch actually gets an up-to-date list in the kext.

#---- PATH VARIABLES ------
backupFolderBeforePatch="$HOME/KextsBackupBeforePatch" #Kexts backup directory, where the original untouched kexts should be placed
backupFolderAfterPatch="$HOME/KextsBackupAfterPatch" #Kexts backup directory, where the patched kexts should be placed, after a successful backup
legacyBackupPath="$HOME/KextsBackup" #backup directory used in CAT 1.0.0 and CAT 1.0.1
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
appDir=$(dirname "$0")
recoveryHdName="Recovery HD"
recoveryDmgPath="/Volumes/Recovery HD/com.apple.recovery.boot/BaseSystem.dmg"
osxBaseSystemPath="/Volumes/OS X Base System"

#---- TOOLCHAIN PATHS ------
#the toolchain path has been hardcoded to avoid having potential 3rd party tools being used
awkPath="/usr/bin/awk"
chmodPath="/bin/chmod"
chownPath="/usr/sbin/chown"
cpPath="/bin/cp"
cutPath="/usr/bin/cut"
diskutilPath="/usr/sbin/diskutil"
duPath="/usr/bin/du"
grepPath="/usr/bin/grep"
hdiutilPath="/usr/bin/hdiutil"
hexdumpPath="/usr/bin/hexdump"
ioregPath="/usr/sbin/ioreg"
kextcachePath="/usr/sbin/kextcache"
kextstatPath="/usr/sbin/kextstat"
mkdirPath="/bin/mkdir"
mvPath="/bin/mv"
nvramPath="/usr/sbin/nvram"
revPath="/usr/bin/rev"
rmPath="/bin/rm"
sedPath="/usr/bin/sed"
shutdownPath="/sbin/shutdown"
sortPath="/usr/bin/sort"
statPath="/usr/bin/stat"
stringsPath="$appDir/strings" #the OS X "strings" utility, from Apple's Command Line Tools, must be bundled with this tool. This avoids prompting to download a ~5 GB Xcode package just to use a 40 KB tool (!).
trPath="/usr/bin/tr"
wcPath="/usr/bin/wc"
xxdPath="/usr/bin/xxd"

#---- FUNCTIONS -----------

#Verifies the presence of the strings binary, necessary to run many checks and patches
#The 'strings' binutil used with the tool comes from the 'Apple Command Line Utilities' package
function verifyStringsUtilPresence() {
	if [ ! -f "${stringsPath}" ]; then
		
		tput clear
		echo ""
		echo "Error: the 'strings' command line utility was not found and is necessary to run the script."
		echo ""
		echo "It is expected to be bundled with the app and located at :"
		echo "'${appDir}/'"
		echo ""
		echo "Aborting."
		echo ""
		exit;
	fi
}

#Quits the script if the OS X version is lower than 10.10, displays warning if higher
function isMyMacOSCompatible() {	
	echo -n "Verifying OS X version...               "
	osVersion=$(sw_vers -productVersion)
	minVersion=10
	subVersion=$(echo "$osVersion" | $cutPath -d '.' -f 2)
	
	if [ "$subVersion" -lt "$minVersion" ]; then 
		if [ "$1" != "verbose" ]; then echo "NOT OK. Your OS X version is too old to work with this hack. Aborting."; exit;
		else echo "NOT OK. Your OS X version is too old to work with this hack. Version detected: ${osVersion}"; fi
		exit;
	else
		if [ "$subVersion" -eq "$minVersion" ]; then 
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Mac OS X 10.10 detected"; fi
		else
			if [ "$subVersion" -gt "$minVersion" ]; then
				if [ "$1" != "verbose" ]; then 
					echo "Warning: This hack wasn't tested on OS X versions higher than 10.10. Detected OS version: ${osVersion}"
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
					echo "Warning: This hack wasn't tested with OS X versions higher than 10.10. Detected OS version: ${osVersion}"
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

	echo -n "Verifying active AirPort drivers...     "
	
	driverVersion=($($kextstatPath | $grepPath "Brcm" | $awkPath -F' ' '{print $6}'))

	#Verify if no Wi-Fi drivers are loaded at all
	if [ -z "${driverVersion}" ]; then
		if [ "$1" != "verbose" ]; then echo "NOT OK. No active Broadcom AirPort card was detected. Aborting."; backToMainMenu;
		else
			possibleDriver=($($kextstatPath | $grepPath "AirPort" | $awkPath -F' ' '{print $6}')) 
			if [ -z "${possibleDriver}" ]; then
				echo "NOT OK. No active Broadcom AirPort card detected"
			else
				echo "NOT OK. AirPort card detected is not a Broadcom one: ${possibleDriver}"
			fi
		fi
	else
		if [ "${#driverVersion[@]}" -eq "1" ]; then
			if [ "$1" != "verbose" ]; then echo "OK"
			else 
				local shortDriverName=$(echo "${driverVersion}" | $awkPath -F'.' '{print $5}')
				echo "OK. Broadcom AirPort driver ${shortDriverName} is currently active";
			fi
		else 

			#More than 1 driver is active, collect their content
			local element
			local activeCards=()
			#detect whether they are Broadcom based
			for element in "${driverVersion[@]}";
				do 
				if [ "${element}" == "com.apple.driver.AirPort.Brcm4331" ]; then
					activeCards+=($(echo "${element}" | $awkPath -F'.' '{print $5}')) #store the short kext name
				else
					if [ "${element}" == "com.apple.driver.AirPort.Brcm4360" ]; then
					activeCards+=($(echo "${element}" | $awkPath -F'.' '{print $5}')) #store the short kext name
					fi
				fi
			done

			#Verify if multiple Broadcom drivers loaded
			if [ "${#activeCards[@]}" -gt 1 ]; then
				if [ "$1" != "verbose" ]; then echo "OK"
				else echo "OK. Broadcom AirPort drivers ${activeCards[*]} are active"; fi
			else 
				#Verify if at least one Broadcom driver is running
				if [ "${#activeCards[@]}" -eq 1 ]; then
					if [ "$1" != "verbose" ]; then echo "OK"
					else echo "OK. ${driverVersion[0]} Airport driver is active"; fi
				else
					#Multiple Wi-Fi drivers loaded, but none are of the Broadcom brand
					if [ "$1" != "verbose" ]; then echo "NOT OK. No Broadcom AirPort card is active. Aborting."; backToMainMenu;
					else echo "NOT OK. No Broadcom AirPort card is active. Type '$kextstatPath | $grepPath AirPort' for more info. brc ${activeCards[*]}"; fi
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
	#echo -n "Verifying Mac model nb compatibility... "
	modelsList=("${mbpCompatibilityList[@]}" "${blacklistedMacs[@]}")
	myMacModel=$($ioregPath -l | $grepPath "model" | $awkPath -F\" '{print $4;exit;}')
	myResult=`containsElement "${myMacModel}" "${modelsList[@]}"; echo $?`
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

	local lmpVersion=$($ioregPath -l | $grepPath "LMPVersion" | $awkPath -F' = ' '{print $2}')

	if [ ! "${lmpVersion}" == "" ]; then
		if [ "${lmpVersion}" == "6" ]; then
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Bluetooth 4.0 detected (LMP Version 6)"; fi
		else
			if [ "$1" != "verbose" ]; then echo "NOT OK. Your hardware doesn't support Bluetooth 4.0, necessary for Continuity Current LMP Version=${lmpVersion}, expected 6. Aborting."; backToMainMenu;
			else echo "NOT OK. Your hardware doesn't support Bluetooth 4.0, necessary for Continuity. Current LMP Version=${lmpVersion}, expected 6."; fi
		fi
	else
		if [ "$1" != "verbose" ]; then echo "NOT OK. No active Bluetooth hardware detected. Aborting."; backToMainMenu;
		else echo "NOT OK. No active Bluetooth hardware detected."; fi
	fi
}

#Counts all kexts in the given folder that either have no signature or that don't pass signature validation
#This function is used during the uninstallation to make sure that the OS Kext Protection doesn't get re-activated and blocks potentially vital kexts from loading
#Output example : "nbOfInvalidKexts=8"
#Negative values indicate an error.
#Usage: countInvalidKexts "${kextFolderPath}" > tmp; . tmp; rm tmp;
function countInvalidKexts(){
	folderToVerify=$1
	if [ -z $folderToVerify ]; then echo "-1"; nbOfInvalidKexts="-1"; #no argument given
    else 
    	if [ ! -d $folderToVerify ]; then echo "-2";nbOfInvalidKexts="-2"; #folder not found
    	else
    		if [ $(ls -1 ${folderToVerify}/*.kext 2>/dev/null | $wcPath -l) -eq 0 ]; then echo "-3";nbOfInvalidKexts="-3"; #no kexts were found in this directory
    		else
    			cd $folderToVerify 
    		 	echo "nbOfInvalidKexts=$(find *.kext -prune -type d | while read kext; do
    			codesign -v "$kext" 2>&1 | $grepPath -E 'invalid signature|not signed at all'
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
			countInvalidKexts "${driverPath}" > tmp.txt & spinner "Verifying system kexts signatures...    "; . tmp.txt; rm tmp.txt;

			#output=$(countInvalidKexts "${driverPath}")
			if [ "${nbOfInvalidKexts}" -gt "0" ]; then
				echo -e "\rVerifying system kexts signatures...    OK. 1 or more unsigned drivers were found. OS kext security protection won't be changed to avoid potential issues."; return;
			else
				if [ "${nbOfInvalidKexts}" -lt "0" ]; then
					#echo "       WARNING. There was an internal error while validating kexts. Proceeding."
					echo -n "Activating OS kext protection...        "
				else
					#the system folder doesn't contain unclean kexts, proceed
					echo "       OK"
					echo -n "Activating OS kext protection...        "
					longSedRegEx="s#\-kext-dev-mode=1##g" #this kext-dev-mode string will be removed. A dash might have been used if there are more than 1 boot-args.
					sedRegEx="s#\kext-dev-mode=1##g" #this kext-dev-mode string will be removed if it exists
					okToDisable="1"
				fi
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
	sudo $nvramPath boot-args >> /dev/null 2>&1
	local bootArgsResult=$?
	if [ $bootArgsResult -eq 0 ]; then #Yes, boot-args exists

		#Verify if kext-dev-mode=1 is set
		sudo $nvramPath boot-args | $grepPath -F "kext-dev-mode=1" >> /dev/null 2>&1
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


#Verifies if the Mac board id is correctly whitelisted in the Wi-Fi drivers
function isMyMacWhitelisted(){
	echo -n "Verifying Wi-Fi whitelist status...     "
	#verify if the Brcm4360 binary exists
	if [ ! -f "${wifiBrcmBinPath}" ]; then
    	if [ "$1" != "verbose" ]; then echo "NOT OK. Wifi binary not found at ${wifiBrcmBinPath}. Aborting."; backToMainMenu;
    	else echo "NOT OK. Wi-Fi binary not found at ${wifiBrcmBinPath}"; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; #Continue the verification. A brcm AirPort driver was found.
    	fi
     	local whitelist=($("${stringsPath}" -a -t x ${wifiBrcmBinPath} | $grepPath Mac- | $awkPath -F" " '{print $2}'))
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
					firstWhitelistedBoardId=$("${stringsPath}" -a -t x ${wifiBrcmBinPath} | $grepPath Mac- | $awkPath -F" " '{print $2;exit;}')
					lastWhitelistedBoardId=$("${stringsPath}" -a -t x ${wifiBrcmBinPath} | $grepPath Mac- | $awkPath -F" " '{a=$0} END{print $2;exit;}')
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
		if [ "$1" != "verbose" ]; then echo "NOT OK. Bluetooth binary not found at ${btBinPath}. Aborting."; backToMainMenu;
    	else echo "NOT OK. Bluetooth binary not found at ${btBinPath}"; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; fi #Continue, the bluetooth binary was found
    	local blacklist=($("${stringsPath}" -a -t x ${btBinPath} | $grepPath Mac | $awkPath -F"'" '{print $2}'))
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
					 echo "                                           However, your Mac model shouldn't need to be removed from that blacklist."; fi					
			fi
		fi
    fi
}

#Makes a backup of the Wifi kext and Bluetooth kext, in a "Backup" folder located in the directory declared as argument
#Any existing copies of these kexts in the backup dir will be silently replaced
function backupKexts(){

	local backupType=""
	local backupFolder=$1

	#set a relevant backup message
	if [ ! -z "$backupFolder" -a "${backupFolder}" == "${backupFolderBeforePatch}" ]; then backupType="original "; fi
	if [ ! -z "$backupFolder" -a  "${backupFolder}" == "${backupFolderAfterPatch}" ]; then backupType="patched "; fi
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
function patchStringsInFile() {
    local FILE="$1"
    local PATTERN="$2"
    local REPLACEMENT="$3"

    #Find all unique strings in FILE that contain the pattern 
    STRINGS=$("${stringsPath}" "${FILE}" | $grepPath "${PATTERN}" | $sortPath -u -r)

    if [ "${STRINGS}" != "" ] ; then
        #echo "File '${FILE}' contain strings with '${PATTERN}' in them:"

        for OLD_STRING in ${STRINGS} ; do
            # Create the new string with a simple bash-replacement
            NEW_STRING=${OLD_STRING//${PATTERN}/${REPLACEMENT}}

            # Create null terminated ASCII HEX representations of the strings
            OLD_STRING_HEX="$(echo -n "${OLD_STRING}" | $xxdPath -g 0 -u -ps -c 256)00"
            NEW_STRING_HEX="$(echo -n "${NEW_STRING}" | $xxdPath -g 0 -u -ps -c 256)00"

            if [ ${#NEW_STRING_HEX} -le ${#OLD_STRING_HEX} ] ; then
                # Pad the replacement string with null terminations so the
                # length matches the original string
                while [ ${#NEW_STRING_HEX} -lt ${#OLD_STRING_HEX} ] ; do
                    NEW_STRING_HEX="${NEW_STRING_HEX}00"
                done

                # Now, replace every occurrence of OLD_STRING with NEW_STRING 
                #echo -n "Replacing ${OLD_STRING} with ${NEW_STRING}... "
                $hexdumpPath -ve '1/1 "%.2X"' "${FILE}" | \
                $sedPath "s/${OLD_STRING_HEX}/${NEW_STRING_HEX}/g" | \
                $xxdPath -r -p > "${FILE}.tmp"
                SAVEMOD=$($statPath -r "$FILE" | $cutPath -f3 -d' ')
                $chmodPath "${SAVEMOD}" "${FILE}.tmp"
                $mvPath "${FILE}.tmp" "${FILE}"
            else
                echo "NOT OK. New string '${NEW_STRING}' is longer than old" \
                     "string '${OLD_STRING}'. Skipping."
            fi
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
			else echo "OK. Old Wi-Fi driver ${wifiObsoleteBrcmKextFilename} is present. This tool can fix this."; fi
	else
		#kext not found - consider it patched
		legacyWifiAlreadyPatched="1";
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Old Wi-Fi driver ${wifiObsoleteBrcmKextFilename} was already removed"; fi
	fi
}

#Removes the Brcm4331 legacy Wi-Fi kext that could load and override the Continuity enabled Brcm4360 driver
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
			echo "WARNING. Failed to delete the old Wi-Fi kext ${wifiObsoleteBrcmKextFilename}. Continuing." #Continuity might still work (as in v.1.0.0 and v.1.0.1 of the script)
		else
			legacyWifiAlreadyPatched="1"
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
		blacklistedMacs=($("${stringsPath}" -a -t x ${btBinPath} | $grepPath Mac | $awkPath -F"'" '{print $2}'))

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
	local whitelist=($("${stringsPath}" -a -t x ${wifiBrcmBinPath} | $grepPath Mac- | $awkPath -F" " '{print $2}'))

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
		echo "      OK"
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

#Prompts to reboot your system, e.g. after patching
function rebootPrompt(){
	echo ""
	read -n 1 -p "Press any key to reboot or CTRL-C to cancel..."
	echo ""
	sudo $shutdownPath -r now
	exit;
}

#Silently repairs the disk permissions using the Disk Utility. Takes a few minutes.
function repairDiskPermissions(){
	sudo $diskutilPath repairpermissions / >> /dev/null 2>&1 & spinner "Fixing disk permissions (~5min wait)... "
	echo -e "\rFixing disk permissions...              OK"
}

#Verifies if the kexts from previous a previous backup can be restored, otherwise use those from the Recovery Disk
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

		#check the presence of CAT <=1.0.1 backups
		$duPath -hs "${legacyBackupPath}/${btKextFilename}" >> /dev/null 2>&1
		local legacyBtPermissionsError=$?
		$duPath -hs "${legacyBackupPath}/${wifiKextFilename}"  >> /dev/null 2>&1
		local legacyWifiPermissionsError=$?
		local legacypPermissionsError=$((legacyBtPermissionsError + legacyWifiPermissionsError))

		
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
				echo "OK. Restored backed up files found in '${backupFolderBeforePatch}'"
			else
				echo "NOT OK. ${errorOutput}."; backToMainMenu;
			fi
		else
			if [ "${legacypPermissionsError}" -eq "0" ]; then

				#recent CAT backup NOT found, but:
				#CAT 1.0.0 or CAT 1.0.1 backup exists, recover those
				#silently remove any existing previous kext backups (doesn't care if the old kexts were found or not)
				sudo $rmPath -rf "${wifiKextPath}" >> /dev/null 2>&1
				sudo $rmPath -rf "${btKextPath}" >> /dev/null 2>&1

				#create the kexts directories in the System Extensions folder
				sudo $mkdirPath -p "${wifiKextPath}"
				sudo $mkdirPath -p "${btKextPath}"

				#now copy the clean kexts
				local uninstallOk=0
				local errorOutput=""

				if sudo $cpPath -R "${legacyBackupPath}/${wifiKextFilename}/" "${driverPath}/${wifiKextFilename}"; then ((uninstallOk+=1)); else errorOutput="Failed to restore ${wifiKextFilename} from ${legacyBackupPath}."; fi
				if sudo $cpPath -R "${legacyBackupPath}/${btKextFilename}/" "${driverPath}/${btKextFilename}"; then ((uninstallOk+=1)); else errorOutput="${errorOutput} Failed to restore ${btKextFilename} from ${legacyBackupPath}."; fi
			
				if [ "${uninstallOk}" -eq "2" ]; then
					echo "OK. Restored backup files found in '${legacyBackupPath}'"
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

#Prompts to go back to the main menu
function backToMainMenu(){
	echo ""
	read -n 1 -p "Press any key to go back to the main menu..."
	displayMainMenu
}

#Initiates the compatibility checks, aborts the script if an uncompatible configuration is detected.
#In case of error, an interpretation of it is displayed.
function compatibilityPrecautions(){
	displaySplash
	echo '--- Initiating system compatibility check ---'
	echo ''
	isMyMacModelCompatible
	isMyMacOSCompatible
	isMyBluetoothVersionCompatible
	isMyMacBoardIdCompatible
	areMyActiveWifiDriversOk
	canMyKextsBeModded
	isMyMacBlacklisted
	isMyMacWhitelisted
	detectLegacyWifiDriver
}

#Initiates the system compatibility checks, displays detailed interpretations of each test's result.
#The goal is to understand if and why the system is compatible with this mod.
function verboseCompatibilityCheck(){
	displaySplash
	echo '--- Initiating system compatiblity check ---'
	echo ''
	isMyMacModelCompatible "verbose"
	isMyMacOSCompatible "verbose"
	isMyBluetoothVersionCompatible "verbose"
	isMyMacBoardIdCompatible "verbose"
	areMyActiveWifiDriversOk "verbose"
	verifyOsKextDevMode "verbose"
	canMyKextsBeModded "verbose"
	isMyMacBlacklisted "verbose"
	isMyMacWhitelisted "verbose"
	detectLegacyWifiDriver "verbose"

	backToMainMenu
}


#Initiates the backup, patching and clean-up.
function checkAndHack(){
	
	if [ "${forceHack}" == "0" ]; then
		
		#reset the patching flags in case they were set in a previous hack/diagnostic in the same session. They will be set again.
		whitelistAlreadyPatched=0
		myMacIsBlacklisted=0
		legacyWifiAlreadyPatched=0

		#run the checks
		compatibilityPrecautions 
	fi

	#prevent patching if all the patches were detected to be already applied
	if [ "${whitelistAlreadyPatched}" == "1" -a "${myMacIsBlacklisted}" == "0" -a "${legacyWifiAlreadyPatched}" == "1" ]; then
		echo ""
		echo "No changes were applied, your system seems to be already OK for Continuity"
		backToMainMenu
	fi
	echo ""
	echo '--- Initiating Continuity mod ---'
	echo ""

	modifyKextDevMode "enableDevMode"
	repairDiskPermissions
	backupKexts "${backupFolderBeforePatch}"
	patchBluetoothKext
	patchWifiKext
	removeObsoleteWifiDriver
	applyPermissions
	updatePrelinkedKernelCache
	updateSystemCache
	backupKexts "${backupFolderAfterPatch}"
	echo ""
	echo "ALMOST DONE! After rebooting:"
	echo "1) Make sure that both your Mac and iOS device have Bluetooth turned on, and are on the same Wi-Fi network."
	echo "2) On OS X go to SYSTEM PREFERENCES> GENERAL> and ENABLE HANDOFF."
	echo "3) On iOS go to SETTINGS> GENERAL> HANDOFF & SUGGESTED APPS> and ENABLE HANDOFF."
	echo "4) On OS X, sign out and then sign in again to your iCloud account."
	echo "Troubleshooting: support.apple.com/kb/TS5458"
	displayThanks
	rebootPrompt
}

#Puts back a clean OS X wireless drivers stack, and attempts to disable the kext-dev-mode
function uninstall(){
	displaySplash
	echo '--- Initiating uninstallation ---'
	echo ''

	startTheKextsReplacement
	applyPermissions
	updatePrelinkedKernelCache
	updateSystemCache
	modifyKextDevMode "disableDevMode"
	echo ""
	echo ""
	echo "DONE. Please reboot now to complete the uninstallation."
	echo ""
	rebootPrompt
}
#Displays the application splash at the top of the Terminal screen
function displaySplash(){
	tput clear
	echo "--- OS X Continuity Activation Tool ${hackVersion} ---"
	echo "                 by dokterdok                 "
	echo ""	
}

#Displays credits, people who helped make it happen
function displayThanks(){
	echo ""
	echo "Thanks to Lem3ssie, UncleSchnitty, Skvo, TealShark, Manic Harmonic, rob3r7o for their research, testing, and support."
	echo ""
}

#Resizes the Terminal Window and recolors the font/background
function applyTerminalTheme(){
	tput setab 0
	tput setaf 10
	printf '\e[8;30;158t'
	printf '\e[3;0;0t'
	tput clear
}

#Displays the main menu and asks the user to select an option
function displayMainMenu(){
	displaySplash
	echo "Select an option:"
	echo ""
	options=("Activate Continuity" "System Diagnostic" "Uninstall" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			'Activate Continuity') 
				checkAndHack
				;;
			'System Diagnostic') 
				verboseCompatibilityCheck
				;;
			'Uninstall') 
				uninstall
				;;
			'Quit')
				displayThanks
				osascript -e 'tell application "Terminal" to quit'
				exit;;
			*)
		 		echo "Invalid option, enter a number"
		 		;;
		esac
	done
}

applyTerminalTheme #apply the theme in case the script was run from the command line
verifyStringsUtilPresence

#Check if the scripts was run with args
param1=$1
if [ ! -z "${param1}" ]; then
	#check what arg this is
	if [ "${param1}" == "activate" ]; then
		checkAndHack
	else
		if [ "${param1}" == "diagnostic" ]; then
			verboseCompatibilityCheck
		else
			if [ "${param1}" == "forceHack" ]; then
				forceHack=1
				checkAndHack
			else
				if [ "${param1}" == "uninstall" ]; then
					uninstall
				else
					if [ "${param1}" == "uninstallWithRecoveryDisk" ]; then
						forceRecoveryDiskBackup=1
						uninstall
					else
						echo "Unknown argument used. Please refer to the documentation."; exit;
					fi
				fi
			fi
		fi
	fi
fi

displayMainMenu

echo ""
echo ""
