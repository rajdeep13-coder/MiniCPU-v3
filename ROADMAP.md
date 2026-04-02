# MiniCPU-v3 Roadmap

This roadmap reflects the next set of practical upgrades after the Day-4 HALT milestone.

## Phase 1: Assembler Labels

- Add symbolic labels for source readability.
- Keep backward compatibility with existing numeric operands.
- Surface clear errors for duplicate and undefined labels.

Status: implemented.

## Phase 2: Data Definitions

- Add assembler directives for embedded bytes and named constants.
- Allow programs to keep small data values beside code where it helps readability.
- Keep the output format compatible with `$readmemh`.

## Phase 3: Control Flow ISA

- Add branch and jump opcodes to the CPU and assembler.
- Support simple loops and conditional execution.
- Update the testbench with programs that use real control flow.

## Phase 4: Regression Coverage

- Add assembler unit tests for syntax and error paths.
- Add CPU integration tests for edge cases, reset behavior, and memory boundaries.
- Expand regression to cover failure diagnostics.

## Phase 5: Documentation and Examples

- Add a short demo guide.
- Add a project report that explains the CPU, ISA, and toolchain.
- Refresh the README with the new workflow and examples.