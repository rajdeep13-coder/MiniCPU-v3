# MiniCPU-v3: 3-Instruction 8-bit Accumulator CPU in Verilog

![Status](https://img.shields.io/badge/Status-Under%20Development-orange)
![Language](https://img.shields.io/badge/HDL-Verilog-blue)
![Assembler](https://img.shields.io/badge/Assembler-Python%203.13-green)
![Architecture](https://img.shields.io/badge/Architecture-von%20Neumann-lightgrey)
![CPU Width](https://img.shields.io/badge/CPU-8--bit-informational)
![ISA](https://img.shields.io/badge/ISA-3%20Instructions-red)
![Memory](https://img.shields.io/badge/Memory-256%20Bytes-purple)
![Simulation](https://img.shields.io/badge/Simulation-Testbench%20Ready-success)

## Project Description

MiniCPU-v3 is a minimal yet fully functional 8-bit von Neumann architecture CPU implemented in Verilog. It supports only three instructions - LOAD, STORE, and ADD - making it an excellent educational project to understand the fundamentals of CPU design, fetch-decode-execute cycle, and hardware description language.

The CPU features an 8-bit Accumulator (ACC), 8-bit Program Counter (PC), and 256 bytes of shared memory. A simple Python-based assembler converts human-readable assembly code into machine code for easy program loading. The design is simulated using a testbench that displays register states and memory changes cycle-by-cycle, with waveform support for debugging.

## Instruction Set Architecture

- LOAD addr  -> Opcode 00 -> 8-bit format: 00xxxxxx (addr = 6 bits)
- STORE addr -> Opcode 01 -> 8-bit format: 01xxxxxx
- ADD addr   -> Opcode 10 -> 8-bit format: 10xxxxxx
- Program execution ends when PC reaches 255

## Repository Contents

- assembler.py: Python assembler that converts assembly into a Verilog-compatible memory file
- program.asm: Default input assembly program
- program.mem: Generated machine code file for readmemh
- add_two_numbers.asm: Sample program to add values at addresses 10 and 11, store at 12
- sum_1_to_5.asm: Sample program to sum values from addresses 20 to 24, store at 30

## Assembler Usage

Run with defaults:

```bash
python assembler.py
```

Run with custom input and output files:

```bash
python assembler.py input.asm output.mem
```

## Output Format

The assembler generates one hex byte per line in the output memory file, compatible with Verilog readmemh:

```text
0A
8B
4C
```

## Development Phase

This project is currently under active development.

Planned next steps include:

- CPU module and control unit integration
- Full fetch-decode-execute validation with testbench
- Additional sample programs and verification cases
- Waveform-based debugging documentation
