/*
    ConvAccum.v
    在4通道卷积的基础上加入累加功能
    当卷积运算的第一个结果完成时，卷积有效信号拉高，将作为请求信号，向外部存储器索要累加数据。
    累加数据到来之前，卷积结果保存在FIFO中。
*/
module ConvAccum
#(
    parameter DataWidth = 32,
    parameter InputDim = 4,
    parameter KernelSize = 9,
    parameter MaxRowWidth = 9,
    parameter MaxColWidth = 9,
    parameter AddrWidth = 16        //18位->16位，考虑到BRAM大小不够，且第一次为视频输入，直接流过，无需缓存
)
(
    Clk,
    Rst,

    row_in,
    col_in,
    conv_first,

    weight_in,
    weight_valid,

    data_in,
    //data_valid,
    col_count,
    row_count,

    rd_addr_conv,
    rd_data_conv,

    wr_addr_conv,
    wr_data_conv,
    wr_en_conv
);

    input                               Clk;
    input                               Rst;

    input [MaxRowWidth-1: 0]            row_in;
    input [MaxColWidth-1: 0]            col_in;
    input                               conv_first;         //第一次卷积时，不进行累加

    input [InputDim*DataWidth-1: 0]     weight_in;
    input                               weight_valid;

    input [InputDim*DataWidth-1: 0]     data_in;
    //input                             data_valid;
    input [MaxColWidth-1: 0]            col_count;
    input [MaxRowWidth-1: 0]            row_count;

    output [AddrWidth-1: 0]             rd_addr_conv;
    input [DataWidth-1: 0]              rd_data_conv;

    output [AddrWidth-1: 0]             wr_addr_conv;
    output [DataWidth-1: 0]             wr_data_conv;
    output                              wr_en_conv;
    

    wire [DataWidth-1: 0]               conv_result;        //卷积结果数据
    wire                                conv_ready;

    reg [AddrWidth-1: 0]                fore_count;         //先行计数器，~first情况下即为rd_addr_conv，first情况下即为wr_addr_conv
    reg [AddrWidth-1: 0]                back_count;         //后行计数器，~first情况下即为wr_addr_conv

    reg [DataWidth-1: 0]                conv_result_delay;  //卷积结果打一拍
    reg                                 conv_ready_delay;   //卷积结果有效信号打一拍

    wire                                add_ready;
    wire [DataWidth-1: 0]               add_result;

    //卷积运算模块
    ConvChannel #(
        .DataWidth      (DataWidth),
        .InputDim       (InputDim),
        .KernelSize     (KernelSize),
        .MaxRowWidth    (MaxRowWidth),
        .MaxColWidth    (MaxColWidth))
    UConvChannel(
        .Clk            (Clk),
        .Rst            (Rst),

        .row_in         (row_in),
        .col_in         (col_in),

        .weight_in      (weight_in),
        .weight_valid   (weight_valid),

        .data_in        (data_in),
        //.data_valid   (data_valid),
        .col_count      (col_count),
        .row_count      (row_count),

        .result_out     (conv_result),
        .result_ready   (conv_ready)
    );

    /*
        fore_count递增：由conv_ready触发
        加法运算：由conv_ready_delay触发
        back_count递增：由add_ready触发
    */

    always @(posedge Clk) begin
        if (Rst) begin
            fore_count <= 0;
            back_count <= 0;
            conv_result_delay <= 0;
            conv_ready_delay <= 0;
        end 
        else begin
            conv_result_delay <= conv_result;
            conv_ready_delay <= conv_ready;
            
            if (conv_ready) begin    //conv_ready是先行计数器开始递增的标志
                fore_count <= fore_count + 1;
            end

            if (add_ready & ~conv_first) begin  //add_ready是后行计数器开始递增的标志，第一次卷积时不需要后行计数器
                back_count <= back_count + 1;
            end
        end
    end

    //累加运算
    assign add_valid = conv_ready_delay & ~Rst & ~conv_first; //conv_ready之后，再等待一周期，从SRAM中取数完毕后再作加法（同时考虑Rst）
    Adder #(.DataWidth (DataWidth))
    Uadder (
        .aclk                   (Clk),
        .s_axis_a_tvalid        (add_valid),
        .s_axis_a_tdata         (rd_data_conv),
        .s_axis_b_tvalid        (add_valid),
        .s_axis_b_tdata         (conv_result_delay),
        .m_axis_result_tvalid   (add_ready),
        .m_axis_result_tdata    (add_result)
    );

    assign rd_addr_conv = (conv_first) ? 0 : fore_count;
    assign wr_addr_conv = (conv_first) ? fore_count : back_count;
    assign wr_en_conv = (conv_first) ? conv_ready : add_ready;
    assign wr_data_conv = (conv_first) ? conv_result : add_result;

endmodule