module regfile (
    input logic clock,
    input logic registerWriteEnable,
    input logic [4:0] readAddress0,
    input logic [4:0] readAddress1, 
    input logic [4:0] writeAddress,
    input logic [31:0] writeData,
    output logic [31:0] readData0,
    output logic [31:0] readData1
);

logic [31:0] registerFile [31:0]; //32 registers, 32 bits each

//On clock positive edge
always_ff @(posedge clock) begin
    if (registerWriteEnable && (writeAddress != 5'b00000)) begin //if enable is ON and writeaddress is not register 0
        registerFile[writeAddress] <= writeData; // write the data into the register that the writeaddress refers to
    end
end

assign readData0 = (readAddress0 == 5'b00000) ? 32'b0 : registerFile[readAddress0];
assign readData1 = (readAddress1 == 5'b00000) ? 32'b0 : registerFile[readAddress1];

endmodule


