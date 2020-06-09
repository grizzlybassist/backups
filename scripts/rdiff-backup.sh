#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
localname=`hostname`
unraid="/mnt/unraid"
backups="$unraid/Cronjobs/backups"
rsource="/mnt/unraid"
rdestin="/mnt/unraid2/KILE-NAS1"

now=$(date +"%Y-%m-%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")
bulogs="$backups/logs"
mkdir -p $bulogs

exec 1>> $bulogs/sys-$month.log
exec 2>> $bulogs/sys-$month.error.log

config="$backups/config/$localname-rdiff.cfg"
echo "$(date) $localname rdiff-backup"

archive_share()
{
#	rdiff-backup --force --remove-older-than $2 $rdestin/$1
	
	rdiff-backup --no-hard-links $rsource/$1 $rdestin/$1
}

if [ $# -ge 2 ]
then
	archive_share $1 $2
else
	shr=`cat $config | awk '{print $1}' | tr "\n" " "`
	for s in ${shr}
	do
		time=`grep $s $config | awk '{print $2}'`
		archive_share $s $arch $time
	done
fi
