extern printf
global main
section .data
    fmt: db "%d ", 0
    newline: db 10, 0
section .text
main:
    push 10
while_1_start:
    pop rax
    push rax
    push rax
    push 0
    pop rbx
    pop rax
    cmp rax, rbx
    mov rax, 0
    setg al
    push rax
    pop rax
    cmp rax, 0
    je while_1_end
    pop rax
    push rax
    push rax
    pop rsi
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
    push 1
    pop rbx
    pop rax
    sub rax, rbx
    push rax
    jmp while_1_start
while_1_end:
    push 6969
    pop rsi
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
    lea rdi, [rel newline]
    xor rax, rax
    call printf
    mov rax, 0
    ret