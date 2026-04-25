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
    reg [1:0] opcode;
    reg [5:0] addr;

    localparam [1:0] OPC_LOAD = 2'b00;
    localparam [1:0] OPC_STORE = 2'b01;
    localparam [1:0] OPC_ADD = 2'b10;
    localparam [1:0] OPC_HALT = 2'b11;

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'd0;
            acc <= 8'd0;
            instruction <= 8'd0;
            done <= 1'b0;
        end else if (done) begin
            // Hold state once execution is complete.
            pc <= pc;
            acc <= acc;
            instruction <= instruction;
            done <= done;
        end else begin
            fetched_instruction <= memory[pc];
            instruction <= fetched_instruction;
            opcode = fetched_instruction[7:6];
            addr = fetched_instruction[5:0];

            if (opcode == OPC_HALT) begin
                if (addr == 6'b000000) begin
                    done <= 1'b1;
                    pc <= pc;
                end else if (addr[5] == 1'b1) begin
                    // 11_1aaaaa : JMP aaaaa
                    pc <= {3'b000, addr[4:0]};
                    done <= 1'b0;
                end else begin
                    // 11_0aaaaa : BRZ aaaaa (except 0 which is HALT)
                    if (acc == 8'd0) begin
                        pc <= {3'b000, addr[4:0]};
                    end else begin
                        pc <= pc + 8'd1;
                    end
                    done <= 1'b0;
                end
            end else begin
                case (opcode)
                    OPC_LOAD: begin
                        acc <= memory[addr];
                    end
                    OPC_STORE: begin
                        memory[addr] <= acc;
                    end
                    OPC_ADD: begin
                        acc <= acc + memory[addr];
                    end
                    default: begin
                    end
                endcase

                pc <= pc + 8'd1;
                done <= 1'b0;
                end
        end
    end
endmodule
