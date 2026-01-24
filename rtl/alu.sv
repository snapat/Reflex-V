module alu (
    input  logic [31:0] inputA,     // Operand A
    input  logic [31:0] inputB,     // Operand B
    input  logic [2:0]  aluControl, // Opcode: determines the operation
    output logic [31:0] aluResult,  
    output logic        zero        // High if aluResult is zero
);

    always_comb begin
        case (aluControl)
            3'b000:  aluResult = inputA + inputB;                 // ADD
            3'b001:  aluResult = inputA - inputB;                 // SUB
            3'b010:  aluResult = inputA & inputB;                 // AND
            3'b011:  aluResult = inputA | inputB;                 // OR
            3'b100:  aluResult = inputA ^ inputB;                 // XOR
            3'b101:  aluResult = (inputA < inputB) ? 32'b1 : 32'b0; // SLT (Set Less Than)
            default: aluResult = 32'b0;                           // Default / NOP
        endcase
    end

    // Status flag logic
    assign zero = (aluResult == 32'b0);

endmodule