#!/bin/ksh
# SPDX-License-Identifier: CDDL-1.0

#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# https://opensource.org/license/CDDL-1.0.
#

#
# Copyright (c) 2026 George Melikov
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/rsend/rsend.kshlib

#
# Description:
# Verify incremental receive handles a FREEOBJECTS record that starts on an
# interior slot of a multi-slot dnode the same stream freed just before.
#
# When a multi-slot dnode is freed on the sender and a smaller one is later
# allocated on one of its interior slots, the stream frees the leading
# slots, claims the new object and then frees the trailing slots as three
# separate records.  The receiver frees the whole dnode on the first one,
# but its interior slots stay marked as such until that free syncs, so the
# claim is deferred and the trailing FREEOBJECTS lands on an interior slot.
#
# Strategy:
# 1. Create two adjacent files with 4k dnodes and send the full stream
# 2. Free the first dnode, place one legacy dnode on its first interior slot
#    and leave the remaining interior slots free
# 3. Verify the incremental stream has the intended record sequence, can be
#    received and produces the same contents as the source
#

verify_runnable "both"

log_assert "Verify incremental receive handles frees over an interior slot"

function cleanup
{
	rm -f $BACKDIR/fs-full
	rm -f $BACKDIR/fs-incr
	rm -f $BACKDIR/fs-incr.dump

	datasetexists $POOL/fs && destroy_dataset $POOL/fs -rR
	datasetexists $POOL/newfs && destroy_dataset $POOL/newfs -rR
}

log_onexit cleanup

# 1. Create files with 4k dnodes and send the full stream
log_must zfs create -o dnodesize=4k -o xattr=sa $POOL/fs

log_must touch /$POOL/fs/old.{0,1}
log_must sync_pool $POOL
typeset -ri old_slots=8
typeset -i freed=$(get_objnum /$POOL/fs/old.0)

log_must zfs snapshot $POOL/fs@a
log_must eval "zfs send $POOL/fs@a > $BACKDIR/fs-full"
log_must eval "zfs recv $POOL/newfs < $BACKDIR/fs-full"

# 2. Put one legacy dnode on the first interior slot of old.0
log_must zfs set dnodesize=legacy $POOL/fs
log_must rm /$POOL/fs/old.0
log_must sync_pool $POOL

#
# Object allocation continues from where it left off for as long as the
# objset stays open, so reopen it to make it start over from the lowest free
# slot.  Create both files in one process so that they receive adjacent object
# IDs, then remove the one at the head of the freed dnode.  This leaves one
# object on an interior slot and the later interior slots free.
#
log_must zpool export $POOL
log_must zpool import $POOL
log_must touch /$POOL/fs/new.{0,1}
log_must sync_pool $POOL

typeset -i head=$(get_objnum /$POOL/fs/new.0)
typeset -i inside=$(get_objnum /$POOL/fs/new.1)
typeset -i trailing
(( trailing = freed + old_slots - inside - 1 ))
(( head == freed )) || log_fail "Expected object $freed, got $head"
(( inside > freed && inside < freed + old_slots )) || \
	log_fail "Object $inside is not inside dnode $freed"
log_must rm /$POOL/fs/new.0
log_must sync_pool $POOL

log_must zfs snapshot $POOL/fs@b

# 3. Verify the incremental stream can be received and the result matches
#    the source
log_must eval "zfs send -i $POOL/fs@a $POOL/fs@b > $BACKDIR/fs-incr"
log_must eval "zstream dump -v < $BACKDIR/fs-incr > $BACKDIR/fs-incr.dump"
log_must grep -q \
	"^FREEOBJECTS firstobj = $freed numobjs = $((inside - freed))\$" \
	$BACKDIR/fs-incr.dump
log_must grep -q "^OBJECT object = $inside .* dn_slots = 1 " \
	$BACKDIR/fs-incr.dump
log_must grep -q \
	"^FREEOBJECTS firstobj = $((inside + 1)) numobjs = $trailing\$" \
	$BACKDIR/fs-incr.dump
log_must eval "zfs recv $POOL/newfs < $BACKDIR/fs-incr"

log_must directory_diff /$POOL/fs /$POOL/newfs

log_pass "Verify incremental receive handles frees over an interior slot"
