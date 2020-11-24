#!/bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or https://opensource.org/licenses/CDDL-1.0.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright (c) 2022 by Triad National Security, LLC.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/direct/dio.cfg
. $STF_SUITE/tests/functional/direct/dio.kshlib

#
# DESCRIPTION:
# 	Verify checksum verify works for Direct I/O writes.
#
# STRATEGY:
#	1. Set the module parameter zfs_vdev_direct_write_verify_cnt to 100.
#	2. Check that manipulating the user buffer while Direct I/O writes are
#	   taking place does not cause any panics with compression turned on.
#	3. Start a Direct IO write workload while manipulating the user buffer
#	   without compression.
#	4. Verify there are Direct I/O write verify failures using
#	   zpool status -d and checking for zevents. We also make sure there
#	   are reported data errors when reading the file back.
#	5. Repeat steps 3 and 4 for 3 iterations.
#	6. Set zfs_vdev_direct_write_verify_cnt set to 1 and repeat 3.
#	7. Verify there are Direct I/O write verify failures using
#	   zpool status -d and checking for zevents. We also make sure there
#	   there are no reported data errors when reading the file back because
#	   with us checking every Direct I/O write and on checksum validation
#	   failure those writes will not be committed to a VDEV.
#	8. Repeat step 6 for for 3 iterations.
#

verify_runnable "global"

function cleanup
{
	# Clearing out DIO counts for Zpool
	log_must zpool clear $TESTPOOL
	# Clearing out dio_verify from event logs
	log_must zpool events -c
	log_must set_tunable32 VDEV_DIRECT_WR_VERIFY_CNT 100
}

log_assert "Verify checksum verify works for Direct I/O writes."

if is_freebsd; then
	log_unsupported "FeeBSD is capable of stable pages for O_DIRECT writes"
fi

log_onexit cleanup

ITERATIONS=3
NUMBLOCKS=8
mntpnt=$(get_prop mountpoint $TESTPOOL/$TESTFS)

# Get a list of vdevs in our pool
set -A array $(get_disklist_fullpath $TESTPOOL)

# Get the first vdev
firstvdev=${array[0]}

log_must zfs set recordsize=128k $TESTPOOL/$TESTFS
log_must set_tunable32 VDEV_DIRECT_WR_VERIFY_CNT 100

# First we will verify there are no panics while manipulating the contents of
# the user buffer during Direct I/O writes with compression. The contents
# will always be copied out of the ABD and there should never be any ABD ASSERT
# failures
log_note "Verifying no panics for Direct I/O writes with compression"
log_must zfs set compression=on $TESTPOOL/$TESTFS
prev_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
log_must manipulate_user_buffer -o "$mntpnt/direct-write.iso" -r 5
curr_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
log_must [ $curr_dio_wr -gt $prev_dio_wr ]
log_must rm -f "$mntpnt/direct-write.iso"


# Next we will verify there are checksum errors for Direct I/O writes while
# manipulating the contents of the user pages.
log_must zfs set compression=off $TESTPOOL/$TESTFS

for i in $(seq 1 $ITERATIONS); do
	log_note "Verifying every 100th Direct I/O write checksum iteration \
	    $i of $ITERATIONS"

	# Clearing out DIO counts for Zpool
	log_must zpool clear $TESTPOOL
	# Clearing out dio_verify from event logs
	log_must zpool events -c

	prev_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
	log_must manipulate_user_buffer -o "$mntpnt/direct-write.iso" -r 5 \
	    -n $NUMBLOCKS -v
	log_mustnot dd if=$mntpnt/direct-write.iso of=/dev/null bs=128k \
	    count=$NUMBLOCKS

	# Getting new Direct I/O write count, Direct I/O write checksum verify
	# errors and zevents.
	curr_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
	DIO_VERIFIES=$(zpool status -dp | awk -v d="raidz" '$0 ~ d {print $6}')
	DIO_VERIFY_EVENTS=$(zpool events | grep -c dio_verify)

	log_must [ $DIO_VERIFIES -gt 0 ]
	log_must [ $DIO_VERIFY_EVENTS -gt 0 ]
	log_must [ $curr_dio_wr -gt $prev_dio_wr ]

	# Verifying there are checksum errors
	cksum=$(zpool status -P -v $TESTPOOL | awk -v v="$firstvdev" '$0 ~ v \
	    {print $5}')
	log_must [ $cksum -ne 0 ]

	log_must rm -f "$mntpnt/direct-write.iso"
done

# Finally we will verfiy that with checking every Direct I/O write we have no
# errors at all.
log_must set_tunable32 VDEV_DIRECT_WR_VERIFY_CNT 1

for i in $(seq 1 $ITERATIONS); do
	log_note "Verifying every Direct I/O write checksums iteration $i of \
	    $ITERATIONS"

	# Clearing out DIO counts for Zpool
	log_must zpool clear $TESTPOOL
	# Clearing out dio_verify from event logs
	log_must zpool events -c

	prev_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
	log_must manipulate_user_buffer -o "$mntpnt/direct-write.iso" -r 5 \
	    -n $NUMBLOCKS -v
	log_must dd if=$mntpnt/direct-write.iso of=/dev/null bs=128k \
	    count=$NUMBLOCKS

	# Getting new Direct I/O write count, Direct I/O write checksum verify
	# errors and zevents.
	curr_dio_wr=$(get_iostats_stat $TESTPOOL direct_write_count)
	DIO_VERIFIES=$(zpool status -dp | awk -v d="raidz" '$0 ~ d {print $6}')
	DIO_VERIFY_EVENTS=$(zpool events | grep -c dio_verify)

	log_must [ $DIO_VERIFIES -gt 0 ]
	log_must [ $DIO_VERIFY_EVENTS -gt 0 ]
	log_must [ $curr_dio_wr -gt $prev_dio_wr ]

	log_must check_pool_status $TESTPOOL "errors" "No known data errors"
	log_must rm -f "$mntpnt/direct-write.iso"
done

log_pass "Verified checksum verify works for Direct I/O writes." 
