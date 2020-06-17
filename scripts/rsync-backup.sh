#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
localname=`hostname`
unraid="/mnt/unraid"
working="$unraid/Cronjobs/backups"
rworking="/mnt/user/Cronjobs/backups"
host="root@192.168.2.201"
remote="root@192.168.2.202"
remdir="/mnt/user/backups"
bremote="$remote:$remdir"
ropts="--exclude-from=$rworking/config/$localname-rsync-sync.excl --exclude=*.AppleDB* -aH --delete -e ssh"

chour=$(date +"%H")
hour=$(date +"%Y-%m-%d.%H")
tday=$(date +"%d")
rday=$(date +"%d" -d "-8 days")
now=$(date +"%Y-%m-%d")
yday=$(date +"%Y-%m-%d" -d "-1 days")
RMday=$(date +"%Y-%m-%d" -d "-8 days")
RMdate=$(date +"%Y-%m-%d" -d "-4 months")
month=$(date +"%Y-%m")
RMmonth=$(date +"%Y-%m" -d "-4 months")
RMymonth=$(date +"%Y-%m" -d "last year")
year=$(date +"%Y")
RMyear=$(date +"%Y" -d "last year")
logs="$unraid/Cronjobs/logs/backups"
mkdir -p $logs

exec 1>> $logs/rsync-$now.log
exec 2>> $logs/rsync-$now.log

config="$working/config/$localname-rsync.cfg"
exclud="config/$localname-rsync.excl"
includ="config/$localname-rsync.incl"
prevconfig="$working/config/previous.backup"
tdayconfig="$working/rsync/$now.backup"
ydayconfig="$working/rsync/$yday.backup"
RMdayconfig="$working/rsync/$RMday.backup"
echo "-----------------------------start------------------------------"
echo "$(date) $localname rsync backup"

clean_backup_old()
{
	if test -e $RMdayconfig && test -s $RMdayconfig
	then
		bdaily=`cat $RMdayconfig`
		bdaily="$remdir/$2/$bdaily"
		bndaily="$remdir/$2/$RMday"
		if (ssh $remote "[ -d $bdaily ]")
		then
			ssh $remote mv $bdaily $bndaily
			ssh $remote rm -R $bndaily.*
		fi
		if (ssh $remote "[ -d $bndaily ]")
		then
			rm $RMdayconfig
		fi
	fi

	bmonthly="$remdir/$2/$RMdate"
	bnmonthly="$remdir/$2/$RMmonth"
	if (ssh $remote "[ -d $bmonthly ]")
	then
		ssh $remote mv $bmonthly $bnmonthly
		ssh $remote rm -R $bnmonthly-*
	fi

	byearly="$remdir/$2/$RMymonth"
	bnyearly="$remdir/$2/$RMyear"
	if (ssh $remote "[ -d $byearly ]")
	then
		echo soon
	fi
}
clean_backup()
{
	count=256
	testday=9999-99-99
	while [ $testday != $RMday ]
	do
		testday=$(date +"%Y-%m-%d" -d "$count days ago")
		testdir="$remdir/$2/$testday"
		if (ssh $remote "[ -d $testdir.* ]")
		then
			#ssh $remote mkdir $testdir
			echo "ssh $remote cp -aul --no-dereference --force $testdir.*/* $testdir/"
			#ssh $remote rm -R $testdir.*
		fi
		echo $testday
		count=$(( count - 1 ))
	done
}

rsync_incremental()
{
	echo "-----Creating incremental backup of $1"
	echo "to $bremote/$2/$hour"

	if test -e $working/$3
	then
		echo "-----excluding the following folders:"
		echo `cat $working/$3`
		ropts2="--exclude-from=$rworking/$3"
	fi

	if [ -f $prevconfig ]
	then
		prebackup=`cat $prevconfig`
#		ropts3="--link-dest=../$prebackup"
        ropts3="--link-dest=../current"
	fi
	
	echo "----------------------------------------------------------------"
	
#	if (ssh $remote "[ -d $remdir/$2/$prebackup ]") && [ -f $prevconfig ]
	if (ssh $remote "[ -d $remdir/$2/current ]") && [ -f $prevconfig ]
	then
#		ssh $host "rsync $ropts $ropts2 $ropts3 $1 $bremote/$2/$hour"
		ssh $host "rsync $ropts $ropts2 $ropts3 $1 $bremote/$2/temp"
		rcode=$?
		if [ $rcode -eq 0 ] || [ $rcode -eq 24 ]
		then
			if (ssh $remote "[ -d $remdir/$2/$prebackup ]"); then ssh $remote "rm -rf $remdir/$2/$prebacku"; fi
			ssh $remote "mv $remdir/$2/current $remdir/$2/$prebackup"
			ssh $remote "mv $remdir/$2/temp $remdir/$2/current"
			echo "Rsync completed at $(date) with code of $rcode"
			if [ -f $prevconfig ]; then rm $prevconfig; fi
			echo $hour > $prevconfig
		else
			echo "Rsync failed with code # $rcode at $(date)"
			echo "REVERTING CHANGES"
#			ssh $remote rm -R $remdir/$2/$hour
			ssh $remote rm -R $remdir/$2/temp
			rm /tmp/rsync.pause

			echo "------------------------------done------------------------------"
			mkdir -p $unraid/Errors
			mv $logs/rsync-$now.log $unraid/Errors/rsync-$hour.log
			exit $rcode
		fi
    elif [ ! -f $prevconfig ]
    then
        ssh $remote "mkdir -p $remdir/$2"
#	ssh $host "rsync $ropts $ropts2 $1 $bremote/$2/$hour"
        ssh $host "rsync $ropts $ropts2 $1 $bremote/$2/current"
	rcode=$?
	if [ $rcode -eq 0 ] || [ $rcode -eq 24 ]
	then
		echo "Rsync completed at $(date) with code of $rcode"
		if [ -f $prevconfig ]; then rm $prevconfig; fi
			echo $hour > $prevconfig
		else
			echo "Rsync failed with code # $rcode at $(date)"
			echo "REVERTING CHANGES"
			ssh $remote rm -R $remdir/$2/$hour
			rm /tmp/rsync.pause

			echo "------------------------------done------------------------------"
			mkdir -p $unraid/Errors
			mv $logs/rsync-$now.log $unraid/Errors/rsync-$hour.log
			exit $rcode
		fi
    else
        echo "Rsync failed at $(date)"
        echo "------------------------------done------------------------------"
		mkdir -p $unraid/Errors
		mv $logs/rsync-$now.log $unraid/Errors/rsync-$hour.log
		exit $rcode
	fi

	#rsnaptotal=$(ssh root@192.168.2.202 "du -cs /mnt/disk*/backups/KILE-NAS1/$prebackup /mnt/disk*/Backups/KILE-NAS1/$hour" | awk -v hour="$hour" '$0 ~ current {sum += $1} END {print sum}' | numfmt --to=iec-i --from-unit=1024 --suffix=B --padding=4)
	rsnaptotal=$(ssh $remote "du -cs /mnt/disk*/backups/$2/$prebackup /mnt/disk*/Backups/$2/current" | awk -v hour="current" '$0 ~ hour {sum += $1} END {print sum}' | numfmt --to=iec-i --from-unit=1024 --suffix=B --padding=4)
	echo "Snapshot $hour has total size of:"
	echo "$rsnaptotal"
	
#	if [ -f $ydayconfig ]
	if (ssh $remote "[ -d $remdir/$2/$yday.$chour]")
	then
#		ydaybackup=`cat $ydayconfig`
		#dailytotal=$(ssh root@192.168.2.202 "du -cs /mnt/disk*/backups/KILE-NAS1/$ydaybackup /mnt/disk*/KILE-NAS1/$hour" | awk -v hour="$hour" '$0 ~ hour {sum += $1} END {print sum}' | numfmt --to=iec-i --from-unit=1024 --suffix=B --padding=4)
		dailytotal=$(ssh $remote "du -cs /mnt/disk*/backups/$2/$yday.$chour /mnt/disk*/Backups/$2/current" | awk -v hour="current" '$0 ~ hour {sum += $1} END {print sum}' | numfmt --to=iec-i --from-unit=1024 --suffix=B --padding=4)
		echo "Total storage of $now is:"
		echo "$dailytotal"
	fi

#	if (ssh $remote "[ -d $remdir/$2/$hour ]")
#	then
#		if [ -f $prevconfig ]; then rm $prevconfig; fi
#		echo $hour > $prevconfig
#	fi

}

rsync_sync()
{	
	if test -e $working/$3 && test -s $working/$3
	then
		echo "----------------------------------------------------------------"
		echo "-----Synchronizing the following folders"
		echo `cat $working/$3`
		echo "-----from $1 to $bremote/$2/sync"

		sync=`cat $working/$3 | awk '{print $1}' | tr "\n" " "`
		for s in ${sync}
		do
			echo "----------------------------------------------------------------"
			ssh $host  "rsync $ropts  /mnt/user/$s $bremote/$2/sync"
			echo "Rsync completed on $s at $(date) with code of $?"
		done
	fi
}

if [ $# -ge 2 ]
then
	rsync_incremental $1 $2 $3
else
	if [ -f /tmp/rsync.pause ]
	then
		echo "Sync in progress"
		echo "------------------------------done------------------------------"
		exit 0
	fi
	
	touch /tmp/rsync.pause
	incre=`cat $config | awk '{print $1}' | tr "\n" " "`
	for i in ${incre}
	do
		destin=`grep $i $config | awk '{print $2}'`
		rsync_incremental $i $destin $exclud
		rsync_sync $i $destin $includ
	done
	rm /tmp/rsync.pause
fi

echo "------------------------------done------------------------------"
