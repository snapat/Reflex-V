module soc_top(
    input  logic       clock,          
    input  logic       resetActiveLow, 
    output logic [7:0] debugLeds,      
    output logic       uartTransmit    
);

    // --- 0. CLOCK SETUP ---
    logic       cpuClock;
    assign cpuClock = clockDivider[2]; // 12.5 MHz

    logic [2:0] clockDivider;
    always_ff @(posedge clock) clockDivider <= clockDivider + 1;
    

    // --- INTERNAL SIGNALS ---
    logic [31:0] programCounter /* verilator public_flat */, nextProgramCounter, instruction, immediateValue;
    logic [31:0] readData1, readData2, aluResult, busReadData, ramReadData;
    logic [31:0] ramWriteAddress, ramReadAddress, ramWriteData;
    logic [31:0] romBusAddress, romBusData;
    logic [31:0] mepcValue;
    logic        registerWriteEnable, memoryWriteEnable, aluInputSource, resultSource, isBranch, zeroFlag;
    logic        ramWriteValid, csrWriteEnable, isTrap, isReturn;
    logic [2:0]  aluControl;

    // --- EXPOSED SIGNALS FOR C++ TESTBENCH ---
    logic        ioWriteValid   /* verilator public_flat */;
    logic [31:0] ioWriteData    /* verilator public_flat */;
    logic [31:0] ioWriteAddress /* verilator public_flat */;
    logic [31:0] ioReadAddress;
    
    logic        uart_is_busy;

    // --- PREEMPTION HARDWARE (DETERMINISTIC FIX) ---
    logic [31:0] timerCount;
    logic        timerInterrupt /* verilator public_flat */;
    
    // 50,000 Cycles = 4ms at 12.5MHz (Good slice time)
    localparam   TIMER_LIMIT = 5000; 

    always_ff @(posedge cpuClock or negedge resetActiveLow) begin
        if (!resetActiveLow) begin
            timerCount <= 0;
            timerInterrupt <= 0;
        end else begin
            // 1. Run the Counter
            if (timerCount >= TIMER_LIMIT) begin
                timerCount <= 0;
            end else begin
                timerCount <= timerCount + 1;
            end

            // 2. The "Sticky Doorbell" Logic
            // Instead of pulsing for 1 cycle, we hold it HIGH for 2000 cycles.
            // This ensures the CPU catches it even if waiting on UART (1080 cycles).
            // It drops LOW before the Scheduler finishes (approx 5000 cycles), preventing double-interrupts.
            if (timerCount < 2000) 
                timerInterrupt <= 1; 
            else 
                timerInterrupt <= 0;
        end
    end

    // --- 1. PC LOGIC ---
    logic [31:0] pcBranch; 
    logic isJAL, isJALR;    
    assign pcBranch = programCounter + immediateValue;
    assign isJAL  = (instruction[6:0] == 7'b1101111);
    assign isJALR = (instruction[6:0] == 7'b1100111);

    assign nextProgramCounter = 
        (isTrap || timerInterrupt) ? 32'h00000010 :           
        isReturn ? mepcValue :                                             
        (isBranch & isJALR) ? aluResult :                       
        (isBranch & (zeroFlag | isJAL)) ? pcBranch :            
        (programCounter + 4);                                   

    pc_reg u_pc (
        .clock(cpuClock), .resetActiveLow(resetActiveLow), .enable(1'b1), 
        .nextProgramCounter(nextProgramCounter), .programCounter(programCounter)
    );

    // --- 2. CORE COMPONENTS ---
    inst_mem u_rom (
        .romAxiReadAddress(programCounter), 
        .romAxiReadData(instruction),
        .busReadAddress(romBusAddress),
        .busReadData(romBusData)
    );

    controller u_ctrl (
        .opcode(instruction[6:0]), .funct3(instruction[14:12]), .funct7(instruction[31:25]),
        .timerInterrupt(timerInterrupt), 
        .registerWriteEnable(registerWriteEnable), .aluInputSource(aluInputSource), 
        .memoryWriteEnable(memoryWriteEnable), .resultSource(resultSource), 
        .isBranch(isBranch), .aluControlSignal(aluControl), 
        .csrWriteEnable(csrWriteEnable), 
        .isTrap(isTrap), .isReturn(isReturn)
    );

    imm_gen u_imm_gen (.instruction(instruction), .immediateValue(immediateValue));

    // Auto-Save MEPC on Timer
    logic        csr_bus_write_en;
    logic [31:0] csr_bus_write_data;
    assign csr_bus_write_en   = (ioWriteValid && (ioWriteAddress == 32'h40000010)) || timerInterrupt;
    assign csr_bus_write_data = timerInterrupt ? programCounter : ioWriteData;

    csr_unit u_csr (
        .clock(cpuClock), .resetActiveLow(resetActiveLow),
        .csrWriteEnable(csrWriteEnable), .pcFromCore(programCounter), 
        .busWriteEnable(csr_bus_write_en), 
        .busWriteData(csr_bus_write_data), 
        .mepcValue(mepcValue)
    );

    // LBU Fix
    logic [31:0] alignedReadData;
    always_comb begin
        alignedReadData = busReadData; 
        if (instruction[6:0] == 7'b0000011 && (instruction[14:12] == 3'b000 || instruction[14:12] == 3'b100)) begin
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
        .writeData(resultSource ? alignedReadData : ((isJAL || isJALR) ? (programCounter + 4) : aluResult)), 
        .readData0(readData1), .readData1(readData2) 
    );

    alu u_alu (
        .inputA((instruction[6:0] == 7'b0110111) ? 32'b0 : readData1), 
        .inputB(aluInputSource ? immediateValue : readData2),
        .aluControl(aluControl), .aluResult(aluResult), .zero(zeroFlag)
    );

    // --- 3. THE BUS ---
    bus_interconnect u_bus (
        .clock(cpuClock), .resetActiveLow(resetActiveLow),
        .cpuAxiWriteAddress(aluResult), .cpuAxiWriteData(readData2), .cpuAxiWriteValid(memoryWriteEnable), .cpuAxiWriteReady(), 
        .cpuAxiWriteReadyData(), .cpuAxiWriteValidData(1'b1),
        .cpuAxiReadAddress(aluResult), .cpuAxiReadValid(resultSource), .cpuAxiReadReady(),
        .cpuAxiReadData(busReadData), .cpuAxiReadValidData(), .cpuAxiReadReadyData(1'b1),
        
        .dmaAxiWriteAddress(32'b0), .dmaAxiWriteValid(1'b0), .dmaAxiWriteReady(), .dmaAxiWriteData(32'b0), .dmaAxiWriteValidData(1'b0), .dmaAxiWriteReadyData(),
        .dmaAxiReadAddress(32'b0), .dmaAxiReadValid(1'b0), .dmaAxiReadReady(), .dmaAxiReadData(), .dmaAxiReadValidData(), .dmaAxiReadReadyData(1'b1),
        
        .romAxiReadAddress(romBusAddress), .romAxiReadValid(), .romAxiReadReady(1'b1),
        .romAxiReadData(romBusData), .romAxiReadValidData(1'b1), .romAxiReadReadyData(),
        
        .ramAxiWriteAddress(ramWriteAddress), .ramAxiWriteValid(ramWriteValid), .ramAxiWriteReady(1'b1), .ramAxiWriteData(ramWriteData), .ramAxiWriteValidData(), .ramAxiWriteReadyData(1'b1),
        .ramAxiReadAddress(ramReadAddress), .ramAxiReadValid(), .ramAxiReadReady(1'b1), .ramAxiReadData(ramReadData), .ramAxiReadValidData(1'b1), .ramAxiReadReadyData(),
        
        .ioAxiWriteAddress(ioWriteAddress), .ioAxiWriteValid(ioWriteValid), .ioAxiWriteReady(1'b1), .ioAxiWriteData(ioWriteData), .ioAxiWriteValidData(), .ioAxiWriteReadyData(1'b1),
        .ioAxiReadAddress(ioReadAddress), .ioAxiReadValid(), .ioAxiReadReady(1'b1),
        .ioAxiReadData((ioReadAddress == 32'h40000004) ? {31'b0, uart_is_busy} : (ioReadAddress == 32'h40000010) ? mepcValue : 32'b0),
        .ioAxiReadValidData(1'b1), .ioAxiReadReadyData()
    );

    data_mem u_ram (
        .clock(cpuClock), .ramAxiWriteAddress(ramWriteAddress), .ramAxiWriteData(ramWriteData),
        .ramAxiWriteValid(ramWriteValid), .ramAxiReadAddress(ramReadAddress), .ramAxiReadData(ramReadData)
    );

    // SPEEDY UART
    uart_tx #(.CLKS_PER_BIT(108)) u_uart (
        .i_Clk(cpuClock), .i_Tx_DV(ioWriteValid && (ioWriteAddress == 32'h40000000)), 
        .i_Tx_Byte(ioWriteData[7:0]), .o_Tx_Serial(uartTransmit), .i_Tx_Active(uart_is_busy), .o_Tx_Done()
    );

    assign debugLeds = programCounter[9:2];

endmodule