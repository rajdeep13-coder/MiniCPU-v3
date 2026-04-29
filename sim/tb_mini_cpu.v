`timescale 1ns/1ps

module tb_mini_cpu;
    reg clk;
    reg reset;
    wire done;

    string test_mode;
    string mem_file;
    integer expected_result;
    integer result_addr;
    integer program_len;

    integer cycle;
    integer i;

    reg [7:0] prev_mem_result;
    reg [7:0] curr_instr;
    reg [5:0] curr_addr;

    mini_cpu dut (
        .clk(clk),
        .reset(reset),
        .done(done)
    );

    // Decode instruction for readable cycle logs.
    function string instr_mnemonic;
        input [7:0] instr;
        begin
            if (instr[7:6] == 2'b11) begin
                if (instr[5:0] == 6'b000000) begin
                    instr_mnemonic = "HALT";
                end else if (instr[5] == 1'b1) begin
                    instr_mnemonic = "JMP";
                end else begin
                    instr_mnemonic = "BRZ";
                end
            end else begin
                case (instr[7:6])
                    2'b00: instr_mnemonic = "LOAD";
                    2'b01: instr_mnemonic = "STORE";
                    2'b10: instr_mnemonic = "ADD";
                    default: instr_mnemonic = "UNK";
                endcase
            end
        end
    endfunction

    task print_header;
        begin
            $display("==============================================================================================");
            $display(" Cycle |  PC  | Instruction           |   ACC(dec/hex)   | Memory Activity");
            $display("----------------------------------------------------------------------------------------------");
        end
    endtask

    task print_cycle_row;
        input integer cyc;
        input [7:0] pc_value;
        input [7:0] instr;
        input [7:0] acc_value;
        begin
            if (instr[7:6] == 2'b01) begin
                $display(
                    " %5d | %4d | %-5s %2d (0x%02h) | %6d / 0x%02h    | STORE -> M[%0d] = %0d (0x%02h)",
                    cyc,
                    pc_value,
                    instr_mnemonic(instr),
                    instr[5:0],
                    instr,
                    acc_value,
                    acc_value,
                    instr[5:0],
                    dut.memory[instr[5:0]],
                    dut.memory[instr[5:0]]
                );
            end else if ((instr[7:6] == 2'b11) && (instr[5:0] == 6'b000000)) begin
                $display(
                    " %5d | %4d | HALT      (0x%02h)    | %6d / 0x%02h    | done asserted",
                    cyc,
                    pc_value,
                    instr,
                    acc_value,
                    acc_value
                );
            end else begin
                $display(
                    " %5d | %4d | %-5s %2d (0x%02h) | %6d / 0x%02h    | -",
                    cyc,
                    pc_value,
                    instr_mnemonic(instr),
                    instr[5:0],
                    instr,
                    acc_value,
                    acc_value
                );
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #50 clk = ~clk; // 100 ns period
    end

    initial begin
        $dumpfile("sim/mini_cpu.vcd");
        $dumpvars(0, tb_mini_cpu);
    end

    initial begin
        reset = 1'b1;
        cycle = 0;

        if (!$value$plusargs("TEST=%s", test_mode)) begin
            test_mode = "add";
        end

        if (test_mode == "sum") begin
            mem_file = "mem/sum_1_to_5.mem";
            expected_result = 15;
            result_addr = 30;
            program_len = 7;
        end else if (test_mode == "branch") begin
            mem_file = "mem/control_flow.mem";
            expected_result = 7;
            result_addr = 28;
            program_len = 9;
        end else if (test_mode == "calc") begin
            mem_file = "mem/calculator.mem";
            expected_result = 25;
            result_addr = 42;
            program_len = 4;
        end else if (test_mode == "storeload") begin
            mem_file = "mem/store_load.mem";
            expected_result = 42;
            result_addr = 30;
            program_len = 4;
        end else begin
            test_mode = "add";
            mem_file = "mem/add_two_numbers.mem";
            expected_result = 12;
            result_addr = 12;
            program_len = 4;
        end

        for (i = 0; i < 256; i = i + 1) begin
            dut.memory[i] = 8'h00;
        end

        $readmemh(mem_file, dut.memory, 0, program_len - 1);

        if (test_mode == "sum") begin
            dut.memory[8'd20] = 8'd1;
            dut.memory[8'd21] = 8'd2;
            dut.memory[8'd22] = 8'd3;
            dut.memory[8'd23] = 8'd4;
            dut.memory[8'd24] = 8'd5;
            dut.memory[8'd30] = 8'd0;
        end else if (test_mode == "branch") begin
            dut.memory[8'd25] = 8'd0;
            dut.memory[8'd26] = 8'd99;
            dut.memory[8'd27] = 8'd7;
            dut.memory[8'd28] = 8'd0;
        end else if (test_mode == "calc") begin
            dut.memory[8'd40] = 8'd9;
            dut.memory[8'd41] = 8'd16;
            dut.memory[8'd42] = 8'd0;
        end else if (test_mode == "storeload") begin
            // initialize data: source at addr 20 = 42, target addr 30 = 0
            dut.memory[8'd20] = 8'd42;
            dut.memory[8'd30] = 8'd0;
        end else begin
            dut.memory[8'd10] = 8'd7;
            dut.memory[8'd11] = 8'd5;
            dut.memory[8'd12] = 8'd0;
        end

        prev_mem_result = dut.memory[result_addr];

        $display("\nStarting TEST=%0s, program=%0s, expected M[%0d]=%0d", test_mode, mem_file, result_addr, expected_result);
        print_header();

        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        while (!done && (cycle < 200)) begin
            @(negedge clk);
            curr_instr = dut.instruction;
            curr_addr = curr_instr[5:0];
            print_cycle_row(cycle, dut.pc, curr_instr, dut.acc);

            if ((curr_instr[7:6] == 2'b01) && (dut.memory[curr_addr] != prev_mem_result)) begin
                $display("         *** memory change detected: M[%0d] now %0d (0x%02h)", curr_addr, dut.memory[curr_addr], dut.memory[curr_addr]);
            end

            prev_mem_result = dut.memory[result_addr];
            cycle = cycle + 1;
        end

        if (!done) begin
            $fatal(1, "Timeout waiting for done. TEST=%0s", test_mode);
        end

        $display("----------------------------------------------------------------------------------------------");
        $display("Done at cycle %0d. Final: PC=%0d ACC=%0d (0x%02h) M[%0d]=%0d", cycle, dut.pc, dut.acc, dut.acc, result_addr, dut.memory[result_addr]);

        if (dut.memory[result_addr] !== expected_result[7:0]) begin
            $fatal(1, "ASSERT FAIL (%0s): M[%0d]=%0d expected %0d", test_mode, result_addr, dut.memory[result_addr], expected_result);
        end else begin
            $display("ASSERT PASS (%0s): M[%0d]=%0d", test_mode, result_addr, dut.memory[result_addr]);
        end

        $finish;
    end
endmodule
