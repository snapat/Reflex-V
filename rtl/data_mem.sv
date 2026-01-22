module data_mem (
    input  logic        clock,
    input  logic [31:0] ramAxiWriteAddress,
    input  logic [31:0] ramAxiWriteData,
    input  logic        ramAxiWriteValid,
    input  logic [31:0] ramAxiReadAddress,
    output logic [31:0] ramAxiReadData
);
    // 4KB RAM
    logic [31:0] ramArray [0:1023];

    always_ff @(posedge clock) begin
        if (ramAxiWriteValid) begin
            // Spy removed for clean output
            ramArray[ramAxiWriteAddress[11:2]] <= ramAxiWriteData;
        end
    end

    assign ramAxiReadData = ramArray[ramAxiReadAddress[11:2]];

endmodule