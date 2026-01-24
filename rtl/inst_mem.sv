module inst_mem (
    // Port A: Instruction Fetch (Dedicated for CPU core)
    input  logic [31:0] romAxiReadAddress, 
    output logic [31:0] romAxiReadData,
    
    // Port B: Data Bus Read (Allows CPU/DMA to read ROM constants)
    input  logic [31:0] busReadAddress,
    output logic [31:0] busReadData
);

    // 4KB ROM: 1024 words (32-bit each) 
    logic [31:0] romArray [0:1023];

    // Initialize memory from hex file at startup 
    initial begin
        $readmemh("firmware/firmware.hex", romArray);
    end

    // Port A Read: Word-aligned indexing using address bits [11:2]
    assign romAxiReadData = romArray[romAxiReadAddress[11:2]];
    
    // Port B Read: Enables "Von Neumann access" to ROM data 
    assign busReadData    = romArray[busReadAddress[11:2]];

endmodule