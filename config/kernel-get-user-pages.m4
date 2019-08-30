dnl #
dnl # get_user_pages_unlocked() function was not available till 4.0.
dnl #
dnl # long get_user_pages_unlocked(struct task_struct *tsk, 
dnl #       struct mm_struct *mm, unsigned long start, unsigned long nr_pages,
dnl #       int write, int force, struct page **pages)
dnl # 4.8 API Change
dnl # long get_user_pages_unlocked(unsigned long start,
dnl #       unsigned long nr_pages, int write, int force, struct page **page)
dnl # 4.9 API Change
dnl # long get_user_pages_unlocked(usigned long start, int nr_pages,
dnl #       struct page **pages, unsigned int gup_flags)
dnl #
dnl #
dnl # In earlier kernels (< 4.0) get_user_pages() is available
dnl # 
dnl # int get_user_pages(struct task_struct *tsk, struct mm_struct *mm,
dnl #       unsigned long start, int nr_pages, int write, int force,
dnl #       struct_page **pages, struct vm_area_struct **vmas)
dnl #
dnl # 4.6 API Change
dnl # long get_user_pages(unsigned long start, unsigned long nr_pages,
dnl #       unsigned int gup_flags, struct page **pages,
dnl #       struct vm_area_struct **vmas)
dnl #
AC_DEFUN([ZFS_AC_KERNEL_GET_USER_PAGES], [
	dnl #
	dnl # Current API of get_user_pages_unlocked
	dnl #
	AC_MSG_CHECKING([whether get_user_pages_unlocked() takes gup flags])
	ZFS_LINUX_TRY_COMPILE([
		#include <linux/mm.h>
	], [
		unsigned long start = 0;
		unsigned long nr_pages = 1;
		unsigned int gup_flags = 0;
		struct page **pages = NULL;
		long ret __attribute__ ((unused));
		ret = get_user_pages_unlocked(start, nr_pages, pages, gup_flags);
	], [
		AC_MSG_RESULT(yes)
		AC_DEFINE(HAVE_GET_USER_PAGES_UNLOCKED_GUP_FLAGS, 1,
		    [get_user_pages_unlocked() takes gup flags])
	], [
		dnl #
		dnl # 4.8 API change, get_user_pages_unlocked
		dnl #
		AC_MSG_RESULT(no)
		AC_MSG_CHECKING([whether get_user_pages_unlocked() takes write flag])
		ZFS_LINUX_TRY_COMPILE([
			#include <linux/mm.h>
		], [
			unsigned long start = 0;
			unsigned long nr_pages = 1;
			int write = 0;
			int force = 0;
			long ret __attribute__ ((unused));
			struct page **pages = NULL;
			ret = get_user_pages_unlocked(start, nr_pages, write, force, pages);
		], [
			AC_MSG_RESULT(yes)
			AC_DEFINE(HAVE_GET_USER_PAGES_UNLOCKED_WRITE_FLAG, 1,
                [get_user_pages_unlocked() takes write flag])
		], [
			dnl #
			dnl # 4.0 API, get_user_pages_unlocked
			dnl #
			AC_MSG_RESULT(no)
			AC_MSG_CHECKING(
			    [whether get_user_pages_unlocked() takes struct task_struct])
			ZFS_LINUX_TRY_COMPILE([
				#include <linux/mm.h>
			], [
				struct task_struct *tsk = NULL;
				struct mm_struct *mm = NULL;
				unsigned long start = 0;
				unsigned long nr_pages = 1;
				int write = 0;
				int force = 0;
				struct page **pages = NULL;
				long ret __attribute__ ((unused));
				ret = get_user_pages_unlocked(tsk, mm, start, nr_pages, write,
				    force, pages);
			], [
				AC_MSG_RESULT(yes)
				AC_DEFINE(HAVE_GET_USER_PAGES_UNLOCKED_TASK_STRUCT, 1,
				    [get_user_pages_unlocked() takes struct task_struct])
			], [
				dnl #
				dnl # 4.6 API change, get_user_pages
				dnl #
				AC_MSG_RESULT(no)
				AC_MSG_CHECKING([whether get_user_pages() takes gup flags])
				ZFS_LINUX_TRY_COMPILE([
					#include <linux/mm.h>
				], [
					struct vm_area_struct **vmas = NULL;
					unsigned long start = 0;
					unsigned long nr_pages = 1;
					unsigned int gup_flags = 0;
					struct page **pages = NULL;
					long ret __attribute__ ((unused));
					ret = get_user_pagees(start, nr_pages, gup_flags, pages, vmas);
				], [
					AC_MSG_RESULT(yes)
					AC_DEFINE(HAVE_GET_USER_PAGES_GUP_FLAGS, 1,
					    [get_user_pages() takes gup flags])
				], [
					dnl #
					dnl # 2.6.31 API, get_user_pages
					AC_MSG_RESULT(no)
					AC_MSG_CHECKING([whether get_user_pages() takes struct task_struct])
					ZFS_LINUX_TRY_COMPILE([
						#include <linux/mm.h>
					], [
						struct task_struct *tsk = NULL;
						struct mm_struct *mm = NULL;
						struct vm_area_struct **vmas = NULL;
						unsigned long start = 0;
						unsigned long nr_pages = 1;
						int write = 0;
						int force = 0;
						struct page **pages = NULL;
						int ret __attribute__ ((unused));
						ret = get_user_pages(tsk, mm, start, nr_pages, write,
					        force, pages, vmas);
					], [
						AC_MSG_RESULT(yes)
						AC_DEFINE(HAVE_GET_USER_PAGES_TASK_STRUCT, 1,
						    [get_user_pages() takes struct task_struct])
					], [
						AC_MSG_ERROR([no; Direct IO not supported for this kernel])
					])
				])
			])
		])
	])
])
