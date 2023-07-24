`timescale 1ps/1ps

module jesd204b_rx_controller_tb ();

// Instance Parameter
    localparam GTY_NUM = 1;

localparam LINE_RATE = 11;   //GHz
localparam DCLK_FREQ = 200;   //MHz 

localparam SYSREF_START = 25000000;
localparam INIT_PROCESS_START = 100; // ns


localparam FMLC_CNT_WIDTH = 8;

reg gty_rxp = 1'b0;
wire gty_rxn;
wire io_nsync,o_data_clk,o_data_from_transceiver;
assign gty_rxn =! gty_rxp;

reg dclk = 1'b0;
reg i_sysref = 1'b0;

task init_dclk();
 begin
    dclk = 1'b0;
    i_sysref = 1'b0;
//    #(10000);
    forever #((500/DCLK_FREQ)*1000) dclk =! dclk; 
 end
endtask

reg [9:0] K285_p = 10'b0101111100;
//reg [9:0] K285_p = 10'b0011111010;
reg [9:0] K285_n = 10'b1010000011;
//reg [9:0] K285_n = 10'b1100000101;

//reg [9:0] K285_p = 10'b0000000001;
//reg [9:0] K285_p = 10'b1111111110;
//reg [9:0] K285_n = 10'b1111111111;
//reg [9:0] K285_n = 10'b0000000000;

//reg [19:0] K285_both = {K285_p,K285_n};
//reg [19:0] K285_both = 20'b10100000111010000011;
//reg [19:0] K285_both = 20'b00000000010000000001;
//reg [19:0] K285_both = 20'b00000000110000000000;
reg [19:0] K285_both = 20'b10100000110101111100;

task send_initializing_sequence();
    begin
        #(INIT_PROCESS_START);
    //    forever begin
    //         #(1/LINE_RATE)  gty_rxp = K285_p[0];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[1];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[2];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[3];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[4];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[5];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[6];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[7];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[8];
    //         #(1/LINE_RATE)  gty_rxp = K285_p[9];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[0];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[1];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[2];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[3];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[4];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[5];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[6];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[7];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[8];
    //         #(1/LINE_RATE)  gty_rxp = K285_n[9];
    //    end
    end
endtask

reg lane_clk;
reg [4:0]K28_cnt = 0;
initial begin
    lane_clk = 1'b0;
//    #(30);
    forever #(500/LINE_RATE) lane_clk =! lane_clk;
end

always @(posedge lane_clk) begin
    if(K28_cnt > 19)begin
        K28_cnt <= 1;
        gty_rxp <= K285_both[0];
    end else begin
        gty_rxp <= K285_both[K28_cnt];
        K28_cnt <= K28_cnt + 1;    
    end
end


initial begin 
    fork
        init_dclk();
        send_initializing_sequence();
    join_none
    
    #(SYSREF_START);
    i_sysref = 1'b1;
    #((500/DCLK_FREQ)*10000);
    i_sysref = 1'b0;
    #(1000);
//    $finish;
end

jesd204b_rx_controller #(
    .DIV_DCLK  (4),   
    .FRAME_SIZE(1),   
    .FMLC_NUM  (8),   
    .GTY_NUM   (GTY_NUM)   
) jesd_rx_controller_inst(
    // External for Transceiver
    .i_gtyrxn_in(gty_rxn),
    .i_gtyrxp_in(gty_rxp),
    .i_gtrefclk00_in(dclk),

    // External for JESD204B core
    .io_nsync(io_nsync),
    .i_sysref(i_sysref),

    // Interface for User Logic or AXI(S) Convertion Logic
    .o_data_clk(o_data_clk),
    .o_data_from_transceiver(o_data_from_transceiver)
);
    
endmodule