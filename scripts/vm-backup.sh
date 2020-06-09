#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
localname=`hostname`
unraid="/mnt/unraid"
backups="$unraid/Cronjobs/backups"

now=$(date +"%Y-%m-%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")

vmback="/mnt/vmback/$year"
bulogs="$backups/logs"
vmlogs="$vmback/logs"

mkdir -p $vmback
mkdir -p $bulogs
mkdir -p $vmlogs

exec 1>> $bulogs/sys-$month.log
exec 2>> $bulogs/sys-$month.log

config="$backups/config/$localname-backup.cfg"
echo "$(date) $localname vm backup"

vm_shutdown()
{
	echo "Shutting down $1 at $(date)"
	ssh root@192.168.2.201 virsh shutdown $1

	try=1
	while [ $try -lt 60 ]; do
		try=$(( $try + 1 ))
		test=`ssh root@192.168.2.201 virsh domstate $1`
		test "$test" = "shut off" && break
		sleep 5
	done

	trys=1
	while [ $trys -lt 60 ]; do
		trys=$(( $trys + 1 ))
		test=`ssh root@192.168.2.201 virsh domstate $1`
		test "$test" = "shut off" && break
		test "$test" = "paused" && break
		test "$test" = "running" && ssh root@192.168.2.201 virsh suspend $1
		sleep 5
	done

	sleep 10
}

vm_startup()
{
	echo "Starting $1 at $(date)"
	while [ $try -lt 60 ]; do
		try=$(( $try + 1 ))
		test=`ssh root@192.168.2.201 virsh domstate $1`
		test "$test" = "running" && break
		test "$test" = "paused" && ssh root@192.168.2.201 virsh resume $1
		test "$test" = "shut off" && ssh root@192.168.2.201 virsh start $1
		sleep 5
	done
}

mk_backup()
{
	exec 1>> $vmlogs/$1-$month.log
	exec 2>> $vmlogs/$1-$month.log
	echo "$(date) $1"
	mkdir -p $vmback/$1
	
	ifile="$2"
	ofile="$vmback/$1/$1.img.gz"
	sig="$vmback/$1/$1.sig"
	md5="$vmback/$1/$1_md5.rtf"

	count=1
	del="$vmback/$1/$1_$count.del.gz"
	while [ -f $del ]; do
		count=$(( $count + 1 ))
		del="$vmback/$1/$1_$count.del.gz"
	done
	
	if [ "$3" = "reboot" ]; then vm_shutdown $1; fi
	ssh root@192.168.2.201 virsh dumpxml $1 | cat > $vmback/$1/$1.xml

	echo "$(date)" >> $md5
	md5sum $ifile >> $md5
	if [ -f $ofile ] && [ -f $sig ];
	then
		echo "Making $1 delta at $(date)"
		rdiff delta $sig $ifile - | gzip > $del
	#	rdiff signature $ifile $sig
	else
		echo "Making $1 signature at $(date)"
		rdiff signature $ifile $sig
		echo "Making $1 image at $(date)"
		dd if=$ifile | gzip -c | dd of=$ofile
	fi

	#sh $backups/scripts/export.sh $1
	
	echo "Finishing $1 at $(date)"
	if [ "$3" = "reboot" ]; then vm_startup $1; fi
	#rm $ifile
}

if mountpoint -q /mnt/vmback
then
	set mounted=yes
else
	mount /mnt/vmback
	if mountpoint -q /mnt/vmback; then set mounted=yes; fi
fi

if [ $# -ge 3 ]
then
	mk_backup $1 $2 $3
elif [ $# -eq 0 ] && [ $mounted == yes ]
then
	vms=`cat $config | awk '{print $1}' | tr "\n" " "`
	for s in ${vms}
	do
		stor=`grep $s $config | awk '{print $2}'`
		boot=`grep $s $config | awk '{print $3}'`
		mk_backup $s $stor $boot
	done
fi
