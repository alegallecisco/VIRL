#!/bin/bash
## This script polls for physical devices found by the OS.
## If the interface does not have driver attached, it will
## not be reported.
##
## Created by: Alejandro Gallego
## Last Updated: Feb 01, 2017

for f in /sys/class/net/*; do
    dev=$(basename $f)
    driver=$(readlink $f/device/driver/module)
    if [ $driver ]; then
        driver=$(basename $driver)
	fi
    addr=$(cat $f/address)
    operstate=$(cat $f/operstate)
	if [[ ! -z $driver ]]; then
	    printf "%10s [%s]: %10s (%s)\n" "$dev" "$addr" "$driver" "$operstate"
	fi
done