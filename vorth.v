import os

struct Vorth {
mut:
    stack []int
}

fn (mut v Vorth) push(x int) {
    v.stack << x
}

fn (mut v Vorth) pop() int {
    if v.stack.len == 0 {
        eprintln('Error: Stack underflow')
        exit(1)
    }
    val := v.stack.last()
    v.stack.delete_last()
    return val
}

fn (mut v Vorth) plus() {
    if v.stack.len < 2 {
        eprintln('Error: Not enough values for +')
        exit(1)
    }
    b := v.pop()
    a := v.pop()
    v.push(a + b)
}

fn (mut v Vorth) minus() {
    if v.stack.len < 2 {
        eprintln('Error: Not enough values for -')
        exit(1)
    }
    b := v.pop()
    a := v.pop()
    v.push(a - b)
}

fn (mut v Vorth) mult() {
    if v.stack.len < 2 {
        eprintln('Error: Not enough values for *')
        exit(1)
    }
    b := v.pop()
    a := v.pop()
    v.push(a * b)
}

fn (mut v Vorth) div() {
    if v.stack.len < 2 {
        eprintln('Error: Not enough values for /')
        exit(1)
    }
    b := v.pop()
    a := v.pop()
    if b == 0 {
        eprintln('Error: Division by zero')
        exit(1)
    }
    v.push(a / b)
}

fn (mut v Vorth) eq() {
    if v.stack.len < 2 {
        eprintln('Error: Not enough values for =')
        exit(1)
    }
    b := v.pop()
    a := v.pop()
    if a == b {
        v.push(1)
    } else {
        v.push(0)
    }
}

fn (mut v Vorth) print() {
    if v.stack.len == 0 {
        eprintln('Error: Stack empty for print')
        exit(1)
    }
    val := v.pop()
    print('$val ')
}

fn simulate_program(program string, filename string) {
    mut v := Vorth{}
    lines := program.split_into_lines()
    for i, line in lines {
        if line.trim_space() == '' { continue }
        words := line.trim_space().split(' ')
        for word in words {
            match word {
                "+" { v.plus() }
                "-" { v.minus() }
                "*" { v.mult() }
                "/" { v.div() }
                "=" { v.eq() }
                "." { v.print() }
                else {
                    num := word.int()
                    if num != 0 || word == '0' {
                        v.push(num)
                    } else {
                        eprintln('Error in $filename at line ${i + 1}: Unknown word "$word"')
                        exit(1)
                    }
                }
            }
        }
        println('')
    }
}

fn validate_program(program string, filename string) {
    lines := program.split_into_lines()
    for i, line in lines {
        if line.trim_space() == '' { continue }
        words := line.trim_space().split(' ')
        for word in words {
            if word !in ['+', '-', '*', '/', '.', '='] {
                num := word.int()
                if num == 0 && word != '0' {
                    eprintln('Error in $filename at line ${i + 1}: Unknown word "$word"')
                    exit(1)
                }
            }
        }
    }
}

// generate assembly using a memory stack (stack resq 1024), rbx is stack index
fn generate_assembly(program string, asm_path string) {
    mut assembly := []string{}

    assembly << 'extern printf'
    assembly << 'global main'
    assembly << 'section .bss'
    assembly << '    stack: resq 1024'
    assembly << 'section .data'
    assembly << '    fmt: db "%ld ", 0'
    assembly << '    newline_fmt: db 10, 0'
    assembly << 'section .text'
    assembly << 'main:'
    assembly << '    xor rbx, rbx    ; stack pointer index = 0'

    lines := program.split_into_lines()
    for line in lines {
        trimmed := line.trim_space()
        if trimmed == '' { continue }
        words := trimmed.split(' ')
        for word in words {
            if word == '+' {
                assembly << '    ; plus'
                assembly << '    dec rbx'
                assembly << '    mov rax, [stack + rbx*8]'
                assembly << '    dec rbx'
                assembly << '    add rax, [stack + rbx*8]'
                assembly << '    mov [stack + rbx*8], rax'
                assembly << '    inc rbx'
            } else if word == '-' {
                assembly << '    ; minus'
                assembly << '    dec rbx'
                assembly << '    mov rax, [stack + rbx*8]'
                assembly << '    dec rbx'
                assembly << '    sub qword [stack + rbx*8], rax'
                assembly << '    inc rbx'
            } else if word == '*' {
                assembly << '    ; multiply'
                assembly << '    dec rbx'
                assembly << '    mov rax, [stack + rbx*8]'
                assembly << '    dec rbx'
                assembly << '    imul rax, [stack + rbx*8]'
                assembly << '    mov [stack + rbx*8], rax'
                assembly << '    inc rbx'
            } else if word == '/' {
                assembly << '    ; divide'
                assembly << '    dec rbx'
                assembly << '    mov rcx, [stack + rbx*8]   ; divisor'
                assembly << '    dec rbx'
                assembly << '    mov rax, [stack + rbx*8]   ; dividend'
                assembly << '    cqo'
                assembly << '    cmp rcx, 0'
                assembly << '    je .div_by_zero'
                assembly << '    idiv rcx'
                assembly << '    mov [stack + rbx*8], rax'
                assembly << '    inc rbx'
                assembly << '    jmp .div_end'
                assembly << '  .div_by_zero:'
                assembly << '    mov qword [stack + rbx*8], 0'
                assembly << '    inc rbx'
                assembly << '  .div_end:'
            } else if word == '=' {
                assembly << '    ; equal'
                assembly << '    dec rbx'
                assembly << '    mov rax, [stack + rbx*8]'
                assembly << '    dec rbx'
                assembly << '    mov rcx, [stack + rbx*8]'
                assembly << '    cmp rcx, rax'
                assembly << '    mov rax, 0'
                assembly << '    sete al'
                assembly << '    mov [stack + rbx*8], rax'
                assembly << '    inc rbx'
            } else if word == '.' {
                assembly << '    ; print'
                assembly << '    dec rbx'
                assembly << '    mov rsi, [stack + rbx*8]'
                assembly << '    lea rdi, [rel fmt]'
                assembly << '    xor rax, rax'
                assembly << '    call printf'
            } else {
                // assume number
                num := word.int()
                if num != 0 || word == '0' {
                    assembly << "    ; push ${num}"
                    assembly << "    mov qword [stack + rbx*8], ${num}"
                    assembly << "    inc rbx"
                } else {
                    eprintln('Internal error generating asm: unknown token "$word"')
                    exit(1)
                }
            }
        }

        // at end of each source line, print newline and reset stack pointer for next line
        assembly << '    ; print newline for this line'
        assembly << '    lea rdi, [rel newline_fmt]'
        assembly << '    xor rax, rax'
        assembly << '    call printf'
        assembly << '    xor rbx, rbx    ; reset stack pointer for next line'
    }

    // return 0
    assembly << '    mov eax, 0'
    assembly << '    ret'

    os.write_file(asm_path, assembly.join('\n')) or {
        eprintln('Failed to write asm file: $err')
        exit(1)
    }
}

fn compile_program(program string, input string) {
    validate_program(program, input)

    base := os.file_name(input)
    ext := os.file_ext(base)
    output := base[..base.len - ext.len]

    asm_path := '${output}.asm'
    obj_path := '${output}.o'

    generate_assembly(program, asm_path)
    println('Generated assembly to $asm_path')

    // assemble
    res := os.execute('nasm -f elf64 $asm_path -o $obj_path')
    if res.exit_code != 0 {
        eprintln('Assembly failed:\n$res.output')
        exit(1)
    }
    println('Assembly successful: $obj_path generated')

    // link
    res2 := os.execute('gcc $obj_path -no-pie -o $output -lc')
    if res2.exit_code != 0 {
        eprintln('Linking failed:\n$res2.output')
        exit(1)
    }
    println('Linked executable $output generated')

    // keep asm and obj by default; uncomment to remove:
    // os.rm(asm_path) or {}
    // os.rm(obj_path) or {}
}

fn main() {
    if os.args.len < 3 {
        eprintln('Usage: ./vorth <sim|com> <input file>')
        exit(1)
    }

    mode := os.args[1]
    input := os.args[2]

    if !os.exists(input) || !os.is_file(input) {
        eprintln('Error: file "$input" not found or is not a file')
        exit(1)
    }

    mut program := os.read_file(input) or {
        eprintln('Error reading file "$input": $err')
        exit(1)
    }
    program = program.trim_space()

    match mode {
        'sim' {
            simulate_program(program, input)
        }
        'com' {
            compile_program(program, input)
        }
        else {
            eprintln('Unknown mode: $mode (use sim or com)')
            exit(1)
        }
    }
}
