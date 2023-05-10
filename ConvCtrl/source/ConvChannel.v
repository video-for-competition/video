/*
   ConvChannel模块：实现4个输入通道的卷积与求和
   1、行缓存，将输入数据由串行改为一个窗口并行
   2、录入权重，要求一个周期并行输入4个权重数据（暂定，不过也挺合理，因为数据的输入也是4个并行的）
   3、权重和数据，统一要求序号小的通道在低位，序号大的通道在高位（weight_in[i*DataWidth +: DataWidth]）
*/
/*
    使用说明
    支持4个输入通道，1个输出通道的卷积，图像尺寸最大为416*416。只输出卷积结果，未进行累加。
    要求：
        1、复位：同步复位。一次运算完成后，必须先复位才能进行下一次运算。
        2、权重：串行输入，但同一周期内4通道的数据并行输入。通道数据并列存放的要求是——标号低的数据在低位。
                valid信号不要求连续，信号有效期间每个时钟上升沿算作1个权重输入。
        3、数据：串行输入，但同一周期内4通道的数据并行输入。
                valid信号实际上没有严格要求，只要求第一个有效数据输入时valid拉高。本模块只判断data_valid信号上升沿，并在处理整个运算后自动结束进程。
        4、时序：权重输入全部完成后，才允许输入数据。
                第一个数据输入后，经过KernelSize+9个时钟周期后，才能输出第一个卷积结果。
*/


module ConvChannel
#(
   parameter DataWidth = 32,
   parameter InputDim = 4,
   parameter KernelSize = 9,
   parameter MaxRowWidth = 9,  //图像最大为416*416，需9位数据
   parameter MaxColWidth = 9
)
(
   Clk,
   Rst,

   row_in,
   col_in,

   weight_in,
   weight_valid,

   data_in,
   //data_valid,
   col_count,
   row_count,

   result_out,
   result_ready
);

   input                                     Clk;
   input                                     Rst;

   input [MaxRowWidth-1: 0]                  row_in;        //图像行尺寸
   input [MaxColWidth-1: 0]                  col_in;        //图像列尺寸

   input [InputDim*DataWidth-1: 0]           weight_in;     //4个权重并行输入
   input                                     weight_valid;

   input [InputDim*DataWidth-1: 0]           data_in;       //4个数据通道并行输入
   //input                                   data_valid;
   input [MaxRowWidth-1: 0]                  col_count;     //图像列计数
   input [MaxColWidth-1: 0]                  row_count;     //图像行计数

   output [DataWidth-1: 0]                   result_out;
   output                                    result_ready;

   wire [InputDim*KernelSize*DataWidth-1: 0] window_trans;
   wire [InputDim-1: 0]                      window_ready;

   wire [InputDim*DataWidth-1: 0]            conv_result;
   wire [InputDim-1: 0]                      conv_ready;

   wire                                      add1_valid;
   wire [2*DataWidth-1: 0]                   add1_result;
   wire [1:0]                                add1_ready;

   wire                                      add2_valid;
   wire [DataWidth-1: 0]                     add2_result;
   wire                                      add2_ready;

   //LineBuffer连接
   genvar i;
   generate
      for (i = 0; i < InputDim; i = i + 1) begin
         LineBuffer #(
            .DataWidth      (DataWidth),
            .KernelSize     (KernelSize),
            .MaxRowWidth    (MaxRowWidth),
            .MaxColWidth    (MaxColWidth)) 
         ULineBuffer (
            .Clk            (Clk),
            .Rst            (Rst),
            .row_in         (row_in),
            .col_in         (col_in),
            .data_in        (data_in[i*DataWidth +: DataWidth]),
            //.data_valid   (data_valid),
            .col_count      (col_count),
            .row_count      (row_count),
            .window_out     (window_trans[i*KernelSize*DataWidth +: KernelSize*DataWidth]),
            .window_valid   (window_ready[i])
         );
      end
   endgenerate
   
   //ConvLayer连接
   assign window_ready_all = & window_ready;
   genvar j;
   generate 
      for (j = 0; j < InputDim; j = j + 1) begin
         ConvLayer #(.DataWidth (DataWidth), .KernelSize (KernelSize))
         UConvLayer (
            .Clk           (Clk),
            .Rst           (Rst),
            .weight_in     (weight_in[j*DataWidth +: DataWidth]),
            .weight_valid  (weight_valid),
            .window_in     (window_trans[j*KernelSize*DataWidth +: KernelSize*DataWidth]),
            .window_valid  (window_ready_all),

            .result_out    (conv_result[j*DataWidth +: DataWidth]),
            .result_ready  (conv_ready[j])
         );
      end
   endgenerate

   //将4个卷积结果进行树状累加
   //第一层
   assign add1_valid = &conv_ready & ~Rst;      //valid信号需引入复位信号
   //1、2相加
   Adder #(.DataWidth (DataWidth))
   Uadder1 (
      .aclk                   (Clk),
      .s_axis_a_tvalid        (add1_valid),
      .s_axis_a_tdata         (conv_result[0 +: DataWidth]),
      .s_axis_b_tvalid        (add1_valid),
      .s_axis_b_tdata         (conv_result[DataWidth +: DataWidth]),
      .m_axis_result_tvalid   (add1_ready[0]),
      .m_axis_result_tdata    (add1_result[0 +: DataWidth])
   );

   //3、4相加
   Adder #(.DataWidth (DataWidth))
   Uadder2 (
      .aclk                   (Clk),
      .s_axis_a_tvalid        (add1_valid),
      .s_axis_a_tdata         (conv_result[2*DataWidth +: DataWidth]),
      .s_axis_b_tvalid        (add1_valid),
      .s_axis_b_tdata         (conv_result[3*DataWidth +: DataWidth]),
      .m_axis_result_tvalid   (add1_ready[1]),
      .m_axis_result_tdata    (add1_result[DataWidth +: DataWidth])
   );

   //第二层，两个加法的结果相加
   assign add2_valid = &add1_ready & ~Rst;
   Adder #(.DataWidth (DataWidth))
   Uadder3 (
      .aclk                   (Clk),
      .s_axis_a_tvalid        (add2_valid),
      .s_axis_a_tdata         (add1_result[0 +: DataWidth]),
      .s_axis_b_tvalid        (add2_valid),
      .s_axis_b_tdata         (add1_result[DataWidth +: DataWidth]),
      .m_axis_result_tvalid   (add2_ready),
      .m_axis_result_tdata    (add2_result)
   );

   assign result_out = add2_result;
   assign result_ready = add2_ready;

endmodule