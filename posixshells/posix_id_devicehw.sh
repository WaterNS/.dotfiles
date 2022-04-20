#!/bin/sh

# Identify hardware
HW_HOSTNAME="??"
HW_TOTALPCPUs="??"
HW_TOTALVCPUs="??"
HW_TOTALRAM="??"
HW_USEDSTORAGE="??"
HW_TOTALSTORAGE="??"
#HW_FREESTORAGE="??"

HW_HOSTNAME=$(hostname)
HW_TOTALVCPUs=$(getconf _NPROCESSORS_ONLN)

if [ -f "/proc/meminfo" ]; then
  meminfo () {
    __meminfo=$(awk '$3=="kB"{if ($2>1024^2){$2=$2/1024^2;$3="GB";} else if ($2>1024){$2=$2/1024;$3="MB";}} 1' /proc/meminfo)
    echo "$__meminfo" | column -t;
    unset __meminfo;
  }
  HW_TOTALRAM=$(meminfo | awk '/MemTotal/ {printf "%.2f", $2; print $3}')
fi

HW_STRING="Host: $HW_HOSTNAME / CPUs: $HW_TOTALPCPUs (${HW_TOTALVCPUs} vCPUs) RAM: $HW_TOTALRAM / Storage: ${HW_USEDSTORAGE}/${HW_TOTALSTORAGE}";
export HW_STRING;
