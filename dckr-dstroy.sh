#!/bin/bash
## Script to maanage docker containers

function int_exit
{
        echo "${PROGNAME}: Aborted by user"
        exit
}

function _resp
{
	until [ "$_resp" = "y" ]; do
    echo -n "Continue? (y/n) "
    read _resp
        case $_resp in
            y ) _resp=y ;;
            n ) clear ; _strt ;;
            * ) printf "Please enter a \"y\" or \"n\"%s\n\n" ;;
        esac
    done
}

function press_enter
{
	echo ""
	echo -n "Press enter to continue"
	read
	clear
}
function _lstimg
{
# List Docker images
docker ps -a
}

function _stop
{
# Stop all containers
cntnr=$(docker ps -aq)
printf "Stopping the following container(s)\n%s\n" $cntnr
sleep 5
docker stop $(docker ps -aq)
}

function _rm
{
# Delete all containers
echo "This action will delete all of the following containers: "
_lstimg
_resp
docker rm $(docker ps -aq)
}

function _del
{
unset options s
# Delete all images
declare -a imag=($(docker images -q))
        options[s++]=$imag
select opt in "${options[@]}" "Exit"; do
    case $opt in
    $imag ) echo "Deleting $opt " ; sleep 2 ; docker image history $imag
     ;;
    "Exit" )
    _strt ;;
    * )
    echo "Invalid Selection"
    ;;
    esac
done
}

function _strt
{
# Select action
sel=
until [ "$sel" = "0" ]; do
	echo ""
	echo "***** Docker Actions ******"
	echo "1 - LIST all docker images"
	echo "2 - STOP all docker containers"
	echo "3 - DELETE all docker containers"
	echo "4 - REMOVE all docker images"
	echo "00 - "
	echo "0 - Exit"
	echo ""
	echo -n "Enter selection: "
	read sel
	echo ""
	case $sel in
		1 ) _lstimg ; press_enter ;;
		2 ) _stop ; press_enter ;;
		3 ) _rm ; press_enter ;;
		4 ) _del ; press_enter ;;
		0 ) _resp ; clear ; exit 0 ;;
		* ) echo "Please select from the menu" ; press_enter ;;
	esac
done
}

trap int_exit INT
_strt
