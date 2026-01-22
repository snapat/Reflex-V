module controller (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic       timerInterrupt, // signal from the hardware timer

    output logic registerWriteEnable,
    output logic aluInputSource,        // 0 = reg b, 1 = immediate
    output logic memoryWriteEnable,
    output logic resultSource,          // 0 = alu result, 1 = memory data
    output logic isBranch,              // tells pc to swap to branch target
    output logic [2:0] aluControlSignal,
    output logic csrWriteEnable,        // saves pc to mepc when we trap
    output logic isTrap,                // forces pc to 0x10 (trap vector)
    output logic isReturn               // forces pc to mepc (return from trap)
);

    // helps us group instructions so we don't have to write 100 if-statements
    logic [1:0] aluOperationCategory;

    // main decoder
    always_comb begin
        // set defaults (reset everything to 0 so we don't accidentally latch)
        registerWriteEnable = 0;
        aluInputSource      = 0;
        memoryWriteEnable   = 0;
        resultSource        = 0;
        isBranch            = 0;
        aluOperationCategory = 2'b00;
        
        // interrupt defaults
        csrWriteEnable      = 0;
        isTrap              = 0;
        isReturn            = 0; // default: we are not returning

        // priority logic (the timer is the boss)
        if (timerInterrupt) begin
            // timer triggered: drop everything and jump to the handler
            isTrap              = 1; // mux selector: jump to 0x10
            csrWriteEnable      = 1; // save where we were (pc) into mepc
            // note: we don't write to regs or memory here, just save state
        end else begin
            // normal mode: decode the opcode like usual
            case (opcode)
                // r-type (math with two registers, like add x1, x2, x3)
                7'b0110011: begin
                    registerWriteEnable = 1; // we are writing back a result
                    aluInputSource      = 0; // use register b
                    memoryWriteEnable   = 0;
                    resultSource        = 0; // result comes from alu
                    isBranch            = 0;
                    aluOperationCategory = 2'b10; // check funct3/7 later
                end
    
                // i-type (math with a constant, like addi x1, x2, 5)
                7'b0010011: begin
                    registerWriteEnable = 1;
                    aluInputSource      = 1; // use the immediate value
                    memoryWriteEnable   = 0;
                    resultSource        = 0;
                    isBranch            = 0;
                    aluOperationCategory = 2'b10; // check funct3 later
                end
    
                // load word (lw x1, offset(x2))
                7'b0000011: begin
                    registerWriteEnable = 1; // need to save the data we read
                    aluInputSource      = 1; // calculate address (reg + imm)
                    memoryWriteEnable   = 0;
                    resultSource        = 1; // result comes from memory (ram)
                    isBranch            = 0;
                    aluOperationCategory = 2'b00; // force add logic
                end
    
                // store word (sw x1, offset(x2))
                7'b0100011: begin
                    registerWriteEnable = 0; // not saving anything to registers
                    aluInputSource      = 1; // calculate address
                    memoryWriteEnable   = 1; // write to ram
                    resultSource        = 0;
                    isBranch            = 0;
                    aluOperationCategory = 2'b00; // force add logic
                end
    
                // branch equal (beq x1, x2, label)
                7'b1100011: begin
                    registerWriteEnable = 0;
                    aluInputSource      = 0; // compare two registers
                    memoryWriteEnable   = 0;
                    resultSource        = 0;
                    isBranch            = 1; // tell pc logic to check zero flag
                    aluOperationCategory = 2'b01; // force sub logic (to compare)
                end
                
                //  system instructions (mret)
                // opcode 1110011 is for environment calls / breaks / returns
                7'b1110011: begin
                    registerWriteEnable = 0;
                    aluInputSource      = 0;
                    memoryWriteEnable   = 0;
                    resultSource        = 0;
                    isBranch            = 0;
                    aluOperationCategory = 2'b00;
                    
                    // this signal tells the pc mux to load from mepc.
                    isReturn = 1; 
                end

                // LUI (Load Upper Immediate) - Critical for 'la sp, ...'
                7'b0110111: begin
                    registerWriteEnable = 1;
                    aluInputSource      = 1; // Use Immediate
                    memoryWriteEnable   = 0;
                    resultSource        = 0; // Select ALU result
                    isBranch            = 0; 
                    aluOperationCategory = 2'b00; // Add
                end

                // JAL (Jump and Link) - Critical for 'call'
                7'b1101111: begin
                    registerWriteEnable = 1; // Save PC+4
                    aluInputSource      = 1; 
                    memoryWriteEnable   = 0;
                    resultSource        = 0; 
                    isBranch            = 1; // Jump!
                    aluOperationCategory = 2'b00;
                end

                // JALR (Jump and Link Register) - Critical for 'ret'
                7'b1100111: begin
                    registerWriteEnable = 1; // Save PC+4
                    aluInputSource      = 1; // Use Imm
                    memoryWriteEnable   = 0;
                    resultSource        = 0;
                    isBranch            = 1; // Jump!
                    aluOperationCategory = 2'b00; // Add (Reg + Imm)
                end
                default: begin
                    // unknown instruction? do nothing.
                    registerWriteEnable = 0;
                    aluInputSource      = 0;
                    memoryWriteEnable   = 0;
                    resultSource        = 0;
                    isBranch            = 0;
                    aluOperationCategory = 2'b00;
                    isReturn            = 0;
                end
            endcase
        end
    end

    // alu decoder
    // this part figures out the specific math operation
    always_comb begin
        case (aluOperationCategory)
            2'b00: aluControlSignal = 3'b000; // force add (used for lw/sw)
            2'b01: aluControlSignal = 3'b001; // force sub (used for beq)
            
            2'b10: begin 
                // it's a "real" math instruction, look at funct3
                case (funct3)
                    // add or sub
                    3'b000: begin
                        // if it's r-type and funct7 has the bit, it's sub
                        if (opcode == 7'b0110011 && funct7[5]) 
                            aluControlSignal = 3'b001; // sub
                        else 
                            aluControlSignal = 3'b000; // add
                    end
                    
                    // slt (set less than)
                    3'b010: aluControlSignal = 3'b101;
                    
                    // or
                    3'b110: aluControlSignal = 3'b011;
                    
                    // and
                    3'b111: aluControlSignal = 3'b010;
                    
                    // xor 
                    3'b100: aluControlSignal = 3'b100;
                    
                    default: aluControlSignal = 3'b000;
                endcase
            end
            
            default: aluControlSignal = 3'b000;
        endcase
    end

endmodule