global _start
global _exit
extern sprintfn
extern putss
extern putss_nl

section .text:
_start:
jmp _exit


_exit:
	mov	rax, 0x1
	mov	rdi, 0x1
	mov	rsi, foo
	mov	rdx, foolen
	syscall


	sub 	rsp, 0x16
	mov 	rax, foo
	mov 	[rsp+0x0], rax
	mov 	qword [rsp+0x8], 0
	mov	rcx, rsp
	mov 	rdi, buff
	mov 	rsi, 500
	mov 	rdx, format
	mov	rcx, rsp
	lea 	rax, [sprintfn]
	call 	rax

	mov	r8, 9
	mov	r9, 2 ; choosing index 2
.target:	
	mov	rdi, buff
	lea 	rax, [putss]
	call	rax

	jmp	.before_jmppoint
;data, very space efficent table
.table:
	dw 0x0,
	dw 0x0,
	dw .target - .jmppoint,
	dw 0x0,
.before_jmppoint:


.jmppoint:
	mov	bx, [rel .table + r9 * 2]
	movsx	rbx, bx ; sx the offset 
	lea	rax, [.jmppoint + rbx]
	sub	r8, 1
	jl	.no_jmp
	jmp	rax ;jump to the entry from the small table
.no_jmp:

	mov	rdi, foo
	call 	putss_nl


	mov	rax, 0x3c
	mov	rsi, 0x00
	syscall

section .data
format: db 'fstr: "%s"',0xa,0
foo:	db 'hello world', 0
foolen: equ $-foo
section .bss
buff: resb 500
