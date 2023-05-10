`timescale 1ns / 1ps
`define UD #1
//cmos1、cmos2二选一，作为视频源输入
`define CMOS_1      //cmos1作为视频输入；
//`define CMOS_2      //cmos2作为视频输入；

module hdmi_ddr_ov5640_top#(
	parameter MEM_ROW_ADDR_WIDTH   = 15         ,
	parameter MEM_COL_ADDR_WIDTH   = 10         ,
	parameter MEM_BADDR_WIDTH      = 3          ,
	parameter MEM_DQ_WIDTH         =  32        ,
	parameter MEM_DQS_WIDTH        =  32/8
)(
	input                                sys_clk              ,//50Mhz
//OV5647
    output  [1:0]                        cmos_init_done       ,//OV5640寄存器初始化完成
    //coms1	
    inout                                cmos1_scl            ,//cmos1 i2c 
    inout                                cmos1_sda            ,//cmos1 i2c 
    input                                cmos1_vsync          ,//cmos1 vsync
    input                                cmos1_href           ,//cmos1 hsync refrence,data valid
    input                                cmos1_pclk           ,//cmos1 pxiel clock
    input   [7:0]                        cmos1_data           ,//cmos1 data
    output                               cmos1_reset          ,//cmos1 reset
    //coms2
    inout                                cmos2_scl            ,//cmos2 i2c 
    inout                                cmos2_sda            ,//cmos2 i2c 
    input                                cmos2_vsync          ,//cmos2 vsync
    input                                cmos2_href           ,//cmos2 hsync refrence,data valid
    input                                cmos2_pclk           ,//cmos2 pxiel clock
    input   [7:0]                        cmos2_data           ,//cmos2 data
    output                               cmos2_reset          ,//cmos2 reset
//DDR
    output                               mem_rst_n                 ,
    output                               mem_ck                    ,
    output                               mem_ck_n                  ,
    output                               mem_cke                   ,
    output                               mem_cs_n                  ,
    output                               mem_ras_n                 ,
    output                               mem_cas_n                 ,
    output                               mem_we_n                  ,
    output                               mem_odt                   ,
    output      [MEM_ROW_ADDR_WIDTH-1:0] mem_a                     ,
    output      [MEM_BADDR_WIDTH-1:0]    mem_ba                    ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs                   ,
    inout       [MEM_DQ_WIDTH/8-1:0]     mem_dqs_n                 ,
    inout       [MEM_DQ_WIDTH-1:0]       mem_dq                    ,
    output      [MEM_DQ_WIDTH/8-1:0]     mem_dm                    ,
    output reg                           heart_beat_led            ,
    output                               ddr_init_done             ,
//MS72xx       
/*   output                               rstn_out                  ,
    output                               iic_tx_scl                ,
    inout                                iic_tx_sda                ,
    output                               hdmi_int_led              ,//HDMI_OUT初始化完成*/
    //增加HDMI输入通道
    output                               hdmi_int_led ,
    output            rstn_out,
    output            iic_scl,
    inout             iic_sda, 
    output            iic_tx_scl,
    inout             iic_tx_sda, 
    input             pixclk_in,                            
    input             vs_in, 
    input             hs_in, 
    input             de_in,
    input     [7:0]   r_in, 
    input     [7:0]   g_in, 
    input     [7:0]   b_in,
//HDMI_OUT
    output                            pix_clk                   ,//pixclk                           
    output                            vs_out                    , 
    output                            hs_out                    , 
    output                            de_out                    ,
    output     [7:0]                  r_out                     , 
    output     [7:0]                  g_out                     , 
    output     [7:0]                  b_out         
);
/////////////////////////////////////////////////////////////////////////////////////
// ENABLE_DDR
    parameter CTRL_ADDR_WIDTH = MEM_ROW_ADDR_WIDTH + MEM_BADDR_WIDTH + MEM_COL_ADDR_WIDTH;//28
    parameter TH_1S = 27'd33000000;
/////////////////////////////////////////////////////////////////////////////////////
    reg  [15:0]                 rstn_1ms            ;
    wire                        cmos_scl            ;//cmos i2c clock
    wire                        cmos_sda            ;//cmos i2c data
    wire                        cmos_vsync          ;//cmos vsync
    wire                        cmos_href           ;//cmos hsync refrence,data valid
    wire                        cmos_pclk           ;//cmos pxiel clock
    wire   [7:0]                cmos_data           ;//cmos data
    wire                        cmos_reset          ;//cmos reset
    wire                        initial_en          ;
    wire[15:0]                  cmos1_d_16bit       ;
    wire                        cmos1_href_16bit    ;
    reg [7:0]                   cmos1_d_d0          ;
    reg                         cmos1_href_d0       ;
    reg                         cmos1_vsync_d0      ;
    wire                        cmos1_pclk_16bit    ;
    wire[15:0]                  cmos2_d_16bit       /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_href_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    reg [7:0]                   cmos2_d_d0          /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_href_d0       /*synthesis PAP_MARK_DEBUG="1"*/;
    reg                         cmos2_vsync_d0      /*synthesis PAP_MARK_DEBUG="1"*/;
    wire                        cmos2_pclk_16bit    /*synthesis PAP_MARK_DEBUG="1"*/;
    wire[15:0]                  o_rgb565            ;
    wire                        pclk_in_test        ;    
    wire                        vs_in_test          ;
    wire                        de_in_test          ;
    wire[15:0]                  i_rgb565            ;
    wire                        de_re               ;
//axi bus   
    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr                 ;
    wire                        axi_awuser_ap              ;
    wire [3:0]                  axi_awuser_id              ;
    wire [3:0]                  axi_awlen                  ;
    wire                        axi_awready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_awvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata                  ;
    wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb                  ;
    wire                        axi_wready                 ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [3:0]                  axi_wusero_id              ;
    wire                        axi_wusero_last            ;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr                 ;
    wire                        axi_aruser_ap              ;
    wire [3:0]                  axi_aruser_id              ;
    wire [3:0]                  axi_arlen                  ;
    wire                        axi_arready                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_arvalid                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata                   /* synthesis syn_keep = 1 */;
    wire                        axi_rvalid                  /* synthesis syn_keep = 1 */;
    wire [3:0]                  axi_rid                    ;
    wire                        axi_rlast                  ;
//axi_0 bus
//axi bus   
    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr_0                 ;
    wire                        axi_awuser_ap_0              ;
    wire [3:0]                  axi_awuser_id_0              ;
    wire [3:0]                  axi_awlen_0                  ;
    wire                        axi_awready_0                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_awvalid_0                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata_0                  ;
    wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb_0                  ;
    wire                        axi_wready_0                 ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [3:0]                  axi_wusero_id_0              ;
    wire                        axi_wusero_last_0            ;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr_0                 ;
    wire                        axi_aruser_ap_0              ;
    wire [3:0]                  axi_aruser_id_0              ;
    wire [3:0]                  axi_arlen_0                  ;
    wire                        axi_arready_0                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_arvalid_0                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata_0                   /* synthesis syn_keep = 1 */;
    wire                        axi_rvalid_0                  /* synthesis syn_keep = 1 */;
    wire [3:0]                  axi_rid_0                    ;
    wire                        axi_rlast_0                  ;
//axi_1 bus
//axi bus   
    wire [CTRL_ADDR_WIDTH-1:0]  axi_awaddr_1                 ;
    wire                        axi_awuser_ap_1              ;
    wire [3:0]                  axi_awuser_id_1              ;
    wire [3:0]                  axi_awlen_1                  ;
    wire                        axi_awready_1                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_awvalid_1                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_wdata_1                  ;
    wire [MEM_DQ_WIDTH*8/8-1:0] axi_wstrb_1                  ;
    wire                        axi_wready_1                 ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [3:0]                  axi_wusero_id_1              ;
    wire                        axi_wusero_last_1            ;
    wire [CTRL_ADDR_WIDTH-1:0]  axi_araddr_1                 ;
    wire                        axi_aruser_ap_1              ;
    wire [3:0]                  axi_aruser_id_1              ;
    wire [3:0]                  axi_arlen_1                  ;
    wire                        axi_arready_1                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire                        axi_arvalid_1                ;/*synthesis PAP_MARK_DEBUG="1"*/
    wire [MEM_DQ_WIDTH*8-1:0]   axi_rdata_1                   /* synthesis syn_keep = 1 */;
    wire                        axi_rvalid_1                  /* synthesis syn_keep = 1 */;
    wire [3:0]                  axi_rid_1                    ;
    wire                        axi_rlast_1                  ;


    reg  [26:0]                 cnt                        ;
    reg  [15:0]                 cnt_1                      ;
    wire                            color_bar_hs;
    wire                            color_bar_vs;
    wire                            color_bar_de;
    wire[7:0]                       color_bar_r;
    wire[7:0]                       color_bar_g;
    wire[7:0]                       color_bar_b;
    wire                            v0_hs;
    wire                            v0_vs;
    wire                            v0_de;
    wire[23:0]                      v0_data;
    wire[23:0] vout_data;

    wire [23:0]ch1_read_data;
    wire ch1_read_en;
    wire ch0_read_en;
/////////////////////////////////////////////////////////////////////////////////////
//PLL
    pll u_pll (
        .clkin1   (  sys_clk    ),//50MHz
        .clkout0  (  pix_clk    ),//307.125M 720P3--》148.5
        .clkout1  (  cfg_clk    ),//10MHz
        .clkout2  (  clk_25M    ),//25M
        .pll_lock (  locked     )
    );

//配置7210
    ms72xx_ctl ms72xx_ctl(
        .clk             (  cfg_clk        ), //input       clk,
        .rst_n           (  rstn_out       ), //input       rstn,
        .init_over_tx    (  init_over_tx   ), //output      init_over,                                
        .init_over_rx    (  init_over_rx   ), //output      init_over,
        .iic_tx_scl      (  iic_tx_scl     ), //output      iic_scl,
        .iic_tx_sda      (  iic_tx_sda     ), //inout       iic_sda
        .iic_scl         (  iic_scl        ), //output      iic_scl,
        .iic_sda         (  iic_sda        )  //inout       iic_sda
    );
   assign    hdmi_int_led    =    init_over_tx; 
    
    always @(posedge cfg_clk)
    begin
    	if(!locked)
    	    rstn_1ms <= 16'd0;
    	else
    	begin
    		if(rstn_1ms == 16'h2710)
    		    rstn_1ms <= rstn_1ms;
    		else
    		    rstn_1ms <= rstn_1ms + 1'b1;
    	end
    end
    
    assign rstn_out = (rstn_1ms == 16'h2710);

//配置CMOS///////////////////////////////////////////////////////////////////////////////////
//OV5640 register configure enable    
    power_on_delay	power_on_delay_inst(
    	.clk_50M                 (sys_clk        ),//input
    	.reset_n                 (1'b1           ),//input	
    	.camera1_rstn            (cmos1_reset    ),//output
    	.camera2_rstn            (cmos2_reset    ),//output	
    	.camera_pwnd             (               ),//output
    	.initial_en              (initial_en     ) //output		
    );
//CMOS1 Camera 
    reg_config	coms1_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos1_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos1_scl          ),//output
    	.i2c_sdat                (cmos1_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[0]  ),//output config_finished
    	.reg_index               (                   ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );

//CMOS2 Camera 
    reg_config	coms2_reg_config(
    	.clk_25M                 (clk_25M            ),//input
    	.camera_rstn             (cmos2_reset        ),//input
    	.initial_en              (initial_en         ),//input		
    	.i2c_sclk                (cmos2_scl          ),//output
    	.i2c_sdat                (cmos2_sda          ),//inout
    	.reg_conf_done           (cmos_init_done[1]  ),//output config_finished
    	.reg_index               (                   ),//output reg [8:0]
    	.clock_20k               (                   ) //output reg
    );
//CMOS 8bit转16bit///////////////////////////////////////////////////////////////////////////////////
//CMOS1
    always@(posedge cmos1_pclk)
        begin
            cmos1_d_d0        <= cmos1_data    ;
            cmos1_href_d0     <= cmos1_href    ;
            cmos1_vsync_d0    <= cmos1_vsync   ;
        end

    cmos_8_16bit cmos1_8_16bit(
    	.pclk           (cmos1_pclk       ),//input
    	.rst_n          (cmos_init_done[0]),//input
    	.pdata_i        (cmos1_d_d0       ),//input[7:0]
    	.de_i           (cmos1_href_d0    ),//input
    	.vs_i           (cmos1_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos1_pclk_16bit ),//output
    	.pdata_o        (cmos1_d_16bit    ),//output[15:0]
    	.de_o           (cmos1_href_16bit ) //output
    );
//CMOS2
    always@(posedge cmos2_pclk)
        begin
            cmos2_d_d0        <= cmos2_data    ;
            cmos2_href_d0     <= cmos2_href    ;
            cmos2_vsync_d0    <= cmos2_vsync   ;
        end

    cmos_8_16bit cmos2_8_16bit(
    	.pclk           (cmos2_pclk       ),//input
    	.rst_n          (cmos_init_done[1]),//input
    	.pdata_i        (cmos2_d_d0       ),//input[7:0]
    	.de_i           (cmos2_href_d0    ),//input
    	.vs_i           (cmos2_vsync_d0    ),//input
    	
    	.pixel_clk      (cmos2_pclk_16bit ),//output
    	.pdata_o        (cmos2_d_16bit    ),//output[15:0]
    	.de_o           (cmos2_href_16bit ) //output
    );
//输入视频源选择//////////////////////////////////////////////////////////////////////////////////////////
`ifdef CMOS_1
assign     pclk_in_test    =    cmos1_pclk_16bit    ;
assign     vs_in_test      =    cmos1_vsync_d0      ;
assign     de_in_test      =    cmos1_href_16bit    ;
assign     i_rgb565        =    {cmos1_d_16bit[4:0],cmos1_d_16bit[10:5],cmos1_d_16bit[15:11]};//{r,g,b}
`elsif CMOS_2
assign     pclk_in_test    =    cmos2_pclk_16bit    ;
assign     vs_in_test      =    cmos2_vsync_d0      ;
assign     de_in_test      =    cmos2_href_16bit    ;
assign     i_rgb565        =    {cmos2_d_16bit[4:0],cmos2_d_16bit[10:5],cmos2_d_16bit[15:11]};//{r,g,b}
`endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//修改ddr读写模块v1

wire state_0,state_1;
 wire done_next_1;
 wire done_next_2;
 reg  begin_first;
 reg vs_in_test_1d;
 
reg wr_en=0;
reg wr_en_1d;
wire wr_clk_1;
assign wr_clk_1=pclk_in_test;
 always @(posedge wr_clk_1)
 begin
 vs_in_test_1d<=vs_in_test;
 wr_en_1d<=wr_en;
 if (~ vs_in_test_1d && vs_in_test)begin
 wr_en<=1;
 end
 else wr_en <= wr_en; 
 end
 always@(posedge wr_clk_1)begin
 if(~wr_en_1d & wr_en)
 begin_first<=1'b1;
 else if(done_next_1)
 begin_first <=0;
 else 
 begin_first<=begin_first;
 end

 reg  state_0_1d ;
 reg  state_0_2d ;
  reg  state_1_1d ;
 reg  state_1_2d ;
 reg  ch1_read_en_1d;
 reg  ch1_read_en_2d;
 always@(posedge core_clk)
 begin
    state_0_1d <=state_0;
    state_0_2d <=state_0_1d;
    state_1_1d <=state_1;
    state_1_2d <=state_1_1d;
    ch1_read_en_1d<=ch1_read_en;
    ch1_read_en_2d<=ch1_read_en_1d;

 end

reg state_r=0;
always@(posedge core_clk)begin
if(ch1_read_en & ~state_r)
state_r<=1'b1;
else if (state_r & ch0_read_en)
state_r<=1'b0;
else state_r<=state_r;
end



 wire[2:0]state_w;
 assign state_w=(state_0==1)?2'b10:
                (state_1==1)?2'b11:
                2'b00;

    fram_buf #(
    .MEM_ROW_WIDTH        ( 15    ),
    .MEM_COLUMN_WIDTH     ( 10    ),
    .MEM_BANK_WIDTH       ( 3     ),
    .MEM_DQ_WIDTH         ( 32    ),
    .CTRL_ADDR_WIDTH      (  28      ),
    .H_NUM                ( 12'd640),
    .V_NUM                ( 12'd720),
    .H_ORIGNAL             (12'd1280),
    .PIX_WIDTH            ( 16),//24
    .ADDR_OFFSET        (28'd0)  
) fram_buf_m0(
        .ddr_clk        (  core_clk             ),//input                         ddr_clk,
        .ddr_rstn       (  ddr_init_done        ),//input                         ddr_rstn,
        //data_in                                  
        .vin_clk        (  pclk_in_test         ),//input                         vin_clk,
        .wr_fsync       (  vs_in_test           ),//input                         wr_fsync,
        .wr_en          (  de_in_test           ),//input                         wr_en,
        .wr_data        (  i_rgb565             ),//input  [15 : 0]  wr_data,
        //data_out
        .vout_clk       (  pix_clk              ),//input                         vout_clk,
        .rd_fsync       (  v0_vs               ),//input                         rd_fsync,
        .rd_en          (  ch0_read_en          ),//input                         rd_en,
        .vout_de        (                    ),//output                        vout_de,
        .vout_data      (  o_rgb565             ),//output [PIX_WIDTH- 1'b1 : 0]  vout_data,
        .init_done      (  init_done            ),//output reg                    init_done,
        //axi bus
        .axi_awaddr     (  axi_awaddr_0           ),// output[27:0]
        .axi_awid       (  axi_awuser_id_0        ),// output[3:0]
        .axi_awlen      (  axi_awlen_0            ),// output[3:0]
        .axi_awsize     (                       ),// output[2:0]
        .axi_awburst    (                       ),// output[1:0]
        .axi_awready    (  axi_awready_0          ),// input
        .axi_awvalid    (  axi_awvalid_0          ),// output               
        .axi_wdata      (  axi_wdata_0            ),// output[255:0]
        .axi_wstrb      (  axi_wstrb_0            ),// output[31:0]
        .axi_wlast      (  axi_wusero_last_0      ),// input
        .axi_wvalid     (                       ),// output
        .axi_wready     (  axi_wready_0           ),// input
        .axi_bid        (  4'd0                 ),// input[3:0]
        .axi_araddr     (  axi_araddr_0           ),// output[27:0]
        .axi_arid       (  axi_aruser_id_0        ),// output[3:0]
        .axi_arlen      (  axi_arlen_0            ),// output[3:0]
        .axi_arsize     (                       ),// output[2:0]
        .axi_arburst    (                       ),// output[1:0]
        .axi_arvalid    (  axi_arvalid_0          ),// output
        .axi_arready    (  axi_arready_0          ),// input
        .axi_rready     (                       ),// output
        .axi_rdata      (  axi_rdata_0            ),// input[255:0]
        .axi_rvalid     (  axi_rvalid_0           ),// input
        .axi_rlast      (  axi_rlast_0            ),// input
        .axi_rid        (  axi_rid_0              ),// input[3:0]
        .begin_next     (  done_next_2| begin_first ),//input//begin_next | done_next_2
        .done_next      (  done_next_1        ),  //output 
        .state(state_0)
    );

/////////////////////////////////////////////////////////////////////////////////////

    fram_buf #(
    .MEM_ROW_WIDTH        ( 15    ),
    .MEM_COLUMN_WIDTH     ( 10    ),
    .MEM_BANK_WIDTH       ( 3     ),
    .MEM_DQ_WIDTH         ( 32    ),
    .CTRL_ADDR_WIDTH      (  28      ),
    .H_NUM                ( 12'd960),//12'd1920),
    .V_NUM                ( 12'd1080),//12'd1080),//12'd106),//\
    .H_ORIGNAL             (12'd1920),
    .PIX_WIDTH            ( 16),//24
    .ADDR_OFFSET        (28'd250000) 
) 
 fram_buf_m1(
        .ddr_clk        (  core_clk             ),//input                         ddr_clk,
        .ddr_rstn       (  ddr_init_done        ),//input                         ddr_rstn,
        //data_in                                  
        .vin_clk        (  pixclk_in         ),//input                         vin_clk,
        .wr_fsync       (  vs_in           ),//input                         wr_fsync,
        .wr_en          (  de_in           ),//input                         wr_en,
        .wr_data        (  {r_in[7:3],g_in[7:2],b_in[7:3]} ),//16'hF410{r_in[7:3],g_in[7:2],b_in[7:3]}input  [15 : 0]  wr_data,
        //data_out
        .vout_clk       (  pix_clk              ),//input                         vout_clk,
        .rd_fsync       (  vs               ),//input                         rd_fsync,
        .rd_en          (  ch1_read_en          ),//input                         rd_en,
        .vout_de        (                   ),//output                        vout_de,
        .vout_data      (  ch1_read_data             ),//output [PIX_WIDTH- 1'b1 : 0]  vout_data,
        .init_done      (  init_done            ),//output reg                    init_done,
        //axi bus
        .axi_awaddr     (  axi_awaddr_1           ),// output[27:0]
        .axi_awid       (  axi_awuser_id_1        ),// output[3:0]
        .axi_awlen      (  axi_awlen_1            ),// output[3:0]
        .axi_awsize     (                       ),// output[2:0]
        .axi_awburst    (                       ),// output[1:0]
        .axi_awready    (  axi_awready_1          ),// input
        .axi_awvalid    (  axi_awvalid_1          ),// output               
        .axi_wdata      (  axi_wdata_1            ),// output[255:0]
        .axi_wstrb      (  axi_wstrb_1            ),// output[31:0]
        .axi_wlast      (  axi_wusero_last_1      ),// input
        .axi_wvalid     (     ),// output
        .axi_wready     (  axi_wready_1           ),// input
        .axi_bid        (  4'd0                 ),// input[3:0]
        .axi_araddr     (  axi_araddr_1           ),// output[27:0]
        .axi_arid       (  axi_aruser_id_1         ),// output[3:0]
        .axi_arlen      (  axi_arlen_1            ),// output[3:0]
        .axi_arsize     (                       ),// output[2:0]
        .axi_arburst    (                       ),// output[1:0]
        .axi_arvalid    (  axi_arvalid_1          ),// output
        .axi_arready    (  axi_arready_1          ),// input
        .axi_rready     (           ),// output
        .axi_rdata      (  axi_rdata_1            ),// input[255:0]
        .axi_rvalid     (  axi_rvalid_1           ),// input
        .axi_rlast      (  axi_rlast_1            ),// input
        .axi_rid        (  axi_rid_1              ),// input[3:0]
        .begin_next     (done_next_1),
        .done_next      (done_next_2) ,
        .state(state_1)           
    );

//视频拼接
color_bar color_bar_m0
(
.pix_clk                            (pix_clk                ),
.rstn_out                            (rstn_out          ),
.hs_out                             (color_bar_hs             ),
.vs_out                             (color_bar_vs             ),
.de_out                             (color_bar_de             ),
.r_out                          (color_bar_r              ),
.g_out                          (color_bar_g              ),
.b_out                          (color_bar_b              )
);

video_rect_read_data video_rect_read_data_m0
(
.video_clk                      (pix_clk                ),
.rst                            (0                      ),
.video_left_offset              (12'd0                    ),
.video_top_offset               (12'd0                    ),
.video_width                    (12'd640                  ),
.video_height	                (12'd720                  ),
//.read_req                       (ch0_read_req             ),
//.read_req_ack                   (ch0_read_req_ack         ),
.read_en                        (ch0_read_en              ),
.read_data                      (o_rgb565                ),
.timing_hs                      (color_bar_hs             ),
.timing_vs                      (color_bar_vs             ),
.timing_de                      (color_bar_de             ),
.timing_data 	                ({color_bar_r[4:0],color_bar_g[5:0],color_bar_b[4:0]}),
.hs                             (v0_hs                    ),
.vs                             (v0_vs                    ),
.de                             (v0_de                    ),
.vout_data                      (v0_data                  )
);

video_rect_read_data video_rect_read_data_m1
(
.video_clk                      (pix_clk                ),
.rst                            (0                   ),
.video_left_offset              (12'd800                  ),
.video_top_offset               (12'd0                    ),
.video_width                    (12'd960                   ),
.video_height	                (12'd1080                 ),
//.read_req                       (ch1_read_req             ),
//.read_req_ack                   (ch1_read_req_ack         ),
.read_en                        (ch1_read_en              ),
.read_data                      (ch1_read_data       ),//
.timing_hs                      (v0_hs                    ),
.timing_vs                      (v0_vs                    ),
.timing_de                      (v0_de                    ),
.timing_data 	                (v0_data                  ),
.hs                             (hs                       ),
.vs                             (vs                       ),
.de                             (de                       ),
.vout_data                      (vout_data                )
);

   assign vs_out  =  vs;                
   assign hs_out  =  hs;               
   assign de_out  =  de;                  
   assign r_out   =  {vout_data[15:11],3'b000};                  
   assign g_out   =  {vout_data[10:5],2'b00};                
   assign b_out   =  {vout_data[4:0],3'b000} ;
   reg vs_1d;
   wire turn;
   reg [2:0]count=2'b00;
   always @(posedge pix_clk)
    begin
        vs_1d <= vs;
        if(~vs_1d &vs)
        count=count+1'b1;
    end 
    assign turn = ~vs_1d &vs;
 
//axi仲裁   
AXI4_Interconnect AXI4_Interconnect_inst(
    .clk(core_clk), 
    .rst(~ddr_init_done),

    .M1_ARID(axi_aruser_id_1),
    .M1_ARADDR(axi_araddr_1),
    .M1_ARVALID(axi_arvalid_1),
    .M1_ARREADY(axi_arready_1),
    .M1_ARLEN(axi_arlen_1),
    // Read Address Channel
    .M1_RDATA(axi_rdata_1),
    .M1_RLAST(axi_rlast_1),
    .M1_RVALID(axi_rvalid_1),
    .M1_RID(axi_rid_1),
    // Read Data Channel
    .M1_AWID(axi_awuser_id_1),
    .M1_AWADDR(axi_awaddr_1),
    .M1_AWVALID(axi_awvalid_1),
    .M1_AWREADY(axi_awready_1),
    .M1_AWLEN(axi_awlen_1),
    // Write Address Channel
    .M1_WDATA(axi_wdata_1),
    .M1_WLAST(axi_wusero_last_1),
    .M1_WREADY(axi_wready_1),
    // Write Data Channel

    .M2_ARID(axi_aruser_id_0),
    .M2_ARADDR(axi_araddr_0),
    .M2_ARVALID(axi_arvalid_0),
    .M2_ARREADY(axi_arready_0),
    .M2_ARLEN(axi_arlen_0),
    // Read Address Channel
    .M2_RDATA(axi_rdata_0),
    .M2_RLAST(axi_rlast_0),
    .M2_RVALID(axi_rvalid_0),
    .M2_RID(axi_rid_0),
    // Read Data Channel
    .M2_AWID(axi_awuser_id_0),
    .M2_AWADDR(axi_awaddr_0),
    .M2_AWVALID(axi_awvalid_0),
    .M2_AWREADY(axi_awready_0),
    .M2_AWLEN(axi_awlen_0),
    // Write Address Channel
    .M2_WDATA(axi_wdata_0),
    .M2_WLAST(axi_wusero_last_0),
    .M2_WREADY(axi_wready_0),
    // Write Data Channel

    .S_ARID(axi_aruser_id),
    .S_ARADDR(axi_araddr),
    .S_ARVALID(axi_arvalid),
    .S_ARREADY(axi_arready),
    .S_ARLEN(axi_arlen),
    // Read Address Channel
    .S_RDATA(axi_rdata),
    .S_RLAST(axi_rlast),
    .S_RVALID(axi_rvalid), 
    .S_RID(axi_rid),
    // Read Data Channel
    .S_AWID(axi_awuser_id),
    .S_AWADDR(axi_awaddr),
    .S_AWVALID(axi_awvalid),
    .S_AWREADY(axi_awready),
    .S_AWLEN(axi_awlen),
    // Write Address Channel
    .S_WDATA(axi_wdata),
    .S_WLAST(axi_wusero_last),
    .S_WREADY(axi_wready),
    // Write Data Channel
    .state_r(state_r),
    .state_w(state_w)//~done_next
    );	


/////////////////////////////////////////////////////////////////////////////////////////////
//ddr    
        DDR3_50H u_DDR3_50H (
             .ref_clk                   (sys_clk            ),
             .resetn                    (rstn_out           ),// input
             .ddr_init_done             (ddr_init_done      ),// output
             .ddrphy_clkin              (core_clk           ),// output
             .pll_lock                  (pll_lock           ),// output

             .axi_awaddr                (axi_awaddr         ),// input [27:0]
             .axi_awuser_ap             (1'b0               ),// input
             .axi_awuser_id             (axi_awuser_id      ),// input [3:0]
             .axi_awlen                 (axi_awlen          ),// input [3:0]
             .axi_awready               (axi_awready        ),// output
             .axi_awvalid               (axi_awvalid        ),// input
             .axi_wdata                 (axi_wdata          ),//input
             .axi_wstrb                 ({MEM_DQ_WIDTH{1'b1}}          ),// input [31:0]
             .axi_wready                (axi_wready         ),// output
             .axi_wusero_id             (                   ),// output [3:0]
             .axi_wusero_last           (axi_wusero_last    ),// output
             .axi_araddr                (axi_araddr         ),// input [27:0]
             .axi_aruser_ap             (1'b0               ),// input
             .axi_aruser_id             (axi_aruser_id     ),// input [3:0]
             .axi_arlen                 (axi_arlen          ),// input [3:0]
             .axi_arready               (axi_arready        ),// output
             .axi_arvalid               (axi_arvalid       ),// input
             .axi_rdata                 (axi_rdata          ),// output [255:0]
             .axi_rid                   (axi_rid            ),// output [3:0]
             .axi_rlast                 (axi_rlast          ),// output
             .axi_rvalid                (axi_rvalid         ),// output

             .apb_clk                   (1'b0               ),// input
             .apb_rst_n                 (1'b1               ),// input
             .apb_sel                   (1'b0               ),// input
             .apb_enable                (1'b0               ),// input
             .apb_addr                  (8'b0               ),// input [7:0]
             .apb_write                 (1'b0               ),// input
             .apb_ready                 (                   ), // output
             .apb_wdata                 (16'b0              ),// input [15:0]
             .apb_rdata                 (                   ),// output [15:0]
             .apb_int                   (                   ),// output

             .mem_rst_n                 (mem_rst_n          ),// output
             .mem_ck                    (mem_ck             ),// output
             .mem_ck_n                  (mem_ck_n           ),// output
             .mem_cke                   (mem_cke            ),// output
             .mem_cs_n                  (mem_cs_n           ),// output
             .mem_ras_n                 (mem_ras_n          ),// output
             .mem_cas_n                 (mem_cas_n          ),// output
             .mem_we_n                  (mem_we_n           ),// output
             .mem_odt                   (mem_odt            ),// output
             .mem_a                     (mem_a              ),// output [14:0]
             .mem_ba                    (mem_ba             ),// output [2:0]
             .mem_dqs                   (mem_dqs            ),// inout [3:0]
             .mem_dqs_n                 (mem_dqs_n          ),// inout [3:0]
             .mem_dq                    (mem_dq             ),// inout [31:0]
             .mem_dm                    (mem_dm             ),// output [3:0]
             //debug
             .debug_data                (                   ),// output [135:0]
             .debug_slice_state         (                   ),// output [51:0]
             .debug_calib_ctrl          (                   ),// output [21:0]
             .ck_dly_set_bin            (                   ),// output [7:0]
             .force_ck_dly_en           (1'b0               ),// input
             .force_ck_dly_set_bin      (8'h05              ),// input [7:0]
             .dll_step                  (                   ),// output [7:0]
             .dll_lock                  (                   ),// output
             .init_read_clk_ctrl        (2'b0               ),// input [1:0]
             .init_slip_step            (4'b0               ),// input [3:0]
             .force_read_clk_ctrl       (1'b0               ),// input
             .ddrphy_gate_update_en     (1'b0               ),// input
             .update_com_val_err_flag   (                   ),// output [3:0]
             .rd_fake_stop              (1'b0               ) // input
       );

//心跳信号
     always@(posedge core_clk) begin
        if (!ddr_init_done)
            cnt <= 27'd0;
        else if ( cnt >= TH_1S )
            cnt <= 27'd0;
        else
            cnt <= cnt + 27'd1;
     end

     always @(posedge core_clk)
        begin
        if (!ddr_init_done)
            heart_beat_led <= 1'd1;
        else if ( cnt >= TH_1S )
            heart_beat_led <= ~heart_beat_led;
    end
                 
/////////////////////////////////////////////////////////////////////////////////////
endmodule
