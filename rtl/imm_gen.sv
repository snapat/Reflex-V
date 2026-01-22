module imm_gen(
    input  logic [31:0] instruction,
    output logic [31:0] immediateValue
);
    always_comb begin
        case (instruction[6:0])
            7'b0010011: immediateValue = {{20{instruction[31]}}, instruction[31:20]}; // ADDI (I-Type)
            7'b0000011: immediateValue = {{20{instruction[31]}}, instruction[31:20]}; // LW (I-Type)
            7'b0100011: immediateValue = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // SW (S-Type)
            7'b1100011: immediateValue = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0}; // BEQ (B-Type)
            7'b0110111: immediateValue = {instruction[31:12], 12'b0}; // LUI (U-Type)
            7'b1101111: immediateValue = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0}; // JAL (J-Type)
            7'b1100111: immediateValue = {{20{instruction[31]}}, instruction[31:20]}; // JALR
            default:    immediateValue = 32'b0;
        endcase
    end
endmodule
