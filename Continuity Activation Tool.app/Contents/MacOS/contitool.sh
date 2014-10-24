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
# as well as a backup of the (presumably untouched) bluetooth and wifi kexts.
# The system check produces a report of typical parameters influencing
# Continuity: this may be useful when troubleshooting.
#
# This hack should work with:
# * mid-2010 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * early-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * late-2011 MacBook Pro models upgraded with an internal BT4 LE Airport wireless card (model BCM94331PCIEBT4CAX)
# * mid-2011 MacBook Airs (no hardware modification required)
# * mid-2011 Mac Minis (no hardware modification required)
# Other Mac models are untested and will be prompted with a warning before applying the hack.
# 

hackVersion="1.0.0"

#---- CONFIG VARIABLES ----
forceHack="0" #default is 0. when set to 1, skips all compatibility checks and forces the hack to be applied (WARNING: may corrupt your system)
myMacIdPattern="" #Mac board id, detected later. Can be manually set here for debugging purposes. E.g.: Mac-00BE6ED71E35EB86.
myMacModel="" #Mac model nb, automatically detected later. Can be manually set here for debugging purposes. E.g.: MacBookAir4,1
skippedPatching=0 #set to 2 to prevent patching

#---- PATH VARIABLES ------
backupFolder="$HOME/KextsBackup"
driverPath="/System/Library/Extensions"
wifiKextFilename="IO80211Family.kext"
wifiKextPath="$driverPath/$wifiKextFilename"
wifiBrcmKextFilename="AirPortBrcm4360.kext"
wifiBrcmBinFilename="AirPortBrcm4360"
wifiBrcmBinPath="$driverPath/$wifiKextFilename/Contents/PlugIns/$wifiBrcmKextFilename/Contents/MacOS/$wifiBrcmBinFilename"
btKextFilename="IOBluetoothFamily.kext"
btKextPath="$driverPath/$btKextFilename"
btBinFilename="IOBluetoothFamily"
btBinPath="$driverPath/$btKextFilename/Contents/MacOS/$btBinFilename"
appDir=$(dirname "$0")
stringsPath="$appDir/strings" #the OS X "strings" utility, from Apple's Command Line Tools, must be bundled with this tool. This avoids prompting to download a ~5 GB Xcode package just to use a 40 KB tool (!).

#---- HACK VARIABLES ------
mbpCompatibilityList=("MacBookPro6,2" "MacBookPro7,1" "MacBookPro8,1" "MacBookPro8,2") #compatible with wireless card upgrade BCM94331PCIEBT4CAX. This list is used during the diagnostic only. The patch actually gets an up-to-date list in the kext.
blacklistedMacs=("MacBookAir4,1" "MacBookAir4,2" "Macmini5,1" "Macmini5,2" "Macmini5,3") #compatible without hardware changes. This list is used during the diagnostic only. The patch actually gets an up-to-date list in the kext.
myMacIsBlacklisted="0" #automatically set to 1 if detected that the Mac model is blacklisted in the Bluetooth drivers


#---- FUNCTIONS -----------

#Verifies the presence of the strings binary, necessary to run many checks and patches
#The 'strings' binutil used with the tool comes from the 'Apple Command Line Utilities' package
function verifyStringsUtilPresence() {
		#verify if the Brcm4360 binary exists
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
	subVersion=$(echo "$osVersion" | cut -d '.' -f 2)
	
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
		du -hs "${btKextPath}" >> /dev/null 2>&1
		btPermissionsError=$?
		du -hs "${wifiKextPath}" >> /dev/null 2>&1
		wifiPermissionsError=$?
		permissionsError=$((btPermissionsError + wifiPermissionsError))
		if [ "${permissionsError}" -gt "0" ]; then
			if [ "$1" != "verbose" ]; then echo "NOT OK. ${btKextFilename} and/or ${wifiKextFilename} are missing or corrupt in ${driverPath}"; echo ""; echo "   To fix this:"; echo "1) delete these files in ${driverPath}"; echo "2) find the original untouched kext backups (check in ${backupFolder})"; echo "3) reinstall them using the Kext Drop app (search online for it)"; echo "4) reboot."; echo ""; backToMainMenu
			else echo "NOT OK. ${btKextFilename} and/or ${wifiKextFilename} are missing or corrupt in ${driverPath}."; echo ""; echo "   To fix this:"; echo "1) delete these files in ${driverPath}"; echo "2) find the original untouched kext backups (check in ${backupFolder})"; echo "3) reinstall them using the Kext Drop app (search online for it)"; echo "4) reboot."; echo ""; fi 
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
		myMacIdPattern=$(ioreg -l | grep "board-id" | awk -F\" '{print $4}')
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
	
	driverVersion=($(kextstat | grep "Brcm" | awk -F' ' '{print $6}'))

	#Verify if no Wi-Fi drivers are loaded at all
	if [ -z "${driverVersion}" ]; then
		if [ "$1" != "verbose" ]; then echo "NOT OK. No active Broadcom AirPort card was detected. Aborting."; backToMainMenu;
		else
			possibleDriver=($(kextstat | grep "AirPort" | awk -F' ' '{print $6}')) 
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
				local shortDriverName=$(echo "${driverVersion}" | awk -F'.' '{print $5}')
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
					activeCards+=($(echo "${element}" | awk -F'.' '{print $5}')) #store the short kext name
				else
					if [ "${element}" == "com.apple.driver.AirPort.Brcm4360" ]; then
					activeCards+=($(echo "${element}" | awk -F'.' '{print $5}')) #store the short kext name
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
					else echo "NOT OK. No Broadcom AirPort card is active. Type 'kextstat | grep AirPort' for more info. brc ${activeCards[*]}"; fi
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
	myMacModel=$(ioreg -l | grep "model" | awk -F\" '{print $4;exit;}')
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

#Verifies if the Bluetooth chip is compatible, by checking if the LMP version is 6
function isMyBluetoothCompatible(){
	echo -n "Verifying Bluetooth hardware...         "

	lmpVersion=$(ioreg -l | grep "LMPVersion" | awk -F' = ' '{print $2}')

	if [ ! "${lmpVersion}" == "" ]; then
		if [ "${lmpVersion}" == "6" ]; then
			if [ "$1" != "verbose" ]; then echo "OK";
			else echo "OK. Bluetooth 4.0 LE detected (LMP Version 6)"; fi
		else
			if [ "$1" != "verbose" ]; then echo "NOT OK. Incompatible Bluetooth hardware detected. LMP Version=${lmpVersion}, but expected 6 (Bluetooth 4.0 LE). Aborting."; backToMainMenu;
			else echo "NOT OK. Incompatible Bluetooth hardware detected. LMP Version=${lmpVersion}, but expected 6 (Bluetooth 4.0 LE)."; fi
		fi
	else
		if [ "$1" != "verbose" ]; then echo "NOT OK. No active Bluetooth hardware detected. Aborting."; backToMainMenu;
		else echo "NOT OK. No active Bluetooth hardware detected."; fi
	fi
}

#Verifies if the kext developer mode is active. If not, it is activated (reboot required).
function disableOsKextProtection(){
	echo -n "Verifying OS kext protection...         "
	sudo nvram boot-args | grep -F "kext-dev-mode=1"
	kextDevMode=$?
	if [ $kextDevMode -eq 0 ]; then
		if [ "$1" != "verbose" ]; then echo "OK";
		else echo "OK. Kext developer mode is active"; fi
	else
		if [ "$1" != "verbose" ]; then
			local output=$(sudo nvram boot-args="kext-dev-mode=1")
			echo "NOT OK. OS is protected against changes. Please reboot to automatically fix this, then relaunch the script."; rebootPrompt; 
		else echo "NOT OK. OS is protected against kext changes. Please reboot to fix this, then relaunch the script."; rebootPrompt; fi
	fi
}

#Verifies if the Mac board id is correctly whitelisted in the Wi-Fi drivers
function isMyMacWhitelisted(){
	echo -n "Verifying Wi-Fi whitelist status...     "
	#verify if the Brcm4360 binary exists
	if [ ! -f "${wifiBrcmBinPath}" ]; then
    	if [ "$1" != "verbose" ]; then echo "NOT OK: Wifi binary not found at ${wifiBrcmBinPath}. Aborting."; backToMainMenu;
    	else echo "NOT OK: Wi-Fi binary not found at ${wifiBrcmBinPath}"; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; #Continue the verification. A brcm AirPort driver was found.
    	fi
     	local whitelist=($("$stringsPath" -a -t x ${wifiBrcmBinPath} | grep Mac- | awk -F" " '{print $2}'))
		myMacIdPattern=$(ioreg -l | grep "board-id" | awk -F\" '{print $4}')
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
					firstWhitelistedBoardId=$("${stringsPath}" -a -t x ${wifiBrcmBinPath} | grep Mac- | awk -F" " '{print $2;exit;}')
					lastWhitelistedBoardId=$("${stringsPath}" -a -t x ${wifiBrcmBinPath} | grep Mac- | awk -F" " '{a=$0} END{print $2;exit;}')
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
					if [ "$1" != "verbose" ]; then echo "OK"; ((skippedPatching+=1));
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
		if [ "$1" != "verbose" ]; then echo "NOT OK: Bluetooth binary not found at ${btBinPath}. Aborting."; backToMainMenu;
    	else echo "NOT OK: Bluetooth binary not found at ${btBinPath}"; fi
    else
    	if [ "$1" != "verbose" ]; then echo -n ""; fi #Continue, the bluetooth binary was found
    	local blacklist=($("$stringsPath" -a -t x ${btBinPath} | grep Mac | awk -F"'" '{print $2}'))
		local myMacModel=$(ioreg -l | grep "model" | awk -F\" '{print $4;exit;}')
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
				if [ "$1" != "verbose" ]; then echo "OK"; ((skippedPatching+=1));
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

#Makes a backup of the Wifi kext and Bluetooth kext, in a "Backup" folder located in the directory declared in the script global variables.
#Any existing copies of these kexts in the backup dir will be silently replaced
function backupKexts(){
	echo -n "Backing up drivers...                   "
	#Verify if the original kexts are there
	if [ ! -d "${btKextPath}" -a ! -d "${wifiKextPath}" ]; then 
		echo "NOT OK. ${btKextFilename} or ${wifiKextFilename} could not be found. Aborting."
		backToMainMenu
	else
		#start the backup
		if [ -d "${backupFolder}" ]; then
			#backup dir already existed
			#remove any existing previous kext backups
			rm -rf "${backupFolder}/${wifiKextFilename}"
			rm -rf "${backupFolder}/${btKextFilename}"
		else
			mkdir -p "${backupFolder}"
		fi
		local backupOk=0
		local errorOutput=""

		if cp -R "${btKextPath}/" "${backupFolder}/${btKextFilename}"; then ((backupOk+=1)); else errorOutput="${btKextFilename} backup failed."; fi
		if cp -R "${wifiKextPath}/" "${backupFolder}/${wifiKextFilename}"; then ((backupOk+=1)); else errorOutput="${errorOutput} ${btKextFilename} backup failed."; fi

		if [ "${backupOk}" -eq "2" ]; then
			echo "OK. Wi-Fi and Bluetooth kexts were backed up in '${backupFolder}'"
		else
			echo "NOT OK. ${errorOutput}"
		fi
	fi
}

#Replaces a string in a binary file by the one given. Usage : patch_strings_in_file foo "old_string" "new_string"
function patch_strings_in_file() {
    local FILE="$1"
    local PATTERN="$2"
    local REPLACEMENT="$3"

    #Find all unique strings in FILE that contain the pattern 
    STRINGS=$("$stringsPath" "${FILE}" | grep "${PATTERN}" | sort -u -r)

    if [ "${STRINGS}" != "" ] ; then
        #echo "File '${FILE}' contain strings with '${PATTERN}' in them:"

        for OLD_STRING in ${STRINGS} ; do
            # Create the new string with a simple bash-replacement
            NEW_STRING=${OLD_STRING//${PATTERN}/${REPLACEMENT}}

            # Create null terminated ASCII HEX representations of the strings
            OLD_STRING_HEX="$(echo -n "${OLD_STRING}" | xxd -g 0 -u -ps -c 256)00"
            NEW_STRING_HEX="$(echo -n "${NEW_STRING}" | xxd -g 0 -u -ps -c 256)00"

            if [ ${#NEW_STRING_HEX} -le ${#OLD_STRING_HEX} ] ; then
                # Pad the replacement string with null terminations so the
                # length matches the original string
                while [ ${#NEW_STRING_HEX} -lt ${#OLD_STRING_HEX} ] ; do
                    NEW_STRING_HEX="${NEW_STRING_HEX}00"
                done

                # Now, replace every occurrence of OLD_STRING with NEW_STRING 
                #echo -n "Replacing ${OLD_STRING} with ${NEW_STRING}... "
                hexdump -ve '1/1 "%.2X"' "${FILE}" | \
                sed "s/${OLD_STRING_HEX}/${NEW_STRING_HEX}/g" | \
                xxd -r -p > "${FILE}.tmp"
                SAVEMOD=$(stat -r "$FILE" | cut -f3 -d' ')
                #chmod --reference ${FILE} ${FILE}.tmp unix command not working on OS X
                chmod "$SAVEMOD" "${FILE}.tmp"
                mv "${FILE}.tmp" "${FILE}"
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


#Disables the blacklist in the bluetooth drivers, only if the current Mac Model is blacklisted.
#A prerequisite is to run the isMyMacBlacklisted function, as it
#will determine whether the Mac is blacklisted. If not done, no patching happens.
# e.g. MacBookAir4,2 will be turned into MacBookAir1,1
function patchBluetoothKext(){

	#reset patching counter
	skippedPatching=0

	#verify if mac is blacklisted, if not skip
	if [ "${myMacIsBlacklisted}" == "1" ]; then
		echo -n "Patching blacklist..."
		
		#(re)populate blacklist
		blacklistedMacs=($("$stringsPath" -a -t x ${btBinPath} | grep Mac | awk -F"'" '{print $2}'))

    	#build a disabled blacklist
    	local disabledBlacklist=()
    	local blacklistedMac
    	for blacklistedMac in "${blacklistedMacs[@]}";
    	do
    		#replace the last three chars of the mac model with "1,1", e.g. MacBookAir4,2 -> MacBookAir1,1
    		disabledBlacklist+=($(echo $blacklistedMac | rev | cut -c 4- | rev | awk '{print $1"1,1"}'))
    	done

    	#verify that the disabled blacklist is correctly built (last chance before applying the hack)
    	if [ "${#disabledBlacklist[@]}" -gt "0" -a "${#disabledBlacklist[@]}" -eq "${#blacklistedMacs[@]}" ]; then

    		#use the helper function to apply the hack
    		for (( i = 0; i < ${#blacklistedMacs[@]}; i++ )); do
    			#patch_strings_in_file foo "old string" "new string"
    			patch_strings_in_file "${btBinPath}" "${blacklistedMacs[i]}" "${disabledBlacklist[i]}"
    			echo -n "."
    		done
    		echo "              OK"
    	else
    		echo "NOT OK. Failed to disable the blacklist - no changes were applied. Aborting."; backToMainMenu
    	fi
	else
		((skippedPatching+=1))
		echo "Skipping blacklist patch...             OK"
	fi
}

#Puts the current Mac board-id in the Brcm 4360 whitelist, the only driver that works with Continuity
#All board-ids are replaced with the current system's own board id
#Patching is skipped if the whitelist is already filled with own board id
function patchWifiKext(){

	#get the current board id
	if [ -z "${myMacIdPattern}" ]; then
		myMacIdPattern=$(ioreg -l | grep "board-id" | awk -F\" '{print $4}')
	fi

	#populate whitelist
	local whitelist=($("$stringsPath" -a -t x ${wifiBrcmBinPath} | grep Mac- | awk -F" " '{print $2}'))

	#check if it needs patching: will do it if the whitelist is not full of own board id
	local occurence=0
	local whitelistedBoardId
	for whitelistedBoardId in "${whitelist[@]}"; do
  		if [ "${whitelistedBoardId}" == "${myMacIdPattern}" ]; then ((occurence+=1)); fi
	done
	#only skip the wifi patching if the wifi kext is not exactly patched as this script does: with all board-ids replaced by own board-id
	if [ "${occurence}" -eq "${#whitelist[@]}" ]; then
		((skippedPatching+=1))
		echo "Skipping whitelist patch...             OK"
	else
		echo -n "Patching whitelist..."
		local whitelistedBoardId
		for whitelistedBoardId in "${whitelist[@]}"; do
			#do the patch, one by one
			patch_strings_in_file "${wifiBrcmBinPath}" "${whitelistedBoardId}" "${myMacIdPattern}"
			echo -n "."
		done
		echo "      OK"
	fi
}

#Applies permissions known to work for the Wi-Fi and Bluetooth Kexts.
function applyPermissions(){
	echo -n "Applying correct permissions...         "
	
	sudo chown -R root:wheel "${btKextPath}"
	sudo chown -R root:wheel "${wifiKextPath}"
	sudo chmod -R 644 "${btKextPath}"
	sudo chmod -R 644 "${wifiKextPath}"

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
	sudo kextcache -system-prelinked-kernel >> /dev/null 2>&1 & spinner "Updating kext caches... "
	echo "               OK"
}

#Avoids having OS X reuse unpatched cached kexts at late system startup and beyond
function updateSystemCache(){
	sudo kextcache -system-caches >> /dev/null 2>&1 & spinner "Updating system caches... "
	echo "             OK"
}

#Prompts to reboot your system, e.g. after patching
function rebootPrompt(){
	echo ""
	read -n 1 -p "Please close any open applications and press any key to reboot..."
	echo ""
	sudo shutdown -r now
	exit;
}

#Silently repairs the disk permissions using the Disk Utility. Takes a few minutes.
function repairDiskPermissions(){
	sudo diskutil repairpermissions / >> /dev/null 2>&1 & spinner "Fixing disk permissions (~5min wait)..."
	echo "OK"
}

#Initiates the compatibility checks, aborts the script if an uncompatible configuration is detected.
#In case of error, an interpretation of it is displayed.
function compatibilityPrecautions(){
	displaySplash
	echo '--- Initiating system compatibility check ---'
	echo ''
	isMyMacModelCompatible
	isMyMacOSCompatible
	isMyBluetoothCompatible
	isMyMacBoardIdCompatible
	areMyActiveWifiDriversOk
	disableOsKextProtection
	canMyKextsBeModded
	isMyMacBlacklisted
	isMyMacWhitelisted
}

#Initiates the system compatibility checks, displays detailed interpretations of each test's result.
#The goal is to understand if and why the system is compatible with this mod.
function verboseCompatibilityCheck(){
	displaySplash
	echo '--- Initiating system compatiblity check ---'
	echo ''
	isMyMacModelCompatible "verbose"
	isMyMacOSCompatible "verbose"
	isMyBluetoothCompatible "verbose"
	isMyMacBoardIdCompatible "verbose"
	areMyActiveWifiDriversOk "verbose"
	disableOsKextProtection "verbose"
	canMyKextsBeModded "verbose"
	isMyMacBlacklisted "verbose"
	isMyMacWhitelisted "verbose"

	backToMainMenu
}

#Prompts to go back to the main menu
function backToMainMenu(){
	echo ""
	read -n 1 -p "Press any key to go back to the main menu..."
	displayMainMenu
}

#Initiates the backup, patching and clean-up.
function checkAndHack(){
	skippedPatching=0 #reset patching counter
	
	if [ "${forceHack}" -ne "1" ]; then
		compatibilityPrecautions
	fi

	#prevent patching if patch is already applied
	if [ "${skippedPatching}" -gt "1" ]; then
		echo ""
		echo "No changes were applied, your system seems to be already OK for Continuity"
		backToMainMenu
	fi
	echo ""
	echo '--- Initiating Continuity mod ---'
	echo ""

	backupKexts
	patchBluetoothKext
	patchWifiKext
	applyPermissions
	updatePrelinkedKernelCache
	updateSystemCache
	repairDiskPermissions
	echo ""
	echo "ALMOST DONE! After rebooting:"
	echo "1) Make sure that both your Mac and iOS device have Bluetooth turned on, and are on the same Wi-Fi network."
	echo "2) On OS X go to SYSTEM PREFERENCES> GENERAL> and ENABLE HANDOFF."
	echo "3) On iOS go to SETTINGS> GENERAL> HANDOFF & SUGGESTED APPS> and ENABLE HANDOFF."
	echo "4) On OS X, and sign out and then sign in again to your iCloud account."
	echo "Further troubleshooting: support.apple.com/kb/TS5458"
	displayThanks
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
	#tput setaf 113
	printf '\e[8;30;158t'
	printf '\e[3;0;0t'
	tput clear
}

#Displays the main menu and asks the user to select an option
function displayMainMenu(){
	displaySplash
	echo "Select an option:"
	echo ""
	options=("Activate Continuity" "System Diagnostic" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			'Activate Continuity') 
				checkAndHack
				;;
			'System Diagnostic') 
				verboseCompatibilityCheck
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
			fi
		fi
	fi
fi

verifyStringsUtilPresence
displayMainMenu

echo ""
echo ""
