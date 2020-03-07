EXEC = ubifs_crypt_policy
OBJS = ubifs_crypt_policy.c
CFLAGS = -Wall

all: $(EXEC)

$(EXEC) : $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

clean:
	-rm -f $(EXEC)
