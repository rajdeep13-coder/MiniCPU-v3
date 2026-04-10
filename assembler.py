#!/usr/bin/env python3
"""MiniCPU assembler: converts MiniCPU assembly into .mem hex bytes."""

from __future__ import annotations

import re
import sys
from pathlib import Path


OPCODES = {
    "LOAD": 0b00,
    "STORE": 0b01,
    "ADD": 0b10,
    "HALT": 0b11,
    "BRZ": 0b11,
    "JMP": 0b11,
}


class AssemblerError(Exception):
    """Raised for assembly parsing and encoding errors."""


LABEL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def strip_inline_comment(line: str) -> str:
    """Remove inline comments that begin with // or #."""
    hash_index = line.find("#")
    slash_index = line.find("//")

    cut_points = [idx for idx in (hash_index, slash_index) if idx != -1]
    if not cut_points:
        return line
    return line[: min(cut_points)]


def parse_int_token(token: str) -> int | None:
    """Parse decimal or 0x-prefixed integer tokens, returning None for non-numeric tokens."""
    if token.startswith(("0x", "0X")):
        try:
            return int(token, 16)
        except ValueError:
            return None

    if token.isdigit():
        return int(token, 10)

    return None


def is_valid_label(name: str) -> bool:
    """Return True when a token is a valid assembler label."""
    return bool(LABEL_RE.fullmatch(name))


def resolve_symbol_or_number(
    token: str,
    labels: dict[str, int],
    constants: dict[str, int],
    line_number: int,
) -> int:
    """Resolve token from numeric literal, constant, or label."""
    numeric = parse_int_token(token)
    if numeric is not None:
        return numeric

    if token in constants:
        return constants[token]

    if token in labels:
        return labels[token]

    raise AssemblerError(f"Line {line_number}: unknown symbol '{token}'")


def resolve_address_operand(
    token: str,
    labels: dict[str, int],
    constants: dict[str, int],
    line_number: int,
    upper_bound: int,
) -> int:
    """Resolve address-like operands and enforce range boundaries."""
    addr = resolve_symbol_or_number(token, labels, constants, line_number)
    if not (0 <= addr <= upper_bound):
        raise AssemblerError(
            f"Line {line_number}: address out of range (0-{upper_bound}), got {addr}"
        )
    return addr


def assemble_lines(lines: list[str]) -> list[tuple[int, str, int]]:
    """Assemble source lines into tuples of (pc, asm_text, machine_byte)."""
    unresolved_program: list[tuple[int, str, str | None, int]] = []
    labels: dict[str, int] = {}
    constants: dict[str, int] = {}
    pc = 0

    for line_number, line in enumerate(lines, start=1):
        stripped = strip_inline_comment(line).strip()
        if not stripped:
            continue

        remaining = stripped
        while remaining:
            parts = remaining.split(maxsplit=1)
            token = parts[0]
            if not token.endswith(":"):
                break

            label_name = token[:-1]
            if not is_valid_label(label_name):
                raise AssemblerError(
                    f"Line {line_number}: invalid label '{label_name}'"
                )
            if label_name in labels:
                raise AssemblerError(
                    f"Line {line_number}: duplicate label '{label_name}'"
                )

            labels[label_name] = pc
            remaining = parts[1].strip() if len(parts) > 1 else ""

        if not remaining:
            continue

        parts = remaining.split()
        directive = parts[0].lower() if parts else ""

        if directive == ".const":
            if len(parts) != 3:
                raise AssemblerError(
                    f"Line {line_number}: expected '.const <NAME> <VALUE>'"
                )

            const_name = parts[1]
            const_value_text = parts[2]

            if not is_valid_label(const_name):
                raise AssemblerError(
                    f"Line {line_number}: invalid constant name '{const_name}'"
                )

            if const_name in constants or const_name in labels:
                raise AssemblerError(
                    f"Line {line_number}: duplicate symbol '{const_name}'"
                )

            const_value = parse_int_token(const_value_text)
            if const_value is None:
                raise AssemblerError(
                    f"Line {line_number}: constant value must be decimal or hex, got '{const_value_text}'"
                )

            if not (0 <= const_value <= 255):
                raise AssemblerError(
                    f"Line {line_number}: constant value out of range (0-255), got {const_value}"
                )

            constants[const_name] = const_value
            continue

        if directive == ".byte":
            if len(parts) != 2:
                raise AssemblerError(
                    f"Line {line_number}: expected '.byte <VALUE>'"
                )

            if pc > 255:
                raise AssemblerError("Program too long: PC exceeded 255")

            unresolved_program.append((pc, ".BYTE", parts[1], line_number))
            pc += 1
            continue

        mnemonic = parts[0].upper() if parts else ""
        if mnemonic not in OPCODES:
            valid = ", ".join(OPCODES.keys())
            raise AssemblerError(
                f"Line {line_number}: invalid instruction '{parts[0] if parts else ''}'. Valid instructions: {valid}"
            )

        if mnemonic == "HALT":
            if len(parts) != 1:
                raise AssemblerError(
                    f"Line {line_number}: HALT takes no operand, got: {line.rstrip()}"
                )
            operand_text: str | None = None
        else:
            if len(parts) != 2:
                raise AssemblerError(
                    f"Line {line_number}: expected '<INSTR> <addr>' or 'HALT', got: {line.rstrip()}"
                )
            operand_text = parts[1]

        if pc > 255:
            raise AssemblerError("Program too long: PC exceeded 255")

        unresolved_program.append((pc, mnemonic, operand_text, line_number))
        pc += 1

    program: list[tuple[int, str, int]] = []

    for pc, mnemonic, operand_text, line_number in unresolved_program:
        if mnemonic == ".BYTE":
            assert operand_text is not None
            value = resolve_symbol_or_number(operand_text, labels, constants, line_number)
            if not (0 <= value <= 255):
                raise AssemblerError(
                    f"Line {line_number}: .byte value out of range (0-255), got {value}"
                )
            asm_text = f".byte {operand_text}"
            machine_byte = value
        elif mnemonic == "HALT":
            addr = 0
            asm_text = "HALT"
            machine_byte = 0xC0
        else:
            assert operand_text is not None
            if mnemonic in ("LOAD", "STORE", "ADD"):
                addr = resolve_address_operand(
                    operand_text, labels, constants, line_number, upper_bound=63
                )
                machine_byte = (OPCODES[mnemonic] << 6) | addr
            elif mnemonic == "JMP":
                addr = resolve_address_operand(
                    operand_text, labels, constants, line_number, upper_bound=31
                )
                machine_byte = 0b11100000 | addr
            elif mnemonic == "BRZ":
                addr = resolve_address_operand(
                    operand_text, labels, constants, line_number, upper_bound=31
                )
                machine_byte = 0b11000000 | addr
            else:
                raise AssemblerError(
                    f"Line {line_number}: unsupported instruction '{mnemonic}'"
                )

            asm_text = f"{mnemonic} {operand_text}"

        program.append((pc, asm_text, machine_byte))

    return program


def write_mem_file(program: list[tuple[int, str, int]], output_path: Path) -> None:
    """Write one two-digit hex byte per line for $readmemh."""
    lines = [f"{machine_byte:02X}" for _, _, machine_byte in program]
    output_path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="ascii")


def print_listing_table(program: list[tuple[int, str, int]]) -> None:
    """Print assembly -> machine code -> address mapping."""
    if not program:
        print("No instructions assembled.")
        return

    print("Address  Assembly      Machine(bin)  Hex")
    print("-------  ------------  ------------  ---")
    for pc, asm_text, machine_byte in program:
        print(f"{pc:>7}  {asm_text:<12}  {machine_byte:08b}      {machine_byte:02X}")


def main() -> int:
    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("asm/program.asm")
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("mem/program.mem")

    try:
        source = input_path.read_text(encoding="ascii").splitlines()
        program = assemble_lines(source)
        write_mem_file(program, output_path)

        print(f"Assembled {len(program)} instruction(s) from '{input_path}' -> '{output_path}'")
        print_listing_table(program)
        return 0
    except FileNotFoundError:
        print(f"Error: input file not found: {input_path}", file=sys.stderr)
        return 1
    except AssemblerError as exc:
        print(f"Assembly error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
