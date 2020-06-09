#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
localname=`hostname`
unraid="/mnt/unraid"
working="$unraid/Cronjobs/backups"

now=$(date +"%Y-%m-%d")
day=$(date +"%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")
logs="$working/logs"
mkdir -p $logs

imgback="/mnt/unraid/Backups/imgback"

#exec 1>> $logs/img-$month.log
#exec 2>> $logs/img-$month.log

config="$backups/config/$localname-img.cfg"
echo "-----------------------------start------------------------------"
echo "$(date) $localname image backup"

mk_backup()
{
	echo "Starting image of $2 with name $1 at $(date)"
	mkdir -p $imgback/$1
	
	ifile="$2"
	ofile="$imgback/$1/$1.img.gz"
	sig="$imgback/$1/$1.sig"
	md5="$imgback/$1/$1_md5.log"

	count=1
	del="$imgback/$1/$1_$count.del.gz"
	while [ -f $del ]; do
		count=$(( $count + 1 ))
		del="$imgback/$1/$1_$count.del.gz"
	done

	echo "$(date)" >> $md5
	echo "Adding md5sum of $ifile on $(date) at $md5"
	md5sum $ifile >> $md5
	if [ -f $ofile ] && [ -f $sig ];
	then
		echo "Making $1 delta of $2 at $(date)"
		rdiff delta $sig $ifile - | gzip > $del
	#	rdiff signature $ifile $sig
	else
		echo "Making $1 signature of $ifile at $(date)"
		rdiff signature $ifile $sig
		echo "Making $1 image of $ifile at $(date)"
		dd if=$ifile | gzip -c | dd of=$ofile
	fi
	
	echo "Finishing $1 at $(date)"
}

if [ $# -ge 2 ]&& [ ! -f /tmp/$1-imgbackup.pause ]
then
	touch /tmp/$1-imgbackup.pause
	mk_backup $1 $2
	rm /tmp/$1-imgbackup.pause
elif [ $# -eq 0 ] && [ ! -f /tmp/imgback.pause ]
then
	touch /tmp/imgback.pause
	vms=`cat $config | awk '{print $1}' | tr "\n" " "`
	for s in ${vms}
	do
		sname=`grep $s $config | awk '{print $2}'`
		mk_backup $s $sname
	done
	rm /tmp/imgback.pause
fi
echo "------------------------------done------------------------------"
