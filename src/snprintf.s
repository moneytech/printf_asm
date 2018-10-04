;
;
;
;       Author: nilput, nilputs@nilput.com
;       LICENSE: MIT (check file)
;
;       
;

global sprintfn
global itoss

global atois

;
;       this is quite a mess, i'm a beginner in assembly, learn how not to do things from this :P
;       i think someone who knows asm can do it in ~300 instructions :)
;       
;
;       supported length modifiers: l,ll,h,hh
;       supported modifiers: d, x, s
;       other modifiers: 
;       
;       the width field is supported, 
;
;       addtionally: supports a nonstandard extension %b for representing binary
;
;       the rest is a work in progress
;
;       absolutely needed and missing: 
;                                       Alignment
;                                       precision
;                                       floats have many formats, currently it only supports %f
;


;rdi will contain the target buffer, rsi will contain its length
;rdx will contain the format, and rcx will contain a char ** terminated with null
;#.text:
    %define DIGITS_BUFF_SIZE            80 ;change DIGITS_BUFF when you change this

sprintfn:
        push            rbp
        push            rbx
        mov             rbp, rsp 
        sub             rsp, 0x30 ;4 variables
        sub             rsp, DIGITS_BUFF_SIZE ; buffer


        ;initialize fpu

        finit
        fldcw           [FPU_FLRDBL]
        ;clear fpu stack
        %rep 8
        fstp            st0
        %endrep



;local variables
        %define COUNTER                         rbp-0x8
        %define LEN_LIMIT                       rbp-0x10
        %define PRECISION                       rbp-0x18 ;d : ld : lld. or negative for hd hhd
        ;these are 1 byte each, we have space for 8 of them
        %define PRECISION_MODE                  rbp-0x25 ;this is initially 0, it is set to 1 after encountering '.' in the format
        %define ALTERNATE_FORM                  rbp-0x26
        %define ALWAYS_PRINT_SIGN               rbp-0x27
        %define JUSTIFY_LEFT                    rbp-0x28
        %define LONG_COUNT                      rbp-0x30 ;d : ld : lld. or negative for hd hhd
        %define DIGITS_BUFF                     rbp-0x80  ;this is an 80 characters big buffer,
        ;enough for representing all integers <= 2**64 with the minus sign
        ;offset is 0x30+0x50 = 0x80
        %define DEST_RDI                        rdi
        %define DEST_LEN_RSI                    rsi
        %define PAT_RDX                         rdx
        %define ARGS_RCX_PTR                    rcx
        %define EFFECTIVE_LIMIT_R8              r8
        %define TMP_ARG_RBX                     rbx
        %define TMP_ARG2_R9                     r9 ;this is used only as the base specifier in integer formats,
        %define TMP_ARG3_R10                    r10 
        %define UNSIGNED_FLAG                   0x200
        %define UPPERCAPS_FLAG                  0x400
        %define ALWAYS_PRINT_SIGN_FLAG          0x800
        %define ALTERNATE_FORM_FLAG             0x1000




;when we see % we wait, if we don't find another % then we goto handle_format
        sub             DEST_LEN_RSI, 1 ; for null terminator


        xor             rax, rax
        mov             ah, byte [PAT_RDX]
        add             PAT_RDX, 1

;optimization notes: some of these cmps can be turned into subtractions then anded
.pat_loop:
        mov             al, ah ;move next byte to current byte register
        test            al, al ;check for null terminator
        jz              .end_of_format ;if null jmp
        mov             ah, byte [PAT_RDX] ; effectively moves the next symbol to ah 
        ;(it is the next because the ptr is increased in the bottom of the loop)


        cmp             al, '%' ;compare current byte
        jne             .not_pescaped
        cmp             ah, '%' ;compare next byte
        jne             .handle_format ;handling formats line %s ; ah is what the table uses, so when we jmp to whatever the next symbol has to be in ah
        ;else it is just an escape so we move the next symbol to ah so this doesnt get loaded
        ;the next two instructions should be done by all branches
        add             PAT_RDX, 1 ;increase the ptr
        mov             ah, [PAT_RDX] ;mov 

.not_pescaped:

.normal:
        sub             DEST_LEN_RSI, 1
        jz              .end_of_format
        mov             [DEST_RDI], al
        add             DEST_RDI, 1
        add             PAT_RDX, 1
        jmp             .pat_loop

.handle_format:
        mov             byte [JUSTIFY_LEFT], 0 ;default to right justify
        mov             byte [ALTERNATE_FORM], 0
        mov             byte [PRECISION_MODE], 0
        mov             byte [ALWAYS_PRINT_SIGN], 0
        mov             qword [LEN_LIMIT], 0
        mov             qword [LONG_COUNT], 0
        mov             qword [PRECISION], 6

;       current state: ah contains the next symbol
;       remember to do: 
;check for null
;increase match count
;move formatted string to DEST
;^while checking DEST_LEN_RSI and jmping to end_of_format if zero
;       at the end: 
;move the next symbol we're not responsible of to ah: handled in after_handling

.format_jmppoint:
        shr             rax, 0x8; shift right so ah becomes al
        movzx           rax, al
        shl             rax, 1 ;multiply by two because the table entries are two bytes each
        lea             rbx, [rel .format_table] 
        add             rax, rbx

        movsx           rax, word [rax]
        add             rbx, rax
        jmp             rbx

align 16
.format_table:
;python generated       
        %include 'format_table.s'

.case_nullchar:
        jmp             .end_of_format
        
.case_invalid:
        ;print as it is, but because RAX was rekt we need to load the same symbol again
        mov             ah, byte [PAT_RDX]
        jmp             .not_pescaped
.handle_len:
        ;push non saved registers
        ;we don't need to push rdx because we want it to advance it for us
        push            ARGS_RCX_PTR
        call            atois

        ;check whether what we just parsed was width or precision
        test            byte [PRECISION_MODE], 0xff
        jnz             .precision_case
        .width_case:
        add             rax, 1 ;add one because it is to be used as an inclusive length
        mov             qword [LEN_LIMIT], rax ;this is the parsed int
        jmp             .handle_len_end
        .precision_case:
        mov             qword [PRECISION], rax


        .handle_len_end:
        pop             ARGS_RCX_PTR
        ;state after calling atoi: rdx will be pointing to next non digit

        jmp             .before_rejump
.case_b:
        mov             TMP_ARG2_R9, 2
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR]  ;the number
        jmp             .unsigned_x_common
.case_o:
        mov             TMP_ARG2_R9, 8
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR]  ;the number
        jmp             .unsigned_x_common


.case_upper_x:
        mov             TMP_ARG2_R9, 16; base 16
        or              TMP_ARG2_R9, UPPERCAPS_FLAG
        jmp             .unsigned_x_common
.case_x:
        mov             TMP_ARG2_R9, 16; base 16
        jmp             .unsigned_x_common

.case_u:
        mov             TMP_ARG2_R9, 10 ; base 10
.unsigned_x_common:
        or              TMP_ARG2_R9, UNSIGNED_FLAG
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR]  ;the number

        cmp             qword [LONG_COUNT], 0
        jz              .uint_32
        jl              .ushort_or_shortshort
        jmp             .uint_64
        .uint_32:
        mov             ebx, ebx ;zero higher bits
        jmp             .case_u_continue
        
        .ushort_or_shortshort:
        cmp             qword [LONG_COUNT], -1
        jl              .ushortshort ; if [LONG_COUNT] < -1 jmp
        .ushort:
        movzx           TMP_ARG_RBX, bx ;16bit
        jmp             .case_u_continue
        .ushortshort:
        movzx           TMP_ARG_RBX, bl
        jmp             .case_u_continue
        .uint_64:
        .case_u_continue:

        jmp             .call_sprint_int

.case_d:

        mov             TMP_ARG2_R9, 10 ; base 10
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR]  ;the number
        ;adjust according to the long modifier
        ;because long is equivilant to long long we treat them the same by simply not doing anything if they're present
        cmp             qword [LONG_COUNT], 0
        jz              .int_32
        jl              .short_or_shortshort
        jmp             .int_64
        .int_32:
        movsx           TMP_ARG_RBX, ebx
        jmp             .case_d_continue
        
        .short_or_shortshort:
        cmp             qword [LONG_COUNT], -1
        jl              .shortshort ; if [LONG_COUNT] < -1 jmp
        .short:
        movsx           TMP_ARG_RBX, bx ;16bit
        jmp             .case_d_continue
        .shortshort:
        movsx           TMP_ARG_RBX, bl ;8bit
        jmp             .case_d_continue



        .int_64:
        .case_d_continue:

        ;implicit jmp to .call_sprint_int


.call_sprint_int:
; add additional flags if they were requested
;       expects the base ORD's with options at TMP_ARG2_R9
;       and it exepcts a 64bit (by default signed number) at TMP_ARG_RBX
        
        ;common or operations
        test            byte [ALWAYS_PRINT_SIGN], 0xff
        jz              .APS_not_set
        or              TMP_ARG2_R9, ALWAYS_PRINT_SIGN_FLAG

        .APS_not_set:
        test            byte [ALTERNATE_FORM], 0xff
        jz              .AF_not_set
        or              TMP_ARG2_R9, ALTERNATE_FORM_FLAG
        .AF_not_set:
        
        call    sprint_integer_to_buff_r

        push            rdi
        push            rsi
        push            rdx

        lea             rsi, [DIGITS_BUFF]

        call            compute_effective_limit_r ;loads the effective limit to r8 without any other sideeffects
        mov             rdx, EFFECTIVE_LIMIT_R8

        call            strncpys

        pop             rdx
        pop             rsi
        pop             rdi

        ;now we need to adjust dest len accordingly by subtracting rax from it
        sub             DEST_LEN_RSI, rax ; rax contains the length of the copied characters (exclusing \0)
        add             DEST_RDI, rax ;advance the pointer


        add             PAT_RDX, 1
        jmp             .after_handling
.case_f:
        
        fld             qword [ARGS_RCX_PTR]

        ;rdi already has a ptr to dest, also rsi has len
        ;even though the function uses rbx,rax, we don't care about them
        ;also it modifies rdi,rsi in a useful way
        push            rcx
        mov             TMP_ARG3_R10, qword [PRECISION]
        call            dtos
        pop             rcx

;       fstp            st0 ;clear what we fld'ed (it's already cleared)

        add             PAT_RDX,1
        jmp             .after_handling

        
.case_c:
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR]
        mov             byte [rdi], bl
        sub             DEST_LEN_RSI, 1
        add             DEST_RDI, 1
        add             PAT_RDX, 1
        jmp             .after_handling
.case_s:
        mov             TMP_ARG_RBX, [ARGS_RCX_PTR] ;TMP_ARG_RBX is a register
        test            TMP_ARG_RBX, TMP_ARG_RBX
        jz              .on_null_str_passed
        .continue_to_print_null:

        call            compute_effective_limit_r

        .copy_str:
        ;push           rdi             ; we don't have to save rdi, the procedure guarentees advancing it for us (it will end at [rdi] = \0)
        push            rdx
        push            rsi
        push            rax

        mov             rdi, DEST_RDI ;destination
        mov             rsi, TMP_ARG_RBX ;source (user provided string)
        mov             rdx, EFFECTIVE_LIMIT_R8 ;the minimum of field width and available space (what's left of the n argument)
        call            strncpys 

        pop             rax
        pop             rsi
        pop             rdx

        add             PAT_RDX, 1
        jmp             .after_handling

        ;exceptional condition
        .on_null_str_passed:
        lea             TMP_ARG_RBX, [rel null_msg]
        mov             TMP_ARG_RBX, [TMP_ARG_RBX]
        jmp             .continue_to_print_null ;this loads the string '(null ptr') then prints it instead

.long_modifier:
        test            qword [LONG_COUNT], 0
        jl              .error_during_handling ;short modifier was used
        cmp             qword [LONG_COUNT], 2
        jge             .error_during_handling ;%llld -> ld

        add             qword [LONG_COUNT], 1
        add             PAT_RDX, 1
        jmp             .before_rejump
.short_modifier:
        ;prevent a case of both long and short
        test            qword [LONG_COUNT], 0
        jg              .error_during_handling ;long modifier was used
        cmp             qword [LONG_COUNT], -2
        jle             .error_during_handling ;%hhhd -> hd

        sub             qword [LONG_COUNT], 1
        add             PAT_RDX, 1
        jmp             .before_rejump

.always_print_sign: ;activates a flag
        mov             byte [ALWAYS_PRINT_SIGN], 1
        add             PAT_RDX, 1
        jmp             .before_rejump 
.left_justify: ;activates a flag
        mov             byte [JUSTIFY_LEFT], 1
        add             PAT_RDX, 1
        jmp             .before_rejump ;continue the pattern (it handles the null terminator), requires that rdx is already pointing to the next char 
.case_alternate: ;activates a flag
        mov             byte [ALTERNATE_FORM], 1
        add             PAT_RDX, 1
        jmp             .before_rejump
.activate_precision: ;activates a flag
        mov             byte [PRECISION_MODE], 1
        add             PAT_RDX, 1
        jmp             .before_rejump




; explaining what these labels are: after_handling or before_rejump
; after handling is used to do the common operation of loading the next symbol before jumping back the the general loop
;before_rejump is used for example in: suppose you have %20s then the part that handles the 20 is first jumped to (handle_len)
; then when that part is done it jumps to before_rejump which then uses the next symbol not to jump to general loop but instead to jump to the handler of the 'd' symbol


;requires that rdx is already pointing to the next char 

.error_during_handling:

.after_handling:
;at this label PAT will be adjusted so it points to the next symbol we don't give a shit about
;move the next symbol we're not responsible of to ah: handled in after_handling
;Then: add 1 to PAT because that's what .normal flow does
        ;advance the char **
        add             ARGS_RCX_PTR, 0x8

        mov             ah, byte [PAT_RDX]
        add             PAT_RDX, 1 ;because the stupid loop does: mov al<ah then load ah<[PAT_RDX]
        jmp             .pat_loop

 ;continue the pattern (it handles the null terminator), requires that rdx is already pointing to the next char 
.before_rejump:
        mov             ah, byte [PAT_RDX]
        jmp             .format_jmppoint


.end_of_format:
        mov             byte [DEST_RDI], 0
    
.return:
        mov             rsp, rbp
        pop             rbx
        pop             rbp
        ret


;*EFFECTIVE_LIMIT_R8 has to be the minimum of DEST_LEN_RSI and [LEN_LIMIT]
;functions that end in _r do not modify any register (unless that is their job)
compute_effective_limit_r:
        push rax
        mov             rax, [LEN_LIMIT]
        test            rax, rax
        jz              .use_global
        cmp             rax, DEST_LEN_RSI
        jg              .use_global
        mov             EFFECTIVE_LIMIT_R8, rax
        jmp             .return

        .use_global:
        mov             EFFECTIVE_LIMIT_R8, DEST_LEN_RSI

        .return:
        pop             rax
        ret
        


;assumes TMP_ARG2_R9 has the base, and rbx has the number
sprint_integer_to_buff_r:

        ;optimize later, registers we dont care about: rax, and maybe others

        push            rdi 
        push            rsi
        push            rdx
        push            rcx
        push            r8
 


        lea             rdi, [DIGITS_BUFF] ;this will not be done directly to the DEST buffer, but using an intermediate one 
        ;(makes it easier, the intermediate one can never overflow)
        mov             rsi, DIGITS_BUFF_SIZE; max length (shouldn't everover flow, unless rdx suddenly becomes a 128bit register)

        mov             rdx, TMP_ARG_RBX

        mov             rcx, TMP_ARG2_R9

        call            itoss


        pop             r8
        pop             rcx
        pop             rdx
        pop             rsi
        pop             rdi

        ret

        





; prototype: rax: long long atois(0,0, RDX: char *)
;local procedure modifies: rdx,rax,rcx,
;uses also: *rbx
;takes the argument in rdx and advances it to the next nondigit (guarentee)
;returns the value in rax
atois:
        %define SIGN_NEGATIVE_BIT_PTR rsp-0x8
        push            rbx

        xor             rax, rax
        xor             rbx, rbx
        mov             rcx, 10
        mov             byte [SIGN_NEGATIVE_BIT_PTR], 0
        mov             bl, byte [rdx]
        cmp             bl, '-' ;in our current use this isn't used as it has a different meaning in printf, but i'm making it support it
        jne             .positive
        mov             byte [SIGN_NEGATIVE_BIT_PTR], 1
        add             rdx, 1
        
        .positive:

        .loop:
        mov             bl, byte [rdx]
        sub             bl, '0' ;this implictly tests for the null terminator
        jl              .end
        cmp             bl, 10
        jge             .end

        imul            rax,rax, 10 ;rcx is = 10
        ;todo is this necessary?
        movzx           rbx, bl
        add             rax, rbx
        add             rdx, 1
        jmp             .loop

        .end:
        mov             bl, [SIGN_NEGATIVE_BIT_PTR]
        test            bl, bl
        jnz             .make_negative
        jmp             .return

        .make_negative:
        neg             rax
        jmp             .return

        .return:
        pop             rbx
        ret

;       integer to string
;       prototype(char *dest, long long size, long long num, long long base)
;                    rdi           rsi             rdx          rcx
;       modifies rdi,rsi,rdx,rcx,rax,r8
;;
; takes these flags ORd with the base, the base is only interepreted as an unsigned byte
;   UNSIGNED_FLAG       
;   UPPERCAPS_FLAG      
;   ALWAYS_PRINT_SIGN_FLAG
;   ALTERNATE_FORM_FLAG
itoss:
;%define BASE_PTR               rsp
%define NUM_PTR                 rsp+0x8
%define ORIGINAL_DEST_PTR       rsp+0x10
%define DIGITS_NEEDED           rsp+0x18
%define FLAGS_RBX               rbx
%define DIGITS_NEEDED_r8        r8
%define BUFFLEN_RSI             rsi
%define NUMBER_RDX              rdx


        push            rbp
        push            rbx
        mov             rbp, rsp
        sub             rsp, 0x20

        mov             qword [ORIGINAL_DEST_PTR], rdi
        mov             FLAGS_RBX, rcx ;contain flags
        and             rcx, 0xFF ;keep only ls8b

;       mov             qword [SIGN_NEGATIVE_BIT_PTR], qword 0

        test            BUFFLEN_RSI, BUFFLEN_RSI
        jle             .cant_fit ;jmp if len <= 0

        test            FLAGS_RBX, UNSIGNED_FLAG
        jnz             .is_positive

        test            NUMBER_RDX, NUMBER_RDX
        jz              .keep_registers ; if zero
        jns             .is_positive ;if positive

        .is_negative:
        mov             byte [rdi], '-'
        add             rdi, 1
        sub             BUFFLEN_RSI, 1
        or              FLAGS_RBX, ALWAYS_PRINT_SIGN_FLAG;to know a sign was printed and add 1 later
        neg             NUMBER_RDX
        jmp             .keep_registers


        .is_positive:
        test            FLAGS_RBX, ALWAYS_PRINT_SIGN_FLAG
        jz              .keep_registers
        ;the always_print_sign flag is active
        mov             byte [rdi], '+'
        add             rdi, 1
        sub             BUFFLEN_RSI, 1


        .keep_registers:

        mov             [NUM_PTR], NUMBER_RDX
        
        xor             DIGITS_NEEDED_r8, DIGITS_NEEDED_r8
        ;find the number log 10 (number of digits), store it in r8
        mov             rax, NUMBER_RDX
        .log_loop:
        add             DIGITS_NEEDED_r8, 1
        xor             rdx,rdx
        div             rcx
        test            rax,rax
        jnz             .log_loop
        

.alternative_form:
        test            FLAGS_RBX, ALTERNATE_FORM_FLAG
        cmp             rcx, 16
        je              .alternative_form_hex
        cmp             rcx, 8
        je              .alternative_form_oct
        cmp             rcx, 2
        je              .alternative_form_bin
        jmp             .no_af
        

.alternative_form_hex:
        cmp             BUFFLEN_RSI, 3
        jl              .no_af

        mov             byte [rdi], '0'
        mov             byte [rdi+1], 'x'
        add             rdi, 2
        sub             BUFFLEN_RSI, 2

        jmp             .no_af

.alternative_form_bin:
        mov             byte [rdi], '0'
        mov             byte [rdi+1], 'b'
        add             rdi, 2
        sub             BUFFLEN_RSI, 2
        jmp             .no_af

.alternative_form_oct:
        cmp             BUFFLEN_RSI, 2
        jl              .no_af


        mov             byte [rdi], '0'
        add             rdi, 1
        sub             BUFFLEN_RSI, 1

        ;implicit jump to .no_af


.no_af:

        cmp             DIGITS_NEEDED_r8, BUFFLEN_RSI
        jge             .cant_fit
        mov             [DIGITS_NEEDED], DIGITS_NEEDED_r8 ;keep a copy to return later

        mov             byte [rdi+DIGITS_NEEDED_r8], 0 ;set the null terminator
        xor             rdx,rdx         
        mov             rax, [NUM_PTR]

        sub             DIGITS_NEEDED_r8, 1 ;initially subtract to point to the char before \0 (we're doing it in reverse)

        .mod_loop:
        div             rcx
        ;handle the case of hex digits
        cmp             dl, 10
        jl              .dec

        .hex:
        sub             dl, 10
        test            FLAGS_RBX, UPPERCAPS_FLAG
        jnz             .hex_upper
        add             dl, 'a'
        jmp             .copy_byte
        .hex_upper:
        add             dl, 'A'
        jmp             .copy_byte
        
        .dec: ; or octal or binary
        add             dl, '0'

        .copy_byte:
        mov             byte [rdi+DIGITS_NEEDED_r8], dl

        xor             rdx, rdx
        sub             DIGITS_NEEDED_r8, 1
        jnl             .mod_loop ;jump while the index is not negative

        add             rdi, [DIGITS_NEEDED] ;now rdi should point to the null terminator
        test            byte [rdi], 0xff
        jz              .end
        mov             rax, 0
        div             rax


        .end:
        ;compute len of string written
        mov             rax, qword [ORIGINAL_DEST_PTR]
        sub             rax, rdi

        jmp             .return

        .cant_fit:
        xor             rax,rax



        .return:

        mov             rsp, rbp
        pop             rbx
        pop             rbp
        ret



;print byte and jmp on buffer full
;example
;       pr_bfjmp        '-', .end

%macro  pr_bfjmp 2
        mov             byte [DEST_RDI] , %1
        add             DEST_RDI, 1
        sub             DEST_LEN_RSI, 1
        jle             %2 ;jmp to second operand if <=1
%endmacro






;       prototype(rdi char * dest, rsi int len, st(0), r10: precision)
;       modifies rax,rbx, rcx, rdi, rsi, r10
;       if precision is 0 then only the integer part will be printed

dtos:
        
        fld             st0 ;keep a copy of the float
        ;when it returns only 1 fpu float should've been consumed, it also need about 5 fpu stack registers space to do its thing
        call            print_float_int
        ;now we will have N = rax, this is the number of zeros
        test            rax,rax
        jle             .frac_part ;if r8 <= 0 (no zeros to print)

        .zeros_loop:
        pr_bfjmp        '0', .dtos_end_pop1
        sub             rax, 1
        jg              .zeros_loop ;while r8 > 0



        .frac_part:
        test            r10,r10 ;precision
        jz              .dtos_end_pop1 ;if precision is 0

        pr_bfjmp        '.', .dtos_end_pop1
        ;this should be operating on the 1 float left we stored earlier
        fld             qword [float_1]
        fxch            ;swap st0 st1
        fprem ;get remainder, which should be the fractional part
        fxch            ;swap st0 st1
        fstp            st0 ;pop, st0 should have the remainder
        fld             qword [float_10]
        fxch
        ; add one to precision because of rounding, example .2393 with a precision of .2 will be printed as 
        ;.239 then the last digit will be replaced with '\0'
        add             r10, 1

        push            r10

        .mul10_loop:
        fmul            st0, st1;st0 = st0 * st1 (10)
        sub             r10, 1
        jnz             .mul10_loop ;while r10 > 0

        pop             r10

        fxch
        fstp            st0 ;pop, now st0 should have the fractional part scaled by precision

        call            print_float_int
        ;at this point all used fpu registers should have been cleared
        cmp             rbx, r10 ;if the number of digits written == original precision + 1 then htere is a useless_digit
        jne             .dtos_end

        .useless_digit:
        ;replace last digit with '\0'
        sub             rdi, 1
        sub             rsi, 1



        .on_bufferfull: ;jumped to when there is 1 byte left
        .dtos_end_pop1:
        fstp            st0
        .dtos_end:
        sub             DEST_LEN_RSI, 1
        mov             byte [DEST_RDI],  0

        ret













float_0:        dq 0.0,
float_1:        dq 1.0,
float_2:        dq 2.0,
float_10:       dq 10.0,



;uses rax,rbx,rcx
;takes st0, saves to rdi, while decrementing and checking rsi
; if a float starts like 123000 then only 123 will be printed and N=3 will be returned
;if a float is 12.32 12 will be printed N=0 will be returned, the fractional part is ignored
;if a float's floor is 0 then 0 will be printed
;returns the number of zeros in rax
;returns the number of written bytes in rbx
;DOESNT PRINT '\0', returns with at least 1 byte left in all conditions (byte reserved for '\0')
print_float_int: 
        %define FLOAT_VAR_R             rsp+0x30
        %define FLOAT_VAR_M             rsp+0x28
        %define FLOAT_VAR_S             rsp+0x20
        %define FLOAT_VAR4              rsp+0x18
        %define NOT_USED                rsp+0x10

        %define INT_VAR_H               rsp+0x8
        %define INT_VAR_TMP             rsp


        %define K_RCX                   rcx ;used as a counter for powers
        %define U_RAX                   rax ;used to convert from floored float to int 
        %define U_EAX                   eax ;used to convert from floored float to int 
        %define N_R8                    r8

        push            rdi ;store the pointer so we later return the length
        sub             rsp, 0x38 ;4 doubles, 2 int, 1 control, 32+16+8 = 56

        ;round to closest int

        fldcw           [FPU_RNDDBL]
        frndint         ;st0 = round(st0)
        fldcw           [FPU_FLRDBL]
        
        xor             K_RCX, K_RCX

        

        ;check if negative
        fld             qword [float_0]
        fucomi
        fstp            st0 ;pop useless
        jb              .positive_flt ;jmp if zero < R :: R >= 0 :: R is positive
        je              .zero_float ; jmp if R == 0
        ;otherwise negative

        ;print sign
        pr_bfjmp        '-', .on_bufferfull_pop1
        fchs            ;change sign
        jmp             .positive_flt

        .zero_float:
        pr_bfjmp        '0', .on_bufferfull_pop1
        jmp             .on_bufferfull_pop1



        .positive_flt:

        mov             rbx, -1 ;n
        mov             rcx, 0 ;k
        ;st0 is our R
        fst             qword [FLOAT_VAR_R]

        fld             qword [float_1] 
        fstp            qword [FLOAT_VAR_M] ; M = 1



        


        ;loop, 
        
        ;we're storing R at st4 (it's already there)
        fld             qword [float_2] ;st3 = 2.0
        ;we're always storing 1.0 in st2 at the beginning of the loop
        fld             qword [float_1] ;st2
        fld             qword [FLOAT_VAR_M] ;st1 this will be the divisor and M at st1
        .loop_spi:
        fld             st3; push st3 (R) again to be st0 (then it stays at st4)
        fprem ;st0 = st0%st1
        fucomi          st2
        jae             .loop_spi_end ; end if remainder < 1.0
        fstp            st0 ; pop useless result
        fmul            st2 ; st2 contains 2.0, so this does st0(previous M) =  st0 * 2.0, 
        ;then the loop will end when we find a power of 2 that f is not divisible by 
        jmp             .loop_spi
        
        ;now m should be the smallest power of 2 that R is indivisible by
        ;we're interested in the power before it
        .loop_spi_end:
        fstp            st0 ;pop useless result
        ;(this should be done in a better way)
        fdiv            st0, st2 ;divide by two because we want the power before it
        fstp            qword [FLOAT_VAR_M]
        ;now st0 contains 1.0, st1 contains 2.0
        fstp            st0 
        fstp            st0
        ;now st0 contains R



        fld             qword [float_10]
        fld             qword [float_1]


        ;find S loop
        .loop_fs:
        fmul            st1 ;st0 = st0*st1 :: S := S * 10
        add             K_RCX, 1
        fld             st0 ;copy of S
        fmul            qword [float_2]
        fld             st3 ;copy of R
        fmul            qword [float_2] ;st0 = R * 2
        fadd            qword [FLOAT_VAR_M]
        fucomi
        jb              .loop_fs_end ;break if (2*R)+M >= 2*s
        ;pop 2 useless results
        fstp            st0 
        fstp            st0 
        jmp             .loop_fs

        
        .loop_fs_end:
        ;pop 2 useless results
        fstp            st0
        fstp            st0
        ;we should have S in st0
        fst             qword [FLOAT_VAR_S]
        ;we will have 10 in st1 which is useful
        ;and R will be in st2
        ;im using the notation :: to mean equivilant to

        sub             K_RCX, 1
        mov             qword [INT_VAR_H], K_RCX
        add             K_RCX, 1

        ;significant digits loop
        .loop_sds:
        sub             K_RCX, 1
        fdiv            st0, st1 ; S = st0 = st0 / st1 (10)
        fld             st2 ; push R so st0 = R
        fdiv            st0, st1 ; floored (R / S) = st0 = st0/st1
        fistp           dword [INT_VAR_TMP] ;store to integer and pop
        ;at this point st0 points to S (this can probably be optimized)
        fld             st2; push R so st0 = R
        fprem           ;st0 = st0%st1 ; R = R % S
        ;st0 is new R, st1 is S, st2 is 10, st3 is old R
        fxch            st3 
        fstp            st0 ;pop old R
        
        fld             st2 ;load new R
        fmul            qword [float_2]

        ;load M
        fld             qword [FLOAT_VAR_M]

        fucomi          
        ja              .loop_sds_end ; !(2R >= M) :: 2R < M :: M > 2R 
        
        ;now st0 = 2R
        fld             qword [float_2]
        fmul            st3 ; st0 = 2 * st3 = 2 * S
        fsub            st1 ; st0 = 2 * S - M
        fxch            ;swap st0, st1 :: swap prev result with M
        fstp            st0 ;throw away M

        fucomi
        jb              .loop_sds_end ; !(2R <= (2S) -M ) :: 2R > 2S - M :: 2S - M < 2R
        

        ;print digit logic
        fstp            st0 ; 2 useless results
        fstp            st0 

        mov             U_EAX, dword [INT_VAR_TMP]
        add             U_EAX, '0'
        pr_bfjmp        al, .on_bufferfull_pop3

        jmp             .loop_sds


        .loop_sds_end:
        ;all branches lead to a useless result in st0, 2R in st1 , st2 = S, st3 = 10, st4 =undefined (exchanged thing), st5=unused
%rep 5
        fstp            st0
%endrep
        ;now st0 = 2R, st1 is S, st2 is 10, st3 is old R
        fucomi
        ja              .sds_u_p_1 ; !(2R <= S) :: 2R > S ;add 1 to u before printing

        mov             U_EAX, dword [INT_VAR_TMP]
        add             U_EAX, '0'
        pr_bfjmp        al, .on_bufferfull_pop0
        jmp             .sds_end


        .sds_u_p_1: ;add1
        mov             U_EAX, dword [INT_VAR_TMP]
        add             U_EAX, '0'
        add             U_EAX, 1
        pr_bfjmp        al, .on_bufferfull_pop0

        ;implicit jmp to .sds_end

        .sds_end:

        add             rsp, 0x38 

        mov             rax, K_RCX ; RAX = N 
        pop             rbx;this is the initial pointer we stored
        neg             rbx
        add             rbx, rdi ; rcx = rdi - initial pointer
        ret


        .on_bufferfull_pop5:
%rep 2
        fstp            st0
%endrep
        .on_bufferfull_pop3:
%rep 2
        fstp            st0
%endrep
        .on_bufferfull_pop1:
        fstp            st0
        .on_bufferfull_pop0: ;jumped to when there is 1 byte left
        jmp             .sds_end



;       prototype(char *src)
;                    rdi
;       modifies rax, rdi, rsi
strlens:
        mov             rsi, rdi ;copy for length       
        mov             al, byte [rsi]
        test            al,al
        jz              .end
        .loop:
        add             rdi, 1
        mov             al, byte [rsi]
        test            al,al
        jnz             .loop
        
        .end:
        sub             rdi, rsi
        mov             rax, rdi
        .return:
        ret
;       prototype(char *dest, char *src)
;                    rdi           rsi
;       uses: rax,rdi,rsi
strcpys:
        push            rdi; for length information
        mov             al, byte [rsi]
        test            al,al
        jz              .end
        .loop:
        mov             byte [rdi], al
        add             rsi, 1
        add             rdi, 1
        mov             al, byte [rsi]
        test            al,al
        jnz             .loop
        
        .end:
        mov             byte [rdi], 0

        .return:
        pop             rsi; the destination original ptr
        sub             rdi, rsi ;rdi has the length
        mov             rax, rdi
        ret
        
        
;       prototype(char *dest, char *src, long long size)
;                    rdi           rsi             rdx
;       always puts \0 unless the size of buffer is 0
;       uses:   rdi,rdx,rsi,rax
;       rdi ends at the new \0, (if size > 0)
strncpys:
        push            rdi ; save to get the length of buffer so we figure out the difference later
        test            rdx,rdx ;if the buff size is zero just return
        jz              .freturn
        mov             al, byte [rsi] ; load first char from src and test
        test            al,al
        jz              .end
        .loop:
        sub             rdx, 1 ; so we can jump when its zero
        test            rdx, rdx ; check destination has enough space
        jz              .end
        mov             byte [rdi], al ; mov char to destination
        add             rsi, 1
        add             rdi, 1
        mov             al, byte [rsi] ;load next char
        test            al,al
        jnz             .loop
        
        .end:
        mov             byte [rdi], 0

        .return:
        ;there might be an off by one error here
        pop             rax; pop the original destination ptr
        mov             rsi, rdi ; 
        sub             rsi, rax ;now rsi has the len
        mov             rax, rsi
        ret
        .freturn:
        pop             rax; pop the length we stored earlier
        mov             rax, -1
        ret

.data:
null_msg                db '(null ptr)'
;fpu control words
FPU_DEFAULT             dw 0x037F
FPU_FLRDBL              dw 0x0E7F ;floor (chop)
FPU_RNDDBL              dw 0x027F ;closest


