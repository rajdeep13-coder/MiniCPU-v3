module mini_cpu (
    input wire clk,
    input wire reset,
    output reg done
);
    reg [7:0] pc;
    reg [7:0] acc;
    reg [7:0] instruction;

    reg [7:0] memory [0:255];

    reg [1:0] opcode;
    reg [5:0] addr;

    localparam [1:0] OPC_LOAD = 2'b00;
    localparam [1:0] OPC_STORE = 2'b01;
    localparam [1:0] OPC_ADD = 2'b10;

    always @(posedge clk) begin
        if (reset) begin
            pc <= 8'd0;
            acc <= 8'd0;
            instruction <= 8'd0;
            done <= 1'b0;
        end else if (done) begin
            pc <= pc;
            acc <= acc;
            instruction <= instruction;
            done <= done;
        end else if (pc == 8'd255) begin
            pc <= pc;
            done <= 1'b1;
        end else begin
            instruction = memory[pc];
            opcode = instruction[7:6];
            addr = instruction[5:0];

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
        end
    end
endmodule
