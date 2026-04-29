module mini_cpu (
    input wire clk,
    input wire reset,
    output reg done
);
    reg [7:0] pc;
    reg [7:0] acc;
    reg [7:0] instruction;

    reg [7:0] memory [0:255];

    reg [7:0] fetched_instruction;
    reg [7:0] operand_data;
    reg write_en;
    reg [7:0] write_addr;
    reg [7:0] write_data;
    reg [1:0] opcode;
    reg [5:0] addr;

    // Combinational read / decode outputs (next-cycle view)
    reg [7:0] fetched_instruction_comb;
    reg [7:0] operand_data_comb;
    reg next_write_en;
    reg [7:0] next_write_addr;
    reg [7:0] next_write_data;
    reg [1:0] next_opcode;
    reg [5:0] next_addr;

    localparam [1:0] OPC_LOAD = 2'b00;
    localparam [1:0] OPC_STORE = 2'b01;
    localparam [1:0] OPC_ADD = 2'b10;
    localparam [1:0] OPC_HALT = 2'b11;

    // Combinational read & decode: compute next-cycle operands and bypass
    always @(*) begin
        // defaults
        fetched_instruction_comb = memory[pc];
        next_write_en = 1'b0;
        next_write_addr = 8'd0;
        next_write_data = 8'd0;

        next_opcode = fetched_instruction_comb[7:6];
        next_addr = fetched_instruction_comb[5:0];

        if (next_opcode == OPC_STORE) begin
            next_write_en = 1'b1;
            next_write_addr = {2'b00, next_addr};
            next_write_data = acc;
        end

        // operand read with same-cycle bypass
        operand_data_comb = memory[next_addr];
        if (next_write_en && (next_write_addr == {2'b00, next_addr})) begin
            operand_data_comb = next_write_data;
        end

        // fetched instruction bypass (if a store in the same decode would write
        // to the instruction address, present the new data deterministically)
        if (next_write_en && (next_write_addr == pc)) begin
            fetched_instruction_comb = next_write_data;
        end
    end

    // Sequential state updates and memory write (synchronous)
    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'd0;
            acc <= 8'd0;
            instruction <= 8'd0;
            done <= 1'b0;
            // clear write intent
            write_en <= 1'b0;
            write_addr <= 8'd0;
            write_data <= 8'd0;
            opcode <= 2'b00;
            addr <= 6'd0;
        end else if (done) begin
            // Hold state once execution is complete.
            pc <= pc;
            acc <= acc;
            instruction <= instruction;
            done <= done;
        end else begin
            // Latch combinational decode outputs into registers
            instruction <= fetched_instruction_comb;
            opcode <= next_opcode;
            addr <= next_addr;
            operand_data <= operand_data_comb;
            write_en <= next_write_en;
            write_addr <= next_write_addr;
            write_data <= next_write_data;

            if (next_opcode == OPC_HALT) begin
                if (next_addr == 6'b000000) begin
                    done <= 1'b1;
                    pc <= pc;
                end else if (next_addr[5] == 1'b1) begin
                    // 11_1aaaaa : JMP aaaaa
                    pc <= {3'b000, next_addr[4:0]};
                    done <= 1'b0;
                end else begin
                    // 11_0aaaaa : BRZ aaaaa (except 0 which is HALT)
                    if (acc == 8'd0) begin
                        pc <= {3'b000, next_addr[4:0]};
                    end else begin
                        pc <= pc + 8'd1;
                    end
                    done <= 1'b0;
                end
            end else begin
                case (next_opcode)
                    OPC_LOAD: begin
                        acc <= operand_data_comb;
                    end
                    OPC_STORE: begin
                        // Write committed below.
                    end
                    OPC_ADD: begin
                        acc <= acc + operand_data_comb;
                    end
                    default: begin
                    end
                endcase

                // Commit memory write synchronously
                if (next_write_en) begin
                    memory[next_write_addr] <= next_write_data;
                end

                pc <= pc + 8'd1;
                done <= 1'b0;
            end
        end
    end
endmodule
