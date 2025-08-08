import os

struct Vorth {
mut:
	stack []int
}

fn (mut v Vorth) push(val int) {
	v.stack << val
}

fn (mut v Vorth) pop() int {
	if v.stack.len == 0 {
		eprintln('Error: stack underflow on pop()')
		return 0
	}
	return v.stack.pop()
}

fn (mut v Vorth) plus() {
	if v.stack.len < 2 {
		eprintln('Error: not enough elements for +')
		return
	}
	b := v.pop()
	a := v.pop()
	v.push(a + b)
}

fn (mut v Vorth) minus() {
	if v.stack.len < 2 {
		eprintln('Error: not enough elements for -')
		return
	}
	b := v.pop()
	a := v.pop()
	v.push(a - b)
}

fn (mut v Vorth) mult() {
	if v.stack.len < 2 {
		eprintln('Error: not enough elements for *')
		return
	}
	b := v.pop()
	a := v.pop()
	v.push(a * b)
}

fn (mut v Vorth) div() {
	if v.stack.len < 2 {
		eprintln('Error: not enough elements for /')
		return
	}
	b := v.pop()
	if b == 0 {
		eprintln('Error: division by zero')
		v.push(b)
		return
	}
	a := v.pop()
	v.push(a / b)
}

// Print number with trailing space, no newline
fn (mut v Vorth) print() {
	if v.stack.len < 1 {
		eprintln('Error: nothing to print')
		return
	}
	val := v.pop()
	print('$val ')
}

fn (mut v Vorth) simulate_program(program string, filename string) {
	lines := program.split_into_lines()
	for i, line in lines {
		words := line.trim_space().split(' ')
		for word in words {
			match word {
				"+" { v.plus() }
				"-" { v.minus() }
				"*" { v.mult() }
				"/" { v.div() }
				"." { v.print() }
				else {
					num := word.int()
					if num != 0 || word == "0" {
						v.push(num)
					} else {
						eprintln('Error in $filename at line ${i + 1}: Unknown word \'$word\'')
						exit(1)
					}
				}
			}
		}
		println('') // newline after each line
	}
}

fn validate_program(program string, filename string) {
	lines := program.split_into_lines()
	for i, line in lines {
		words := line.trim_space().split(' ')
		for word in words {
			if word !in ['+', '-', '*', '/', '.'] {
				num := word.int()
				if num == 0 && word != "0" {
					eprintln('Error in $filename at line ${i + 1}: Unknown word \'$word\'')
					exit(1)
				}
			}
		}
	}
}

fn generate_asm(program string, asm_path string) {
	mut assembly := []string{}

	assembly << "global main"
	assembly << "extern printf"
	assembly << "section .bss"
	assembly << "stack resq 1024"
	assembly << "section .data"
	assembly << "fmt db \"%ld \", 0"        // number with trailing space
	assembly << "newline_fmt db 10, 0"       // newline

	assembly << "section .text"
	assembly << "main:"
	assembly << "    xor rbx, rbx   ; stack pointer index = 0"

	lines := program.split_into_lines()
	for line in lines {
		words := line.trim_space().split(' ')
		for word in words {
			if word == "+" {
				assembly << "
    ; plus
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    add rax, [stack + rbx*8]
    mov [stack + rbx*8], rax
    inc rbx
				"
			} else if word == "-" {
				assembly << "
    ; minus
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    sub [stack + rbx*8], rax
    inc rbx
				"
			} else if word == "*" {
				assembly << "
    ; multiply
    dec rbx
    mov rax, [stack + rbx*8]
    dec rbx
    imul rax, [stack + rbx*8]
    mov [stack + rbx*8], rax
    inc rbx
				"
			} else if word == "/" {
				assembly << "
    ; divide
    dec rbx
    mov rdi, [stack + rbx*8]  ; divisor
    dec rbx
    mov rax, [stack + rbx*8]  ; dividend
    xor rdx, rdx
    cmp rdi, 0
    je _div_by_zero
    idiv rdi
    mov [stack + rbx*8], rax
    inc rbx
    jmp _div_end
_div_by_zero:
    mov qword [stack + rbx*8], 0
    inc rbx
_div_end:
				"
			} else if word == "." {
				assembly << "
    ; print
    dec rbx
    mov rsi, [stack + rbx*8]
    lea rdi, [rel fmt]
    xor rax, rax
    call printf
				"
			} else {
				num := word.int()
				assembly << "    ; push $num"
				assembly << "    mov qword [stack + rbx*8], $num"
				assembly << "    inc rbx"
			}
		}

		assembly << "
    ; print newline for line
    lea rdi, [rel newline_fmt]
    xor rax, rax
    call printf
    xor rbx, rbx    ; reset stack pointer for next line
		"
	}

	assembly << "    mov rax, 0"
	assembly << "    ret"

	os.write_file(asm_path, assembly.join('\n')) or {
		eprintln('Failed to write asm file: $err')
		exit(1)
	}
}

fn main() {
	args := os.args
	if args.len < 3 {
		eprintln('Usage:')
		eprintln('  For simulation:')
		eprintln('    vorth sim <program_string_or_file>')
		eprintln('  For compilation:')
		eprintln('    vorth com <input_file_path>')
		exit(1)
	}

	mode := args[1]

	if mode == 'sim' {
		input := args[2]
		mut program := ''
		if os.exists(input) && os.is_file(input) {
			program = os.read_file(input) or {
				eprintln('Failed to read input file: $input')
				exit(1)
			}
			program = program.trim_space()
		} else {
			program = input
		}

		mut vorth := Vorth{}
		println('Simulating program:')
		println(program)
		vorth.simulate_program(program, input)

	} else if mode == 'com' {
		input := args[2]

		if !os.exists(input) || !os.is_file(input) {
			eprintln('Input file not found or is not a file: $input')
			exit(1)
		}

		mut program := os.read_file(input) or {
			eprintln('Failed to read input file: $input')
			exit(1)
		}
		program = program.trim_space()

		validate_program(program, input)

		base := os.file_name(input)
		ext := os.file_ext(base)
		output := base[..base.len - ext.len]

		asm_path := '${output}.asm'
		obj_path := '${output}.o'

		generate_asm(program, asm_path)
		println('Generated assembly to $asm_path')

		res := os.execute('nasm -f elf64 $asm_path -o $obj_path')
		if res.exit_code != 0 {
			eprintln('Assembly failed:\n$res.output')
			exit(1)
		}
		println('Assembly successful: $obj_path generated')

		res2 := os.execute('gcc $obj_path -no-pie -o $output -lc')
		if res2.exit_code != 0 {
			eprintln('Linking failed:\n$res2.output')
			exit(1)
		}
		println('Linked executable $output generated')

		// os.rm(asm_path) or {}
		// os.rm(obj_path) or {}

	} else {
		eprintln('Unknown mode: $mode')
		exit(1)
	}
}
