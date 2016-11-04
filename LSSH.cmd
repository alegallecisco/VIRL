@echo off

REM SSH launcher!
TITLE Bigger Deal Than YOU
MODE con:cols=80 lines=22
COLOR 1F
SET _HIST=%TEMP%\ssh_hist.txt
SET h_count=0
echo Application Started: %DATE% %TIME%> "%_HIST%"
echo    	      The ssh Launcher
echo	 	  *** I AM A BIG DEAL! ***
CHOICE /T 2 /C Y /D Y > NUL
cls
echo This small script will make ssh sessions using
echo PuTTY easier. For more info go to http://www.putty.org/
echo.
echo CHOICES
echo [S] Single Session
echo [M] Multi-Session
echo [C] Cancel
echo.
CHOICE /C SMC /M "Will this be single or multi-session? " 
	if errorlevel 3 goto sub_END
	if errorlevel 2 cls && goto sub_MULTI1
	if errorlevel 1 goto sub_SINGLE

:sub_MULTI1

SET s_count=0

:sub_MULTI

echo SELECT
echo []  Hostname/IP Address
echo [t] Telnet
echo [p] Ping test
echo [r] Remote Desktop
echo [q] Quit

:sub_CHOICE

	if %s_count%==6 goto :WIPE
SET /a s_count +=1
SET /a h_count +=1
SET /P ssh_rqst=Host/IP or Select [t] [p] [r] [q]: 
echo %ssh_rqst% %TIME%>> "%_HIST%"	
	if %ssh_rqst%==q goto sub_PART
	if %ssh_rqst%==r goto sub_RDP
	if %ssh_rqst%==t START LTEL && goto sub_CHOICE
	if %ssh_rqst%==p START LPING && goto sub_CHOICE
SET /P user_name=Username to connect with: 
START ssh "%user_name%"@"%ssh_rqst%" && goto sub_CHOICE

:WIPE

cls && goto sub_MULTI1

:sub_SINGLE

SET /P ssh_rqst=Enter Hostname or IP Address: 
SET /P user_name=Username to connect with: 
START ssh "%user_name%"@"%ssh_rqst%" && goto sub_END

:sub_PART

if %h_count% LEQ 2 goto sub_END
			
:sub_HIST

CHOICE /C YN /M "Would you like to see your connections?"
	if errorlevel 2 echo "Application closed by user!" >> %_HIST% && goto sub_END 
	if errorlevel 1 goto sub_SHOW

:sub_SHOW

more %_HIST% 
pause
echo "Application closed by user!" >> %_HIST%
	exit

:sub_RDP

SET /P rdp_rqst=Host/IP Addr: 
START mstsc /v:%rdp_rqst% /console && goto sub_CHOICE
	
:sub_END
	
exit

