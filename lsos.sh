#!/bin/bash

#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 


set -o errexit -o nounset -o pipefail

# "|| true" has been added to the lines executing the command "tail" to avoid pipefail.
# https://stackoverflow.com/questions/19120263/why-exit-code-141-with-grep-q
# https://stackoverflow.com/questions/33020759/piping-to-head-results-in-broken-pipe-in-shell-script-called-from-python

# If the used memory percentage is greater or equal, a warning will be shown
readonly MEMORY_WARNING=80

# Output lengths
readonly PS_LENGTH=1
readonly LOG_LENGTH=1

# Colours
readonly RED='\033[0;31m'
readonly GREEN='\033[0;92m'
readonly NO_COLOUR='\033[0m'
# Removing colours from journalctl outputs
export SYSTEMD_COLORS=false


echo_title()
	{
	local i
	local UNDERLINE_CHAR='-'
	if [ $# -ne 1 ]
		then
		echo "Error: function called with missing argument" >&2
printf_title()
	{
	local i
	local UNDERLINE_CHAR='-'
	if [ $# -eq 0 ]
		then
		printf "Error: function called with missing argument\n" >&2
		return 22
		fi
	local STR="$1"
	local LENGTH=${#STR}
	echo -e "${RED}${STR}"
	for i in $(seq 1 $LENGTH)
		do
		echo -en "$UNDERLINE_CHAR"
		done
	echo -e "${NO_COLOUR}"
	}

echo_green()
	{
	if [ $# -ne 1 ]
                then
                echo "Error: function called with missing argument" >&2
                return 22
                fi
        local STR="$1"
	echo -e "${GREEN}${STR}${NO_COLOUR}"
	}

	printf "${RED}${STR}\n"
	for i in $(seq 1 $LENGTH)
		do
		printf "$UNDERLINE_CHAR"
		done
	printf "${NO_COLOUR}\n"
	}

printf_green()
	{
	if [ $# -eq 0 ]
                then
                printf "Error: function called with missing argument\n" >&2
                return 22
                fi
        local STR="$1"
	local ARGS="${@:2}"
        printf "${GREEN}${STR}${NO_COLOUR}\n" $ARGS	
	}

printf_red()
	{
	if [ $# -eq 0 ]
                then
                printf "Error: function called with missing argument\n" >&2
                return 22
                fi
        local STR="$1"
	local ARGS="${@:2}"
        printf "${RED}${STR}${NO_COLOUR}\n" $ARGS	
	}

if [ $# -ne 1 ]
	then
	printf "Use: $0 <sosreport_directory>\n" >&2
	exit 2
	fi
cd $1


# SYSTEM
echo_title "SYSTEM"
echo_green "\nOperating system:"
grep -w "^PRETTY_NAME" etc/os-release | awk -F '=' '{print $2}' | tr -d '"'
echo_green "\nKernel:"
cat 'uname'
echo -e "\n"

# CPU
echo_title "CPU"
echo_green "\nCPU load:"
printf_title "SYSTEM"
printf_green "\nOperating system:"
grep -w "^PRETTY_NAME" etc/os-release | awk -F '=' '{print $2}' | tr -d '"'
printf_green "\nKernel:"
cat 'uname'
printf "\n\n"

# CPU
printf_title "CPU"
printf_green "\nCPU load:"
cat 'uptime'
CORES=$(grep '^processor' proc/cpuinfo | tail -n 1 | awk '{print $3}')
# The core count in proc/cpuinfo starts with zero. Therefore, adding 1
CORES=$((${CORES}+1))
echo "Number of cores: $CORES"
echo_green "\nTop CPU-consuming process/es:"
printf "Number of cores: ${CORES}\n"
printf_green "\nTop CPU-consuming process/es:"
head -n 1 ps
{ tail -n +2 ps | sort -nr -k 3 | head -n $PS_LENGTH; } || true
#sort -nr -k 3 ps | head -n $PS_LENGTH
printf "\n\n"

# Memory
echo_title "MEMORY"
echo_green "\nMemory load in MiB:"
cat 'sos_commands/memory/free_-m'
USED_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $3}')
TOTAL_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $2}')
USED_MEMORY_PERCENT=$(echo "scale=10; $USED_MEMORY / $TOTAL_MEMORY * 100" | bc -l)
printf "Memory use: %.2f%% \n" $USED_MEMORY_PERCENT
echo_green "\nTop memory-consuming process/es:"
printf_title "MEMORY"
printf_green "\nMemory load in MiB:"
cat 'sos_commands/memory/free_-m'
USED_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $3}')
TOTAL_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $2}')
USED_MEMORY_PERCENT=$(echo "scale=10; $USED_MEMORY / $TOTAL_MEMORY * 100" | bc --mathlib)
printf "Memory use: "
if (( $(echo "$USED_MEMORY_PERCENT >= $MEMORY_WARNING" | bc --mathlib) ))
	then
	printf_red "%.2f%% (WARNING!)\n" $USED_MEMORY_PERCENT
else	
	printf "%.2f%%\n" $USED_MEMORY_PERCENT
	fi
printf_green "\nTop memory-consuming process/es:"
head -n 1 ps
{ tail -n +2 ps | sort -nr -k 4 | head -n $PS_LENGTH; } || true
#sort -nr -k 4 ps | head -n $PS_LENGTH
printf "\n\n"

# Local storage
echo_title "LOCAL STORAGE"
echo_green "\nMost relevant file systems:"
printf_title "LOCAL STORAGE"
printf_green "\nMost relevant file systems:"
grep -w '/' sos_commands/filesys/df_-al_-x_autofs
#grep -w '/var' sos_commands/filesys/df_-al_-x_autofs | grep -Fv '/var/' || true
if ! grep -w '/var' sos_commands/filesys/df_-al_-x_autofs | grep -Fv '/var/'
	then
	printf "Warning: /var file system not found\n" >&2
	fi
printf "\n\n"

# Logs
echo_title "LOGS"
JOURNAL_FIND=$(find ./var -name system.journal)
if [ $(echo "$JOURNAL_FIND" | wc -l) -gt 1 ]
	then
	echo "Error: multiple system.journal files found in var directory:" >&2
	echo "$JOURNAL_FIND" >&2
printf_title "LOGS"
JOURNAL_FIND=$(find ./var -name system.journal)
if [ $(printf "$JOURNAL_FIND" | wc -l) -gt 1 ]
	then
	printf "Error: multiple system.journal files found in var directory:\n" >&2
	printf "${JOURNAL_FIND}\n" >&2
	exit 7
	fi
if [ -z "$JOURNAL_FIND" ] || [ $(printf "$JOURNAL_FIND" | wc -l) -eq 0 ]
	then
	echo "Error: No system.journal file found in var directory" >&2
	printf "Error: No system.journal file found in var directory\n" >&2
	exit 7
	fi
JOURNAL_DIR=$(readlink -e "$(dirname "$JOURNAL_FIND")")
#LOG_LINES=$(journalctl -D "$JOURNAL_DIR" --no-pager | wc -l)
LOG_LINES_ERR=$(journalctl -D "$JOURNAL_DIR" --no-pager -p err | wc -l)
#LOG_ERR_PERCENTAGE=$(echo "scale=10; $LOG_LINES_ERR / $LOG_LINES * 100" | bc -l)
echo_green "\nNumber of error log lines:"
echo "Total: $LOG_LINES_ERR"
#printf "Percentage: %.1f%% \n" $LOG_ERR_PERCENTAGE
echo_green "\nLast error log line/s:"
journalctl -D "$JOURNAL_DIR" --no-pager -p err -n $LOG_LENGTH 
echo_green "\nLast error log line/s of crio unit:"
journalctl -D "$JOURNAL_DIR" --no-pager -u crio -p err -n $LOG_LENGTH 
echo_green "\nLast error log line/s of kubelet unit:"
journalctl -D "$JOURNAL_DIR" --no-pager -u kubelet -p err -n $LOG_LENGTH 
echo_green "\nLast error log line/s of kernel:"
journalctl -D "$JOURNAL_DIR" --no-pager -t kernel -p err -n $LOG_LENGTH 
echo_green "\nCommands to execute for complete logs:"
#LOG_ERR_PERCENTAGE=$(printf "scale=10; $LOG_LINES_ERR / $LOG_LINES * 100" | bc -l)
printf_green "\nNumber of error log lines:"
printf "Total: ${LOG_LINES_ERR}\n"
#printf "Percentage: %.1f%% \n" $LOG_ERR_PERCENTAGE
printf_green "\nLast error log line/s:"
journalctl -D "$JOURNAL_DIR" --no-pager -p err -n $LOG_LENGTH 
printf_green "\nLast error log line/s of crio unit:"
journalctl -D "$JOURNAL_DIR" --no-pager -u crio -p err -n $LOG_LENGTH 
printf_green "\nLast error log line/s of kubelet unit:"
journalctl -D "$JOURNAL_DIR" --no-pager -u kubelet -p err -n $LOG_LENGTH 
printf_green "\nLast error log line/s of kernel:"
journalctl -D "$JOURNAL_DIR" --no-pager -t kernel -p err -n $LOG_LENGTH 
printf_green "\nCommands to execute for complete logs:"
cat <<-EOF
	journalctl -D "$JOURNAL_DIR" | less
	journalctl -D "$JOURNAL_DIR" -u crio | less
	journalctl -D "$JOURNAL_DIR" -u kubelet | less
	journalctl -D "$JOURNAL_DIR" -t kernel | less
	EOF
