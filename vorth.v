import os

struct VM {
mut:
	stack []int
}

fn (mut vm VM) push(v int) {
	vm.stack << v
}

fn (mut vm VM) pop() int {
	if vm.stack.len == 0 {
		eprintln("Runtime error: stack underflow")
		exit(1)
	}
	val := vm.stack.last()
	vm.stack.delete_last()
	return val
}

fn plus(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	vm.push(a + b)
}

fn minus(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	vm.push(a - b)
}

fn mult(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	vm.push(a * b)
}

fn div(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	if b == 0 {
		eprintln("Runtime error: division by zero")
		exit(1)
	}
	vm.push(a / b)
}

fn eq(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	if a == b {
		vm.push(1)
	} else {
		vm.push(0)
	}
}

fn print_val(mut vm VM) {
	val := vm.pop()
	print("${val} ")
}

fn simulate_program(input_path string) {
	source := os.read_file(input_path) or {
		eprintln("Error: cannot read file '$input_path'")
		exit(1)
	}
	mut vm := VM{}
	tokens := source.split_any(" \n\t").filter(it.len > 0)

	mut skip_block := false
	mut printed := false

	for i, tok in tokens {
		tok_clean := tok.trim_space()
		if skip_block {
			if tok_clean == "end" {
				skip_block = false
			}
			continue
		}
		match tok_clean {
			"+" { plus(mut vm) }
			"-" { minus(mut vm) }
			"*" { mult(mut vm) }
			"/" { div(mut vm) }
			"=" { eq(mut vm) }
			"." {
				print_val(mut vm)
				printed = true
			}
			"if" {
				cond := vm.pop()
				if cond == 0 {
					skip_block = true
				}
			}
			"end" {}
			else {
				num := tok_clean.int()
				if num.str() == tok_clean {
					vm.push(num)
				} else {
					eprintln("Error in '$input_path' at token #${i+1} ('$tok_clean') — unknown word")
					exit(1)
				}
			}
		}
	}
	if printed {
		println("")
	}
}

fn generate_asm(program string, asm_path string, input_path string) {
	mut assembly := []string{}
	assembly << "extern printf"
	assembly << "global main"
	assembly << "section .data"
	assembly << "    fmt: db \"%d \", 0"
	assembly << "    newline: db 10, 0"
	assembly << "section .text"
	assembly << "main:"

	tokens := program.split_any(" \n\t").filter(it.len > 0)

	mut if_stack := []string{}
	mut label_count := 0
	mut printed := false

	for i, tok in tokens {
		tok_clean := tok.trim_space()
		match tok_clean {
			"+" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    add rax, rbx"
				assembly << "    push rax"
			}
			"-" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    sub rax, rbx"
				assembly << "    push rax"
			}
			"*" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    imul rax, rbx"
				assembly << "    push rax"
			}
			"/" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    cqo"
				assembly << "    idiv rbx"
				assembly << "    push rax"
			}
			"=" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    cmp rax, rbx"
				assembly << "    mov rax, 0"
				assembly << "    sete al"
				assembly << "    push rax"
			}
			"." {
				assembly << "    pop rsi"
				assembly << "    lea rdi, [rel fmt]"
				assembly << "    xor rax, rax"
				assembly << "    call printf"
				printed = true
			}
			"if" {
				label_count++
				label := "skip_${label_count}"
				if_stack << label

				assembly << "    pop rax"
				assembly << "    cmp rax, 0"
				assembly << "    je ${label}"
			}
			"end" {
				if if_stack.len > 0 {
					label := if_stack.last()
					if_stack.delete_last()
					assembly << "${label}:"
				}
			}
			else {
				num := tok_clean.int()
				if num.str() == tok_clean {
					assembly << "    push ${num}"
				} else {
					eprintln("Error in '$input_path' at token #${i+1} ('$tok_clean') — unknown word")
					eprintln("Tokens processed so far: ${tokens[..i+1]}")
					exit(1)
				}
			}
		}
	}

	if printed {
		assembly << "    lea rdi, [rel newline]"
		assembly << "    xor rax, rax"
		assembly << "    call printf"
	}

	assembly << "    mov rax, 0"
	assembly << "    ret"

	os.write_file(asm_path, assembly.join("\n")) or {
		eprintln("Failed to write assembly file: $err")
		exit(1)
	}
}

fn compile_program(input_path string) {
	program := os.read_file(input_path) or {
		eprintln("Error: cannot read file '$input_path'")
		exit(1)
	}
	base := os.file_name(input_path).all_before_last(".")
	asm_path := "${base}.asm"
	obj_path := "${base}.o"
	exe_path := base

	generate_asm(program, asm_path, input_path)

	nasm_res := os.execute("nasm -f elf64 ${asm_path} -o ${obj_path}")
	if nasm_res.exit_code != 0 {
		eprintln("NASM failed for '${asm_path}':\n${nasm_res.output}")
		exit(1)
	}

	gcc_res := os.execute("gcc -no-pie -o ${exe_path} ${obj_path}")
	if gcc_res.exit_code != 0 {
		eprintln("GCC linking failed for '${obj_path}':\n${gcc_res.output}")
		exit(1)
	}

	println("Compiled executable: ${exe_path}")
}

fn main() {
	if os.args.len < 3 {
		println("Usage: v run vorth.v <sim|com> <input_file>")
		exit(1)
	}

	cmd := os.args[1]
	input_path := os.args[2]

	match cmd {
		"sim" { simulate_program(input_path) }
		"com" { compile_program(input_path) }
		else {
			eprintln("Unknown command '$cmd'")
			exit(1)
		}
	}
}
