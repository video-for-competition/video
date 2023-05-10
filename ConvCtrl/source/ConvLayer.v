/*
   ConvLayer.v
   功能：单层卷积
   （1）只可自动完成一次卷积运算，若要进行下一次卷积，需先reset；
   （2）权重参数为串行输入，reset过后，在weight_valid上升沿后，同步进入读取参数状态，读完3*3个参数后进入运算状态；
   （3）窗口数据为并行输入，数据由上层模块负责整理，本模块直接对数据作运算

   注意：weight的次序与window数据的次序相反，即：若weight输入的先后顺序为(1,1)~(3,3)，则window从低位到高位为(1,1)~(3,3)
*/

module ConvLayer
#(
   parameter DataWidth = 32,
   parameter KernelSize = 9
)
(
   Clk,
   Rst,
   weight_in,        //权重串行输入
   weight_valid,     //标志权重输入有效
   window_in,        //窗口数据并行输入
   window_valid,     //窗口数据有效

   result_out,       //乘加结果输出
   result_ready      //结果输出有效
);

   parameter WeightCountWidth = $clog2(KernelSize);

   input                               Clk;
   input                               Rst;
   input [DataWidth-1: 0]              weight_in;
   input                               weight_valid;
   input [KernelSize*DataWidth-1: 0]   window_in;
   input                               window_valid;

   output [DataWidth-1: 0]             result_out;
   output                              result_ready;

   reg [WeightCountWidth-1: 0]         weight_count;     //权重输入计数器，计满9个开始计算
   reg [KernelSize*DataWidth-1: 0]     weight_reg;       //寄存全部权重
   wire                                weight_ready;     //标志权重读取结束

   wire                                mult_valid;       //标志允许开始进行计算
   wire [KernelSize-1: 0]              mult_ready;       //标志乘法运算完成。每一级流水线接收到valid信号后，才会在下一周期释放ready信号，保证时序的正确
   wire [KernelSize*DataWidth-1: 0]    mult_result;      //乘法结果

   wire                                add1_valid;       //add1表示树形累加的第一层
   wire [3:0]                          add1_ready;
   wire [4*DataWidth-1: 0]             add1_result;
   reg  [DataWidth-1: 0]               mult9_delay1;     //第9个乘积不参与累加，需打三拍。delay1表示第一次寄存的结果。

   wire                                add2_valid;       //add2表示树形累加的第二层
   wire [1:0]                          add2_ready;
   wire [2*DataWidth-1: 0]             add2_result;
   reg  [DataWidth-1: 0]               mult9_delay2;     //delay2表示第二次寄存的结果

   wire                                add3_valid;       //add3表示树形累加的第三层
   wire                                add3_ready;
   wire [DataWidth-1: 0]               add3_result;
   reg  [DataWidth-1: 0]               mult9_delay3;

   wire                                add4_valid;
   wire                                add4_ready;
   wire [DataWidth-1: 0]               add4_result;


   //参数读取
   assign weight_ready = (weight_count == KernelSize);
   always @(posedge Clk) begin
      if (Rst) begin
         weight_count   <= 0;
         weight_reg     <= 0;
      end

      else begin
         if (weight_ready | ~weight_valid)      //若权重未录完，且输入权重有效，即录入一个权重
            ;
         else begin
            weight_reg[weight_count * DataWidth +: DataWidth]  <= weight_in;
            weight_count                                       <= weight_count + 1;
         end
      end
   end

   //乘法计算
   assign mult_valid = weight_ready & window_valid & ~Rst;
   genvar i;
   generate
      for (i = 0; i < KernelSize; i = i+1) begin
         Mult #(.DataWidth(DataWidth))
         UMult (
            .aclk                 (Clk),
            .s_axis_a_tvalid      (mult_valid),
            .s_axis_a_tdata       (window_in     [i * DataWidth +: DataWidth]),
            .s_axis_b_tvalid      (mult_valid),
            .s_axis_b_tdata       (weight_reg    [i * DataWidth +: DataWidth]),
            .m_axis_result_tvalid (mult_ready    [i]),
            .m_axis_result_tdata  (mult_result   [i * DataWidth +: DataWidth])
         );
      end
   endgenerate

   //树状累加
   //第一层
   assign add1_valid = &mult_ready & ~Rst;   //此处等待所有乘法运算完毕，再统一推进流水线（实际上所有乘法在同一周期完成）
                                             //Rst汇入所有的valid信号，实现对乘加器的同步清零
   genvar j;
   generate
      for (j = 0; j < 4; j = j + 1) begin
         Adder #(.DataWidth(DataWidth))
         UAdder (
            .aclk                   (Clk),
            .s_axis_a_tvalid        (add1_valid),
            .s_axis_a_tdata         (mult_result[2*j*DataWidth +: DataWidth]),
            .s_axis_b_tvalid        (add1_valid),
            .s_axis_b_tdata         (mult_result[(2*j+1)*DataWidth +: DataWidth]),
            .m_axis_result_tvalid   (add1_ready[j]),
            .m_axis_result_tdata    (add1_result[j * DataWidth +: DataWidth])
         );
      end
   endgenerate
   //第9个乘积不作加法，保存1周期
   always @(posedge Clk) begin
      if (Rst)
         mult9_delay1 <= 0;
      else if (add1_valid)
         mult9_delay1 <= mult_result[8*DataWidth +: DataWidth];
      else
         ;
   end

   //第二层
   assign add2_valid = &add1_ready & ~Rst;
   genvar k;
   generate
      for (k = 0; k < 2; k = k + 1) begin
         Adder #(.DataWidth(DataWidth))
         UAdder (
            .aclk                   (Clk),
            .s_axis_a_tvalid        (add2_valid),
            .s_axis_a_tdata         (add1_result[2*k*DataWidth +: DataWidth]),
            .s_axis_b_tvalid        (add2_valid),
            .s_axis_b_tdata         (add1_result[(2*k+1)*DataWidth +: DataWidth]),
            .m_axis_result_tvalid   (add2_ready[k]),
            .m_axis_result_tdata    (add2_result[k * DataWidth +: DataWidth])
         );
      end
   endgenerate
   //第9个乘积不作加法，再保存1周期
   always @(posedge Clk) begin
      if (Rst)
         mult9_delay2 <= 0;
      else if (add2_valid)
         mult9_delay2 <= mult9_delay1;
      else
         ;
   end

   //第三层
   assign add3_valid = &add2_ready & ~Rst;
   Adder #(.DataWidth(DataWidth))
   UAdder3 (
      .aclk                   (Clk),
      .s_axis_a_tvalid        (add3_valid),
      .s_axis_a_tdata         (add2_result[0 +: DataWidth]),
      .s_axis_b_tvalid        (add3_valid),
      .s_axis_b_tdata         (add2_result[DataWidth +: DataWidth]),
      .m_axis_result_tvalid   (add3_ready),
      .m_axis_result_tdata    (add3_result)
   );
   //第9个乘积不作加法，再再保存1周期
   always @(posedge Clk) begin
      if (Rst)
         mult9_delay3 <= 0;
      else if (add3_valid)
         mult9_delay3 <= mult9_delay2;
      else
         ;
   end

   //第四层
   assign add4_valid = add3_ready & ~Rst;
   Adder #(.DataWidth(DataWidth))
   UAdder4 (
      .aclk                   (Clk),
      .s_axis_a_tvalid        (add4_valid),
      .s_axis_a_tdata         (add3_result),
      .s_axis_b_tvalid        (add4_valid),
      .s_axis_b_tdata         (mult9_delay3),
      .m_axis_result_tvalid   (add4_ready),
      .m_axis_result_tdata    (add4_result)
   );

   assign result_ready  = add4_ready;
   assign result_out    = add4_result;

endmodule