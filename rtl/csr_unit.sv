module csr_unit (
    input  logic        clock,
    input  logic        resetActiveLow,
    
    // Hardware Trap Interface
    input  logic        csrWriteEnable, // Signal from Controller to capture PC
    input  logic [31:0] pcFromCore,     // Current PC to be saved
    
    // Software Bus Interface (MMIO: 0x40000010)
    input  logic        busWriteEnable, // Write request from Bus Interconnect
    input  logic [31:0] busWriteData,   // Data from Bus Interconnect
    
    // Output to Program Counter Logic
    output logic [31:0] mepcValue       // Value stored in MEPC register
);

    logic [31:0] mepc;

    // MEPC Register Logic
    always_ff @(posedge clock or negedge resetActiveLow) begin
        if (!resetActiveLow) begin
            mepc <= 32'h00000000;
        end 
        // PRIORITY: Software writes via Bus override Hardware Traps
        else if (busWriteEnable) begin
            mepc <= busWriteData;
        end 
        // CAPTURE: Hardware saves PC during a Trap/Interrupt
        else if (csrWriteEnable) begin
            mepc <= pcFromCore;
        end
    end

    // Continuous assignment to output
    assign mepcValue = mepc;

endmodule