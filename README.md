# Vorth — A Forth-like Programming Language in V

Vorth is a simple stack-based programming language inspired by Forth, implemented in the V programming language. It supports basic arithmetic, stack operations, control flow constructs (`if`, `else`, `while`, `do`, `end`), and allows simulating or compiling Vorth programs to x86-64 assembly with NASM and GCC.

---

## Features

- Stack-based operations: `+`, `-`, `*`, `/`, `=`, `>`, `dup`, `.`
- Control flow: `if`, `else`, `end`
- Looping constructs: `while`, `do`, `end`
- Simulation mode to run Vorth programs directly
- Compilation mode to generate assembly, object file, and executable
- Supports nested control flow and loops
- Clear error reporting on syntax and runtime errors

---

## Requirements

- [V programming language](https://vlang.io/) compiler
- NASM assembler
- GCC compiler (for linking)

---

## Usage

Compile and run the Vorth interpreter/compiler:

```bash
v run vorth.v <command> <input_file>
