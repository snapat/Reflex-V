module pc_reg(
    input  logic        clock,
    input  logic        resetActiveLow,     // Synchronous reset to 0x00000000
    input  logic        enable,             // PC update enable (stall control)
    input  logic [31:0] nextProgramCounter, // Target address for the next cycle
    output logic [31:0] programCounter      // Current instruction address
);

    always_ff @(posedge clock or negedge resetActiveLow) begin
        if (!resetActiveLow) 
            // Reset PC to 0x00000000 per CPU specifications
            programCounter <= 32'h00000000;
        else if (enable)  
            // Update PC with the next address when enabled
            programCounter <= nextProgramCounter;
    end

endmodule