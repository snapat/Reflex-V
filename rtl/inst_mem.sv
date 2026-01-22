module inst_mem (
    input  logic [31:0] romAxiReadAddress,
    output logic [31:0] romAxiReadData,
    
    input  logic [31:0] busReadAddress,
    output logic [31:0] busReadData
);
    logic [31:0] romArray [0:1023];

    initial begin
        $readmemh("firmware/firmware.hex", romArray);
    end

    // Port A: Instruction Fetch
    assign romAxiReadData = romArray[romAxiReadAddress[11:2]];
    
    // Port B: Data Bus Read
    assign busReadData = romArray[busReadAddress[11:2]];

endmodule