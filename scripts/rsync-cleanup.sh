#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
localname=`hostname`
unraid="/mnt/unraid"
working="$unraid/Cronjobs/backups"
rworking="/mnt/user/Cronjobs/backups"
host="root@192.168.2.201"
remote="root@192.168.2.202"
remdir="/mnt/user/Backups"
bremote="$remote:$remdir"
ropts="-ah  --delete -e ssh"

chour=$(date +"%H")
hour=$(date +"%Y-%m-%d.%H")
tday=$(date +"%d")
rday=$(date +"%d" -d "-3 days")
now=$(date +"%Y-%m-%d")
yday=$(date +"%Y-%m-%d" -d "-1 days")
RMday=$(date +"%Y-%m-%d" -d "-3 days")
RMdmonth=$(date +"%Y-%m-%d" -d "-3 months")
month=$(date +"%Y-%m")
RMmonth=$(date +"%Y-%m" -d "-3 months")
RMymonth=$(date +"%Y-%m" -d "-6 months")
year=$(date +"%Y")
RMyear=$(date +"%Y" -d "-6 months")
logs="$working/logs"
mkdir -p $logs

exec 1>> $logs/rsync-clean-$now.log
exec 2>> $logs/rsync-clean-$now.log

config="$working/config/$localname-rsync.cfg"
exclud="$working/config/$localname-rsync.excl"
includ="$working/config/$localname-rsync.incl"
yremove="$working/config/$localname-rsync-clean.rmv"
prevconfig="$working/config/previous.backup"
tdayconfig="$working/rsync/$now.backup"
ydayconfig="$working/rsync/$yday.backup"
RMdayconfig="$working/rsync/$RMday.backup"
echo "-----------------------------start------------------------------"
echo "$(date) $localname rsync cleanup"

clsync_yearly()
{
	echo "----------------------------------------------------------------"
	echo "Beginning rsync monthly cleanup at $(date)"
	count=48
	testmon=9999-99
	while [ "$testmon" != "$RMymonth" ] && [ $count -gt 0 ]
	do
		testmon=$(date +"%Y-%m" -d "$count months ago")
		testyear=$(date +"%Y" -d "$count months ago")
		testdir="$remdir/$2/$testmon"
		newdir="$remdir/$2/$testyear"
#		echo $count
#		echo "Checking for $testdir"
		if (ssh $remote "ls $testdir 1> /dev/null 2>&1")
		then
			echo "----------------------------------------------------------------"
			echo "Making $newdir on $remote"
			ssh $remote mkdir -p $newdir
			echo "Beginning copy of $testdir"
			ssh $remote cp -aul --no-dereference --force $testdir/* $newdir/
			cpcode=$?
			if [ ! $cpcode -eq 0 ]
			then
				echo "Copy did not complete with error $cpcode, leaving files for next attempt"
				rm /tmp/rsync-clean.pause
				echo "------------------------------done-----------------------------"
				exit $cpcode
			fi
			echo "Finished coping $testdir to $newdir with error code $cpcode"
			echo "Removing $testdir"
			ssh $remote rm -R $testdir
		fi
		count=$(( count - 1 ))
	done
}

clsync_monthly()
{
	echo "----------------------------------------------------------------"
	echo "Beginning rsync daily cleanup at $(date)"
	count=356
	testday=9999-99-99
	while [ "$testday" != "$RMdmonth" ] && [ $count -gt 0 ]
	do
		testday=$(date +"%Y-%m-%d" -d "$count days ago")
		testmon=$(date +"%Y-%m" -d "$count days ago")
		testdir="$remdir/$2/$testday"
		newdir="$remdir/$2/$testmon"
#		echo $count
#		echo "Checking for $testdir"
		if (ssh $remote "ls $testdir 1> /dev/null 2>&1")
		then
			echo "----------------------------------------------------------------"
			echo "Making $newdir on $remote"
			ssh $remote mkdir -p $newdir
			echo "Beginning copy of $testdir"
			ssh $remote cp -aul --no-dereference --force $testdir/* $newdir/
			cpcode=$?
			if [ ! $cpcode -eq 0 ]
			then
				echo "Copy did not complete with error $cpcode, leaving files for next attempt"
				rm /tmp/rsync-clean.pause
				echo "------------------------------done-----------------------------"
				exit $cpcode
			fi
			echo "Finished coping $testdir to $newdir with error code $cpcode"
			echo "Removing $testdir"
			ssh $remote rm -R $testdir
		fi
		count=$(( count - 1 ))
	done
}

clsync_daily()
{
	echo "----------------------------------------------------------------"
	echo "Beginning rsync hourly cleanup at $(date)"
	count=90
	testday=9999-99-99
	while [ "$testday" != "$RMday" ] && [ $count -gt 0 ]
	do
		testday=$(date +"%Y-%m-%d" -d "-$count days")
		testdir="$remdir/$2/$testday"
		echo $count
		echo "Checking for $testdir"
		if (ssh $remote "ls $testdir.* 1> /dev/null 2>&1")
		then
			echo "----------------------------------------------------------------"
			echo "Making $testdir on $remote"
			ssh $remote mkdir -p $testdir
			ssh $remote cp -aul --no-dereference --force $testdir.*/* $testdir/
			cpcode=$?
			if [ ! $cpcode -eq 0 ]
			then
				echo "Copy did not complete with error $cpcode, leaving files for next attempt"
				rm /tmp/rsync-clean.pause
				echo "------------------------------done------------------------------"
				exit $cpcode
			fi
			echo "Finished copy with error $cpcode, removing hourly"
			ssh $remote rm -R $testdir.*
		fi
		count=$(( count - 1 ))
	done
}

if [ -f /tmp/rsync-clean.pause ]
then
	echo "Cleanup in progress"
	echo "------------------------------done------------------------------"
	exit 0
fi

touch /tmp/rsync-clean.pause

sourc=`cat $config | awk '{print $1}' | tr "\n" " "`
for s in ${sourc}
do
	folde=`grep $s $config | awk '{print $2}'`
	clsync_daily $s $folde
	clsync_monthly $s $folde
	clsync_yearly $s $folde
done

rm /tmp/rsync-clean.pause

echo "------------------------------done------------------------------"
