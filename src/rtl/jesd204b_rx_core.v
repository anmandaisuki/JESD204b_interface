

module jesd204b_rx_core #(
    parameter LMFC_CNT_WIDTH    = 8,
    parameter USERDATA_WIDTH    = 32,

    parameter JESD204B_CONFIG_L = 5'b00000,
    parameter JESD204B_CONFIG_F = 8'b00000000,
    parameter JESD204B_CONFIG_K = 5'b00000,
    parameter JESD204B_CONFIG_M = 8'b00000000
) (
    // External
        inout wire io_nsync,
        input wire i_sysref,

    // Connect with transceiver
        input wire i_dclk,  //250 MHz, bypassed from qpll0outrefclk_out of rx_transceiver

    // reset sequence control
        output wire o_gtwiz_userclk_rx_active_in, 
        output wire o_gtwiz_reset_clk_freerun_in, // 250 MHz
        output wire o_gtwiz_reset_all_in,
        input  wire i_gtwiz_reset_rx_done_out,
        input  wire i_gtpowergood_out,


    // Connect to Transceiver

        // output wire o_rx8b10ben       , always 1
        // output wire o_rxcommadeten_in , always 1
        output wire o_rxpcommaalignen   ,
        output wire o_rxmcommaalignen   ,
        input wire i_rxbyteisaligned_out,

        output wire o_rxusrclk2,    // 250 MHz (RXDATA = 64bit), 62.5MHz (RXDATA = 32bit)
        input wire [USERDATA_WIDTH-1:0] i_gtwiz_userdata_rx_out,

    // Interface with User Logic or AXIS convertion Logic
        output wire o_data_clk, // 250 MHz
        output wire [USERDATA_WIDTH-1:0] o_data_from_transceiver
);

localparam STARTUP_TIME = 100;
reg [7:0] startup_cnt = 0;

assign o_gtwiz_reset_clk_freerun_in = i_dclk;
assign o_rxusrclk2 = i_dclk;

reg gtwiz_userclk_rx_active_in;
assign o_user_rx_active_in = gtwiz_userclk_rx_active_in;

reg gtwiz_reset_all_in;
assign o_gtwiz_reset_all_in = gtwiz_reset_all_in;

wire                      lmfc          ;
wire [LMFC_CNT_WIDTH-1:0] lmfc_cnt      ;
wire                      sysref_done   ;
reg                       lmfc_alligned ; // maybe not needed

reg [2:0] JESD204_state; // 000: NONE, 001: SYSREFDONE, 010: CGS, 011: CGS_after, 100: ILAS, 101: ILASDONE, 110: ILAS check is failed. 
reg [2:0] ILAS_lmfc_cnt;

wire [7:0] lane0_data0;
wire [7:0] lane0_data1;
wire [7:0] lane0_data2;
wire [7:0] lane0_data3;
assign lane0_data0 = i_gtwiz_userdata_rx_out[7:0];
assign lane0_data0 = i_gtwiz_userdata_rx_out[15:8];
assign lane0_data0 = i_gtwiz_userdata_rx_out[23:16];
assign lane0_data0 = i_gtwiz_userdata_rx_out[31:24];

reg nsync = 1'b1;
assign io_nsync = nsync;

reg rxpcommaalignen;
assign o_rxpcommaalignen = rxpcommaalignen;
reg rxmcommaalignen;
assign o_rxmcommaalignen = rxmcommaalignen;

// Transceiver Reset > sysref > nsync H -> L(CGS) > nsync L -> H (ILAS)

// transceiver reset sequence. Check Power and Reset PLL and Data Line.
    always @(posedge o_gtwiz_reset_clk_freerun_in ) begin
        if(startup_cnt < STARTUP_TIME)
            startup_cnt <= startup_cnt + 1;

        if(startup_cnt == STARTUP_TIME - 1)
            gtwiz_userclk_rx_active_in <= 1;

    end
    
    reg [15:0] reset_hold = 0;
    localparam reset_hold_time = 4000;

    always @(posedge o_gtwiz_reset_clk_freerun_in ) begin
        if(i_gtpowergood_out && reset_hold > reset_hold_time) begin
            gtwiz_reset_all_in <= 1'b0;
            
        end else begin
            gtwiz_reset_all_in <= 1'b1;
            reset_hold <= reset_hold + 1;
        end
    end

// JESD204B initialize sequence (subclass 1)
    localparam K285_K = 8'b10111100 ;
    localparam K283_A = 8'b01111100 ;
    localparam K280_R = 8'b00011100 ;
    
    reg [13:0] ILAS_SECOND_MULTI_FLAME [7:0];   // To store ADC Config at ILAS Process (Second Multi Frame)
    reg [3 :0] ILAS_SECOND_MULTI_FLAME_pnt  ; 
    reg        SECOND_FLAME_DETECT          ;
    reg        CGS_ILAS_DONE_LINK_OK        ;

    /////////////////////////////////////////////////
    ///// JESD204B ILAS SECOND MULTI FRAME CHECK/////
    ////////////////////////////////////////////////
    wire ILAS_config_check;
    assign ILAS_config_check = (ILAS_SECOND_MULTI_FLAME[3][4:0] == JESD204B_CONFIG_L &&
                                ILAS_SECOND_MULTI_FLAME[4][7:0] == JESD204B_CONFIG_F &&
                                ILAS_SECOND_MULTI_FLAME[5][4:0] == JESD204B_CONFIG_K &&
                                ILAS_SECOND_MULTI_FLAME[6][7:0] == JESD204B_CONFIG_M );
    


    // sysref_done signal after reset process is registerd in order to start CGS and ILAS process.
    always @(posedge sysref_done ) begin
        if(i_gtwiz_reset_rx_done_out && i_gtpowergood_out)begin
            lmfc_alligned <= 1'b1;
            JESD204_state <= 3'b001;
        end else begin
            lmfc_alligned <= 1'b0;
        end
    end

    // LINK Establishment Process
    always @(posedge o_rxusrclk2) begin
            if (i_gtwiz_reset_rx_done_out && i_gtpowergood_out && lmfc_alligned) begin
                case (JESD204_state)
                    3'b001: begin // SYSREFDONE. 
                        JESD204_state <= 3'b010;
                        nsync <= 1'b0; // activate sync
                        // Transceiver Alignment is turned on 
                          rxpcommaalignen <= 1'b1;
                          rxmcommaalignen <= 1'b1;
                    end
                    3'b010: begin // CGS: Check if RX data equal to K28.5 or not. 
                        if(i_rxbyteisaligned_out)begin
                            JESD204_state <= 3'b011;
                            nsync <= 1'b1; 
                            // Transceiver Alignment is turned off
                              rxpcommaalignen <= 1'b0;
                              rxmcommaalignen <= 1'b0;
                        end
                    end
                    3'b011: begin // CGS_after: Wait until K28.0 come 
                        if(lane0_data0 == K280_R | 
                           lane0_data1 == K280_R | 
                           lane0_data2 == K280_R | 
                           lane0_data3 == K280_R  
                        )begin
                            ILAS_lmfc_cnt <= 1;
                            JESD204_state <= 3'b100;
                        end
                    end
                    3'b100: begin //ILAS: Count LMFC and Check Second Multi Frame.  
                        if(ILAS_lmfc_cnt == 1 && SECOND_FLAME_DETECT == 0) begin
                            if( lane0_data0 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0]  <= lane0_data1;
                                ILAS_SECOND_MULTI_FLAME[1]  <= lane0_data2;
                                ILAS_SECOND_MULTI_FLAME[2]  <= lane0_data3;
                                ILAS_SECOND_MULTI_FLAME_pnt <= 3;
                                SECOND_FLAME_DETECT <= 1;
                            end
                            if( lane0_data1 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0] = lane0_data2;
                                ILAS_SECOND_MULTI_FLAME[1] = lane0_data3;
                                ILAS_SECOND_MULTI_FLAME_pnt <= 2;
                                SECOND_FLAME_DETECT <= 1;
                            end
                            if( lane0_data2 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0] = lane0_data3;
                                ILAS_SECOND_MULTI_FLAME_pnt <= 1;
                                SECOND_FLAME_DETECT <= 1;
                            end
                            if( lane0_data3 == K283_A )begin
                                SECOND_FLAME_DETECT <= 1;
                            end
                        end else if (ILAS_lmfc_cnt == 1 && SECOND_FLAME_DETECT)begin
                            
                                if(ILAS_SECOND_MULTI_FLAME_pnt + 3 < 13)begin
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+1] <= lane0_data1;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+2] <= lane0_data2;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+3] <= lane0_data3;

                                end else if(ILAS_SECOND_MULTI_FLAME_pnt + 2 < 13)begin
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+1] <= lane0_data1;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+2] <= lane0_data2;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+3] <= lane0_data3;
                                    ILAS_lmfc_cnt <= 2;

                                end else if(ILAS_SECOND_MULTI_FLAME_pnt + 1 < 13)begin 
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+1] <= lane0_data1;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+2] <= lane0_data2;
                                    ILAS_lmfc_cnt <= 2;

                                end else if (ILAS_SECOND_MULTI_FLAME_pnt < 13)begin
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt+1] <= lane0_data1;
                                    ILAS_lmfc_cnt <= 2;

                                end else if (ILAS_SECOND_MULTI_FLAME_pnt == 13) begin
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    ILAS_lmfc_cnt <= 2;
                                end

                        end else begin
                            if (lane0_data0 == K283_A |
                                lane0_data1 == K283_A |
                                lane0_data2 == K283_A |
                                lane0_data3 == K283_A)begin
                                    ILAS_lmfc_cnt <= ILAS_lmfc_cnt + 1;
                                end
                            if(ILAS_lmfc_cnt == 4)begin
                                // ILAS Config is checked. 
                                if (ILAS_config_check) begin
                                    JESD204_state <= 3'b101;
                                end else begin
                                    JESD204_state <= 3'b110;
                                end
                            end
                        end  
                    end
                    3'b101: begin // JESD Initialization Done
                        CGS_ILAS_DONE_LINK_OK <= 1'b1;
                    end
                    3'b110: begin // ILAS Check is failed
                        JESD204_state <= 3'b000; // Restart from SYSREF alignment 
                    end

                    default:
                             ;
                endcase
                
            end
    end

    // Transfer Data to User Logic or AXIS Conversion Logic
    assign o_data_clk = o_rxusrclk2;
    reg [USERDATA_WIDTH-1:0] tx_data;
    assign o_data_from_transceiver = tx_data;

    always @(posedge o_data_clk) begin
        if(CGS_ILAS_DONE_LINK_OK)begin
            tx_data <= i_gtwiz_userdata_rx_out;
        end else begin
            tx_data <= 0;
        end
    end

jesd204b_lmfc_generator #(
    .JESD_F        (1)       ,  
    .JESD_K        (8)       ,   
    .DCLK_DIV      (4)       , 
    .LMFC_CNT_WIDTH(LMFC_CNT_WIDTH) 
) lmfc_gen_inst (
    .dclk       (i_dclk)     ,    
    .sysref     (i_sysref)   , 

    .o_lmfc     (lmfc)       ,
    .o_lmfc_cnt (lmfc_cnt)   ,
    .o_sysref_done(sysref_done)
);
    
endmodule

// jesd204b_rx_core #(
//     .LMFC_CNT_WIDTH   (),
//     .USERDATA_WIDTH   (),
//     .JESD204B_CONFIG_L(),
//     .JESD204B_CONFIG_F(),
//     .JESD204B_CONFIG_K(),
//     .JESD204B_CONFIG_M()
// ) jesd204b_rx_core_inst (
//     .io_nsync                    (),
//     .i_sysref                    (),
//     .i_dclk                      (),  
//     .i_gtwiz_userclk_rx_active_in(),
//     .o_gtwiz_reset_clk_freerun_in(),
//     .o_gtwiz_reset_all_in        (),
//     .i_gtwiz_reset_rx_done_out   (),
//     .i_gtpowergood_out           (),
//     .o_rxpcommaalignen           (),
//     .o_rxmcommaalignen           (),
//     .i_rxbyteisaligned_out       (),
//     .o_rxusrclk2                 (),  
//     .i_gtwiz_userdata_rx_out     (),
//     .o_data_clk                  (), 
//     .o_data_from_transceiver     ()
// );
