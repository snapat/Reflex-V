module controller (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic       timerInterrupt,      // Preemption signal from hardware timer

    output logic       registerWriteEnable, // Enables register file updates
    output logic       aluInputSource,      // 0: reg b, 1: immediate
    output logic       memoryWriteEnable,   // Enables RAM/MMIO writes
    output logic       resultSource,        // 0: ALU result, 1: memory data
    output logic       isBranch,            // High for Jumps/Branches
    output logic [2:0] aluControlSignal,    // 3-bit opcode for the ALU
    output logic       csrWriteEnable,      // Captures current PC to MEPC on traps
    output logic       isTrap,              // High forces jump to 0x00000010
    output logic       isReturn             // High forces jump to MEPC (MRET)
);

    logic [1:0] aluOperationCategory;

    // --- 1. MAIN INSTRUCTION DECODER ---
    always_comb begin
        // Reset defaults to prevent unintended latches
        registerWriteEnable  = 0;
        aluInputSource       = 0;
        memoryWriteEnable    = 0;
        resultSource         = 0;
        isBranch             = 0;
        aluOperationCategory = 2'b00;
        csrWriteEnable       = 0;
        isTrap               = 0;
        isReturn             = 0;

        // Hardware Preemption: Timer takes absolute priority over decoding
        if (timerInterrupt) begin
            isTrap         = 1;
            csrWriteEnable = 1;
        end else begin
            case (opcode)
                7'b0110011: begin // R-TYPE
                    registerWriteEnable  = 1;
                    aluInputSource       = 0;
                    aluOperationCategory = 2'b10;
                end
                7'b0010011: begin // I-TYPE
                    registerWriteEnable  = 1;
                    aluInputSource       = 1;
                    aluOperationCategory = 2'b10;
                end
                7'b0000011: begin // LW
                    registerWriteEnable  = 1;
                    aluInputSource       = 1;
                    resultSource         = 1;
                end
                7'b0100011: begin // SW
                    memoryWriteEnable    = 1;
                    aluInputSource       = 1;
                end
                7'b1100011: begin // BEQ
                    isBranch             = 1;
                    aluOperationCategory = 2'b01; // Force SUB for comparison
                end
                7'b1110011: begin // MRET
                    isReturn             = 1;
                end
                7'b0110111: begin // LUI
                    registerWriteEnable  = 1;
                    aluInputSource       = 1;
                end
                7'b1101111: begin // JAL
                    registerWriteEnable  = 1;
                    isBranch             = 1;
                    aluInputSource       = 1;
                end
                7'b1100111: begin // JALR
                    registerWriteEnable  = 1;
                    isBranch             = 1;
                    aluInputSource       = 1;
                end
                default: ; // Defaults handled above
            endcase
        end
    end

    // --- 2. ALU OPERATION DECODER ---
    always_comb begin
        case (aluOperationCategory)
            2'b00: aluControlSignal = 3'b000; // Force ADD
            2'b01: aluControlSignal = 3'b001; // Force SUB
            2'b10: begin 
                case (funct3)
                    3'b000:  aluControlSignal = (opcode == 7'b0110011 && funct7[5]) ? 3'b001 : 3'b000;
                    3'b010:  aluControlSignal = 3'b101; // SLT
                    3'b110:  aluControlSignal = 3'b011; // OR 
                    3'b111:  aluControlSignal = 3'b010; // AND
                    3'b100:  aluControlSignal = 3'b100; // XOR
                    default: aluControlSignal = 3'b000;
                endcase
            end
            default: aluControlSignal = 3'b000;
        endcase
    end

endmodule