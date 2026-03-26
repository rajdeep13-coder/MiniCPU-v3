`timescale 1ns/1ps

module tb_mini_cpu;
    reg clk;
    reg reset;
    wire done;

    integer i;
    integer cycle;

    mini_cpu dut (
        .clk(clk),
        .reset(reset),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #50 clk = ~clk; // 10 MHz clock (100 ns period)
    end

    initial begin
        $dumpfile("mini_cpu.vcd");
        $dumpvars(0, tb_mini_cpu.dut);
    end

    initial begin
        reset = 1'b1;

        for (i = 0; i < 256; i = i + 1) begin
            dut.memory[i] = 8'h00;
        end

        $readmemh("program.mem", dut.memory);

        // Hand-coded data for add-two-numbers program:
        // LOAD 10; ADD 11; STORE 12
        dut.memory[8'd10] = 8'd7;
        dut.memory[8'd11] = 8'd5;

        repeat (3) @(posedge clk);
        reset = 1'b0;

        begin : run_loop
            for (cycle = 0; cycle < 300; cycle = cycle + 1) begin
                @(posedge clk);
                $display(
                    "cycle=%0d pc=%0d instr=0x%02h acc=%0d mem[12]=%0d done=%0b",
                    cycle,
                    dut.pc,
                    dut.instruction,
                    dut.acc,
                    dut.memory[8'd12],
                    done
                );

                if (done) begin
                    $display("CPU done asserted at cycle %0d", cycle);
                    disable run_loop;
                end
            end
        end

        $display("Final: pc=%0d acc=%0d mem[12]=%0d done=%0b", dut.pc, dut.acc, dut.memory[8'd12], done);
        $finish;
    end
endmodule
