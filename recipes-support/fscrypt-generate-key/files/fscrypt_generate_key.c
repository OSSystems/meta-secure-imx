#define _GNU_SOURCE

#include <errno.h>
#include <error.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

#define getrandom(dst,s,flags) syscall(__NR_getrandom, (void*)dst, (size_t)s, (unsigned int)flags)

#define FS_MIN_KEY_SIZE	        16
#define FS_MAX_KEY_SIZE         64

struct fscrypt_key {
        uint32_t mode;
        uint8_t raw[FS_MAX_KEY_SIZE];
        uint32_t size;
};


static int key_length = 16;

static void print_usage(char *cmd)
{
	fprintf(stderr, "USAGE: %s <key-length>\n\n"
		"Generates a random key in the fscrypt format and outputs it as hex to stdout\n\n"
		"<key-length> is the key length in bytes\n",
		cmd);
}

static int parse_options(int argc, char **argv)
{
	int kl;

	if (argc != 2) {
		print_usage(argv[0]);
		return -EINVAL;
	}

	kl = atoi(argv[1]);
	if (kl < FS_MIN_KEY_SIZE || kl > FS_MAX_KEY_SIZE) {
		fprintf(stderr, "Key length must be between %d and %d!\n",
			FS_MIN_KEY_SIZE, FS_MAX_KEY_SIZE);
		return -EINVAL;
	}
	key_length = kl;

	return 0;
}

static int generate_key(struct fscrypt_key *key, int key_len)
{
	ssize_t ret;

	ret = getrandom(key->raw, key_len, 0);
	if (ret != key_len) {
		fprintf(stderr, "Failed to generate random key: %ld\n", ret);
		if (ret < 0)
			perror("getrandom");
		return -EINVAL;
	}

	return 0;
}

static void print_key(struct fscrypt_key *key)
{
	uint8_t *ptr = (uint8_t *)key;

	for (; ptr < (uint8_t *)key + sizeof(struct fscrypt_key); ptr++) {
		printf("%02x", *ptr);
	}
}

int main(int argc, char **argv)
{
	int ret;
	struct fscrypt_key *key;

	ret = parse_options(argc, argv);
	if (ret)
		return EXIT_FAILURE;

	fprintf(stderr, "Generating %i bit key...\n", key_length);

	key = calloc(1, sizeof(struct fscrypt_key));
	if (!key) {
		perror("calloc");
		return EXIT_FAILURE;
	}

	key->size = key_length;
	ret = generate_key(key, key_length);
	if (ret)
		return EXIT_FAILURE;

	print_key(key);

	return EXIT_SUCCESS;
}
