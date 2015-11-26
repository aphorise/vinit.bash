#!/bin/bash
# //##############
# // description: Screen process / service initialiser with monitor.
# // linked to vinit.template for "service vinit stop/start"
# //##############
# #// Executing user, service/process name & path of process being monitored
USER="$(whoami)" ;
SNAME="vinit.bash" ;
APATH="$(pwd)" ;
PS_LOOP="yes > /dev/null" ;
# #// or bash ==: PS_LOOP="while :; do echo 1 > /dev/null ; done" ;
# #// or node.js ==: PS_LOOP="echo 'while (1) { }' | node" ;
# #// interval between checks - where total is times by ilimit (90 secs if 3x30).
cpu_max=99.1 ;
cpu_ilimit=3 ;
cpu_icheck=30 ;
# #// notification-reset + interval in seconds, & total strikes limit.
tNoticeReset=240 ;
tNoticeGap=15 ;
iNoticeMax=2 ;
# #// File names of temporary counters stored in /tmp/zSentTotal_...
zPrefixSent='zSentTotal_' ;
zPrefixLast='zSentLast_' ;
# #// special seperator for files & screen session naming.
PSE="___" ;
HELP="Use:\n\t start\n\t stop (all|screen_id)\n\t restart\n\t update\n\t ^ argument\n" ;
# #// ----------------------------------------------
# #// process launch / relauncher with CPU monitor
# #// ----------------------------------------------
function ps_loop()
{
	if ! cd $APATH 2>/dev/null ; then echo -e "\nINVALID path: $APATH - or not installed.\n" && exit 2 ; fi ;
	# # // counter of number of bad strikes.
	cpu_bad=0 ;
	TSTART=$(date +%s) ; # #// START TIME
	# #// Temporary file refrences:
	PTOTAL=/tmp/$zPrefixSent$1.txt ; PSEND=/tmp/$zPrefixLast$1.txt ;
	if ((UID == 0)) ; then
		su -l $USER -s /bin/bash -c "cd $APATH && screen -L -m -d -S $1 sh -c \"$PS_LOOP\" " ;
	else
		cd $APATH && screen -L -m -d -S $1 sh -c "$PS_LOOP" ;
	fi ;
	echo -e "\nStarted process on SCREEN: $1" ;
	sleep 1 ; PIDACTIVE=0 ;
	# #// First run is fired early to ensure proper start & setting of active status
	# #// --------------------------------------------------------------------------
	if ls /var/run/screen/S-$USER/*.$1 1> /dev/null 2>&1; then
		# #// Check for screen presance before doing anything.
		for f in /var/run/screen/S-$USER/*.$1 ; do
			if [ -e "$f" ] ; then
				parentpid=$(echo "$f" | awk -F"." "{print \$1}" | awk -F"/" "{print \$6}") ;
				pid=$(ps --ppid $parentpid -o pid | tail -n 1) ;
				pid=$(ps --ppid $pid -o pid | tail -n 1) ;
				IFS=: read -a aVar < /tmp/"$1".txt ;
				echo "${aVar[0]}:active" > /tmp/$1.txt ;
				PIDACTIVE=1 ;
				break ;
			fi ;
		done ;
	fi ;
	if ((PIDACTIVE==1)) ; then
		# #// Well check every X seconds for PID being present and CPU usage
		while sleep $cpu_icheck ; do
			# #// --------------------------------------------------------------------------
			# #// Check for screen presance before doing anything.
			if ls /var/run/screen/S-$USER/*.$1 1> /dev/null 2>&1; then
				for f in /var/run/screen/S-$USER/*.$1 ; do
					if [ -e $f ] ; then
						parentpid=$(ls /var/run/screen/S-$USER/*.$1 | awk -F"." "{print \$1}" | awk -F"/" "{print \$6}") ;
						pid=$(ps --ppid $parentpid -o pid | tail -n 1) ;
						pid=$(ps --ppid $pid -o pid | tail -n 1) ;
					else
						echo -e "\nMISSING / CLOSED Screen session: $f\n" ;
						break 2 ;
					fi ;
					break ;
				done ;
				# #// We must have PID value of inner SCREEN process. Check usage.
				total_ps=$(ps -eo pcpu,pid,user,args | grep $pid | wc -l) ;
				ps_loop=$(ps -eo pcpu,pid,user,args | grep $pid | head -n 1 | awk "{print \$1}") ;
				if (( `echo $ps_loop"<"$cpu_max | bc` )) ; then
					if ((cpu_bad > 0)) ; then ((--cpu_bad)) ; fi ;
				else
					((++cpu_bad)) ;
					if ((cpu_bad >= cpu_ilimit)) ; then
						echo "$BASHPID:inactive" > /tmp/$1.txt ;
						if ((UID == 0)) ; then su -l $USER -s /bin/bash -c "screen -S $1 -X quit && screen -wipe" ;
						else screen -S $1 -X quit ; fi ;
						break ;
					fi ;
					if ((total_ps<2)) ; then break ; fi ;
				fi ;
			else
				echo -e "\nNO RELATED Screen sessions!.\n" ;
				IFS=$PSE read -a fList < "${2}"
				for f in /tmp/${fList[0]}*.txt ; do
					if [ -f $f ] ; then
						IFS=: read -a aVar < "$f" ;
						if [[ $BASHPID == ${aVar[0]} ]] || [[ ${aVar[1]} == 'active' ]] ; then
							# #//echo "${aVar[0]} === active <--- KILLING" ;
							psCheck=$(ps -p ${aVar[0]} -o%cpu='')
							if ((${#psCheck} != 0)) ; then
								if [[ $BASHPID == ${aVar[0]} ]] ; then echo "$BASHPID:inactive" > $f ; break 2 ; fi ;
							fi ;
						fi ;
					fi ;
				done ;
			fi ;
			# #// --------------------------------------------------------------------------
		done ;
	fi ;
	# #//---------------------------------------------------------------
	# #// CRASH - Notifications: counter / checks for e-mail & SMS
	# #//---------------------------------------------------------------
	TEND=$(date +%s) ; TDIFF=$(( $TEND - $TSTART )) ;
	echo -e "\033[0m\nPROCESS: $node_pid executed for: $TDIFF seconds.\n" ;
	echo -e "\NProcess died or is > above 99.5% use for too long.\nRESTARTING process by invoking self.\n" ;
	if [ ! -f $PSEND ] ; then echo $(date +%s) > $PSEND ; fi ;
	if [ ! -f $PTOTAL ] ; then echo 0 > $PTOTAL ; fi ;
	SENT_TOTAL=$(awk "{print $NF}" $PTOTAL) ;
	SEND_LAST=$(awk "{print $NF}" $PSEND) ;
	SEND_NOW=$(date +%s) ;
	TDIFF=$((SEND_NOW-SEND_LAST)) ;
	TOSEND=0 ;
	if ((TDIFF == 0)) || ((TDIFF > tNoticeGap)) ; then
		# #// IF 2 minutes have elapsed allow resending in next 15 secs
		if ((TDIFF > tNoticeReset )) ; then echo $SEND_NOW > $PSEND ; echo 0 > $PTOTAL ; fi ;
		if ((SENT_TOTAL < iNoticeMax )) ; then
			((++SENT_TOTAL)) ;
			echo $SEND_NOW > $PSEND ;
			echo $SENT_TOTAL > $PTOTAL ;
			TOSEND=1 ;
		fi ;
	fi ;
	if ((TOSEND==1)) ; then
		echo -e "\nWOULD invoke notifications here...\n" ;
	fi ;
	ps_loop $1 $2 $3 $4 &
	echo "$!:inactive" > /tmp/$1.txt ;
	return ;
}
# #// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# #// MAIN CASE STATMENT
# #// @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
if ! cd $APATH 2>/dev/null; then echo -e "INVALID path: $APATH - or not installed.\n" && exit 2 ; fi;
case "$1" in
 start)
	if [[ $2 != *"$PSE"* ]] ; then a2="$SNAME$PSE$(date +%Y_%m_%d_%H_%M_%S_%N)" ; else a2=$2 ; fi ;
	ps_loop $a2 $3 $4 $5 &
	sPS="$!" ;
	echo "$sPS:inactive" > /tmp/$a2.txt ;
	echo -e "\nLaunched anew with PID == $sPS\n\n" ;
 ;;
 stop)
	PSDEL=0 ;
	SIP=$(screen -ls $USER/ | grep $SNAME) ;
	SIPT=$(echo -e "$SIP" | wc -l) ;
	if ((${#SIP} == 0)) ; then
		echo -e "\nNO Running ($SNAME) instance(s)! - Doing DEEP check.\n" ;
		for f in /tmp/$SNAME*.txt ; do
			if [ -f "$f" ] ; then
				IFS=: read -a aVar < "$f" ;
				if [[ "inactive" == ${aVar[1]} ]] ; then
					echo -e "$SNAME - PID instannce: ${aVar[0]} - being deleted." ;
					rm -rf $f /tmp/$zPrefixSent\$1.txt /tmp/$zPrefixLast\$f.txt 2>/dev/null ;
					kill -9 ${aVar[0]} 2>/dev/null ;
					((++PSDEL)) ;
				fi ;
			fi ;
		done ;
	fi ;
	if [ -e $2 ] ; then
		if ((SIPT != 1)) ; then
			echo -e "\nToo many ($SIPT) matching service instnaces for $SNAME.\nCan NOT determine PS to stop!\n" ;
			exit 2 ;
		else
			if ((${#SIP} != 0)) ; then
				aSPS=$(echo "$SIP" | cut -d. -f 2- | awk "{print \$1}") ;
				if [ -f /tmp/"$aSPS".txt ] ; then
					IFS=: read -a aVar < /tmp/"$aSPS".txt ;
					kill -9 "${aVar[0]}" 2>/dev/null ;
				fi ;
				if ((${#aSPS} != 0 )) ; then 
					if ((UID == 0)) ; then su -l $USER -s /bin/bash -c "screen -S $aSPS -X quit ; screen -wipe" ;
					else screen -S $aSPS -X quit ; fi ;
					((++PSDEL)) ;
				else
					echo -e "Not screen session found to stop." ;
				fi ;
			fi ;
		fi ;
	else # #// search for passed screen session_id or all
		if [[ ! $2 == "all"  ]] ; then
			SIP=$(screen -ls $USER/ | grep $SNAME | grep $2) ;
			SIPT=$(echo "$SIP" | wc -l) ;
			if ((${#SIP} == 0)) ; then
				echo "\nNO MATCH found for $SNAME with $2 key!\n" ; exit 2 ;
			else
				aSPS=$(echo "$SIP" | cut -d. -f 2- | awk "{print \$1}") ;
				if [ -f /tmp/$aSPS.txt ] ; then
					IFS=: read -a aVar < /tmp/"$aSPS".txt ;
					kill -9 "${aVar[0]}" 2>/dev/null;
				fi ;
				if ((${#SIP} != 0)) ; then
					aSPS=$(echo "$SIP" | awk -F" " "{print \$1}" | awk -F"." "{print \$2}") ;
					echo -e "$aSPS" | while read -r line ; do
						if ((UID == 0)) ; then su -l $USER -s /bin/bash -c "screen -S $line -X quit ; screen -wipe" ;
						else screen -S $line -X quit && screen -wipe ; fi ;
					done ;
				fi ;
			fi ;
		else
			for f in /tmp/$SNAME*.txt ; do
				if [ -f $f ] ; then
					IFS=: read -a aVar < "$f" ;
					echo -e "$SNAME - PID instannce: ${aVar[0]} - being deleted." ;
					rm -rf $f /tmp/$zPrefixSent\$f.txt /tmp/$zPrefixLast\$f.txt 2>/dev/null ;
					kill -9 "${aVar[0]}" 2>/dev/null;
					SIP=$(screen -ls $USER/ | grep $SNAME) ;
					SIPT=$(echo -e "$SIP" | wc -l) ;
					if ((${#SIPT} != 0)) && ((${#SIP} != 0)) ; then
						echo -e "$SIP" | while read -r line ; do
							aScreen=$(echo $line | awk -F" " "{print \$1}") ;
							if ((UID == 0)) ; then su -l $USER -s /bin/bash -c "screen -S $aScreen -X quit ; screen -wipe" ;
							else screen -S $aScreen -X quit ; fi ;
						done ;
					fi ;
					((++PSDEL)) ;
				 fi ;
			done ;
		fi ;
	fi ;
	if ((PSDEL==0)) ; then echo -e "\nERROR: $SNAME Lacks any known Sessions / PID.\n" ; exit 2 ;
	else echo -e "\nSuccesfully stopped: $SNAME on $PSDEL instances.\n" ; fi ;
 ;;
 update)
	echo -e "\nUpdating $SNAME -- git pulling ..." ;
	if ((UID == 0)) ; then su -l $USER -s /bin/bash -c "cd $APATH && git pull" ;
	else cd $APATH && git pull ; fi
	# #// $0 restart $2 ; # to auto-restart on update
 ;;
 status)
	running="$(screen -ls $USER/ | grep $SNAME)" ;
	if ((${#running}==0)) || [[ "$running" == *"No"* ]] ; then echo -e "\nNO Running $SNAME instance(s)!\n" ;
	else echo -e "\n$SNAME - SESSIONS:\n$running\n"; fi ;
 ;;
 restart)
	$0 stop $2 ;
	$0 start $2 ;
 ;;
 *) echo -e "\n$HELP" ;
 ;;
esac ;
exit 0 ;
