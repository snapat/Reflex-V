module data_mem (
    input  logic        clock,
    
    // Write Interface (AXI-lite compatible)
    input  logic [31:0] ramAxiWriteAddress, // Byte-address for memory write 
    input  logic [31:0] ramAxiWriteData,    // 32-bit word to be stored 
    input  logic        ramAxiWriteValid,   // Write strobe from bus interconnect 
    
    // Read Interface
    input  logic [31:0] ramAxiReadAddress,  // Byte-address for memory read 
    output logic [31:0] ramAxiReadData      // 32-bit word output to bus 
);

    // 4KB RAM: 1024 words of 32 bits each 
    logic [31:0] ramArray [0:1023];

    // Synchronous Write Logic: Updates RAM on the positive clock edge 
    always_ff @(posedge clock) begin
        if (ramAxiWriteValid) begin
            // Address bits [11:2] select the word index (stripping byte-offset) 
            ramArray[ramAxiWriteAddress[11:2]] <= ramAxiWriteData;
        end
    end

    // Asynchronous Read Logic: Provides immediate data based on address 
    assign ramAxiReadData = ramArray[ramAxiReadAddress[11:2]];

endmodule