/*
   1、本模块只检测data_valid上升沿，并在valid的第一个有效周期内进入工作状态；完成整个流程后自动进入退休状态
   2、window的高位对应大标号数据，低位对应小标号数据（先入放在低位）
   3、在输入数据有效期间，图像尺寸信号要保证全程有效且不变（暂定）
   4、col_in，row_in不允许超过416
*/

module LineBuffer
#(
   parameter DataWidth = 64,
   parameter KernelSize = 9,
   parameter MaxRowWidth = 9,
   parameter MaxColWidth = 9
)
(
   Clk,
   Rst,

   row_in,
   col_in,

   data_in,
   //data_valid,
   row_count,
   col_count,

   window_out,
   window_valid
);

   input                               Clk;
   input                               Rst;

   input [MaxRowWidth-1: 0]            row_in;     //图像行尺寸
   input [MaxColWidth-1: 0]            col_in;     //图像列尺寸

   input [DataWidth-1: 0]              data_in;
   //input                             data_valid;
   input [MaxRowWidth-1: 0]            row_count;
   input [MaxColWidth-1: 0]            col_count;

   output [KernelSize*DataWidth-1: 0]  window_out;
   output reg                          window_valid;


   //windowmn用于保存输入数据
   wire [DataWidth-1: 0]               window33;   //window33就是输入的data_in，其值本身保存在寄存器中
   reg [DataWidth-1: 0]                window32;
   reg [DataWidth-1: 0]                window31;   //window31表示窗口数据的第三行第一列
                                                   //其余类推
   reg [DataWidth-1: 0]                window23;
   reg [DataWidth-1: 0]                window22;
   reg [DataWidth-1: 0]                window21;

   reg [DataWidth-1: 0]                window13;
   reg [DataWidth-1: 0]                window12;
   reg [DataWidth-1: 0]                window11;


   reg [DataWidth-1: 0]                window33_out;  //windowmn_out为置零操作后的数据
   reg [DataWidth-1: 0]                window32_out;
   reg [DataWidth-1: 0]                window31_out;  //window31表示窗口数据的第三行第一列
                                                      //其余类推
   reg [DataWidth-1: 0]                window23_out;
   reg [DataWidth-1: 0]                window22_out;
   reg [DataWidth-1: 0]                window21_out;

   reg [DataWidth-1: 0]                window13_out;
   reg [DataWidth-1: 0]                window12_out;
   reg [DataWidth-1: 0]                window11_out;

   wire [MaxRowWidth-1: 0]             buffer_addr;
   wire [DataWidth-1: 0]               shift2_out;
   wire [DataWidth-1: 0]               shift1_out;


   //为方便起见，将window_out拆分为9个变量。
   //先入的数据在低位，后入的数据在高位
   assign window_out = {window33_out, window32_out, window31_out,
                        window23_out, window22_out, window21_out,
                        window13_out, window12_out, window11_out};
   
   //窗口数据的移位
   //不论数据是否有效，统统进行移位
   assign window33 = data_in;
   always @(posedge Clk) begin
      if (Rst) begin
         {window32, window31,
         window23, window22, window21,
         window13, window12, window11} <= 0;
      end
      else begin
         //窗口最后一行的移位
         window32 <= window33;
         window31 <= window32;

         //窗口中间一行的移位
         window23 <= shift2_out;
         window22 <= window23;
         window21 <= window22;

         //窗口最前一行的移位
         window13 <= shift1_out;
         window12 <= window13;
         window11 <= window12;
      end
   end
   
   //ShiftReg参数：动态延时，最大延时413，数据位宽64，同步复位
   //中间一行移位寄存器的连接
   assign buffer_addr = row_in - 4;
   ShiftReg413 UShiftReg2 (
      .din(window31),   // input [63:0]
      .addr(buffer_addr),
      .clk(Clk),        // input
      .rst(Rst),        // input
      .dout(shift2_out) // output [63:0]
   );

   //最前一行移位寄存器的连接
   ShiftReg413 UShiftReg1 (
      .din(window21),   // input [63:0]
      .addr(buffer_addr),
      .clk(Clk),        // input
      .rst(Rst),        // input
      .dout(shift1_out) // output [63:0]
   );

   /*
   //状态机
   parameter SIdle = 2'b00, SWork = 2'b01, SRetire = 2'b11;
   always @(posedge Clk) begin
      if (Rst)
         state <= SIdle;
      else if (state == SIdle && data_valid)
         state <= SWork;
      else if (state == SWork && work_end)
         state <= SRetire;
   end

   //程序计数
   always @(posedge Clk) begin
      if (Rst) begin
         row_count <= 0;
         col_count <= 0;
      end
      else if (state == SWork || (state == SIdle && data_valid)) begin
         if (row_count >= row_in - 1) begin     //row_count数值本身表示最新行已进入的个数（0~row_in-1）
            row_count <= 0;                     //也是此刻data_in数据在原始图像中的行序号（从零开始）
            col_count <= col_count + 1;         //col_count数值本身表示已完整进入的行数
         end                                    //也是此刻data_in数据在原始图像中的列序号（从零开始）
         else begin
            row_count <= row_count + 1;
         end
      end
   end
   */

   //window_valid信号有效的判断
   always @(*) begin
      if (col_count == 0 ||
         (col_count == 1 && row_count < 2)
      ) begin
         window_valid = 0;
      end

      else if ((col_count == col_in + 1 && row_count >= 2) ||
               col_count > col_in + 1
      ) begin
         window_valid = 0;
      end

      else begin
         window_valid = 1;
      end
   end

   //部分窗格的置零操作（考虑到padding）      
   always @(*) begin
      {window33_out, window32_out, window31_out,
      window23_out, window22_out, window21_out,
      window13_out, window12_out, window11_out}
      =
      {window33, window32, window31,
      window23, window22, window21,
      window13, window12, window11};

      //换行第一帧（图像右padding）
      if (row_count == 1) begin
         window13_out = 0;
         window23_out = 0;
         window33_out = 0;
      end

      //换行第二帧（图像左padding）
      if (row_count == 2) begin
         window11_out = 0;
         window21_out = 0;
         window31_out = 0;
      end

      //前三行未备好（图像上padding）
      if (col_count < 2 ||
         (col_count == 2 && row_count < 2)
      ) begin
         window11_out = 0;
         window12_out = 0;
         window13_out = 0;
      end

      //最后两行流出（图像下padding）
      if (col_count > col_in ||
         (col_count == col_in && row_count >= 2)
      ) begin
         window31_out = 0;
         window32_out = 0;
         window33_out = 0;
      end
   end

endmodule