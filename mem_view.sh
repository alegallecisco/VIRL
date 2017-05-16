#!/bin/bash
## Memory usage viewer! Must be enabled in the kernel!!
## while /bin/true; do cat /sys/kernel/mm/uksm/pages_shared; sleep 5; done
## See: https://virl-dev.atlassian.net/wiki/display/VIRL/Release+Readiness+for+VIRL+1.3+2017-05-10
##
## Last modified: May 15, 2017

clear
while /bin/true
do
## Get system memory information
    mfree=$(cat /proc/meminfo | awk '/MemFree/ {print $2}')
    mavail=$(cat /proc/meminfo | awk '/MemAvailable/ {print $2}')
    MemFree=$(bc -l <<< "scale=2; $mfree / 1024 * .001")
    MemAvailable=$(bc -l <<< "scale=2; $mavail / 1024 * .001")
## Get info from UKSM
    pgshr=$(cat /sys/kernel/mm/uksm/pages_shared)
    mem_svd=$(cat /sys/kernel/mm/uksm/pages_sharing)
## Convert to MegaByte
    mb_pgshr=$(bc -l <<< "scale=2; $pgshr / 1024 * .1")
    mb_svd=$(bc -l <<< "scale=2; $mem_svd / 1024 * .1")
    m_info=$(free -h |egrep -B2 Mem)
    uks=$(cat /sys/kernel/mm/uksm/run)

    if [[ "$uks" -eq "1" ]]; then
        rn=ON
    else
        rn=OFF
    fi

## Display system and UKSM memory information
    echo -ne "UKSM state: [ $rn ] Memory info:\n$m_info\n\nUKSM info\nMemory Saved: $mb_svd(MB)  Shared Pages: $mb_pgshr(MB)  Free Mem: $MemFree(GB)  Available Mem: $MemAvailable(GB)"'\r'
    sleep 2
    clear
done
