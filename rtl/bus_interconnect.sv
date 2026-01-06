/*
 * MEMORY MAP:
 * - 0x00xx_xxxx -> Instruction RAM (ROM) - (Bit 30=0, Bit 29=0)
 * - 0x20xx_xxxx -> Data RAM              - (Bit 30=0, Bit 29=1)
 * - 0x40xx_xxxx -> MMIO (UART/GPIO)      - (Bit 30=1)
 */

module bus_interconnect (
    input  logic        clock,
    input  logic        resetActiveLow,

    // MASTERS
    // --- Master 0: CPU Core ---
    // Write Address Channel
    input  logic [31:0] cpuAxiWriteAddress, 
    input  logic        cpuAxiWriteValid,    
    output logic        cpuAxiWriteReady,
    // Write Data Channel
    input  logic [31:0] cpuAxiWriteData,     
    input  logic        cpuAxiWriteValidData, 
    output logic        cpuAxiWriteReadyData,
    // Read Address Channel
    input  logic [31:0] cpuAxiReadAddress,   
    input  logic        cpuAxiReadValid,     
    output logic        cpuAxiReadReady,
    // Read Data Channel
    output logic [31:0] cpuAxiReadData,      
    output logic        cpuAxiReadValidData,
    input  logic        cpuAxiReadReadyData,

    // --- Master 1: DMA Engine ---
    input  logic [31:0] dmaAxiWriteAddress, input  logic dmaAxiWriteValid, output logic dmaAxiWriteReady,
    input  logic [31:0] dmaAxiWriteData,    input  logic dmaAxiWriteValidData, output logic dmaAxiWriteReadyData,
    input  logic [31:0] dmaAxiReadAddress,  input  logic dmaAxiReadValid,  output logic dmaAxiReadReady,
    output logic [31:0] dmaAxiReadData,     output logic dmaAxiReadValidData, input  logic dmaAxiReadReadyData,


    //SLAVES
    // --- Slave 0: Instruction RAM (ROM) @ 0x0000_0000 ---
    output logic [31:0] romAxiReadAddress,  output logic romAxiReadValid,  input  logic romAxiReadReady,
    input  logic [31:0] romAxiReadData,     input  logic romAxiReadValidData, output logic romAxiReadReadyData,

    // --- Slave 1: Data RAM @ 0x2000_0000 ---
    output logic [31:0] ramAxiWriteAddress, output logic ramAxiWriteValid, input  logic ramAxiWriteReady,
    output logic [31:0] ramAxiWriteData,    output logic ramAxiWriteValidData, input  logic ramAxiWriteReadyData,
    output logic [31:0] ramAxiReadAddress,  output logic ramAxiReadValid,  input  logic ramAxiReadReady,
    input  logic [31:0] ramAxiReadData,     input  logic ramAxiReadValidData, output logic ramAxiReadReadyData,

    // --- Slave 2: MMIO @ 0x4000_0000 ---
    output logic [31:0] ioAxiWriteAddress,  output logic ioAxiWriteValid,  input  logic ioAxiWriteReady,
    output logic [31:0] ioAxiWriteData,     output logic ioAxiWriteValidData, input  logic ioAxiWriteReadyData,
    output logic [31:0] ioAxiReadAddress,   output logic ioAxiReadValid,   input  logic ioAxiReadReady,
    input  logic [31:0] ioAxiReadData,      input  logic ioAxiReadValidData,  output logic ioAxiReadReadyData
);

    // BUS ARBITER
    // 0 = CPU (Default), 1 = DMA
    logic activeMaster;

    always_ff @(posedge clock or negedge resetActiveLow) begin
        if (!resetActiveLow) begin
            activeMaster <= 1'b0; // Reset Condition, CPU master wins
        end else begin
            if (activeMaster == 1'b0) begin
                if (!cpuAxiWriteValid && !cpuAxiReadValid && (dmaAxiReadValid || dmaAxiWriteValid)) begin
                    activeMaster <= 1'b1;
                end
            end
        else begin
                if (!dmaAxiReadValid && !dmaAxiWriteValid) begin
                    activeMaster <= 1'b0;   
                end
        end
    end
    end


    // Routing Logic
    always_comb begin
        // --- A. Default / Reset Values (Prevents Latches) ---
        // Masters
        cpuAxiWriteReady = 0; cpuAxiWriteReadyData = 0; cpuAxiReadReady = 0; cpuAxiReadData = 0; cpuAxiReadValidData = 0;
        dmaAxiWriteReady = 0; dmaAxiWriteReadyData = 0; dmaAxiReadReady = 0; dmaAxiReadData = 0; dmaAxiReadValidData = 0;
        // Slaves
        romAxiReadAddress = 0; romAxiReadValid = 0; romAxiReadReadyData = 0;
        ramAxiWriteAddress = 0; ramAxiWriteValid = 0; ramAxiWriteData = 0; ramAxiWriteValidData = 0; ramAxiReadAddress = 0; ramAxiReadValid = 0; ramAxiReadReadyData = 0;
        ioAxiWriteAddress = 0; ioAxiWriteValid = 0; ioAxiWriteData = 0; ioAxiWriteValidData = 0; ioAxiReadAddress = 0; ioAxiReadValid = 0; ioAxiReadReadyData = 0;

        // --- B. Master Selection (Internal Mux) ---
        // We capture the signals of whoever is currently the 'activeMaster'
        logic [31:0] currAddr_R, currAddr_W;
        logic        currValid_R, currValid_W;
        logic [31:0] currData_W;
        logic        currValidData_W;

        if (activeMaster == 1'b0) begin // CPU
            currAddr_R      = cpuAxiReadAddress;
            currValid_R     = cpuAxiReadValid;
            currAddr_W      = cpuAxiWriteAddress;
            currValid_W     = cpuAxiWriteValid;
            currData_W      = cpuAxiWriteData;
            currValidData_W = cpuAxiWriteValidData;
        end else begin // DMA
            currAddr_R      = dmaAxiReadAddress;
            currValid_R     = dmaAxiReadValid;
            currAddr_W      = dmaAxiWriteAddress;
            currValid_W     = dmaAxiWriteValid;
            currData_W      = dmaAxiWriteData;
            currValidData_W = dmaAxiWriteValidData;
        end

        // --- C. Address Decoding & Routing (Demux) ---
        
        // ---------------- READ CHANNEL ----------------
        if (currValid_R) begin
            if (currAddr_R[30]) begin 
                // [Address 0x4...] -> MMIO
                ioAxiReadAddress = currAddr_R;
                ioAxiReadValid   = 1'b1;
                // Route reply back to Active Master
                if (!activeMaster) begin 
                    cpuAxiReadReady     = ioAxiReadReady; 
                    cpuAxiReadData      = ioAxiReadData; 
                    cpuAxiReadValidData = ioAxiReadValidData;
                    ioAxiReadReadyData  = cpuAxiReadReadyData;
                end else begin
                    dmaAxiReadReady     = ioAxiReadReady;
                    dmaAxiReadData      = ioAxiReadData;
                    dmaAxiReadValidData = ioAxiReadValidData;
                    ioAxiReadReadyData  = dmaAxiReadReadyData;
                end
            end else if (currAddr_R[29]) begin
                // [Address 0x2...] -> Data RAM
                ramAxiReadAddress = currAddr_R;
                ramAxiReadValid   = 1'b1;
                if (!activeMaster) begin
                    cpuAxiReadReady     = ramAxiReadReady;
                    cpuAxiReadData      = ramAxiReadData;
                    cpuAxiReadValidData = ramAxiReadValidData;
                    ramAxiReadReadyData = cpuAxiReadReadyData;
                end else begin
                    dmaAxiReadReady     = ramAxiReadReady;
                    dmaAxiReadData      = ramAxiReadData;
                    dmaAxiReadValidData = ramAxiReadValidData;
                    ramAxiReadReadyData = dmaAxiReadReadyData;
                end
            end else begin
                // [Address 0x0...] -> Instruction RAM (ROM)
                romAxiReadAddress = currAddr_R;
                romAxiReadValid   = 1'b1;
                if (!activeMaster) begin
                    cpuAxiReadReady     = romAxiReadReady;
                    cpuAxiReadData      = romAxiReadData;
                    cpuAxiReadValidData = romAxiReadValidData;
                    romAxiReadReadyData = cpuAxiReadReadyData;
                end else begin
                    dmaAxiReadReady     = romAxiReadReady;
                    dmaAxiReadData      = romAxiReadData;
                    dmaAxiReadValidData = romAxiReadValidData;
                    romAxiReadReadyData = dmaAxiReadReadyData;
                end
            end
        end

        // ---------------- WRITE CHANNEL ----------------
        if (currValid_W) begin
            if (currAddr_W[30]) begin 
                // [Address 0x4...] -> MMIO
                ioAxiWriteAddress   = currAddr_W;
                ioAxiWriteValid     = 1'b1;
                ioAxiWriteData      = currData_W;
                ioAxiWriteValidData = currValidData_W;
                if (!activeMaster) begin
                    cpuAxiWriteReady     = ioAxiWriteReady;
                    cpuAxiWriteReadyData = ioAxiWriteReadyData;
                end else begin
                    dmaAxiWriteReady     = ioAxiWriteReady;
                    dmaAxiWriteReadyData = ioAxiWriteReadyData;
                end
            end else begin 
                // [Address 0x2...] -> Data RAM
                // Note: We also map 0x0... to RAM write channel here to act as "garbage bin" 
                // or legitimate self-modifying code if ROM is actually RAM.
                ramAxiWriteAddress   = currAddr_W;
                ramAxiWriteValid     = 1'b1;
                ramAxiWriteData      = currData_W;
                ramAxiWriteValidData = currValidData_W;
                if (!activeMaster) begin
                    cpuAxiWriteReady     = ramAxiWriteReady;
                    cpuAxiWriteReadyData = ramAxiWriteReadyData;
                end else begin
                    dmaAxiWriteReady     = ramAxiWriteReady;
                    dmaAxiWriteReadyData = ramAxiWriteReadyData;
                end
            end
        end
    end
endmodule