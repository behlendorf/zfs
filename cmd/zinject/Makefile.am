sbin_PROGRAMS   += zinject
CPPCHECKTARGETS += zinject

zinject_CPPFLAGS  = $(AM_CPPFLAGS) $(LIBZPOOL_CPPFLAGS)

zinject_SOURCES = \
	%D%/translate.c \
	%D%/zinject.c \
	%D%/zinject.h

zinject_LDADD = \
	libzfs.la \
	libzfs_core.la \
	libnvpair.la
