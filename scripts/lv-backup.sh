#!/bin/bash
localname=`hostname`
vmstor="/vm-ovfs"
config="$vmstor/scripts/$localname.cfg"
now=$(date +"%Y-%m-%d")
month=$(date +"%Y-%m")
year=$(date +"%Y")
exec 1>> $vmstor/logs/sys-$month.rtf
exec 2>> $vmstor/logs/sys-$month.rtf
echo "$(date) $localname $1"

mk_lvolume()
{
	
}

mk_image()
{
	exec 1>> $vmstor/logs/$1-$month.rtf
	exec 2>> $vmstor/logs/$1-$month.rtf
	echo "$(date) $1"
	mkdir -p $vmstor/$1

	vmfile="/dev/$3-$2/$1"
	ifile="/dev/$3-$2/$1_snapshot"
	ofile="$vmstor/$1/$1.gz"
	sig="$vmstor/$1/$1.sig"
	md5="$vmstor/$1/$1_md5.rtf"

	count=1
	del="$vmstor/$1/$1_$count.del"
	while [ -f $del ]; do
		count=$(( $count + 1 ))
		del="$vmstor/$1/$1_$count.del"
	done
	
	echo "Creating snapshot at $(date)"
	lvcreate -s -n $1_snapshot -L 4GB $vmfile
	
	echo "$(date)" >> $md5
	md5sum $ifile >> $md5
	if [ -f $ofile ] && [ -f $sig ];
	then
		echo "Making $1 delta at $(date)"
		rdiff delta $sig $ifile $del
		rdiff signature $ifile $sig
	else
		echo "Making $1 signature at $(date)"
		rdiff signature $ifile $sig
		echo "Making $1 image at $(date)"
		dd if=$ifile | gzip -c | dd of=$ofile
	fi

	sh $vmstor/scripts/export.sh $1
	
	echo "Removing snapshot."
	lvremove -f $ifile
	echo "Finishing $1 at $(date)"
}

vms=`cat $config | awk '{print $1}' | tr "\n" " "`
for s in ${vms}
do
	vg=`grep $s $config | awk '{print $2}'`
	mk_image $s $vg $localname
done