extern printf
global main
section .data
    fmt: db "%d ", 0
    newline: db 10, 0
section .text
main:
    push 34
    push 35
    pop rbx
    pop rax
    add rax, rbx
    push rax
    push 69
    pop rbx
    pop rax
    cmp rax, rbx
    mov rax, 0
    sete al
    push rax
    pop rax
    cmp rax, 0
    je skip_if_1
    push 0
    pop rax
    cmp rax, 0
    je skip_if_2
    push 23
    pop rsi
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
    jmp skip_else_3
skip_if_2:
    push 42
    pop rsi
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
skip_else_3:
    jmp skip_else_4
skip_if_1:
    push 420
    pop rsi
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
skip_else_4:
    lea rdi, [rel newline]
    xor rax, rax
    call printf
    mov rax, 0
    ret