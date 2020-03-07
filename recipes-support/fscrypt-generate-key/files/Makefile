EXEC = fscrypt_generate_key
OBJS = fscrypt_generate_key.c
CFLAGS = -Wall

all: $(EXEC)

$(EXEC) : $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

clean:
	-rm -f $(EXEC)
