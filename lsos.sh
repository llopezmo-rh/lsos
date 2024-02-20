#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>. 


#!/bin/bash

# Option pipefail unset because the script exits with return code 141 after the following line:
# tail -n +2 ps | sort -nr -k 3 | head -n $PS_LENGTH
# Reason: PIPEFAIL signal sent. More information on the links below:
# https://stackoverflow.com/questions/19120263/why-exit-code-141-with-grep-q
# https://stackoverflow.com/questions/33020759/piping-to-head-results-in-broken-pipe-in-shell-script-called-from-python
# Alternatively, trap can be used
#set -o errexit -o nounset -o pipefail
set -o errexit -o nounset

# Output lengths
PS_LENGTH=1
LOG_LENGTH=1

# Colours
RED='\033[0;31m'
NO_COLOUR='\033[0m'
# Removing colours from journalctl outputs
export SYSTEMD_COLORS=false

if [ $# -ne 1 ]
	then
	echo "Use: $0 <sosreport_directory>" >&2
	exit 2
	fi
cd $1

# CPU
echo -e "${RED}CPU"
echo -e "---${NO_COLOUR}"
echo "CPU load:"
cat uptime
echo -n "Number of cores: "
CORES=$(grep '^processor' proc/cpuinfo | tail -n 1 | awk '{print $3}')
# The core count in proc/cpuinfo starts with zero. Therefore, adding 1
CORES=$((${CORES}+1))
echo "$CORES"
echo -e "\nTop CPU-consuming process/es:"
head -n 1 ps
tail -n +2 ps | sort -nr -k 3 | head -n $PS_LENGTH
#sort -nr -k 3 ps | head -n $PS_LENGTH
echo -e "\n"

# Memory
echo -e "${RED}MEMORY"
echo -e "------${NO_COLOUR}"
echo "Memory load in MiB:"
cat 'sos_commands/memory/free_-m'
USED_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $3}')
TOTAL_MEMORY=$(grep -w '^Mem:' 'sos_commands/memory/free_-m' | awk '{print $2}')
USED_MEMORY_PERCENT=$(echo "scale=10; $USED_MEMORY / $TOTAL_MEMORY *100" | bc -l)
printf "Memory use: %.2f%% \n" $USED_MEMORY_PERCENT
echo -e "\nTop memory-consuming process/es:"
head -n 1 ps
tail -n +2 ps | sort -nr -k 4 | head -n $PS_LENGTH
#sort -nr -k 4 ps | head -n $PS_LENGTH
echo -e "\n"

# Local storage
echo -e "${RED}LOCAL STORAGE"
echo -e "-------------${NO_COLOUR}"
echo "Most relevant file systems:"
grep -w '/' sos_commands/filesys/df_-al_-x_autofs
#grep -w '/var' sos_commands/filesys/df_-al_-x_autofs | grep -Fv '/var/' || true
if ! grep -w '/var' sos_commands/filesys/df_-al_-x_autofs | grep -Fv '/var/'
	then
	echo "Warning: /var file system not found" >&2
	fi
echo -e "\n"

# Logs
echo -e "${RED}LOGS"
echo -e "----${NO_COLOUR}"
JOURNAL_FIND=$(find . -name system.journal)
if [ $(echo "$JOURNAL_FIND" | wc -l) -gt 1 ]
	then
	echo "Error: multiple system.journal files found:" >&2
	echo "$JOURNAL_FIND" >&2
	exit 7
	fi
if [ -z "$JOURNAL_FIND" ] || [ $(echo "$JOURNAL_FIND" | wc -l) -eq 0 ]
	then
	echo "Error: No system.journal file found" >&2
	exit 7
	fi
JOURNAL_DIR=$(readlink -e "$(dirname "$JOURNAL_FIND")")
echo -e "\nLast error log line/s of crio unit:"
journalctl -D "$JOURNAL_DIR" -u crio -p err -n $LOG_LENGTH 
echo -e "\nLast error log line/s of kubelet unit:"
journalctl -D "$JOURNAL_DIR" -u kubelet -p err -n $LOG_LENGTH 
echo -e "\nLast error log line/s of kernel:"
journalctl -D "$JOURNAL_DIR" -t kernel -p err -n $LOG_LENGTH 
echo
cat <<-EOF
	Commands to execute for complete logs:
	journalctl -D "$JOURNAL_DIR" | less
	journalctl -D "$JOURNAL_DIR" -u crio | less
	journalctl -D "$JOURNAL_DIR" -u kubelet | less
	journalctl -D "$JOURNAL_DIR" -t kernel | less
	EOF
