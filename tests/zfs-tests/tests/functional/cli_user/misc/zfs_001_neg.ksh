#!/bin/ksh -p
# SPDX-License-Identifier: CDDL-1.0
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
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# Copyright (c) 2013, 2016 by Delphix. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/cli_user/misc/misc.cfg

#
# DESCRIPTION:
#
# zfs shows a usage message when run as a user
#
# STRATEGY:
# 1. Run zfs as a user
# 2. Verify it produces a usage message
#

function cleanup
{
	rm -f "$TEMPFILE"
}

log_onexit cleanup
log_assert "zfs shows a usage message when run as a user"

TEMPFILE="$TEST_BASE_DIR/zfs_001_neg.$$.txt"

zfs > $TEMPFILE 2>&1
log_must grep "usage: zfs command args" "$TEMPFILE"

log_must awk 'length($0) > 80 {print; ++err} END {exit err}' $TEMPFILE

log_pass "zfs shows a usage message when run as a user"
