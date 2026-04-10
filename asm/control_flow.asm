// control_flow.asm
// Demonstrates Phase 2 (.const, .byte) and Phase 3 (BRZ, JMP).
// If FLAG is zero, store RIGHT to RESULT; otherwise store WRONG.

.const FLAG 25
.const WRONG 26
.const RIGHT 27
.const RESULT 28

LOAD FLAG
BRZ write_right
LOAD WRONG
STORE RESULT
JMP done

write_right:
LOAD RIGHT
STORE RESULT

done:
HALT

sentinel:
.byte 0xAA
