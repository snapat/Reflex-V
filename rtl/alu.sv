module alu (
    input logic [31:0] inputA,
    input logic [31:0] inputB,
    input logic [2:0] aluControl, //opcode
    output logic [31:0] aluResult,
    output logic zero // 1 if aluResult == 0
);

always_comb begin
    case (aluControl)
    3'b000: aluResult = inputA + inputB; //ADD
    3'b001: aluResult = inputA - inputB; //SUB
    3'b010: aluResult = inputA & inputB; //AND
    3'b011: aluResult = inputA | inputB; //OR
    3'b100: aluResult = inputA ^ inputB; //XOR
    3'b101: aluResult = (inputA < inputB)? 32'b1: 32'b0; //SLT: set lass than
    default: aluResult = 32'b0; //safe default
    endcase
end

assign zero = (aluResult == 32'b0);

endmodule