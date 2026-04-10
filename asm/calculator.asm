// calculator.asm
// Simple calculator flow:
// LOAD A from memory[40]
// ADD  B from memory[41]
// STORE result to memory[42]

.const A 40
.const B 41
.const RESULT 42

LOAD A
ADD B
STORE RESULT
HALT
