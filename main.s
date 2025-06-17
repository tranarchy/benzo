.text
.global _start

# SYSCALLS

.equ SYS_READ, 0
.equ SYS_WRITE, 1
.equ SYS_OPEN, 2
.equ SYS_CLOSE, 3
.equ SYS_EXIT, 60
.equ SYS_WAIT4, 61
.equ SYS_CHDIR, 80
.equ SYS_PTRACE, 101
.equ SYS_GETDENTS64, 217
.equ SYS_PROCESS_VM_READV, 310

# ASCII

.equ NEWLINE, 10
.equ SPACE, 32
.equ DASH, 45
.equ NUM_0, 48
.equ NUM_9, 57
.equ LOWER_A, 97
.equ LOWER_F, 102

# sys/ptrace.h

.equ PTRACE_PEEKDATA, 2
.equ PTRACE_POKEDATA, 5
.equ PTRACE_ATTACH, 16
.equ PTRACE_DETACH, 17

# sys/wait.h

.equ WUNTRACED, 2

# CONSTS

.equ PATTERN_LEN, 7
.equ BYTE_TO_WRITE, 0xc3

_start:
    mov $SYS_CHDIR, %rax
    mov $proc_dir, %rdi
    syscall

    mov $SYS_OPEN, %rax
    mov $cwd, %rdi
    mov $0, %rsi
    mov $0, %rdx
    syscall

    mov %rax, %r12
    
    mov $0, %r10

loop_getdents:
    mov $SYS_GETDENTS64, %rax
    mov %r12, %rdi
    mov $dirent_buff, %rsi
    mov $8129, %rdx
    syscall

    mov %rax, %rbx

    cmp $0, %rbx 
    jle exit

    lea dirent_buff(%rip), %r13

parse_entry:
    movzwl 16(%r13), %ecx

    xor %r15, %r15
    mov %ecx, %r15d

    # d_name
    mov %r13, %r14
    add $19, %r14

    # d_len
    mov %r15, %rbp
    sub $20, %rbp

    cmp $2, %r10
    jle next_entry

    mov $SYS_CHDIR, %rax
    mov %r14, %rdi
    syscall

    mov $SYS_OPEN, %rax
    mov $cmdline_file, %rdi
    mov $0, %rsi
    mov $0, %rdx
    syscall

    mov %rax, %r9

    cmp $0, %r9
    jl failed_cmdline

    mov $SYS_READ, %rax
    mov %r9, %rdi
    mov $cmdline_buff, %rsi
    mov $512, %rdx
    syscall

    cmp $0, %rax
    jl failed_cmdline

    movq %rax, cmdline_buff_read

    mov $SYS_CLOSE, %rax
    mov %r9, %rdi
    syscall

    mov $0, %r9

strcmp_cmdline_loop:
    mov cmdline_buff_read, %rcx
    sub %r9, %rcx 

    cmp $target_proc_len, %rcx
    jl failed_cmdline

    lea target_proc(%rip), %rsi
    lea cmdline_buff(%rip), %rdi
    add %r9, %rdi

    mov $target_proc_len, %rcx
    repe cmpsb

    je get_pid

    inc %r9
    jmp strcmp_cmdline_loop

failed_cmdline:
    mov $SYS_CHDIR, %rax
    mov $proc_dir, %rdi
    syscall

next_entry:
    inc %r10

    add %r15, %r13
    sub %r15, %rbx

    cmp $0, %rbx
    jg parse_entry

    jmp loop_getdents

get_pid:
    mov $SYS_CLOSE, %rax
    mov %r12, %rdi
    syscall

    mov $0, %rcx
    mov $0, %r15

convert_pid_loop:
    movb (%r14), %al

    cmpb $NUM_0, %al
    jl read_maps_file

    cmpb $NUM_9, %al
    jg read_maps_file

    subb $NUM_0, %al
    movzbq %al, %rcx

    imul $10, %r15
    add %rcx, %r15

    inc %r14
    jmp convert_pid_loop


read_maps_file:
    movq %r15, pid

    mov $SYS_OPEN, %rax
    mov $maps_file, %rdi
    mov $0, %rsi
    mov $0, %rdx
    syscall

    mov %rax, maps_fd

    sub $1, %rsp

    mov $line, %r12

    mov $0, %rbx

read_file_by_line:
    mov $SYS_READ, %rax
    mov maps_fd, %rdi
    mov %rsp, %rsi
    mov $1, %rdx
    syscall

    cmp $0, %rax
    je exit

    inc %rbx

    movzbl (%rsp), %eax

    cmp $NEWLINE, %eax
    je parse_line

    movb %al, (%r12)
    inc %r12

    jmp read_file_by_line

parse_line:
    mov $line, %r12
    mov $start_addr_buff, %r13
    mov $end_addr_buff, %r14
    mov $read_file, %r15

    mov $0, %rcx

get_start_addr:
    movb (%r12), %al

    cmp $DASH, %al
    je got_start_addr

    movb %al, (%r13)

    inc %r12
    inc %r13
    inc %rcx

    jmp get_start_addr

got_start_addr:
    inc %r12
    inc %rcx

get_end_addr:
    movb (%r12), %al

    cmp $SPACE, %al
    je got_end_addr

    movb %al, (%r14)

    inc %r12
    inc %r14
    inc %rcx

    jmp get_end_addr

got_end_addr:
    mov %rbx, %rbp
    sub $target_file_len, %rbp

skip_until_wanted_name:
    cmp %rbp, %rcx
    je start_copy_file_name

    inc %r12
    inc %rcx

    jmp skip_until_wanted_name

start_copy_file_name:
    mov $target_file_len, %rcx
    sub $1, %rcx

copy_file_name:
    cmp $0, %rcx
    je term_file_name

    movb (%r12), %al
    movb %al, (%r15)

    inc %r12
    inc %r15
    dec %rcx

    jmp copy_file_name

term_file_name:
    movb $0, (%r15)

    mov $target_file, %r12
    mov $read_file, %r13

    mov $target_file_len, %rcx

    jmp strcmp_file

clear_line:
    xor %eax, %eax
    mov $32, %rcx
    mov $start_addr_buff, %rdi
    cld
    rep stosb

    xor %eax, %eax
    mov $32, %rcx
    mov $end_addr_buff, %rdi
    cld
    rep stosb

    xor %eax, %eax
    mov %rbx, %rcx
    mov $line, %rdi
    cld
    rep stosb

    mov $line, %r12

    mov $0, %rbx

    jmp read_file_by_line


strcmp_file:
    movb (%r12), %al
    movb (%r13), %bl

    cmp %bl, %al
    jne clear_line

    inc %r12
    inc %r13

    loop strcmp_file

found_file:
    lea start_addr_buff, %r12
    lea start_addr, %r13
    mov $0, %r14


convert_start_addr:
    movzbq (%r12), %rcx
    cmp $0, %cl
    je done_start_addr

    shl $4, %r14

    cmp $NUM_9, %cl
    jle convert_start_digit

    cmp $LOWER_F, %cl
    jle convert_start_alpha

convert_start_digit:
    sub $NUM_0, %cl
    jmp add_to_temp_start

convert_start_alpha:
    sub $LOWER_A, %cl
    add $10, %cl
    jmp add_to_temp_start

add_to_temp_start:
    add %rcx, %r14
    inc %r12

    jmp convert_start_addr

done_start_addr:
    mov %r14, (%r13)

    lea end_addr_buff, %r12
    lea end_addr, %r13
    mov $0, %r14

    jmp convert_end_addr

convert_end_addr:
    movzbq (%r12), %rcx
    cmp $0, %cl
    je done_end_addr

    shl $4, %r14

    cmp $NUM_9, %cl
    jle convert_end_digit

    cmp $LOWER_F, %cl
    jle convert_end_alpha

convert_end_digit:
    sub $NUM_0, %cl
    jmp add_to_temp_end


convert_end_alpha:
    sub $LOWER_A, %cl
    add $10, %cl
    jmp add_to_temp_end

add_to_temp_end:
    add %rcx, %r14
    inc %r12

    jmp convert_end_addr

done_end_addr:
    mov %r14, (%r13)

    movq start_addr, %r12
    movq end_addr, %r13

loop_addr_range:
    cmpq %r12, %r13
    je clear_line

    # bytes left
    movq %r13, %r15
    subq %r12, %r15

    # bytes to read
    movq $1024, %r14
    addq $PATTERN_LEN, %r14
    subq $1, %r14

read_mem:
    subq $32, %rsp

    leaq mem_read_buff(%rip), %rax
    movq %rax, 0(%rsp)
    movq %r14, 8(%rsp)
    movq %r12, 16(%rsp)
    movq %r14, 24(%rsp)

    mov $SYS_PROCESS_VM_READV, %rax
    mov pid, %rdi 
    mov %rsp, %rsi
    mov $1, %rdx
    leaq 16(%rsp), %r10
    movq $1, %r8
    movq $0, %r9
    syscall

    addq $32, %rsp

    movq %rax, bytes_read

    cmpq $0, bytes_read
    jle continue_loop_addr_range

    cmp $PATTERN_LEN, %rax
    jle continue_loop_addr_range

    movq $0, loop_read_mem_cnt
    

loop_read_mem:
    movq loop_read_mem_cnt, %rax

    cmpq %rax, bytes_read
    je continue_loop_addr_range

    movq $0, sig_scan_cnt

    jmp sig_scan

sig_scan:
    movq sig_scan_cnt, %rax

    cmp $PATTERN_LEN - 1, %rax
    je found_match


    movq loop_read_mem_cnt, %rsi
    addq sig_scan_cnt, %rsi

    leaq mem_read_buff(%rip), %rbp
    addq %rsi, %rbp
    movb (%rbp), %al

    leaq pattern_bytes(%rip), %rdi
    addq sig_scan_cnt, %rdi
    movb (%rdi), %bl

    cmp %al, %bl
    jne failed_match

    incq sig_scan_cnt

    jmp sig_scan


found_match:  
    addq loop_read_mem_cnt, %r12
    addq $2, %r12

write_mem:
    mov $SYS_PTRACE, %rax
    mov $PTRACE_ATTACH, %rdi
    mov pid, %rsi
    mov $0, %rdx
    mov $0, %r10
    syscall

    subq $8, %rsp

    mov $SYS_WAIT4, %rax
    mov pid, %rdi
    movq %rsp, %rsi
    mov $WUNTRACED, %rdx
    mov $0, %r10
    syscall

    movq %r12, %r15
    movq %r15, %rbx
    mov $7, %r10
    notq %r10
    andq %r10, %rbx

    movq %r15, %rax
    xorq %rdx, %rdx
    movq $8, %rcx
    divq %rcx
    movq %rdx, %r13

    mov $SYS_PTRACE, %rax
    mov $PTRACE_PEEKDATA, %rdi
    mov pid, %rsi
    movq %rbx, %rdx
    leaq read_word(%rip), %r10
    syscall

    movq read_word, %rbp

    movq $0xFF, %r11
    movq %r13, %rcx
    imulq $8, %rcx
    shlq %cl, %r11
    notq %r11
    andq %r11, %rbp

    mov $BYTE_TO_WRITE, %r11
    movq %r13, %rcx
    imulq $8, %rcx
    shlq %cl, %r11
    orq %r11, %rbp

    mov $SYS_PTRACE, %rax
    mov $PTRACE_POKEDATA, %rdi
    movq pid, %rsi
    movq %rbx, %rdx
    movq %rbp, %r10
    syscall

    mov $SYS_PTRACE, %rax
    mov $PTRACE_DETACH, %rdi
    mov pid, %rsi
    mov $0, %rdx
    mov $0, %r10
    syscall

    mov $SYS_WRITE, %rax
    mov $1, %rdi
    mov $patched_msg, %rsi
    mov $patched_msg_len, %rdx
    syscall

    jmp exit

failed_match:
    incq loop_read_mem_cnt
    jmp loop_read_mem 

continue_loop_addr_range:
    addq $1024, %r12
    jmp loop_addr_range

exit:
    mov $SYS_CLOSE, %rax
    mov maps_fd, %rdi
    syscall

    mov $SYS_EXIT, %rax 
    mov $0, %rdi
    syscall

.bss
    dirent_buff:        .space 8129
    cmdline_buff:       .space 512

    line:               .space 1024
    
    read_file:          .space 256  
    start_addr_buff:    .space 32
    end_addr_buff:      .space 32

    mem_read_buff:      .space 1030 

.data
    target_file:        .asciz "libclient.so"
    target_file_len =.- target_file

    target_proc:        .asciz "cs2"
    target_proc_len =.- target_proc

    cmdline_buff_read:  .quad 0

    pid:                .quad 0

    maps_fd:            .int 0

    start_addr:         .quad 0
    end_addr:           .quad 0

    bytes_read:         .quad 0

    loop_read_mem_cnt:  .quad 0
    sig_scan_cnt:       .quad 0

    read_word:          .quad 0

    pattern_bytes:      .byte 49, 192, 72, 133, 246, 15, 132

    proc_dir:           .asciz "/proc"
    maps_file:          .asciz "maps"
    cmdline_file:       .asciz "cmdline"

    cwd:                .asciz "."

    patched_msg:        .asciz "Patched!\n"
    patched_msg_len =.- patched_msg
