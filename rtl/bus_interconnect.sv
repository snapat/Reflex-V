module bus_interconnect (
    input  logic        clock,
    input  logic        resetActiveLow,

    // CPU MASTER
    input  logic [31:0] cpuAxiWriteAddress,   input  logic cpuAxiWriteValid,     output logic cpuAxiWriteReady,
    input  logic [31:0] cpuAxiWriteData,      input  logic cpuAxiWriteValidData, output logic cpuAxiWriteReadyData,
    input  logic [31:0] cpuAxiReadAddress,    input  logic cpuAxiReadValid,      output logic cpuAxiReadReady,
    output logic [31:0] cpuAxiReadData,       output logic cpuAxiReadValidData,  input  logic cpuAxiReadReadyData,

    // DMA MASTER
    input  logic [31:0] dmaAxiWriteAddress,   input  logic dmaAxiWriteValid,     output logic dmaAxiWriteReady,
    input  logic [31:0] dmaAxiWriteData,      input  logic dmaAxiWriteValidData, output logic dmaAxiWriteReadyData,
    input  logic [31:0] dmaAxiReadAddress,    input  logic dmaAxiReadValid,      output logic dmaAxiReadReady,
    output logic [31:0] dmaAxiReadData,       output logic dmaAxiReadValidData,  input  logic dmaAxiReadReadyData,

    // SLAVES
    output logic [31:0] romAxiReadAddress,    output logic romAxiReadValid,      input  logic romAxiReadReady,
    input  logic [31:0] romAxiReadData,       input  logic romAxiReadValidData,  output logic romAxiReadReadyData,

    output logic [31:0] ramAxiWriteAddress,   output logic ramAxiWriteValid,     input  logic ramAxiWriteReady,
    output logic [31:0] ramAxiWriteData,      output logic ramAxiWriteValidData, input  logic ramAxiWriteReadyData,
    output logic [31:0] ramAxiReadAddress,    output logic ramAxiReadValid,      input  logic ramAxiReadReady,
    input  logic [31:0] ramAxiReadData,       input  logic ramAxiReadValidData,  output logic ramAxiReadReadyData,

    output logic [31:0] ioAxiWriteAddress,    output logic ioAxiWriteValid,      input  logic ioAxiWriteReady,
    output logic [31:0] ioAxiWriteData,       output logic ioAxiWriteValidData,  input  logic ioAxiWriteReadyData,
    output logic [31:0] ioAxiReadAddress,     output logic ioAxiReadValid,       input  logic ioAxiReadReady,
    input  logic [31:0] ioAxiReadData,        input  logic ioAxiReadValidData,   output logic ioAxiReadReadyData
);

    // --- 1. ARBITRATION ---
    // DMA takes priority; bus returns to CPU only when DMA is idle
    logic activeMasterReg; 
    always_ff @(posedge clock or negedge resetActiveLow) begin
        if (!resetActiveLow) 
            activeMasterReg <= 1'b0;
        else if (activeMasterReg == 0 && (dmaAxiReadValid || dmaAxiWriteValid)) 
            activeMasterReg <= 1'b1;
        else if (activeMasterReg == 1 && (!dmaAxiReadValid && !dmaAxiWriteValid)) 
            activeMasterReg <= 1'b0;
    end

    // --- 2. MASTER MUX ---
    // Routes signals from the active master to the internal bus
    logic [31:0] currAddr_R, currAddr_W, currData_W;
    logic        currValid_R, currValid_W;

    always_comb begin
        if (activeMasterReg == 0) begin // CPU
            currAddr_R  = cpuAxiReadAddress;  currValid_R = cpuAxiReadValid;
            currAddr_W  = cpuAxiWriteAddress; currValid_W = cpuAxiWriteValid;
            currData_W  = cpuAxiWriteData;
        end else begin                 // DMA
            currAddr_R  = dmaAxiReadAddress;  currValid_R = dmaAxiReadValid;
            currAddr_W  = dmaAxiWriteAddress; currValid_W = dmaAxiWriteValid;
            currData_W  = dmaAxiWriteData;
        end
    end

    // --- 3. SLAVE ROUTING & DECODING ---
    always_comb begin
        // Initialize handshakes & outputs to prevent latches
        cpuAxiWriteReady = 1'b1; cpuAxiWriteReadyData = 1'b1; cpuAxiReadReady = 1'b1;
        dmaAxiWriteReady = 1'b1; dmaAxiWriteReadyData = 1'b1; dmaAxiReadReady = 1'b1;
        
        cpuAxiReadData   = 32'h0; dmaAxiReadData   = 32'h0;
        ramAxiWriteValid = 0;     ioAxiWriteValid  = 0; 
        romAxiReadValid  = 0;     ramAxiReadValid  = 0;    ioAxiReadValid  = 0;

        // Broadcast current master lines to all slave address/data ports
        ramAxiWriteAddress = currAddr_W; ramAxiWriteData = currData_W;
        ioAxiWriteAddress  = currAddr_W; ioAxiWriteData  = currData_W;
        ramAxiReadAddress  = currAddr_R; ioAxiReadAddress = currAddr_R;
        romAxiReadAddress  = currAddr_R;

        // Write Demux (Decoded by Bits [30:29])
        if (currValid_W) begin
            if (currAddr_W[30])      ioAxiWriteValid  = 1; // MMIO (0x4000_0000)
            else if (currAddr_W[29]) ramAxiWriteValid = 1; // RAM  (0x2000_0000)
        end

        // Read Demux (Decoded by Bits [30:29])
        if (currValid_R) begin
            if (currAddr_R[30]) begin // MMIO
                ioAxiReadValid = 1;
                if (!activeMasterReg) cpuAxiReadData = ioAxiReadData; else dmaAxiReadData = ioAxiReadData;
            end else if (currAddr_R[29]) begin // RAM
                ramAxiReadValid = 1;
                if (!activeMasterReg) cpuAxiReadData = ramAxiReadData; else dmaAxiReadData = ramAxiReadData;
            end else begin // ROM (0x0000_0000)
                romAxiReadValid = 1;
                if (!activeMasterReg) cpuAxiReadData = romAxiReadData; else dmaAxiReadData = 32'h0;
            end
        end
    end

    // --- 4. STATIC AXI CONTROL FLAGS ---
    assign cpuAxiReadValidData  = 1'b1;
    assign dmaAxiReadValidData  = 1'b1;
    assign ramAxiWriteValidData = 1'b1;
    assign ioAxiWriteValidData  = 1'b1;
    assign romAxiReadReadyData  = 1'b1;
    assign ramAxiReadReadyData  = 1'b1;
    assign ioAxiReadReadyData   = 1'b1;

endmodule