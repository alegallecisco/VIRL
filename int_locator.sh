#!/bin/bash
## This script polls for physical devices found by the OS.
## If the interface does not have driver attached, it will
## not be reported.
##
## Created by: Alejandro Gallego
## Last Updated: Apr 18, 2017

printf "\n%10s\t [%s]:\t\t%s\t\t%10s (%s)\n" "Interface" "MAC" "IP Addr" "Driver" "Status"
for f in /sys/class/net/*; do
    dev=$(basename $f)
    driver=$(readlink $f/device/driver/module)
    iaddr=$(ip addr show dev $dev | awk '$1 == "inet" { sub("/..", "", $2); print $2}')
    if [[ -z $iaddr ]]; then
    iaddr=$(printf "No IP Address")
    fi
    if [ $driver ]; then
        driver=$(basename $driver)
	fi
    addr=$(cat $f/address)
    operstate=$(cat $f/operstate)
	if [[ ! -z $driver ]]; then
	    printf "%10s [%s]: %s\t%10s (%s)\n" "$dev" "$addr" "$iaddr" "$driver" "$operstate"
	fi
done
echo ""