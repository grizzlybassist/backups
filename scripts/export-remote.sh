#!/bin/sh
SHELL=/bin/sh
PATH=/bin:/sbin:/usr/bin:/usr/sbin
localname=`hostname`
unraid="/mnt/unraid"
backups="$unraid/Cronjobs/backups"

now=$(date +"%Y-%m-%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")
backup="root@192.168.2.202"
vmback="/mnt/user/backups/vmback"
bulogs="$backups/logs"
mkdir -p $bulogs

exec 1>> $bulogs/export-$month.log
exec 2>> $bulogs/export-$month.log

config="$backups/config/$localname-xml.cfg"
echo "$(date) $localname xml export"

find_machines()
{
    machines=$(ssh root@$1 virsh list --all | tail -n +2 | awk '{print $2}')
	for s in ${machines}
	do
		export_xml $1 $s
	done
}

export_xml()
{
	ssh $backup "mkdir -p $vmback"
	ssh $backup "rm -f $vmback/$2.xml"
	ssh $backup "rm -f $vmback/$2.xml"
	ssh root@$1 "virsh dumpxml $2" | ssh $backup "cat > $vmback/$2.xml"
}

if [ $# -eq 2 ]
then
	export_xml $1 $2
elif [ $# -eq 1 ]
then
	find_machines $1
else
	find_machines 192.168.2.201
    find_machines 192.168.2.202
fi
