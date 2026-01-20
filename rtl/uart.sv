module uart_tx #(parameter CLKS_PER_BIT = 108) (
    input       i_Clk,
    input       i_Tx_DV,
    input [7:0] i_Tx_Byte,
    output      i_Tx_Active,
    output reg  o_Tx_Serial,
    output      o_Tx_Done
);
    localparam s_IDLE = 3'b000, s_TX_START_BIT = 3'b001, s_TX_DATA_BITS = 3'b010, s_TX_STOP_BIT = 3'b011, s_CLEANUP = 3'b100;
    reg [2:0] r_SM_Main = 0;
    reg [15:0] r_Clk_Count = 0;
    reg [2:0] r_Bit_Index = 0;
    reg [7:0] r_Tx_Data = 0;
    reg r_Tx_Done = 0, r_Tx_Active = 0;

    always @(posedge i_Clk) begin
        case (r_SM_Main)
            s_IDLE: begin
                o_Tx_Serial <= 1'b1; r_Tx_Done <= 1'b0; r_Tx_Active <= 1'b0; r_Clk_Count <= 0; r_Bit_Index <= 0;
                if (i_Tx_DV == 1'b1) begin r_Tx_Active <= 1'b1; r_Tx_Data <= i_Tx_Byte; r_SM_Main <= s_TX_START_BIT; end
            end
            s_TX_START_BIT: begin
                o_Tx_Serial <= 1'b0;
                if (r_Clk_Count < CLKS_PER_BIT-1) begin r_Clk_Count <= r_Clk_Count + 1; end
                else begin r_Clk_Count <= 0; r_SM_Main <= s_TX_DATA_BITS; end
            end
            s_TX_DATA_BITS: begin
                o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
                if (r_Clk_Count < CLKS_PER_BIT-1) begin r_Clk_Count <= r_Clk_Count + 1; end
                else begin r_Clk_Count <= 0; if (r_Bit_Index < 7) begin r_Bit_Index <= r_Bit_Index + 1; end else begin r_Bit_Index <= 0; r_SM_Main <= s_TX_STOP_BIT; end end
            end
            s_TX_STOP_BIT: begin
                o_Tx_Serial <= 1'b1;
                if (r_Clk_Count < CLKS_PER_BIT-1) begin r_Clk_Count <= r_Clk_Count + 1; end
                else begin r_Tx_Done <= 1'b1; r_Clk_Count <= 0; r_SM_Main <= s_CLEANUP; r_Tx_Active <= 1'b0; end
            end
            s_CLEANUP: begin r_Tx_Done <= 1'b1; r_SM_Main <= s_IDLE; end
            default: r_SM_Main <= s_IDLE;
        endcase
    end
    assign o_Tx_Done = r_Tx_Done; assign i_Tx_Active = r_Tx_Active;
endmodule