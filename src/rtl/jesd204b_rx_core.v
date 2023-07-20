module jesd204b_rx_core #(
    parameter LMFC_CNT_WIDTH = 8,
    parameter USERDATA_WIDTH = 128,

    parameter JESD204B_L = 5'b00000,
    parameter JESD204B_F = 8'b00000000,
    parameter JESD204B_K = 5'b00000,
    parameter JESD204B_M = 8'b00000000,
) (
    // External
    inout wire io_nsync,
    input wire i_sysref,
    input wire i_dclk,  //200 MHz, MRCC pin

    // Connect with transceiver

    // reset sequence control
        output wire o_gtwiz_reset_clk_freerun_in,
        output wire o_gtwiz_reset_all_in,
        input  wire i_gtwiz_reset_rx_done_out,
        input  wire i_gtpowergood_out,



    // output wire o_rx8b10ben,
    output wire o_rxpcommaalignen,
    output wire o_rxmcommaalignen,

    input wire i_rxbyteisaligned_out,

    output wire o_gtwiz_usrclk_rx_active_in,
    output wire o_rxusrclk,     // 125 MHz (10Gbps/80bit)
    output wire o_rxusrclk2,    // 125 MHz (RXDATA = 64bit), 62.5MHz (RXDATA = 32bit)
    output wire [USERDATA_WIDTH-1:0] gtwiz_userdata_rx_out,

    input wire i_rxcommadeten,


    // Connect with AXI convertion circuit


);

wire                      core_clk   ;

reg gtwiz_reset_all_in;
assign o_gtwiz_reset_all_in = gtwiz_reset_all_in;

wire                      lmfc       ;
wire [LMFC_CNT_WIDTH-1:0] lmfc_cnt   ;
wire                      sysref_done;
reg                       lmfc_alligned; // maybe not needed

reg [2:0] JESD204_state; // 000: NONE, 001: SYSREFDONE, 010: CGS, 011: CGS_after, 100: ILAS, 101: ILASDONE
reg [2:0] ILAS_lmfc_cnt;

wire [7:0] lane0_data0;
wire [7:0] lane0_data1;
wire [7:0] lane0_data2;
wire [7:0] lane0_data3;
assign lane0_data0 = gtwiz_userdata_rx_out[7:0];
assign lane0_data0 = gtwiz_userdata_rx_out[15:8];
assign lane0_data0 = gtwiz_userdata_rx_out[23:16];
assign lane0_data0 = gtwiz_userdata_rx_out[31:24];

reg nsync;
assign io_nsync =! nsync;

// Transceiver Reset > sysref > nsync H -> L(CGS) > nsync L -> H (ILAS)

// transceiver reset sequence. Check Power and Reset PLL and Data Line.
    always @(posedge o_gtwiz_reset_clk_freerun_in ) begin
        if(i_gtpowergood_out && i_gtwiz_reset_rx_done_out == 1'b0) begin
            gtwiz_reset_all_in <= 1'b1;
        end else begin
            gtwiz_reset_all_in <= 1'b0;
        end
    end

// JESD204B initialize sequence (subclass 1)
    localparam K285_K = 8'b10111100 ;
    localparam K283_A = 8'b01111100 ;
    localparam K280_R = 8'b00011100 ;
    reg [2 :0] FLAME_BO;
    reg [13:0] ILAS_SECOND_MULTI_FLAME [7:0];   // To check ADC setting
    reg [3 :0] ILAS_SECOND_MULTI_FLAME_pnt  ; 
    reg        SECOND_FLAME_DETECT          ;

    /////////////////////////////////////////////////
    ///// JESD204B ILAS SECOND MULTI FRAME CHECK/////
    ////////////////////////////////////////////////



    always @(posedge sysref_done ) begin
        if(i_gtwiz_reset_rx_done_out && i_gtpowergood_out)begin
            lmfc_alligned <= 1'b1;
            JESD204_state <= 3'b001
        end else begin
            lmfc_alligned <= 1'b0;
        end
    end

    // always @(posedge lmfc) begin
    always @(posedge o_rxusrclk2) begin
            if (i_gtwiz_reset_rx_done_out && i_gtpowergood_out && lmfc_alligned) begin
                case (JESD204_state)
                    3'b001: begin // SYSREFDONE
                        JESD204_state <= 3'b010;
                        nsync <= 1'b0; // activate sync
                    end
                    3'b010: begin // CGS: Check if RX data equal to K28.5 or not. 
                        if(i_rxbyteisaligned_out)begin
                            JESD204_state <= 3'b011;
                            nsync <= 1'b1; 
                        end
                    end
                    3'b011: begin // CGS_after: Wait until K28.0 come 
                        if(lane0_data0 == K280_R | :
                           lane0_data1 == K280_R | :
                           lane0_data2 == K280_R | :
                           lane0_data3 == K280_R | :
                        )begin
                            ILAS_lmfc_cnt <= 1;
                            JESD204_state <= 3'b100;
                        end
                    end
                    3'b100: begin //ILAS: Count LMFC and Check Second Multi Frame.  
                        if(ILAS_lmfc_cnt == 1 && SECOND_FLAME_DETECT == 0) begin
                            if( lane0_data0 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0]  <= lane0_data1
                                ILAS_SECOND_MULTI_FLAME[1]  <= lane0_data2
                                ILAS_SECOND_MULTI_FLAME[2]  <= lane0_data3
                                ILAS_SECOND_MULTI_FLAME_pnt <= 3;
                                SECOND_FLAME_DETECT <= 1;
                            end
                            if( lane0_data1 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0] = lane0_data2
                                ILAS_SECOND_MULTI_FLAME[1] = lane0_data3
                                ILAS_SECOND_MULTI_FLAME_pnt <= 2;
                                SECOND_FLAME_DETECT <= 1;
                            end
                            if( lane0_data2 == K283_A )begin
                                ILAS_SECOND_MULTI_FLAME[0] = lane0_data3
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
                                    LAS_lmfc_cnt <= 2;

                                end else if (ILAS_SECOND_MULTI_FLAME_pnt == 13) begin
                                    ILAS_SECOND_MULTI_FLAME[ILAS_SECOND_MULTI_FLAME_pnt  ] <= lane0_data0;
                                    LAS_lmfc_cnt <= 2;
                                end

                        end else begin
                            if (lane0_data0 == K283_A |:
                                lane0_data1 == K283_A |:
                                lane0_data2 == K283_A |:
                                lane0_data3 == K283_A)begin
                                    ILAS_lmfc_cnt <= ILAS_lmfc_cnt + 1;
                                end
                            if(ILAS_lmfc_cnt == 4)
                                JESD204_state <= 3'b101;
                        end  
                    end
                    3'b101: begin // JESD Initialization Done
                        
                    end

                    default: 
                endcase
                
            end
    end

    always @(posedge i_rxcommadeten ) begin
        CGS_state <= 1'b0;
    end

    always @(negedge i_nsync ) begin
        
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
    .o_sysref_done(sysref_done),
);
    
endmodule