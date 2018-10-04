#this makefile is a mess :D
#CFLAGS = -g
CFLAGS = -O0 -g -fno-stack-protector -no-pie -fno-PIC -fno-PIE

.PHONY: all build
all: build 

build: asmtry printf_tests

asmtry: src/tests/testasm.s obj/snprintf.o obj/strlen.o
	nasm -f elf64 src/tests/testasm.s -o obj/testasm.o
	ld obj/snprintf.o obj/testasm.o obj/strlen.o -o asmtest

src/format_table.s: src/scripts/py_gen_ascii.py
	python src/scripts/py_gen_ascii.py > $@
obj/snprintf.o: src/snprintf.s src/format_table.s
	nasm -f elf64 $< -o $@ -Isrc/
obj/strlen.o: src/strlen.s
	nasm -f elf64 $^ -o $@
obj/write.o: src/write.s
	nasm -f elf64 $< -o $@ -Isrc/

obj/printfs.o: src/printfs.c
	cc -nostdlib $(CFLAGS) -c $^ -o $@
printf_tests: obj/printfs.o obj/snprintf.o obj/write.o src/tests/printf_tests.c
	cc -nostdlib $(CFLAGS) $^ -o $@


libc_tests: src/tests/libc_tests.c obj/snprintf.o
	cc $(CFLAGS) $^ -o $@

clean:
	rm -f asmtest test printf_tests obj/*.o *.o format_table.s 
