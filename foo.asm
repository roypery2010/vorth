extern printf
global main
section .bss
    stack: resq 1024
section .data
    fmt: db "%ld ", 0
    newline_fmt: db 10, 0
section .text
main:
    xor rbx, rbx    ; stack pointer index = 0
    ; push 34
    mov qword [stack + rbx*8], 34
    inc rbx
    ; push 35
    mov qword [stack + rbx*8], 35
    inc rbx
    ; plus
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    add rax, [stack + rbx*8]
    mov [stack + rbx*8], rax
    inc rbx
    ; push 420
    mov qword [stack + rbx*8], 420
    inc rbx
    ; equal
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    mov rcx, [stack + rbx*8]
    cmp rcx, rax
    mov rax, 0
    sete al
    mov [stack + rbx*8], rax
    inc rbx
    ; print
    dec rbx
    mov rsi, [stack + rbx*8]
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
    ; print newline for this line
    lea rdi, [rel newline_fmt]
    xor rax, rax
    call printf
    xor rbx, rbx    ; reset stack pointer for next line
    mov eax, 0
    ret