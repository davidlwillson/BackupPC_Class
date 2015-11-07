#!/bin/bash
#
# lvsnap Ver 0.7b
# Author: Tom Sightler 
#
# This script is primarily designed for taking a list of LVM volumes
# and automatically creating LVM snapshots and mounting them at the
# specified locations.  We use these to create LVM snapshot based
# chroot environments for rdiff-backup but there are of course plenty
# of other uses.  
#
# Versions of this script greather than 0.5 include the ability to mount
# portions of the chroot environment as simple bind mounts.  Bind mounts
# don't offer much security, but can be useful if you want to make complete
# chroot backups of the host when some of the volumes are not LVM (for example
# the /boot volume, which is usually a straight partition).  This was particularly
# useful for us because of older system where the OS volumes were installed
# on simple partitions rather than LVM.

# Location of the lvsnap configuration file
#LVSNAPTAB=/root/bin/lvsnaptab
LVSNAPTAB=$2

export PATH=/usr/bin:/bin:/usr/sbin:/sbin


# Function Definitions

# Loop through the LVs and create the snap LVs
# Returns failure if any snap fails
function createsnaps {
	ret=0
	for i in ${SNAPVOLSCOUNT}; do
		if [ ${MOUNTTYPE[$i]} == "snap" ]; then
			echo -n "Creating LVM snaphot of ${SNAPVOLS[$i]}..."
			if ! lvcreate -L ${SNAPSPACEPCT[$i]} -s -n ${SNAPNAME[$i]} ${SNAPVOLS[$i]} >/dev/null 2>&1; then
				echo -e $FAILURE
				echo lvcreate -L ${SNAPSPACEPCT[$i]} -s -n ${SNAPNAME[$i]} ${SNAPVOLS[$i]}
				ret=1
			else
				echo -e $SUCCESS
			fi
		fi
	done
	return $ret
}

# Loop through the LVs and delete the snap LVs
function destroysnaps {
	ret=0
	for i in ${SNAPVOLSCOUNT}; do
		# This causes volumes to be destroyed in reverse order of
		# their creation.  Not really important here, but done for
		# consistency with umounting since it can be important there.
		let "j = (${#SNAPVOLS[@]}-1) - i"
		if [ ${MOUNTTYPE[$j]} == "snap" ]; then
			echo -n "Removing LVM snapshot of ${SNAPVOLS[$j]}..."
			if ! lvremove -f ${SNAPVG[$j]}/${SNAPNAME[$j]} >/dev/null 2>&1; then
				echo -e $FAILURE
				ret=1
			else
				echo -e $SUCCESS
			fi
		fi
		sleep 1
	done
	return $ret
}

# Loop through the snap LV list and mount them
function mountsnaps {
	ret=0
        for i in ${SNAPVOLSCOUNT}; do
		if ! ismount ${SNAPMOUNTS[$i]}; then
			if [ ${MOUNTTYPE[$i]} == "snap" ]; then
				echo -n "Mounting snapshot volume ${SNAPVG[$i]}/${SNAPNAME[$i]} at ${SNAPMOUNTS[$i]}..."
				if ! mount ${SNAPVG[$i]}/${SNAPNAME[$i]} ${SNAPMOUNTS[$i]} >/dev/null 2>&1; then
					echo -e $FAILURE
					ret=1
				else
					echo -e $SUCCESS
				fi
			elif [ ${MOUNTTYPE[$i]} == "bind" ]; then
				echo -n "Creating bind mount for ${SNAPVOLS[$i]} at ${SNAPMOUNTS[$i]}..."
				if ! mount --bind ${SNAPVOLS[$i]} ${SNAPMOUNTS[$i]} >/dev/null 2>&1; then
					echo -e $FAILURE
					ret=1
				else
					echo -e $SUCCESS
				fi
			fi
		else
			echo -e "${SNAPMOUNTS[$i]} is already mounted...${COL_FAILURE}Failed${COL_NORMAL}"
		fi
        done
	return $ret
}

# Loop throught the snap LV list and unmount them
function umountsnaps {
	ret=0
        for i in ${SNAPVOLSCOUNT}; do
		# This causes the volumes to be mounted in reverse order
		# from the order they were mounted.  This is required if
		# some snaps are submounts of others.
		let "j = (${#SNAPVOLS[@]}-1) - i"
		if [ ${MOUNTTYPE[$j]} == "snap" ]; then
			echo -n "Unmounting snapshot volume ${SNAPVG[$j]}/${SNAPNAME[$j]} from ${SNAPMOUNTS[$j]}..."
			if ! umount ${SNAPMOUNTS[$j]} >/dev/null 2>&1; then
				echo -e $FAILURE
				ret=1
                	else
				echo -e $SUCCESS
			fi
		elif [ ${MOUNTTYPE[$j]} == "bind" ]; then
			echo -n "Unmounting bind mount from ${SNAPMOUNTS[$j]}..."
			if ! umount ${SNAPMOUNTS[$j]} >/dev/null 2>&1; then
				echo -e $FAILURE
				ret=1
			else
				echo -e $SUCCESS
			fi
		fi
        done
	return $ret
}

function ismount () {
	for m in `mount | cut -d' ' -f3`; do
   		if [ "$1" = "$m" ]; then
			return 0
		fi
	done
	return 1
}

# End of funtion definitions
# Start of code block 

# Initialize static values
# Default return value
RETVAL=0

if tty -s; then
        COL_SUCCESS="\\033[1;32m"
	COL_FAILURE="\\033[1;31m"
	COL_NORMAL="\\033[0;39m"
else
	COL_SUCCESS=""
	COL_FAILURE=""
	COL_NORMAL=""
fi

SUCCESS="${COL_SUCCESS}OK${COL_NORMAL}"
FAILURE="${COL_FAILURE}Failed${COL_NORMAL}"


# Read and parse config file
i=0
while read line; do
	# Remove comment lines
	parsedline=`echo $line | sed '/^ *#/d;s/#.*//'`
	# Only parse non-null lines
	if [ -n "$parsedline" ]; then
		SNAPVOLS[$i]=`echo $parsedline|awk '{print $1}'`
		SNAPMOUNTS[$i]=`echo $parsedline|awk '{print $2}'`
		SNAPFSTYPE[$i]=`echo $parsedline|awk '{print $3}'`
		MOUNTTYPE[$i]=`echo $parsedline|awk '{print $4}'`
		SNAPSPACEPCT[$i]=`echo $parsedline|awk '{print $5}'`
		let "i = i + 1"
	fi
done < ${LVSNAPTAB}

# Count the number of elements in the SNAPVOLS and SNAPMOUNTS arrays
SNAPVOLSCOUNT=$(seq 0 $((${#SNAPVOLS[@]} - 1)))
SNAPMOUNTSCOUNT=$(seq 0 $((${#SNAPMOUNTS[@]} - 1)))

# Make sure the number of volumes and number of mount points are equal
if [ "${SNAPVOLSCOUNT}" != "${SNAPMOUNTSCOUNT}" ]; then
        echo "The number of snap volumes and mount points must match"
        exit 1
fi

# Split the full device path into VG device path and LV name
# Create the snap name by adding "-snap" to LV name 
for i in ${SNAPVOLSCOUNT}; do
        SNAPVG[$i]=`dirname ${SNAPVOLS[$i]}`
        SNAPLV[$i]=`basename ${SNAPVOLS[$i]}`
        SNAPNAME[$i]=$3${SNAPLV[$i]}-snap
done

case "$1" in
        start)
		err=""
		if ! createsnaps; then
			err="${err}At least one snapshot failed to be created\n"
			RETVAL=2
		fi
		if ! mountsnaps; then
        		err="${err}At least one snapshot failed to mount\n"
			RETVAL=2
		fi
		;;
	stop)
		err=""
		if ! umountsnaps; then
			err="${err}At least one snapshot failed to unmount\n"
			RETVAL=2
		fi
		if ! destroysnaps; then
			err="${err}At least one snapshot failed to be destroyed\n"
			RETVAL=2
		fi
		;;
	*)
		echo $"Usage: $0 {start|stop}"
		RETVAL=1
esac

# IF RETVAL > 1 then print the errors
if [ $RETVAL -gt "1" ]; then
	echo -e "\n${COL_FAILURE}The following errors were reported:${COL_NORMAL}\n${err}"
fi

echo ""
exit $RETVAL

