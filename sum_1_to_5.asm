// sum_1_to_5.asm
// Assumes memory[20..24] contain 1,2,3,4,5 and memory[30] starts at 0.
// Program computes 1+2+3+4+5 and stores the result in memory[30].

LOAD 20
ADD 21
ADD 22
ADD 23
ADD 24
STORE 30
