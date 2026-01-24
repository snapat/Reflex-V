module uart_tx #(parameter clocksPerBit = 108) (
    input        systemClock,
    input        transmitDataValid,
    input  [7:0] transmitByte,
    output       isTransmitActive,
    output reg   serialDataOutput,
    output       isTransmitDone
);

    // State machine encodings
    localparam stateIdle         = 3'b000;
    localparam stateTransmitStart = 3'b001;
    localparam stateTransmitData  = 3'b010;
    localparam stateTransmitStop  = 3'b011;
    localparam stateCleanup       = 3'b100;

    // Internal registers
    reg [2:0]  mainStateMachine   = 0;
    reg [15:0] clockCycleCounter  = 0;
    reg [2:0]  bitIndexCounter    = 0;
    reg [7:0]  transmitDataBuffer = 0;
    reg        transmitDoneFlag   = 0;
    reg        transmitActiveFlag = 0;

    always @(posedge systemClock) begin
        case (mainStateMachine)
            
            // Wait for transmit pulse; reset counters
            stateIdle: begin
                serialDataOutput   <= 1'b1; // Drive high (idle)
                transmitDoneFlag   <= 1'b0;
                transmitActiveFlag <= 1'b0;
                clockCycleCounter  <= 0;
                bitIndexCounter    <= 0;

                if (transmitDataValid == 1'b1) begin
                    transmitActiveFlag <= 1'b1;
                    transmitDataBuffer <= transmitByte;
                    mainStateMachine   <= stateTransmitStart;
                end
            end

            // Drive line LOW for 1 bit period (Start Bit)
            stateTransmitStart: begin
                serialDataOutput <= 1'b0;
                if (clockCycleCounter < clocksPerBit - 1) begin
                    clockCycleCounter <= clockCycleCounter + 1;
                end else begin
                    clockCycleCounter <= 0;
                    mainStateMachine   <= stateTransmitData;
                end
            end

            // Shift out 8 bits, LSB first
            stateTransmitData: begin
                serialDataOutput <= transmitDataBuffer[bitIndexCounter];
                if (clockCycleCounter < clocksPerBit - 1) begin
                    clockCycleCounter <= clockCycleCounter + 1;
                end else begin
                    clockCycleCounter <= 0;
                    // Check if all 8 bits are sent
                    if (bitIndexCounter < 7) begin
                        bitIndexCounter <= bitIndexCounter + 1;
                    end else begin
                        bitIndexCounter <= 0;
                        mainStateMachine <= stateTransmitStop;
                    end
                end
            end

            // Drive line HIGH for 1 bit period (Stop Bit)
            stateTransmitStop: begin
                serialDataOutput <= 1'b1;
                if (clockCycleCounter < clocksPerBit - 1) begin
                    clockCycleCounter <= clockCycleCounter + 1;
                end else begin
                    transmitDoneFlag   <= 1'b1;
                    clockCycleCounter  <= 0;
                    mainStateMachine   <= stateCleanup;
                    transmitActiveFlag <= 1'b0;
                end
            end

            // Single cycle completion pulse
            stateCleanup: begin
                transmitDoneFlag <= 1'b1;
                mainStateMachine <= stateIdle;
            end

            default: mainStateMachine <= stateIdle;
        endcase
    end

    // Continuous assignments for flags
    assign isTransmitDone   = transmitDoneFlag;
    assign isTransmitActive = transmitActiveFlag;

endmodule