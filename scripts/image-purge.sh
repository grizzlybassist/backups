#!/bin/bash
localname=`hostname`
vmstor="/mnt/backups/virtual"
archive="/mnt/archives/Archive-VM-OVFs"
config="$vmstor/scripts/$localname.cfg"
now=$(date +"%Y-%m-%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")
exec 1>> $vmstor/logs/sys-$month.rtf
exec 2>> $vmstor/logs/sys-$month.rtf
echo "Checking backup sizes $(date)"

auto_clean()
{
	sizeof=`du -s $vmstor/$1 | awk '{print $1}'`
	if [ $sizeof -gt 20000000 ];
	then
		cl_backups $1 $2 $3
	fi
}
cl_backups()
{
	mkdir $archive
	ifile="$vmstor/$1/$1.gz"
	ofile="$archive/$1_$now.tar"

	cd $vmstor/$1
	tar -cvf $ofile * --remove-files
#	rm -r "$vmstor/$1"
}
discard_ssd()
{
	lvcreate -l100%FREE -n trim $1
	blkdiscard /dev/$1/trim
	lvremove $1/trim
}

trim_ssd()
{
	fstrim -va
}

mount -a

if [ $# -eq 1 ]
then
	cl_backups $1 $2 $3
else
	vms=`cat $config | awk '{print $1}' | tr "\n" " "`
	for s in ${vms}
	do
		vg=`grep $s $config | awk '{print $2}'`
		auto_clean $s $vg $localname
	done
#	auto_clean kile-win8 ssd1 kile-vms1
fi

trim_ssd
