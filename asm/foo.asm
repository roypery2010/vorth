global main
extern printf
section .bss
stack resq 1024
section .data
fmt db "%ld ", 0
newline_fmt db 10, 0
section .text
main:
    xor rbx, rbx   ; stack pointer index = 0
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
				

    ; print
    dec rbx
    mov rsi, [stack + rbx*8]
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
				

    ; print newline for line
    lea rdi, [rel newline_fmt]
    xor rax, rax
    call printf
    xor rbx, rbx    ; reset stack pointer for next line
		
    ; push 200
    mov qword [stack + rbx*8], 200
    inc rbx
    ; push 220
    mov qword [stack + rbx*8], 220
    inc rbx

    ; plus
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    add rax, [stack + rbx*8]
    mov [stack + rbx*8], rax
    inc rbx
				

    ; print
    dec rbx
    mov rsi, [stack + rbx*8]
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
				

    ; print newline for line
    lea rdi, [rel newline_fmt]
    xor rax, rax
    call printf
    xor rbx, rbx    ; reset stack pointer for next line
		
    ; push 10
    mov qword [stack + rbx*8], 10
    inc rbx
    ; push 20
    mov qword [stack + rbx*8], 20
    inc rbx

    ; plus
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    add rax, [stack + rbx*8]
    mov [stack + rbx*8], rax
    inc rbx
				

    ; print
    dec rbx
    mov rsi, [stack + rbx*8]
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
				

    ; print newline for line
    lea rdi, [rel newline_fmt]
    xor rax, rax
    call printf
    xor rbx, rbx    ; reset stack pointer for next line
		
    mov rax, 0
    ret