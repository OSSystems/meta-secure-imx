#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>


#define FS_KEY_DESCRIPTOR_SIZE		8

#define FS_ENCRYPTION_MODE_AES_128_CBC	5
#define FS_ENCRYPTION_MODE_AES_128_CTS	6

#define FS_IOC_SET_ENCRYPTION_POLICY	_IOR('f', 19, struct fscrypt_policy)
#define FS_IOC_GET_ENCRYPTION_POLICY	_IOW('f', 21, struct fscrypt_policy)

struct fscrypt_policy {
	uint8_t version;
	uint8_t contents_encryption_mode;
	uint8_t filenames_encryption_mode;
	uint8_t flags;
	uint8_t master_key_descriptor[FS_KEY_DESCRIPTOR_SIZE];
} __packed;


struct options {
	unsigned char *master_key_desc;
	char *path;
	bool write;
};

static const unsigned char *hexchars = (const unsigned char *) "0123456789abcdef";
static const size_t hexchars_size = 16;

static struct options opts;

static void print_usage(char *cmd)
{
	fprintf(stderr, "USAGE: %s (-r|-w) <path> [<master-key-descriptor>]\n\n"
		"-r reads the current policy\n-w installs a new policy\n"
		"<path> is the ubifs directory for which to perform the operation\n"
		"<master-key-descriptor> has to be exactly 8 characters long\n",
		cmd);
}

static char *enc_mode2str(int enc_mode)
{
	switch(enc_mode) {
	case FS_ENCRYPTION_MODE_AES_128_CBC:
		return "AES-128-CBC";
	case FS_ENCRYPTION_MODE_AES_128_CTS:
		return "AES-128-CBC-CTS";
	default:
		return "unknown";
	}
}

/* taken from e4crypt of e2fsprogs */
static int hex2byte(const char *hex, size_t hex_size, unsigned char *bytes,
		    size_t bytes_size)
{
	size_t x;
	unsigned char *h, *l;

	if (hex_size % 2)
		return -EINVAL;
	for (x = 0; x < hex_size; x += 2) {
		h = memchr(hexchars, hex[x], hexchars_size);
		if (!h)
			return -EINVAL;
		l = memchr(hexchars, hex[x + 1], hexchars_size);
		if (!l)
			return -EINVAL;
		if ((x >> 1) >= bytes_size)
			return -EINVAL;
		bytes[x >> 1] = (((unsigned char)(h - hexchars) << 4) +
				 (unsigned char)(l - hexchars));
	}
	return 0;
}

static int parse_options(int argc, char **argv)
{
	unsigned char *key_desc;

	if (argc < 3 || argc > 4) {
		print_usage(argv[0]);
		return -EINVAL;
	}

	if (strncmp(argv[1], "-w", 2) == 0) {
		opts.write = true;
	} else if (strncmp(argv[1], "-r", 2) == 0) {
		opts.write = false;
	} else {
		fprintf(stderr, "Invalid option: Expected '-r' or '-w'\n");
		print_usage(argv[0]);
		return -EINVAL;
	}

	opts.path = argv[2];

	if (opts.write) {
		if (argc == 4) {
			if (strlen(argv[3]) != (2 * FS_KEY_DESCRIPTOR_SIZE)) {
				fprintf(stderr, "Invalid option: master key descriptor must be exactly %d characters long\n",
					(2 * FS_KEY_DESCRIPTOR_SIZE));
				return -EINVAL;
			}

			key_desc = malloc(FS_KEY_DESCRIPTOR_SIZE);
			if (!key_desc)
				return -ENOMEM;

			hex2byte(argv[3], (2 * FS_KEY_DESCRIPTOR_SIZE),
				 key_desc, FS_KEY_DESCRIPTOR_SIZE);
			opts.master_key_desc = key_desc;
		} else {
			fprintf(stderr, "Missing value for <master-key-descriptor>\n");
			return -EINVAL;
		}
	}

	return 0;
}

static int do_ioctl(char *path, int ioc, struct fscrypt_policy *policy)
{
	int fd;
	int ret;

	fd = open(path, O_DIRECTORY);
	if (fd == -1) {
		perror(path);
		return -EINVAL;
	}

	ret = ioctl(fd, ioc, policy);
	close(fd);
	if (ret) {
		fprintf(stderr, "ioctl failed with error: %s\n", strerror(errno));
		ret = -EINVAL;
	}

	return ret;
}

static int set_policy(void)
{
	struct fscrypt_policy policy;

	policy.version = 0;
	policy.flags = 0;
	policy.contents_encryption_mode = FS_ENCRYPTION_MODE_AES_128_CBC;
	policy.filenames_encryption_mode = FS_ENCRYPTION_MODE_AES_128_CTS;
	memcpy(policy.master_key_descriptor, opts.master_key_desc,
	       FS_KEY_DESCRIPTOR_SIZE);

	return do_ioctl(opts.path, FS_IOC_SET_ENCRYPTION_POLICY, &policy);
}

static int get_policy(void)
{
	int ret;
	struct fscrypt_policy policy;
	size_t i;

	ret = do_ioctl(opts.path, FS_IOC_GET_ENCRYPTION_POLICY, &policy);
	if (ret)
		return ret;

	printf("encryption policy for %s:\n", opts.path);
	printf("master key descriptor: ");
	for (i = 0; i < FS_KEY_DESCRIPTOR_SIZE; i++) {
		printf("%02x", policy.master_key_descriptor[i]);
	}
	printf("\n");
	printf("contents encryption mode: %s\n",
	       enc_mode2str(policy.contents_encryption_mode));
	printf("filenames encryption mode: %s\n",
	       enc_mode2str(policy.filenames_encryption_mode));

	return 0;
}

int main(int argc, char **argv)
{
	int ret;

	ret = parse_options(argc, argv);
	if (ret)
		return EXIT_FAILURE;

	if (opts.write)
		ret = set_policy();
	else
		ret = get_policy();

	if (ret) {
		fprintf(stderr, "Command failed!\n");
		return EXIT_FAILURE;
	}

	free(opts.master_key_desc);

	return EXIT_SUCCESS;
}
