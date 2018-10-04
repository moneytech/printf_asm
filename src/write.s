global write
global exit
write:
	mov	rax, 1
	syscall
	ret
exit:
	mov	rax, 0x3c
	syscall
