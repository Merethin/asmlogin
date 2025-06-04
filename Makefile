NASM := $(if $(NASM),$(NASM),nasm)
CC := $(if $(CC),$(CC),gcc)
LIBDIR := $(if $(LIBDIR),$(LIBDIR),/usr/lib)

asmlogin: main.asm.o net.asm.o
	$(CC) -o $@ -lcurl $^

main.asm.o: main.asm
	$(NASM) -felf64 -g -Fdwarf -o $@ $^

net.asm.o: net.asm
	$(NASM) -felf64 -g -Fdwarf -o $@ $^