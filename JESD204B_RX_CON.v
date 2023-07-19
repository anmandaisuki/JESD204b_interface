module jesd204b_rx_con #(
    parameter DIV_DCLK   = 4,   // i_dclk = adc device clock freq / DIV_DCLK
    parameter FRAME_SIZE = 1, // frame size in byte. 
    parameter FMLC_NUM   = 8   // multi frame size. 
) (

    // JESD204 protocol control wire
        // input to gtwizardIP

            // To transceiver Primitive
            output wire o_rx8b10ben,
            output wire o_rxcommadeten, // comma detect enable
            output wire o_rxpcommaalignen,
            output wire o_rxmcommaalignen,
            output wire o_rxusrclk,
            output wire o_rxusrclk2,

            // To Helper (not directly transceiver Primitive)
            

        // JESD204b interface (sub class 1)
            input wire i_dclk   , // device clock
            input wire i_sysref , // allign FMLC 
            input wire i_nsync  ,
            input wire [3 : 0] gtyrxn_in,
            input wire [3 : 0] gtyrxp_in
);

// Initialize Process
// 1. input gtwiz_reset_clk_freerun_in > 2. gtwiz_reset_all_in(L > H > L)
// 3.gtwiz_userclk_rx_reset_in (1 > 0) > 4.gtwiz_userclk_rx_reset_in(0>1)
wire gtwiz_userclk_rx_reset_in; // 1(reset) > 0 (after reset)
wire gtwiz_userclk_rx_reset_in; //

wire gtwiz_reset_clk_freerun_in ;
wire gtwiz_reset_all_in         ;
wire gtwiz_reset_rx_done_out    ;
wire [3 : 0] gtpowergood_out;

// user interface data
wire [127:0]gtwiz_userdata_rx_out;
wire gtrefclk00_in; // 100MHz

// comma detection process
    wire [3:0] rx8b10ben_in;
    wire [3 : 0] rxcommadeten_in;
    wire [3 : 0] rxmcommaalignen_in;
    wire [3 : 0] rxpcommaalignen_in;
    wire [3 : 0] rxbyteisaligned_out;
    wire [3 : 0] rxcommadet_out;

    wire [63 : 0] rxctrl0_out;
    wire [63 : 0] rxctrl1_out;
    wire [31 : 0] rxctrl2_out;
    wire [31 : 0] rxctrl3_out;

// user interface clock
    wire [3 : 0] rxusrclk_in  ;  // PCS clock
    wire [3 : 0] rxusrclk2_in  ; // user logic clock


// jesd204b core 
    wire fmlc_multi_local_clock;
    reg [10:0] fmlc_cnt;





gtwizard_ultrascale_0 gty_inst (
  .gtwiz_userclk_tx_active_in(gtwiz_userclk_tx_active_in),                  // 
  .gtwiz_userclk_rx_active_in(gtwiz_userclk_rx_active_in),                  // 
  .gtwiz_reset_clk_freerun_in(gtwiz_reset_clk_freerun_in),                  // 
  .gtwiz_reset_all_in(gtwiz_reset_all_in),                                  // 
  .gtwiz_reset_tx_pll_and_datapath_in(gtwiz_reset_tx_pll_and_datapath_in),  // 0
  .gtwiz_reset_tx_datapath_in(gtwiz_reset_tx_datapath_in),                  // 0
  .gtwiz_reset_rx_pll_and_datapath_in(gtwiz_reset_rx_pll_and_datapath_in),  // 0
  .gtwiz_reset_rx_datapath_in(gtwiz_reset_rx_datapath_in),                  // 0
  .gtwiz_reset_rx_cdr_stable_out(gtwiz_reset_rx_cdr_stable_out),            // DNC
  .gtwiz_reset_tx_done_out(gtwiz_reset_tx_done_out),                        // output wire [0 : 0] gtwiz_reset_tx_done_out
  .gtwiz_reset_rx_done_out(gtwiz_reset_rx_done_out),                        // output wire [0 : 0] gtwiz_reset_rx_done_out
  .gtwiz_userdata_tx_in(gtwiz_userdata_tx_in),                              // input wire [127 : 0] gtwiz_userdata_tx_in
  .gtwiz_userdata_rx_out(gtwiz_userdata_rx_out),                            // output wire [127 : 0] gtwiz_userdata_rx_out
  .gtrefclk00_in(gtrefclk00_in),                                            // 
  .qpll0outclk_out(qpll0outclk_out),                                        // not necessary
  .qpll0outrefclk_out(qpll0outrefclk_out),                                  // not necessary
  .gtyrxn_in(gtyrxn_in),                                                    // 
  .gtyrxp_in(gtyrxp_in),                                                    // 
  .rx8b10ben_in(rx8b10ben_in),                                              // 
  .rxcommadeten_in(rxcommadeten_in),                                        // 
  .rxmcommaalignen_in(rxmcommaalignen_in),                                  // 
  .rxpcommaalignen_in(rxpcommaalignen_in),                                  // 
  .rxusrclk_in(rxusrclk_in),                                                // 
  .rxusrclk2_in(rxusrclk2_in),                                              // 
  .tx8b10ben_in(tx8b10ben_in),                                              // input wire [3 : 0] tx8b10ben_in
  .txctrl0_in(txctrl0_in),                                                  // input wire [63 : 0] txctrl0_in
  .txctrl1_in(txctrl1_in),                                                  // input wire [63 : 0] txctrl1_in
  .txctrl2_in(txctrl2_in),                                                  // input wire [31 : 0] txctrl2_in
  .txusrclk_in(txusrclk_in),                                                // input wire [3 : 0] txusrclk_in
  .txusrclk2_in(txusrclk2_in),                                              // input wire [3 : 0] txusrclk2_in
  .gtpowergood_out(gtpowergood_out),                                        // 
  .gtytxn_out(gtytxn_out),                                                  // not necessary (this port is only for GTY transceiver)
  .gtytxp_out(gtytxp_out),                                                  // 
  .rxbyteisaligned_out(rxbyteisaligned_out),                                // 
  .rxbyterealign_out(rxbyterealign_out),                                    // not necessariliy used
  .rxcommadet_out(rxcommadet_out),                                          // 
  .rxctrl0_out(rxctrl0_out),                                                //  
  .rxctrl1_out(rxctrl1_out),                                                //  
  .rxctrl2_out(rxctrl2_out),                                                //  
  .rxctrl3_out(rxctrl3_out),                                                //  
  .rxoutclk_out(rxoutclk_out),                                              // output wire [3 : 0] rxoutclk_out
  .rxpmaresetdone_out(rxpmaresetdone_out),                                  // output wire [3 : 0] rxpmaresetdone_out
  .txoutclk_out(txoutclk_out),                                              // output wire [3 : 0] txoutclk_out
  .txpmaresetdone_out(txpmaresetdone_out)                                  // output wire [3 : 0] txpmaresetdone_out
);

    
endmodule