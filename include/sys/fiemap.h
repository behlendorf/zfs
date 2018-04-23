/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */
/*
 * Copyright (c) 2018, Lawrence Livermore National Security, LLC.
 */

#ifndef	_SYS_FIEMAP_H
#define	_SYS_FIEMAP_H

#include <sys/spa.h>		/* for SPA_DVAS_PER_BP */
#include <sys/avl.h>
#include <sys/range_tree.h>

/*
 * Generic supported flags.  The FIEMAP_FLAG_COPIES and FIEMAP_FLAG_NOMERGE
 * are excluded from compatibility check until they are provided by a
 * future Linux kernel.  Until then they are a ZFS specific extension.
 */
#define	ZFS_FIEMAP_FLAGS_COMPAT	(FIEMAP_FLAG_SYNC)
#define	ZFS_FIEMAP_FLAGS_ZFS	(FIEMAP_FLAG_COPIES | FIEMAP_FLAG_NOMERGE)

typedef struct zfs_fiemap_entry {
	uint64_t fe_logical_start;
	uint64_t fe_logical_len;
	uint64_t fe_physical_start;
	uint64_t fe_physical_len;
	uint64_t fe_vdev;
	uint64_t fe_flags;
	avl_node_t fe_node;
} zfs_fiemap_entry_t;

typedef struct zfs_fiemap_tree {
	avl_tree_t ft_tree;
	zfs_fiemap_entry_t *ft_prev_fe;
	boolean_t ft_used;
} zfs_fiemap_tree_t;

typedef struct zfs_fiemap {
	zfs_fiemap_tree_t fm_bp_trees[SPA_DVAS_PER_BP];
	range_tree_t *fm_dirty_tree;
	uint64_t fm_flags;
	int fm_copies;
} zfs_fiemap_t;

int zfs_fiemap_assemble(struct inode *ip, zfs_fiemap_t *fm);
int zfs_fiemap_fill(zfs_fiemap_t *fm, struct fiemap_extent_info *fei,
    uint64_t start, uint64_t len);
zfs_fiemap_t *zfs_fiemap_create(uint64_t start, uint64_t len, uint64_t flags);
void zfs_fiemap_destroy(zfs_fiemap_t *fm);

#endif	/* _SYS_FIEMAP_H */
