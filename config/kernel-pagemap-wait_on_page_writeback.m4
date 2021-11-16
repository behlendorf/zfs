dnl #
dnl # Linux 5.16 no longer allows directly calling wait_on_page_bit, and
dnl # instead requires you to call bit-specific functions. In this case,
dnl # wait_on_page_bit(pg, PG_writeback) becomes
dnl # wait_on_page_writeback(pg)
dnl #
AC_DEFUN([ZFS_AC_KERNEL_SRC_PAGEMAP_WAIT_ON_PAGE_WRITEBACK], [
	ZFS_LINUX_TEST_SRC([pagemap_has_wait_on_page_writeback], [
		#include <linux/pagemap.h>
	],[
		static struct page *p = NULL;

		wait_on_page_writeback(p);
	])
])

AC_DEFUN([ZFS_AC_KERNEL_PAGEMAP_WAIT_ON_PAGE_WRITEBACK], [
	AC_MSG_CHECKING([wait_on_page_writeback() exists])
	ZFS_LINUX_TEST_RESULT([pagemap_has_wait_on_page_writeback], [
		AC_MSG_RESULT([yes])
		AC_DEFINE(HAVE_PAGEMAP_WAIT_ON_PAGE_WRITEBACK, 1,
			[wait_on_page_writeback() exists])
	],[
		AC_MSG_RESULT([no])
	])
])
