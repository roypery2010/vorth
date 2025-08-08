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
	vm.push(if a == b { 1 } else { 0 })
}

fn gt(mut vm VM) {
	b := vm.pop()
	a := vm.pop()
	vm.push(if a > b { 1 } else { 0 })
}

fn dup(mut vm VM) {
	val := vm.pop()
	vm.push(val)
	vm.push(val)
}

fn print_val(mut vm VM) {
	val := vm.pop()
	print("${val} ")
}

// --- Simulator ---

fn simulate_program(input_path string) {
	source := os.read_file(input_path) or {
		eprintln("Error: cannot read file '$input_path'")
		exit(1)
	}
	mut vm := VM{}
	tokens := source.split_any(" \n\t").filter(it.len > 0)

	mut control_stack := []string{} // "keep", "skip", "while"
	mut while_stack := []int{}      // positions of while tokens for loops
	mut printed := false

	mut i := 0
	for i < tokens.len {
		tok := tokens[i].trim_space()

		// Skipping block
		if control_stack.len > 0 && control_stack.last() == "skip" {
			match tok {
				"if", "while" {
					control_stack << "skip"
				}
				"end" {
					control_stack.delete_last()
					if while_stack.len > 0 {
						while_stack.delete_last()
					}
				}
				"else" {
					if control_stack.len == 0 {
						eprintln("Error: 'else' without matching 'if'")
						exit(1)
					}
					if control_stack.last() == "skip" {
						control_stack.delete_last()
						control_stack << "keep"
					} else {
						control_stack.delete_last()
						control_stack << "skip"
					}
				}
				else {}
			}
			i++
			continue
		}

		match tok {
			"+" { plus(mut vm) }
			"-" { minus(mut vm) }
			"*" { mult(mut vm) }
			"/" { div(mut vm) }
			"=" { eq(mut vm) }
			">" { gt(mut vm) }
			"dup" { dup(mut vm) }
			"." {
				print_val(mut vm)
				printed = true
			}
			"if" {
				cond := vm.pop()
				if cond == 0 {
					control_stack << "skip"
				} else {
					control_stack << "keep"
				}
			}
			"else" {
				if control_stack.len == 0 {
					eprintln("Error: 'else' without matching 'if'")
					exit(1)
				}
				if control_stack.last() == "skip" {
					control_stack.delete_last()
					control_stack << "keep"
				} else {
					control_stack.delete_last()
					control_stack << "skip"
				}
			}
			"end" {
				if control_stack.len == 0 {
					eprintln("Error: 'end' without matching 'if' or 'while'")
					exit(1)
				}
				last_control := control_stack.last()
				control_stack.delete_last()

				if last_control == "while" {
					if while_stack.len == 0 {
						eprintln("Error: while_stack empty at end")
						exit(1)
					}
					loop_start := while_stack.last()
					i = loop_start - 1 // jump back to 'while' token (minus 1 because of i++ below)
				} else if last_control == "skip" || last_control == "keep" {
					// normal if/end, do nothing extra
				} else {
					eprintln("Error: unknown control flow state '$last_control'")
					exit(1)
				}

				if last_control == "while" {
					while_stack.delete_last()
				}
			}
			"while" {
				control_stack << "while"
				while_stack << i
			}
			"do" {
				if control_stack.len == 0 || control_stack.last() != "while" {
					eprintln("Error: 'do' without matching 'while'")
					exit(1)
				}
				cond := vm.pop()
				if cond == 0 {
					// Skip loop body, find matching end
					mut nested := 1
					mut j := i + 1
					for j < tokens.len && nested > 0 {
						t := tokens[j].trim_space()
						if t == "while" {
							nested++
						} else if t == "end" {
							nested--
						}
						j++
					}
					if nested != 0 {
						eprintln("Error: unmatched 'while'/'end' in loop")
						exit(1)
					}
					i = j - 1
					control_stack.delete_last() // pop 'while'
					while_stack.delete_last()
				}
			}
			else {
				num := tok.int()
				if num.str() == tok {
					vm.push(num)
				} else {
					eprintln("Error at token #${i+1} ('$tok') — unknown word")
					exit(1)
				}
			}
		}
		i++
	}

	if printed {
		println("")
	}
}

// --- Compiler ---

struct LoopLabels {
	start string
	end   string
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
	mut else_stack := []string{}
	mut while_stack := []LoopLabels{}
	mut label_count := 0
	mut printed := false

	for i := 0; i < tokens.len; i++ {
		tok := tokens[i].trim_space()

		match tok {
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
			">" {
				assembly << "    pop rbx"
				assembly << "    pop rax"
				assembly << "    cmp rax, rbx"
				assembly << "    mov rax, 0"
				assembly << "    setg al"
				assembly << "    push rax"
			}
			"dup" {
				assembly << "    pop rax"
				assembly << "    push rax"
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
				skip_if_label := "skip_if_${label_count}"
				if_stack << skip_if_label

				assembly << "    pop rax"
				assembly << "    cmp rax, 0"
				assembly << "    je ${skip_if_label}"
			}
			"else" {
				if if_stack.len == 0 {
					eprintln("Error: 'else' without matching 'if' in '$input_path'")
					exit(1)
				}
				label_count++
				skip_else_label := "skip_else_${label_count}"
				else_stack << skip_else_label

				assembly << "    jmp ${skip_else_label}"

				skip_if_label := if_stack.last()
				if_stack.delete_last()
				assembly << "${skip_if_label}:"
			}
			"end" {
				if else_stack.len > 0 {
					skip_else_label := else_stack.last()
					else_stack.delete_last()
					assembly << "${skip_else_label}:"
				} else if if_stack.len > 0 {
					skip_if_label := if_stack.last()
					if_stack.delete_last()
					assembly << "${skip_if_label}:"
				} else if while_stack.len > 0 {
					loop_labels := while_stack.last()
					while_stack.delete_last()
					assembly << "    jmp ${loop_labels.start}"
					assembly << "${loop_labels.end}:"
				} else {
					eprintln("Error: 'end' without matching 'if', 'else', or 'while' in '$input_path'")
					exit(1)
				}
			}
			"while" {
				label_count++
				start_label := "while_${label_count}_start"
				end_label := "while_${label_count}_end"
				while_stack << LoopLabels{start_label, end_label}
				assembly << "${start_label}:"
			}
			"do" {
				if while_stack.len == 0 {
					eprintln("Error: 'do' without matching 'while' in '$input_path'")
					exit(1)
				}
				loop_labels := while_stack.last()
				assembly << "    pop rax"
				assembly << "    cmp rax, 0"
				assembly << "    je ${loop_labels.end}"
			}
			else {
				num := tok.int()
				if num.str() == tok {
					assembly << "    push ${num}"
				} else {
					eprintln("Error in '$input_path' at token #${i+1} ('$tok') — unknown word")
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
