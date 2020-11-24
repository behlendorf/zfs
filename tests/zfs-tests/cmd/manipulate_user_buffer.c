/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or https://opensource.org/licenses/CDDL-1.0.
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
 * Copyright (c) 2022 by Triad National Security, LLC.
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <assert.h>

#ifndef MIN
#define	MIN(a, b)	((a) < (b)) ? (a) : (b)
#endif

static char *outputfile = NULL;
static int blocksize = 131072; /* 128K */
static int numblocks = 8;
static double runtime = 10; /* 10 seconds */
static char *execname = NULL;
static int print_usage = 0;
static int randompattern = 0;
static int ofd;
static int verify_wr_err = 0;
char *buf = NULL;

typedef struct {
	int entire_file_written;
	int done;
	int total_errors;
} pthread_args_t;

static void
usage(void)
{
	(void) fprintf(stderr,
	    "usage %s -o outputfile [-b blocksize] [-n numblocks]\n"
	    "         [-p randpattern] [-r runtime] [-v verify_wr_error]\n"
	    "         [-h help]\n"
	    "\n"
	    "Testing whether checksum verify works correctly for O_DIRECT.\n"
	    "when manipulating the contents of a userspace buffer.\n"
	    "\n"
	    "    outputfile:    File to write to.\n"
	    "    blocksize:     Size of each block to write (must be at \n"
	    "                   least >= 512).\n"
	    "    numblocks:     Total number of blocksized blocks to write.\n"
	    "    randpattern:   Fill data buffer with random data. Default \n"
	    "                   behavior is to fill the buffer with the \n"
	    "                   known data pattern (0xdeadbeef).\n"
	    "    runtime:       Total amount of time to run test in seconds.\n"
	    "                   Test will run till the specified runtime or\n"
	    "                   when blocksize * numblocks data is written.\n"
	    "    verify_wr_err: Check that pwrite() returns EINVAL at least \n"
	    "                   once\n"
	    "    help:          Print usage information and exit.\n"
	    "\n"
	    "    Required parameters:\n"
	    "    outputfile\n"
	    "\n"
	    "    Default Values:\n"
	    "    blocksize     -> 131072\n"
	    "    numblocks     -> 8\n"
	    "    randpattern   -> false\n"
	    "    runtime       -> 10 seconds\n"
	    "    verify_wr_err -> false\n",
	    execname);
	(void) exit(1);
}

static void
parse_options(int argc, char *argv[])
{
	int c;
	int errflag = 0;
	extern char *optarg;
	extern int optind, optopt;
	execname = argv[0];

	while ((c = getopt(argc, argv, "b:hn:o:pr:v")) != -1) {
		switch (c) {
			case 'b':
				blocksize = atoi(optarg);
				break;

			case 'h':
				print_usage = 1;
				break;

			case 'n':
				numblocks = atoi(optarg);
				break;

			case 'o':
				outputfile = optarg;
				break;

			case 'p':
				randompattern = 1;
				break;

			case 'r':
				runtime = (double)atoi(optarg);
				break;

			case 'v':
				verify_wr_err = 1;
				break;

			case ':':
				(void) fprintf(stderr,
				    "Option -%c requires an opertand\n",
				    optopt);
				errflag++;
				break;
			case '?':
			default:
				(void) fprintf(stderr,
				    "Unrecognized option: -%c\n", optopt);
				errflag++;
				break;
		}
	}

	if (errflag || print_usage == 1)
		(void) usage();

	if (blocksize < 512 || outputfile == NULL || runtime <= 0 ||
	    numblocks <= 0) {
		(void) fprintf(stderr,
		    "Required paramater(s) missing or invalid.\n");
		(void) usage();
	}
}

/*
 * Continually write to the file using O_DIRECT from the range of 0 to
 * blocksize * numblocks for the requested runtime.
 */
static void *
write_thread(void *arg)
{
	size_t offset = 0;
	int total_data = blocksize * numblocks;
	int left = total_data;
	ssize_t wrote = 0;
	pthread_args_t *args = (pthread_args_t *)arg;

	while (!args->done || !args->entire_file_written) {
		wrote = pwrite(ofd, buf, blocksize, offset);
		if (wrote < 0) {
			assert(errno == EINVAL);
			assert(wrote == -1);
			args->total_errors += -(wrote);
		} else {
			assert(wrote == blocksize);
		}

		offset = ((offset + blocksize) % total_data);
		if (left > 0)
			left -= blocksize;
		else
			args->entire_file_written = 1;
	}

	pthread_exit(NULL);
}

/*
 * Update the buffers contents with random data.
 */
static void *
manipulate_buf_thread(void *arg)
{
	size_t rand_offset;
	char rand_char;
	pthread_args_t *args = (pthread_args_t *)arg;

	while (!args->done || !args->entire_file_written) {
		rand_offset = (rand() % blocksize);
		rand_char = (rand() % (126 - 33) + 33);
		buf[rand_offset] = rand_char;
	}

	pthread_exit(NULL);
}

int
main(int argc, char *argv[])
{
	const char *datapattern = "0xdeadbeef";
	int ofd_flags = O_WRONLY | O_CREAT | O_DIRECT;
	mode_t mode = S_IRUSR | S_IWUSR;
	pthread_t write_thr;
	pthread_t manipul_thr;
	int left = blocksize;
	int offset = 0;
	int rc;
	time_t start;
	pthread_args_t args = { 0, 0, 0};

	parse_options(argc, argv);

	ofd = open(outputfile, ofd_flags, mode);
	if (ofd == -1) {
		(void) fprintf(stderr, "%s, %s\n", execname, outputfile);
		perror("open");
		exit(2);
	}

	int err = posix_memalign((void **)&buf, sysconf(_SC_PAGE_SIZE),
	    blocksize);
	if (err != 0) {
		(void) fprintf(stderr,
		    "%s: %s\n", execname, strerror(err));
		exit(2);
	}

	if (!randompattern) {
		/* Putting known data pattern in buffer */
		while (left) {
			size_t amt = MIN(strlen(datapattern), left);
			memcpy(&buf[offset], datapattern, amt);
			offset += amt;
			left -= amt;
		}
	} else {
		/* Putting random data in buffer */
		for (int i = 0; i < blocksize; i++)
			buf[i] = rand();
	}

	if ((rc = pthread_create(&write_thr, NULL, write_thread, &args))) {
		fprintf(stderr, "error: pthreads_create, write_thr, "
		    "rc: %d\n", rc);
		exit(2);
	}

	if ((rc = pthread_create(&manipul_thr, NULL, manipulate_buf_thread,
	    &args))) {
		fprintf(stderr, "error: pthreads_create, manipul_thr, "
		    "rc: %d\n", rc);
		exit(2);
	}

	time(&start);

	/*
	 * Writing while manipulating the buffer conntents until either then
	 * runtime is met or the entire file is written. In the event the
	 * runtime takes less time than to write the entire file we will wait
	 * for the entire file to be written.
	 */
	while (difftime(time(NULL), start) < runtime ||
	    args.entire_file_written == 0) {}
	args.done = 1;

	pthread_join(write_thr, NULL);
	pthread_join(manipul_thr, NULL);

	assert(args.entire_file_written == 1);

	if (verify_wr_err)
		assert(args.total_errors > 0);

	(void) close(ofd);

	free(buf);

	return (0);
}
