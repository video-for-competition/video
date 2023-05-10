`timescale 1ns / 1ns
module AXI4_Interconnect(
                        clk, rst,

                         //Master_1_Release,
                         M1_ARID, M1_ARADDR, M1_ARVALID, M1_ARREADY, M1_ARLEN,// Read Address Channel
                         M1_RDATA, M1_RLAST, M1_RVALID,  M1_RID,		// Read Data Channel
                         M1_AWID, M1_AWADDR, M1_AWVALID, M1_AWREADY, M1_AWLEN, // Write Address Channel
                         M1_WDATA, M1_WLAST,  M1_WREADY, 				// Write Data Channel
                         					        
                        // Master_2_Release,
                         M2_ARID, M2_ARADDR, M2_ARVALID, M2_ARREADY, M2_ARLEN,// Read Address Channel
                         M2_RDATA, M2_RLAST, M2_RVALID,  M2_RID,		// Read Data Channel
                         M2_AWID, M2_AWADDR, M2_AWVALID, M2_AWREADY, M2_AWLEN, // Write Address Channel
                         M2_WDATA, M2_WLAST,  M2_WREADY, 				// Write Data Channel

                
                         S_ARID, S_ARADDR, S_ARVALID, S_ARREADY, S_ARLEN,// Read Address Channel
                         S_RDATA, S_RLAST, S_RVALID,  S_RID,		// Read Data Channel
                         S_AWID, S_AWADDR, S_AWVALID, S_AWREADY, S_AWLEN, // Write Address Channel
                         S_WDATA, S_WLAST,  S_WREADY ,				// Write Data Channel
                         state_r,
                         state_w
                         );							             

parameter memWidth = 256;
parameter addressLength = 28;		// Calculated by taking (log2) of "memDepth"

/*			
input clk;
input rst;

/////////// Interconnect's Circular Arbitration Ports ///////////

input [0:0] Master_1_Release;
input [0:0] Master_2_Release;

/////////// Master 1 Ports ///////////

input [3:0] M1_ARID;
input [addressLength-1:0] M1_ARADDR;	// Read Address Channel
input [0:0] M1_ARVALID;
output reg [0:0] M1_ARREADY;
input [3:0] M1_ARLEN;

output reg[3:0]M1_RID;
output reg[memWidth-1:0]M1_RDATA;			// Read Data Channel
output reg[0:0]M1_RLAST;
output reg[0:0]M1_RVALID;

input [3:0] M1_AWID;
input [addressLength-1:0] M1_AWADDR;	// Write Address Channel
input [0:0] M1_AWVALID;
output reg[0:0] M1_AWREADY;
input [3:0] M1_AWLEN;



input [memWidth-1:0] M1_WDATA;		// Write Data Channel
output reg[0:0] M1_WREADY;
output reg  [0:0] M1_WLAST;


/////////// Master 2 Ports ///////////
input [3:0]M2_ARID;
input [addressLength-1:0]M2_ARADDR;	// Read Address Channel
input [0:0]M2_ARVALID;
output reg[0:0]M2_ARREADY;
input [3:0]M2_ARLEN;

output reg[3:0]M2_RID;
output reg[memWidth-1:0]M2_RDATA;			// Read Data Channel
output reg[0:0]M2_RLAST;
output reg[0:0]M2_RVALID;


input [3:0]M2_AWID;
input [addressLength-1:0]M2_AWADDR;	// Write Address Channel
input [0:0]M2_AWVALID;
output reg[0:0]M2_AWREADY;
input [3:0]M2_AWLEN;

input [memWidth-1:0]M2_WDATA;		// Write Data Channel
output reg[0:0]M2_WREADY;
output reg  [0:0]M2_WLAST;

// Slave Wires
output reg[3:0] S_ARID;
output reg[addressLength-1:0] S_ARADDR;	// Read Address Channel
output reg[0:0] S_ARVALID;
input[0:0] S_ARREADY;
output reg[3:0] S_ARLEN;

input[3:0] S_RID;
input[memWidth-1:0] S_RDATA;			// Read Data Channel
input[0:0] S_RLAST;
input[0:0] S_RVALID;


output reg[3:0] S_AWID;
output reg[addressLength-1:0] S_AWADDR;	// Write Address Channel
output reg[0:0] S_AWVALID;
input [0:0] S_AWREADY;
output reg[3:0] S_AWLEN;

output reg[memWidth-1:0] S_WDATA;		// Write Data Channel
input[0:0] S_WREADY;
input[0:0] S_WLAST;

reg state;
always @(posedge clk ) begin
    if (rst == 1'b1)
    state=0;
    else  if (Master_1_Release | Master_2_Release)
    state=~state;
    else
    state=state;
end
    

always @(posedge clk ) begin
    if (rst == 1'b1)
    begin 
        M1_ARREADY<= 0;//
        M1_RID<= 0;//
        M1_RDATA<= 0;//
        M1_RLAST<= 0;//
        M1_RVALID<= 0;//
        M1_AWREADY  <= 0;//
        M1_WREADY <= 0;//
        M1_WLAST<= 0;//

        M2_ARREADY<= 0;
        M2_RID<= 0;
        M2_RDATA<= 0;
        M2_RLAST<= 0;
        M2_RVALID<= 0;
        M2_AWREADY  <= 0;
        M2_WREADY <= 0;
        M1_WLAST<= 0;

        S_ARID<= 0;
        S_ARADDR<= 0;
        S_ARVALID<= 0;
        S_ARLEN<= 0;
        S_AWID<= 0;
        S_AWADDR<= 0;
        S_AWVALID<= 0;
        S_AWLEN<= 0;
        S_WDATA<= 0;


    end
    else if(state==1'b1)
    begin
        M1_ARREADY<= S_ARREADY;
        M1_RID<= S_RID;
        M1_RDATA<= S_RDATA;
        M1_RLAST<= S_RLAST;
        M1_RVALID<= S_RVALID;
        M1_AWREADY  <= S_AWREADY;
        M1_WREADY <= S_WREADY;
        M1_WLAST <= S_WLAST;

        M2_ARREADY<= M2_ARREADY;
        M2_RID<= M2_RID;
        M2_RDATA<= M2_RDATA;
        M2_RLAST<= M2_RLAST;
        M2_RVALID<= M2_RVALID;
        M2_AWREADY  <= M2_AWREADY;
        M2_WREADY <= M2_WREADY;
        M2_WLAST <= M2_WLAST;

        S_ARID<= M1_ARID;
        S_ARADDR<= M1_ARADDR;
        S_ARVALID<= M1_ARVALID;
        S_ARLEN<= M1_ARLEN;
        S_AWID<= M1_AWID;
        S_AWADDR<= M1_AWADDR;
        S_AWVALID<= M1_AWVALID;
        S_AWLEN<= M1_AWLEN;
        S_WDATA<= M1_WDATA;

    end
    else if(state==1'b0)
        M2_ARREADY<= S_ARREADY;
        M2_RID<= S_RID;
        M2_RDATA<= S_RDATA;
        M2_RLAST<= S_RLAST;
        M2_RVALID<= S_RVALID;
        M2_AWREADY  <= S_AWREADY;
        M2_WREADY <= S_WREADY;
        M2_WLAST <= S_WLAST;

        M1_ARREADY<= M1_ARREADY;
        M1_RID<= M1_RID;
        M1_RDATA<= M1_RDATA;
        M1_RLAST<= M1_RLAST;
        M1_RVALID<= M1_RVALID;
        M1_AWREADY  <= M1_AWREADY;
        M1_WREADY <= M1_WREADY;
        M1_WLAST <= M1_WLAST;
        
        S_ARID<= M2_ARID;
        S_ARADDR<= M2_ARADDR;
        S_ARVALID<= M2_ARVALID;
        S_ARLEN<= M2_ARLEN;
        S_AWID<= M2_AWID;
        S_AWADDR<= M2_AWADDR;
        S_AWVALID<= M2_AWVALID;
        S_AWLEN<= M2_AWLEN;
        S_WDATA<= M2_WDATA;

    begin

    end
*/
input clk;
input rst;
input  state_r;
input  [2:0]state_w;//state=10是M2，state=11是M1
/////////// Interconnect's Circular Arbitration Ports ///////////

//input [0:0] Master_1_Release;
//input [0:0] Master_2_Release;

/////////// Master 1 Ports ///////////

input [3:0] M1_ARID;
input [addressLength-1:0] M1_ARADDR;	// Read Address Channel
input [0:0] M1_ARVALID;
output [0:0] M1_ARREADY;
input [3:0] M1_ARLEN;

output[3:0]M1_RID;
output[memWidth-1:0]M1_RDATA;			// Read Data Channel
output[0:0]M1_RLAST;
output[0:0]M1_RVALID;

input [3:0] M1_AWID;
input [addressLength-1:0] M1_AWADDR;	// Write Address Channel
input [0:0] M1_AWVALID;
output[0:0] M1_AWREADY;
input [3:0] M1_AWLEN;



input [memWidth-1:0] M1_WDATA;		// Write Data Channel
output[0:0] M1_WREADY;
output  [0:0] M1_WLAST;


/////////// Master 2 Ports ///////////
input [3:0]M2_ARID;
input [addressLength-1:0]M2_ARADDR;	// Read Address Channel
input [0:0]M2_ARVALID;
output[0:0]M2_ARREADY;
input [3:0]M2_ARLEN;

output[3:0]M2_RID;
output[memWidth-1:0]M2_RDATA;			// Read Data Channel
output[0:0]M2_RLAST;
output[0:0]M2_RVALID;


input [3:0]M2_AWID;
input [addressLength-1:0]M2_AWADDR;	// Write Address Channel
input [0:0]M2_AWVALID;
output[0:0]M2_AWREADY;
input [3:0]M2_AWLEN;

input [memWidth-1:0]M2_WDATA;		// Write Data Channel
output[0:0]M2_WREADY;
output  [0:0]M2_WLAST;

// Slave Wires
output[3:0] S_ARID;
output[addressLength-1:0] S_ARADDR;	// Read Address Channel
output[0:0] S_ARVALID;
input[0:0] S_ARREADY;
output[3:0] S_ARLEN;

input[3:0] S_RID;
input[memWidth-1:0] S_RDATA;			// Read Data Channel
input[0:0] S_RLAST;
input[0:0] S_RVALID;


output[3:0] S_AWID;
output[addressLength-1:0] S_AWADDR;	// Write Address Channel
output[0:0] S_AWVALID;
input [0:0] S_AWREADY;
output[3:0] S_AWLEN;

output[memWidth-1:0] S_WDATA;		// Write Data Channel
input[0:0] S_WREADY;
input[0:0] S_WLAST;



assign    M2_ARREADY= (state_r==0)?S_ARREADY:0;
assign        M2_RID= (state_r==0)?S_RID:0;
assign      M2_RDATA= (state_r==0)?S_RDATA:0;
assign      M2_RLAST= (state_r==0)?S_RLAST:0;
assign     M2_RVALID= (state_r==0)?S_RVALID:0;
assign   M2_AWREADY = (state_w==2'b10)?S_AWREADY:0;
assign    M2_WREADY = (state_w==2'b10)?S_WREADY:0;
assign     M2_WLAST = (state_w==2'b10)?S_WLAST:0;

assign    M1_ARREADY= (state_r==0)?0:S_ARREADY;
assign        M1_RID= (state_r==0)?0:S_RID;
assign      M1_RDATA= (state_r==0)?0:S_RDATA;
assign      M1_RLAST= (state_r==0)?0:S_RLAST;
assign     M1_RVALID= (state_r==0)?0:S_RVALID;
assign  M1_AWREADY  = (state_w==2'b11)?S_AWREADY:0;
assign    M1_WREADY = (state_w==2'b11)?S_WREADY:0;
assign     M1_WLAST = (state_w==2'b11)?S_WLAST:0;
        
assign        S_ARID= (state_r==0)?M2_ARID:M1_ARID;
assign      S_ARADDR= (state_r==0)?M2_ARADDR:M1_ARADDR;
assign     S_ARVALID= (state_r==0)?M2_ARVALID:M1_ARVALID;
assign       S_ARLEN= (state_r==0)?M2_ARLEN:M1_ARLEN;

assign        S_AWID= (state_w==2'b10)?M2_AWID:
                      (state_w==2'b11)?M1_AWID:
                      0;
assign      S_AWADDR= (state_w==2'b10)?M2_AWADDR:
                      (state_w==2'b11)?M1_AWADDR:
                      0;
assign     S_AWVALID= (state_w==2'b10)?M2_AWVALID:
                      (state_w==2'b11)?M1_AWVALID:
                      0;
assign       S_AWLEN= (state_w==2'b10)?M2_AWLEN:
                      (state_w==2'b11)?M1_AWLEN:
                        0;
assign       S_WDATA= (state_w==2'b10)?M2_WDATA:
                      (state_w==2'b11)?M1_WDATA:
                        0;
/*
always @(posedge clk ) begin
    if (rst == 1'b1)
    begin 
        M1_ARREADY<= 0;//
        M1_RID<= 0;//
        M1_RDATA<= 0;//
        M1_RLAST<= 0;//
        M1_RVALID<= 0;//
        M1_AWREADY  <= 0;//
        M1_WREADY <= 0;//
        M1_WLAST<= 0;//

        M2_ARREADY<= 0;
        M2_RID<= 0;
        M2_RDATA<= 0;
        M2_RLAST<= 0;
        M2_RVALID<= 0;
        M2_AWREADY  <= 0;
        M2_WREADY <= 0;
        M1_WLAST<= 0;

        S_ARID<= 0;
        S_ARADDR<= 0;
        S_ARVALID<= 0;
        S_ARLEN<= 0;
        S_AWID<= 0;
        S_AWADDR<= 0;
        S_AWVALID<= 0;
        S_AWLEN<= 0;
        S_WDATA<= 0;


    end
    else if(state==1'b1)
    begin
        M1_ARREADY<= S_ARREADY;
        M1_RID<= S_RID;
        M1_RDATA<= S_RDATA;
        M1_RLAST<= S_RLAST;
        M1_RVALID<= S_RVALID;
        M1_AWREADY  <= S_AWREADY;
        M1_WREADY <= S_WREADY;
        M1_WLAST <= S_WLAST;

        M2_ARREADY<= M2_ARREADY;
        M2_RID<= M2_RID;
        M2_RDATA<= M2_RDATA;
        M2_RLAST<= M2_RLAST;
        M2_RVALID<= M2_RVALID;
        M2_AWREADY  <= M2_AWREADY;
        M2_WREADY <= M2_WREADY;
        M2_WLAST <= M2_WLAST;

        S_ARID<= M1_ARID;
        S_ARADDR<= M1_ARADDR;
        S_ARVALID<= M1_ARVALID;
        S_ARLEN<= M1_ARLEN;
        S_AWID<= M1_AWID;
        S_AWADDR<= M1_AWADDR;
        S_AWVALID<= M1_AWVALID;
        S_AWLEN<= M1_AWLEN;
        S_WDATA<= M1_WDATA;

    end
    else if(state==1'b0)
        M2_ARREADY<= S_ARREADY;
        M2_RID<= S_RID;
        M2_RDATA<= S_RDATA;
        M2_RLAST<= S_RLAST;
        M2_RVALID<= S_RVALID;
        M2_AWREADY  <= S_AWREADY;
        M2_WREADY <= S_WREADY;
        M2_WLAST <= S_WLAST;

        M1_ARREADY<= M1_ARREADY;
        M1_RID<= M1_RID;
        M1_RDATA<= M1_RDATA;
        M1_RLAST<= M1_RLAST;
        M1_RVALID<= M1_RVALID;
        M1_AWREADY  <= M1_AWREADY;
        M1_WREADY <= M1_WREADY;
        M1_WLAST <= M1_WLAST;
        
        S_ARID<= M2_ARID;
        S_ARADDR<= M2_ARADDR;
        S_ARVALID<= M2_ARVALID;
        S_ARLEN<= M2_ARLEN;
        S_AWID<= M2_AWID;
        S_AWADDR<= M2_AWADDR;
        S_AWVALID<= M2_AWVALID;
        S_AWLEN<= M2_AWLEN;
        S_WDATA<= M2_WDATA;

    begin

    end
end
*/
endmodule










