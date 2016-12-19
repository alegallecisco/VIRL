#!/bin/bash

function mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) printf "Error: $dec invalid net mask"; nmask ;;
        esac
    done
    echo "$nbits"
}

function validateIP()
{
local ip=$1
local stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[0]} -ge ${ip[1]} && ${ip[1]} -le 255 && ${ip[1]} -ge ${ip[2]} \
        && ${ip[2]} -le 255 && ${ip[2]} -ge ${ip[3]} && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function inip()
{
    read -p "Enter IP: " ip
    validateIP $ip

    if [[ $? -ne 0 ]];then
        echo "Invalid IP Address"
    fi
}

function nmask()
{
    read -p "Enter NetMask: " MASK
    numbits=$(mask2cidr $MASK)
    echo "/$numbits"
    local stat=1
    if [[ $MASK =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        MASK=($MASK)
        IFS=$OIFS
        [[ ${MASK[0]} -le 255 && ${MASK[0]} -ge ${MASK[1]} && ${MASK[1]} -le 255 && ${MASK[1]} -ge ${MASK[2]} \
        && ${MASK[2]} -le 255 && ${MASK[2]} -ge ${MASK[3]} && ${MASK[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
    
    exit 0
}

function _netmask()
{
    local netmask=$1
    read -p "Enter NetMask: " netmask
    local netmask_binary
    local octet
    local stat

    if [[ $netmask =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        stat=0
        for ((i=0; i<4; i++))
        do
            octet=${netmask%%.*}
            netmask=${netmask#*.}
            [[ $octet -gt 255 ]] && { stat=1; echo "Invalid entry" ; _netmask; }
            netmask_binary=$netmask_binary$( echo "obase=2; $octet" | bc )
            [[ $netmask_binary =~ 01 ]] && { stat=1; echo "Invalid entry" ; _netmask; }
        done
    else
        stat=1
    fi
    return $stat
    echo $netmask
}

function _ip()
{
    read -p "Enter IP Addr.: " inip
    local ip_binary
    local octet
    local stat

    if [[ $inip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        stat=0
        for ((i=0; i<4; i++))
        do
            octet=${inip%%.*}
            netmask=${inip#*.}
            [[ $octet -gt 255 ]] && { stat=1; echo "Invalid entry" ; _ip; }
            ip_binary=$ip_binary$( echo "obase=2; $octet" | bc )
            [[ $ip_binary =~ 01 ]] && { stat=1; echo "Invalid entry" ; _ip; }
        done
    else
        stat=1
    fi
    return $stat
    echo $inip
}



inip
nmask
#_ip  
#_netmask
