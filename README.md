# MiniCPU-v3

MiniCPU-v3 is a compact 8-bit educational CPU project that combines:

- A Verilog CPU core with accumulator architecture
- A Python assembler for converting assembly to machine code
- A simulation testbench with readable cycle-by-cycle logs and waveform dumps

This final Day-4 version includes a proper HALT opcode in the ISA and a cleaned project structure ready for hardware-focused next steps.

## Final Project Structure

```text
MiniCPU-v3/
  assembler.py
  ROADMAP.md
  README.md
  run_regression.ps1
  asm/
    add_two_numbers.asm
    sum_1_to_5.asm
    calculator.asm
    program.asm
  mem/
    add_two_numbers.mem
    sum_1_to_5.mem
    calculator.mem
    program.mem
  src/
    mini_cpu.v
  sim/
    tb_mini_cpu.v
    logs/
      add.log
      sum.log
      calc.log
    waves/
      add.vcd
      sum.vcd
      calc.vcd
```

## ISA Specification

Instruction format is 8 bits total:

- Bits [7:6] are opcode
- Bits [5:0] are address/immediate field

Supported instructions:

- LOAD addr: opcode 00, binary format 00aaaaaa
- STORE addr: opcode 01, binary format 01aaaaaa
- ADD addr: opcode 10, binary format 10aaaaaa
- HALT: opcode 11, binary format 11000000 in assembler output

Address range is 0 to 63 because the operand field is 6 bits.

## Prerequisites

- Python 3.10+ (tested with Python 3.13)
- Icarus Verilog tools:
  - C:/iverilog/bin/iverilog.exe
  - C:/iverilog/bin/vvp.exe
- Optional waveform viewer: GTKWave

## Quick Start

1. Assemble and run all regression tests:

```powershell
.\run_regression.ps1
```

Keep logs/waves even on success:

```powershell
.\run_regression.ps1 -KeepArtifactsOnSuccess
```

2. Expected high-level result:

- add test passes with M[12] = 12
- sum test passes with M[30] = 15
- calc test passes with M[42] = 25

3. Generated outputs:

- On failure: logs in sim/logs/ and waveforms in sim/waves/
- On success: temporary logs/waves are cleaned by default for faster, cleaner runs

## Continuous Integration

GitHub Actions runs regression on every push and pull request:

- Workflow file: `.github/workflows/verilog-regression.yml`
- Uses Ubuntu runner with Icarus Verilog (`iverilog`, `vvp`)
- Executes `run_regression.ps1` in fail-fast mode
- Uploads `sim/logs/` and `sim/waves/` artifacts only when a failure occurs

## Assembler Usage

Default files:

```powershell
python assembler.py
```

Explicit files:

```powershell
python assembler.py asm/program.asm mem/program.mem
```

Assembler behavior:

- Accepts LOAD, STORE, ADD, HALT
- Supports labels in the form `LABEL:` before an instruction
- Supports comments using # and //
- Enforces address range 0 to 63
- Produces one hex byte per line for $readmemh

See [ROADMAP.md](ROADMAP.md) for the next planned phases.

Example output table:

```text
Assembled 4 instruction(s) from 'asm\add_two_numbers.asm' -> 'mem\add_two_numbers.mem'
Address  Assembly      Machine(bin)  Hex
-------  ------------  ------------  ---
      0  LOAD 10       00001010      0A
      1  ADD 11        10001011      8B
      2  STORE 12      01001100      4C
      3  HALT          11000000      C0
```

## Verilog Design Summary

CPU state elements:

- PC: 8-bit program counter
- ACC: 8-bit accumulator
- instruction: current fetched byte
- memory: 256 x 8-bit shared instruction/data memory
- done: high when HALT executes

Execution model:

1. Fetch instruction from memory[PC]
2. Decode opcode/address fields
3. Execute operation on ACC or memory
4. Increment PC for non-HALT instructions
5. Assert done on HALT and hold state

## Simulation and Verification

Testbench features:

- Chooses add/sum/calc program via +TEST plusarg
- Initializes data memory for each scenario
- Prints cycle table with PC, instruction, ACC, and store activity
- Fails with timeout or assertion mismatch

Sample pass summary:

```text
ASSERT PASS (add): M[12]=12
ASSERT PASS (sum): M[30]=15
ASSERT PASS (calc): M[42]=25
```

## Learning Outcomes

This project demonstrates:

- Designing a minimal ISA and encoding format
- Implementing fetch/decode/execute logic in Verilog
- Building a robust assembler-to-hardware workflow
- Using simulation logs and waveforms for debug and validation
- Organizing HDL projects for maintainability and next-phase FPGA work

## Notes

- Additional docs (project report and demo guide) coming soon.
