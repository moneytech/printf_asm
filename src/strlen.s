global strlens
global putss
global putss_nl

section .text:
strlens:

	xor	rcx, rcx
	.loop:
	mov 	al, [rdi+rcx]
	test	al, al
	jz	.end
	add	rcx, 1
	jmp	.loop

.end:
	mov	rax, rcx
	ret

; this does not print a newline
putss:
	call	strlens
	mov	rdx, rax
	mov 	rsi, rdi

	mov	rax, 0x1
	mov	rdi, 0x1
	;mov	rsi, foo
	;mov	rdx, foolen
	syscall

	ret

putss_nl:
	call	putss

	mov	rsi, rsp
	sub	rsi, 1
	mov	byte [rsi], 0xa

	mov	rax, 0x1
	mov	rdi, 0x1
	mov	rdx, 0x1
	;mov	rsi, foo
	;mov	rdx, foolen
	syscall
	ret
	


section .data
format: db 'fstr: %s',0xa,0
foo:	db 'hello world',0xa, 0
foolen: equ $-foo
section .bss
buff: resb 500
