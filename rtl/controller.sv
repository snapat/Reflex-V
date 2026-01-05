module controller (
input logic [6:0] opcode,
input logic [2:0] funct3,
input logic [6:0] funct7,

output logic registerWriteEnable,
output logic aluInputSource,        //0 = Register B, 1 = Immediate
output logic memoryWriteEnable,
output logic resultSource,          // 0 = ALU Result, 1 = Memory Data
output logic isBranch,              // Controls 
output logic [2:0] aluControlSignal
);


    // Internal Signal: Tells the ALU Decoder what broad category of math to do
    logic [1:0] aluOperationCategory;

    // --- 1. MAIN DECODER ---
    always_comb begin
        // Default values
        registerWriteEnable = 0;
        aluInputSource      = 0;
        memoryWriteEnable   = 0;
        resultSource        = 0;
        isBranch            = 0;
        aluOperationCategory = 2'b00; 

        case (opcode)
            // R-Type (Math with Registers)
            7'b0110011: begin
                registerWriteEnable = 1;
                aluInputSource      = 0; 
                memoryWriteEnable   = 0;
                resultSource        = 0;
                isBranch            = 0;
                aluOperationCategory = 2'b10; // Look at funct3
            end

            // I-Type (Math with Constants)
            7'b0010011: begin
                registerWriteEnable = 1;
                aluInputSource      = 1;      // Use Immediate
                memoryWriteEnable   = 0;
                resultSource        = 0;
                isBranch            = 0;
                aluOperationCategory = 2'b10; // Look at funct3
            end

            // Load Word (LW)
            7'b0000011: begin
                registerWriteEnable = 1;
                aluInputSource      = 1;      // Add Offset
                memoryWriteEnable   = 0;
                resultSource        = 1;      // From Memory
                isBranch            = 0;
                aluOperationCategory = 2'b00; // Force ADD
            end

            // Store Word (SW)
            7'b0100011: begin
                registerWriteEnable = 0;
                aluInputSource      = 1;      // Add Offset
                memoryWriteEnable   = 1;      // Write RAM
                resultSource        = 0;
                isBranch            = 0;
                aluOperationCategory = 2'b00; // Force ADD
            end

            // Branch Equal (BEQ)
            7'b1100011: begin
                registerWriteEnable = 0;
                aluInputSource      = 0;
                memoryWriteEnable   = 0;
                resultSource        = 0;
                isBranch            = 1;
                aluOperationCategory = 2'b01; // Force SUB
            end
            
            default: begin
                registerWriteEnable = 0;
                aluInputSource      = 0;
                memoryWriteEnable   = 0;
                resultSource        = 0;
                isBranch            = 0;
                aluOperationCategory = 2'b00;
            end
        endcase
    end

    // --- 2. ALU DECODER ---
    always_comb begin
        case (aluOperationCategory)
            2'b00: aluControlSignal = 3'b000; // Force ADD (LW/SW)
            2'b01: aluControlSignal = 3'b001; // Force SUB (BEQ)
            
            2'b10: begin 
                case (funct3)
                    // ADD or SUB
                    3'b000: begin
                        if (opcode == 7'b0110011 && funct7[5]) 
                            aluControlSignal = 3'b001; // SUB
                        else 
                            aluControlSignal = 3'b000; // ADD
                    end
                    
                    // SLT (Set Less Than)
                    // RISC-V funct3 is 010, Your ALU code is 101
                    3'b010: aluControlSignal = 3'b101; 

                    // OR
                    // RISC-V funct3 is 110, Your ALU code is 011
                    3'b110: aluControlSignal = 3'b011; 

                    // AND
                    // RISC-V funct3 is 111, Your ALU code is 010
                    3'b111: aluControlSignal = 3'b010; 

                    // XOR 
                    // RISC-V funct3 is 100, Your ALU code is 100
                    3'b100: aluControlSignal = 3'b100;

                    default: aluControlSignal = 3'b000;
                endcase
            end
            
            default: aluControlSignal = 3'b000;
        endcase
    end

endmodule