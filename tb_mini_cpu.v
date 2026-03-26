`timescale 1ns/1ps

module tb_mini_cpu;
    reg clk;
    reg reset;
    wire done;
    string test_mode;
    string mem_file;
    integer expected_result;
    integer result_addr;
    integer target_cycle;

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

        if (!$value$plusargs("TEST=%s", test_mode)) begin
            test_mode = "add";
        end

        if (test_mode == "sum") begin
            mem_file = "sum_1_to_5.mem";
            expected_result = 15;
            result_addr = 30;
            target_cycle = 12;
        end else begin
            test_mode = "add";
            mem_file = "program.mem";
            expected_result = 12;
            result_addr = 12;
            target_cycle = 8;
        end

        for (i = 0; i < 256; i = i + 1) begin
            dut.memory[i] = 8'h00;
        end

        $readmemh(mem_file, dut.memory);

        if (test_mode == "sum") begin
            // Data for sum_1_to_5 program:
            // LOAD 20; ADD 21; ADD 22; ADD 23; ADD 24; STORE 30
            dut.memory[8'd20] = 8'd1;
            dut.memory[8'd21] = 8'd2;
            dut.memory[8'd22] = 8'd3;
            dut.memory[8'd23] = 8'd4;
            dut.memory[8'd24] = 8'd5;
            dut.memory[8'd30] = 8'd0;
        end else begin
            // Data for add-two-numbers program:
            // LOAD 10; ADD 11; STORE 12
            dut.memory[8'd10] = 8'd7;
            dut.memory[8'd11] = 8'd5;
            dut.memory[8'd12] = 8'd0;
        end

        $display(
            "Starting TEST=%0s mem=%0s expected memory[%0d]=%0d by cycle %0d",
            test_mode,
            mem_file,
            result_addr,
            expected_result,
            target_cycle
        );

        repeat (3) @(posedge clk);
        reset = 1'b0;

        begin : run_loop
            for (cycle = 0; cycle < 300; cycle = cycle + 1) begin
                @(posedge clk);
                $display(
                    "cycle=%0d pc=%0d instr=0x%02h acc=%0d mem[%0d]=%0d done=%0b",
                    cycle,
                    dut.pc,
                    dut.instruction,
                    dut.acc,
                    result_addr,
                    dut.memory[result_addr],
                    done
                );

                if (cycle == target_cycle) begin
                    if (dut.memory[result_addr] !== expected_result[7:0]) begin
                        $fatal(
                            1,
                            "ASSERT FAIL (%0s): memory[%0d]=%0d, expected %0d at cycle %0d",
                            test_mode,
                            result_addr,
                            dut.memory[result_addr],
                            expected_result,
                            cycle
                        );
                    end else begin
                        $display(
                            "ASSERT PASS (%0s): memory[%0d]=%0d at cycle %0d",
                            test_mode,
                            result_addr,
                            dut.memory[result_addr],
                            cycle
                        );
                    end
                end

                if (done) begin
                    $display("CPU done asserted at cycle %0d", cycle);
                    disable run_loop;
                end
            end
        end

        $display(
            "Final: TEST=%0s pc=%0d acc=%0d mem[%0d]=%0d done=%0b",
            test_mode,
            dut.pc,
            dut.acc,
            result_addr,
            dut.memory[result_addr],
            done
        );
        $finish;
    end
endmodule
