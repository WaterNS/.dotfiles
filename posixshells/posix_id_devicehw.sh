#!/bin/sh

# Identify hardware
HW_HOSTNAME="??"
HW_CPUNAME="??"
HW_TOTALPCPUs="??"
HW_TOTALCORES="??"
HW_TOTALRAM="??"
HW_USEDSTORAGE="??"
HW_TOTALSTORAGE="??"
HW_FREESTORAGE="??"

HW_HOSTNAME=$(hostname)
HW_TOTALCORES=$(getconf _NPROCESSORS_ONLN)


#REF: https://unix.stackexchange.com/a/149634
bytesToHumanReadable() {
  # Converts bytes value to human-readable string [$1: bytes value]
  # Relies on awk to do floating point math
  __NUMBER=${1%.*}
  for __DESIG in Bytes KB MB GB TB PB
  do
    [ "${__NUMBER%.*}" -lt 1024 ] && break
    __NUMBER=$(awk -v dividend="${__NUMBER}" -v divisor=1024 'BEGIN {printf "%.2f", dividend/divisor; exit(0)}')
  done
  __NUMBER=$(echo "$__NUMBER" | awk '/^ *[0-9]+\.[0-9]+/{sub(/0+$/,"");sub(/\.$/,"")}1') #REF: https://stackoverflow.com/a/24109175
  echo "$__NUMBER $__DESIG";
  unset __NUMBER; unset __DESIG;
}

kbToHumanReadable() {
  # Converts bytes value to human-readable string [$1: kilobytes value]
  # Relies on awk to do floating point math
  __NUMBER=${1%.*}
  for __DESIG in KB MB GB TB PB
  do
    [ "${__NUMBER%.*}" -lt 1024 ] && break
    __NUMBER=$(awk -v dividend="${__NUMBER}" -v divisor=1024 'BEGIN {printf "%.2f", dividend/divisor; exit(0)}')
  done
  __NUMBER=$(echo "$__NUMBER" | awk '/^ *[0-9]+\.[0-9]+/{sub(/0+$/,"");sub(/\.$/,"")}1') #REF: https://stackoverflow.com/a/24109175
  echo "$__NUMBER $__DESIG";
  unset __NUMBER; unset __DESIG;
}


if [ -f "/proc/meminfo" ]; then
  meminfo () {
    __meminfo=$(awk '$3=="kB"{if ($2>1024^2){$2=$2/1024^2;$3="GB";} else if ($2>1024){$2=$2/1024;$3="MB";}} 1' /proc/meminfo)
    echo "$__meminfo" | column -t;
    unset __meminfo;
  }
  HW_TOTALRAM=$(meminfo | awk '/MemTotal/ {printf "%.2f", $2; print $3}')
fi

if [ "$OS_FAMILY" = "Darwin" ]; then
  HW_CPUNAME=$(sysctl -n machdep.cpu.brand_string)
  HW_TOTALPCPUs="1" #$(sysctl -n machdep.cpu.core_count)
  HW_TOTALCORES=$(sysctl -n machdep.cpu.core_count)
  HW_TOTALRAM=$(bytesToHumanReadable "$(sysctl -n hw.memsize)")
fi

if [ -x "$(command -v df)" ]; then
  __rootdiskspace=$(df -k / | awk 'NR>1')
  if [ "$OS_FAMILY" = "Darwin" ];then
    __rootdiskspace=$(df -k /System/Volumes/Data | awk 'NR>1')
  fi
  HW_TOTALSTORAGE=$(kbToHumanReadable "$(echo "$__rootdiskspace" | awk '{print $2}')")
  HW_USEDSTORAGE=$(kbToHumanReadable "$(echo "$__rootdiskspace" | awk '{print $3}')")
  HW_FREESTORAGE=$(kbToHumanReadable "$(echo "$__rootdiskspace" | awk '{print $4}')")
fi


HW_STRING="Host: $HW_HOSTNAME / CPU: $HW_CPUNAME ($HW_TOTALPCPUs cpu/${HW_TOTALCORES} cores) RAM: $HW_TOTALRAM / Storage: ${HW_USEDSTORAGE}/${HW_TOTALSTORAGE} ($HW_FREESTORAGE free)";
export HW_STRING;
