module csr_unit (
    input  logic        clock,
    input  logic        resetActiveLow,
    
    // Hardware Trap Interface
    input  logic        csrWriteEnable, 
    input  logic [31:0] pcFromCore,     
    
    // Software Bus Interface
    input  logic        busWriteEnable, 
    input  logic [31:0] busWriteData,   
    
    // Output to Program Counter
    output logic [31:0] mepcValue       
);

    logic [31:0] mepc;

    

    always_ff @(posedge clock or negedge resetActiveLow) begin
        if (!resetActiveLow) begin
            mepc <= 32'b0;
        end 
        // SOFTWARE PRIORITY: Allows the scheduler to switch tasks
        else if (busWriteEnable) begin
            mepc <= busWriteData;
        end 
        // HARDWARE SAVE: Saves the current PC during a trap
        else if (csrWriteEnable) begin
            mepc <= pcFromCore;
        end
    end

    assign mepcValue = mepc;

endmodule