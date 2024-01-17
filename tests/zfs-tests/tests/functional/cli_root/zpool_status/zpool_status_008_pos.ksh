#!/bin/ksh -p

#
# CDDL HEADER START
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
# CDDL HEADER END
#

#
# Copyright (c) 2024 by Lawrence Livermore National Security, LLC.
#

. $STF_SUITE/include/libtest.shlib

#
# DESCRIPTION:
# Verify 'zpool status -e' only shows unhealthy devices.
#
# STRATEGY:
# 1. Create zpool
# 2. Force DEGRADE vdev
# 3. Verify only the DEGRADED vdev and parents show
#

function mkvdev
{
	for vdev in {1..$children};do
		truncate -s $MINVDEVSIZE $TESTDIR/vdev$vdev
	done
}

function cleanup
{
	log_must zinject -c all
	datasetexists $TESTPOOL2 && log_must zpool destroy $TESTPOOL2
	rm -f $TESTDIR/vdev_a
}

log_assert "Verify 'zpool -e'"

for raid_type in "draid" "raidz1"; do

	parity=1
	data=4
	spare=1
	children=6

	if [[ "$raid_type" = "draid" ]]; then
		raidfmt="draid${parity}:${data}d:${children}c:${spare}s"
	else
		raidfmt="raidz${parity}"
	fi

	log_must mkdir -p $TESTDIR
	log_must eval mkvdev
	log_must eval "zpool create -f -m /$TESTPOOL2 $TESTPOOL2 $raidfmt " \
		"$TESTDIR/vdev1 $TESTDIR/vdev2 $TESTDIR/vdev3" \
		"$TESTDIR/vdev4 $TESTDIR/vdev5" "$TESTDIR/vdev6" 

	log_must check_vdev_state $TESTPOOL2 $TESTDIR/vdev4 "ONLINE"
	log_must zinject -d $TESTDIR/vdev4 -A degrade $TESTPOOL2
	log_must eval "zpool status $TESTPOOL2"
	log_must check_vdev_state $TESTPOOL2 $TESTDIR/vdev4 "DEGRADED"
	log_must eval "zpool status -e $TESTPOOL2"
	log_mustnot eval "zpool status -e $TESTPOOL2 | grep ONLINE"
	cleanup
done

log_pass "Verify zpool status -e shows only unhealthy vdevs"
