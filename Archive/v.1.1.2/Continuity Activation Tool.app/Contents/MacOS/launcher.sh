#!/bin/bash
scriptPath=$(dirname "$0")'/contitool.sh'
#Resizes / recolors the Terminal Window
function applyTerminalTheme(){
	tput setab 0
	tput setaf 10
	#tput setaf 113
	printf '\e[8;30;158t'
	printf '\e[3;0;0t'
	tput clear
}
applyTerminalTheme
tput clear
echo ""
echo "You must run this script with admin privileges, please enter your password."
echo ""
sudo "${scriptPath}"