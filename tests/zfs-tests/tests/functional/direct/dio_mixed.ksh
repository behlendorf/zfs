#!/bin/ksh -p
#
# DDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
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
# Copyright (c) 2021 by Lawrence Livermore National Security, LLC.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/include/properties.shlib
. $STF_SUITE/tests/functional/direct/dio.cfg
. $STF_SUITE/tests/functional/direct/dio.kshlib

#
# DESCRIPTION:
# 	Verify mixed buffered and direct IO are cohearant.
#
# STRATEGY:
#	1. Verify interleaved buffered and direct IO
#

verify_runnable "global"

function cleanup
{
	log_must rm -f $src_file $new_file $tmp_file
}

log_assert "Verify mixed buffered and direct IO are cohearant."

log_onexit cleanup

mntpnt=$(get_prop mountpoint $TESTPOOL/$TESTFS)

src_file=$mntpnt/src_file
new_file=$mntpnt/new_file
tmp_file=$mntpnt/tmp_file
page_size=$(getconf PAGESIZE)
file_size=1048576

log_must dd if=/dev/urandom of=$src_file bs=$file_size count=1

#
# Using mixed input and output block sizes verify that buffered and
# direct IO can be interleaved and the result with always be cohearant.
#
for ibs in "512" "$page_size" "131072"; do
	for obs in "512" "$page_size" "131072"; do
		iblocks=$(($file_size / $ibs))
		oblocks=$(($file_size / $obs))
		iflags=""
		oflags=""

		# Only allow direct IO when it is at least page sized.
		if [[ $ibs -ge $page_size ]]; then
			iflags="iflag=direct"
		fi

		if [[ $obs -ge $page_size ]]; then
			oflags="oflag=direct"
		fi

		# Verify buffered write followed by a direct read.
		log_must dd if=$src_file of=$new_file bs=$obs count=$oblocks
		log_must dd if=$new_file of=$tmp_file bs=$ibs count=$iblocks \
		    $iflags
		log_must cmp_md5s $new_file $tmp_file
		log_must rm -f $new_file $tmp_file

		# Verify direct write followed by a buffered read.
		log_must dd if=$src_file of=$new_file bs=$obs count=$oblocks \
		    $oflags
		log_must dd if=$new_file of=$tmp_file bs=$ibs count=$iblocks
		log_must cmp_md5s $new_file $tmp_file
		log_must rm -f $new_file $tmp_file

		# Verify direct write followed by a direct read.
		log_must dd if=$src_file of=$new_file bs=$obs count=$oblocks \
		    $oflags
		log_must dd if=$new_file of=$tmp_file bs=$ibs count=$iblocks \
		    $iflags
		log_must cmp_md5s $new_file $tmp_file
		log_must rm -f $new_file $tmp_file
	done
done

log_pass "Verify mixed buffered and direct IO are cohearant."
