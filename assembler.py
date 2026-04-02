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


def parse_instruction(line: str, line_number: int) -> tuple[str, int] | None:
    """Parse one line of assembly into (mnemonic, addr) or return None for blank/comment lines."""
    stripped = line.strip()

    if not stripped:
        return None
    if stripped.startswith("#") or stripped.startswith("//"):
        return None

    no_comment = strip_inline_comment(stripped).strip()
    if not no_comment:
        return None

    parts = no_comment.split()
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
        return mnemonic, 0

    if len(parts) != 2:
        raise AssemblerError(
            f"Line {line_number}: expected '<INSTR> <addr>' or 'HALT', got: {line.rstrip()}"
        )

    addr_text = parts[1]
    if not addr_text.isdigit():
        raise AssemblerError(
            f"Line {line_number}: address must be decimal 0-63, got '{addr_text}'"
        )

    addr = int(addr_text, 10)
    if not (0 <= addr <= 63):
        raise AssemblerError(
            f"Line {line_number}: address out of range (0-63), got {addr}"
        )

    return mnemonic, addr


def is_valid_label(name: str) -> bool:
    """Return True when a token is a valid assembler label."""
    return bool(LABEL_RE.fullmatch(name))


def resolve_operand(operand_text: str, labels: dict[str, int], line_number: int) -> int:
    """Resolve a numeric operand or label name to a 6-bit address."""
    if operand_text.isdigit():
        addr = int(operand_text, 10)
    elif operand_text in labels:
        addr = labels[operand_text]
    else:
        raise AssemblerError(
            f"Line {line_number}: unknown address or label '{operand_text}'"
        )

    if not (0 <= addr <= 63):
        raise AssemblerError(
            f"Line {line_number}: address out of range (0-63), got {addr}"
        )

    return addr


def assemble_lines(lines: list[str]) -> list[tuple[int, str, int]]:
    """Assemble source lines into tuples of (pc, asm_text, machine_byte)."""
    unresolved_program: list[tuple[int, str, str | None, int]] = []
    labels: dict[str, int] = {}
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
        if mnemonic == "HALT":
            addr = 0
            asm_text = "HALT"
        else:
            assert operand_text is not None
            addr = resolve_operand(operand_text, labels, line_number)
            asm_text = f"{mnemonic} {operand_text}"

        machine_byte = (OPCODES[mnemonic] << 6) | addr
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
