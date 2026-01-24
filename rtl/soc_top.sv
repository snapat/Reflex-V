module soc_top (
    input  logic       clock,          
    input  logic       resetActiveLow, 
    output logic [7:0] debugLeds,      
    output logic       uartTransmit    
);

    // --- 1. CLOCK & SYSTEM TIMING ---
    logic       cpuClock;
    logic [2:0] clockDivider;
    logic [31:0] timerCount;
    logic        timerInterrupt /* verilator public_flat */;

    assign cpuClock = clockDivider[2]; 
    always_ff @(posedge clock) clockDivider <= clockDivider + 1;

    localparam TIMER_LIMIT = 50000; 
    always_ff @(posedge cpuClock or negedge resetActiveLow) begin
        if (!resetActiveLow) begin
            timerCount     <= 0;
            timerInterrupt <= 0;
        end else begin
            if (timerCount >= TIMER_LIMIT) timerCount <= 0;
            else                           timerCount <= timerCount + 1;
            timerInterrupt <= (timerCount < 2000); 
        end
    end

    // --- 2. INSTRUCTION FETCH & PC LOGIC ---
    logic [31:0] programCounter /* verilator public_flat */; 
    logic [31:0] nextProgramCounter, instruction, immediateValue, mepcValue;
    logic        isTrap, isReturn, isBranch, zeroFlag;

    assign nextProgramCounter = 
        (isTrap || timerInterrupt)      ? 32'h00000010 :
        isReturn                        ? mepcValue    :
        (isBranch && (instruction[6:0] == 7'b1100111)) ? aluResult :
        (isBranch && (zeroFlag || (instruction[6:0] == 7'b1101111))) ? (programCounter + immediateValue) :
                                          (programCounter + 4);

    pc_reg u_pc (
        .clock(cpuClock), .resetActiveLow(resetActiveLow), .enable(1'b1), 
        .nextProgramCounter(nextProgramCounter), .programCounter(programCounter)
    );

    // --- 3. CORE DATAPATH & CONTROL ---
    logic [31:0] readData1, readData2, aluResult, busReadData, alignedReadData;
    logic [2:0]  aluControl;
    logic        registerWriteEnable, memoryWriteEnable, aluInputSource, resultSource, csrWriteEnable;

    controller u_ctrl (
        .opcode(instruction[6:0]), .funct3(instruction[14:12]), .funct7(instruction[31:25]),
        .timerInterrupt(timerInterrupt), .registerWriteEnable(registerWriteEnable), 
        .aluInputSource(aluInputSource), .memoryWriteEnable(memoryWriteEnable), 
        .resultSource(resultSource), .isBranch(isBranch), .aluControlSignal(aluControl), 
        .csrWriteEnable(csrWriteEnable), .isTrap(isTrap), .isReturn(isReturn)
    );

    always_comb begin
        alignedReadData = busReadData; 
        if (instruction[6:0] == 7'b0000011 && instruction[14:12] == 3'b100) begin
            case (aluResult[1:0])
                2'b00: alignedReadData = {24'b0, busReadData[7:0]};   
                2'b01: alignedReadData = {24'b0, busReadData[15:8]};  
                2'b10: alignedReadData = {24'b0, busReadData[23:16]}; 
                2'b11: alignedReadData = {24'b0, busReadData[31:24]}; 
            endcase
        end
    end

    regfile u_rf (
        .clock(cpuClock), .registerWriteEnable(registerWriteEnable),
        .readAddress0(instruction[19:15]), .readAddress1(instruction[24:20]), 
        .writeAddress(instruction[11:7]), 
        .writeData(resultSource ? alignedReadData : ((instruction[6:0] == 7'b1101111 || instruction[6:0] == 7'b1100111) ? (programCounter + 4) : aluResult)), 
        .readData0(readData1), .readData1(readData2) 
    );

    alu u_alu (
        .inputA((instruction[6:0] == 7'b0110111) ? 32'b0 : readData1), 
        .inputB(aluInputSource ? immediateValue : readData2),
        .aluControl(aluControl), .aluResult(aluResult), .zero(zeroFlag)
    );

    // --- 4. BUS, MEMORY & PERIPHERALS ---
    logic [31:0] ioWriteAddress /* verilator public_flat */;
    logic [31:0] ioWriteData    /* verilator public_flat */;
    logic        ioWriteValid   /* verilator public_flat */;
    logic [31:0] ramWriteAddress, ramReadAddress, ramWriteData, romBusAddress, romBusData, ioReadAddress;
    logic [31:0] ramReadData; 
    logic        ramWriteValid, uartIsBusy;

    bus_interconnect u_bus (
        .clock(cpuClock), .resetActiveLow(resetActiveLow),
        
        // CPU Master Interface
        .cpuAxiWriteAddress(aluResult), .cpuAxiWriteValid(memoryWriteEnable), .cpuAxiWriteReady(), // FIXED HERE
        .cpuAxiWriteData(readData2), .cpuAxiWriteValidData(1'b1), .cpuAxiWriteReadyData(),
        .cpuAxiReadAddress(aluResult), .cpuAxiReadValid(resultSource), .cpuAxiReadReady(),
        .cpuAxiReadData(busReadData), .cpuAxiReadValidData(), .cpuAxiReadReadyData(1'b1),

        // DMA Master Interface (Unused)
        .dmaAxiWriteAddress(32'b0), .dmaAxiWriteValid(1'b0), .dmaAxiWriteReady(),
        .dmaAxiWriteData(32'b0), .dmaAxiWriteValidData(1'b0), .dmaAxiWriteReadyData(),
        .dmaAxiReadAddress(32'b0), .dmaAxiReadValid(1'b0), .dmaAxiReadReady(),
        .dmaAxiReadData(), .dmaAxiReadValidData(), .dmaAxiReadReadyData(1'b1),

        // ROM Slave Interface
        .romAxiReadAddress(romBusAddress), .romAxiReadValid(), .romAxiReadReady(1'b1),
        .romAxiReadData(romBusData), .romAxiReadValidData(1'b1), .romAxiReadReadyData(),

        // RAM Slave Interface
        .ramAxiWriteAddress(ramWriteAddress), .ramAxiWriteValid(ramWriteValid), .ramAxiWriteReady(1'b1),
        .ramAxiWriteData(ramWriteData), .ramAxiWriteValidData(), .ramAxiWriteReadyData(1'b1),
        .ramAxiReadAddress(ramReadAddress), .ramAxiReadValid(), .ramAxiReadReady(1'b1),
        .ramAxiReadData(ramReadData), .ramAxiReadValidData(1'b1), .ramAxiReadReadyData(),

        // MMIO Slave Interface
        .ioAxiWriteAddress(ioWriteAddress), .ioAxiWriteValid(ioWriteValid), .ioAxiWriteReady(1'b1),
        .ioAxiWriteData(ioWriteData), .ioAxiWriteValidData(), .ioAxiWriteReadyData(1'b1),
        .ioAxiReadAddress(ioReadAddress), .ioAxiReadValid(), .ioAxiReadReady(1'b1),
        .ioAxiReadData((ioReadAddress == 32'h40000004) ? {31'b0, uartIsBusy} : 
                       (ioReadAddress == 32'h40000010) ? mepcValue : 32'b0),
        .ioAxiReadValidData(1'b1), .ioAxiReadReadyData()
    );

    csr_unit u_csr (
        .clock(cpuClock), .resetActiveLow(resetActiveLow),
        .csrWriteEnable(csrWriteEnable), .pcFromCore(programCounter), 
        .busWriteEnable((ioWriteValid && (ioWriteAddress == 32'h40000010)) || timerInterrupt), 
        .busWriteData(timerInterrupt ? programCounter : ioWriteData), 
        .mepcValue(mepcValue)
    );

    uart_tx #(.clocksPerBit(108)) u_uart (
        .systemClock(cpuClock), 
        .transmitDataValid(ioWriteValid && (ioWriteAddress == 32'h40000000)), 
        .transmitByte(ioWriteData[7:0]), 
        .serialDataOutput(uartTransmit), 
        .isTransmitActive(uartIsBusy), 
        .isTransmitDone()
    );

    inst_mem u_rom (.romAxiReadAddress(programCounter), .romAxiReadData(instruction), .busReadAddress(romBusAddress), .busReadData(romBusData));
    data_mem u_ram (.clock(cpuClock), .ramAxiWriteAddress(ramWriteAddress), .ramAxiWriteData(ramWriteData), .ramAxiWriteValid(ramWriteValid), .ramAxiReadAddress(ramReadAddress), .ramAxiReadData(ramReadData));
    imm_gen  u_imm_gen (.instruction(instruction), .immediateValue(immediateValue));

    assign debugLeds = programCounter[9:2];

endmodule