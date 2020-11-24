dnl #
dnl # Check generic_file_direct_write() interface
dnl #
dnl # Both HAVE_GENERIC_FILE_DIRECT_WRITE_IOV_ITER and
dnl # HAVE_GENERIC_FILE_DIRECT_WRITE_IOV_ITER_WITH_LOFF will align with
dnl @ HAVE_VFS_RW_ITERATE as they are valid in kernels >= 3.16.
dnl #
AC_DEFUN([ZFS_AC_KERNEL_SRC_GENERIC_FILE_DIRECT_WRITE], [
	ZFS_LINUX_TEST_SRC([generic_file_direct_write_iov_iter], [
		#include <linux/fs.h>
	], [
		struct kiocb *kiocb = NULL;
		struct iov_iter *iter = NULL;
		ssize_t ret __attribute__ ((unused));

		ret = generic_file_direct_write(kiocb, iter);
	])

	ZFS_LINUX_TEST_SRC([generic_file_direct_write_iov_iter_loff], [
		#include <linux/fs.h>
	], [
		struct kiocb *kiocb = NULL;
		struct iov_iter *iter = NULL;
		loff_t off = 0;
		ssize_t ret __attribute__ ((unused));

		ret = generic_file_direct_write(kiocb, iter, off);
	])

	ZFS_LINUX_TEST_SRC([generic_file_direct_write_iovec_loff], [
		#include <linux/fs.h>
	], [
		struct kiocb *kiocb = NULL;
		const struct iovec *iovec = NULL;
		unsigned long nr_segs = 0;
		loff_t pos = 0;
		size_t count = 0;
		size_t ocount = 0;
		ssize_t ret __attribute__ ((unused));

		ret = generic_file_direct_write(kiocb, iovec, &nr_segs, pos,
		    count, ocount);
	])

	ZFS_LINUX_TEST_SRC([generic_file_direct_write_iovec_loff_ptr], [
		#include <linux/fs.h>
	], [
		struct kiocb *kiocb = NULL;
		const struct iovec *iovec = NULL;
		unsigned long nr_segs;
		loff_t pos = 0;
		loff_t *ppos = NULL;
		size_t count = 0;
		size_t ocount = 0;
		ssize_t ret __attribute__ ((unused));

		ret = generic_file_direct_write(kiocb, iovec, &nr_segs, pos,
		    ppos, count, ocount);
	])
])

AC_DEFUN([ZFS_AC_KERNEL_GENERIC_FILE_DIRECT_WRITE], [
	dnl #
	dnl # Linux 4.7 change
	dnl #
	AC_MSG_CHECKING([whether generic_file_direct_write() passes iov_iter])
	ZFS_LINUX_TEST_RESULT([generic_file_direct_write_iov_iter], [
		AC_MSG_RESULT([yes])
		AC_DEFINE(HAVE_GENERIC_FILE_DIRECT_WRITE_IOV_ITER, 1,
		    [generic_file_direct_write() passes iov_iter])
	], [
		AC_MSG_RESULT([no])

		dnl #
		dnl # Linux 3.16 change
		dnl #
		AC_MSG_CHECKING(
		    [whether generic_file_direct_write() passes iov_iter with loff])
		ZFS_LINUX_TEST_RESULT(
		    [generic_file_direct_write_iov_iter_loff], [
			AC_MSG_RESULT([yes])
			AC_DEFINE(
			    HAVE_GENERIC_FILE_DIRECT_WRITE_IOV_ITER_WITH_LOFF, 1,
			    [generic_file_direct_write() passes iov_iter with loff])
		], [
			AC_MSG_RESULT([no])
			
			dnl #
			dnl # Linux 3.15 change
			dnl #
			AC_MSG_CHECKING(
			    [whether generic_file_direct_write() passes struct iovec])
			ZFS_LINUX_TEST_RESULT([generic_file_direct_write_iovec_loff], [
				AC_MSG_RESULT([yes])
				AC_DEFINE(
				    HAVE_GENERIC_FILE_DIRECT_WRITE_IOVEC, 1,
				    [generic_file_direct_write() passes struct iovec])
			], [
				AC_MSG_RESULT([no])

				dnl #
				dnl # Covers Linux 3.10
				dnl #
				AC_MSG_CHECKING(
				    [whether generic_file_direct_write() passes struct iovec with loff ptr])
				ZFS_LINUX_TEST_RESULT(
				    [generic_file_direct_write_iovec_loff_ptr], [
					AC_MSG_RESULT([yes])
					AC_DEFINE(
					    HAVE_GENERIC_FILE_DIRECT_WRITE_IOVEC_LOFF_PTR, 1,
					    [generic_file_direct_write() passes struct iovec with loff ptr])
				], [
					ZFS_LINUX_TEST_ERROR(
					    [generic_file_direct_write])
					AC_MSG_RESULT([no])
				])
			])
		])
	])
])
