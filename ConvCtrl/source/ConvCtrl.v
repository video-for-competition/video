module ConvCtrl
#(
    parameter DataWidth = 32,
    parameter InputDim = 4,
    parameter KernelSize = 9,
    parameter MaxAddrWidth = 32,
    parameter MaxPictWidth = 9,
    parameter MaxPixelNum = 18,
    parameter MaxRamWidth = 16
)
(
    Rst,
    Clk0,
    Clk1,

    weight_addr0_in,
    weight_addr1_in,
    weight_addr2_in,
    weight_addr3_in,

    data_addr0_in,
    data_addr1_in,
    data_addr2_in,
    data_addr3_in,

    pict_size_in,
    conv_first_in,
    conv_last_in,
    inst_tag_in,

    read_rdata_in,

    read_addr_out,
    read_en_out,

    write_en_out,
    write_data_out
);

    input                           Rst;
    input                           Clk0;                   //主时钟，用于卷积模块工作
    input                           Clk1;                   //数据读取时钟，四倍于主时钟，用于每周期读取4个数据

    input [MaxAddrWidth-1: 0]       weight_addr0_in;
    input [MaxAddrWidth-1: 0]       weight_addr1_in;
    input [MaxAddrWidth-1: 0]       weight_addr2_in;
    input [MaxAddrWidth-1: 0]       weight_addr3_in;

    input [MaxAddrWidth-1: 0]       data_addr0_in;
    input [MaxAddrWidth-1: 0]       data_addr1_in;
    input [MaxAddrWidth-1: 0]       data_addr2_in;
    input [MaxAddrWidth-1: 0]       data_addr3_in;
    
    input [MaxPictWidth-1: 0]       pict_size_in;
    input                           conv_first_in;
    input                           conv_last_in;
    input                           inst_tag_in;            //指令发生变化的标志

    input [DataWidth-1: 0]          read_rdata_in;

    output [MaxAddrWidth-1: 0]      read_addr_out;
    output                          read_en_out;

    output                          write_en_out;
    output [DataWidth-1: 0]         write_data_out;


    reg [1:0]                       state;
    reg [1:0]                       sub_count;              //将Clk0一分为四的计数器

    wire                            weight_last;            //正在读取最后一个权重/数据的标志
    wire                            data_last;
    reg                             read_rdata_en_delayed;           

    wire                            inst_changed;
    reg                             inst_tag_delayed;

    reg [3:0]                       weight_count;
    reg [MaxPictWidth-1: 0]         row_count;
    reg [MaxPictWidth-1: 0]         col_count;
    reg [MaxPixelNum-1: 0]          col_accum;              //col_accum即为col_count * pict_size_in

    reg [DataWidth-1: 0]            data0 = 0;              //每4个Clk1周期装载一次data_bus
    reg [DataWidth-1: 0]            data1 = 0;              //为方便仿真，将初值设为0
    reg [DataWidth-1: 0]            data2 = 0;
    //reg [DataWidth-1: 0]          data3 = 0;              //不需要data3
    reg [DataWidth*InputDim-1: 0]   data_bus = 0;

    wire [MaxPixelNum-1: 0]         addr_bias;              //当前Clk0周期下的地址偏移量，用于计算读取数据的地址
    reg [MaxAddrWidth-1: 0]         read_addr;              //当前Clk1周期下的读取地址，寄存器型，等同于read_addr_out

    wire                            weight_valid;           //向ConvAccum模块发送的权重有效和数据有效信号
    //wire                          data_valid;

    wire [DataWidth-1: 0]           wr_data_conv;           //ConvAccum连接
    wire [MaxRamWidth-1: 0]         wr_addr_conv;
    wire                            wr_en_conv;
    wire [DataWidth-1: 0]           rd_data_conv;
    wire [MaxRamWidth-1: 0]         rd_addr_conv;

    wire [DataWidth-1: 0]           wr_data_ram;            //RAM连接
    wire [MaxRamWidth: 0]           wr_addr_ram;
    wire                            wr_en_ram;

    
//状态转换---------------------------------------------------------------------------------------------------
    //读权重/读数据状态转换
    parameter WeightFetch = 2'b00, DataFetch = 2'b01, Idle = 2'b11;
    always @(posedge Clk0) begin
        if (Rst) begin
            state <= WeightFetch;
        end
        else begin
            if ((state == WeightFetch) && weight_last)  //最后一个权重读取完毕同时，转入读数据状态
                state <= DataFetch;
            else if ((state == DataFetch) && data_last) //数据计数器计数完毕同时，转入闲置状态
                state <= Idle;
            else if ((state == Idle) && inst_changed)   //切换为下一条指令后，转入读权重状态
                state <= WeightFetch;
        end
    end

    /*
    //判断权重/数据是否读取完毕
    always @(posedge Clk0) begin
        if (Rst) begin
            read_rdata_en_delayed <= 0;
        end
        else begin
            read_rdata_en_delayed <= read_rdata_en_in;
        end
    end
    assign read_last = read_rdata_en_delayed & ~read_rdata_en_in;
    */
    
    //判断指令是否发生转换
    always @(posedge Clk0) begin
        if (Rst) begin
            inst_tag_delayed <= 0;
        end
        else begin
            inst_tag_delayed <= inst_tag_in;
        end
    end
    assign inst_changed = inst_tag_delayed ^ inst_tag_in;   //前后两个tag不一致，说明指令发生变化


    //读权重计数
    always @(posedge Clk0) begin
        if (Rst || (state != WeightFetch)) begin
            weight_count <= 0;
        end
        else begin
            weight_count <= weight_count + 1;
        end
    end

    assign weight_last = (weight_count >= 8);

    //读数据计数
    always @(posedge Clk0) begin
        if (Rst || (state != DataFetch)) begin
            row_count <= 0;
            col_count <= 0;
            col_accum <= 0;
        end
        else if (row_count >= pict_size_in - 1) begin    //row_count数值本身表示最新行已进入的个数（0~row_in-1）
            row_count <= 0;                         //也是此刻data_in数据在原始图像中的行序号（从零开始）
            col_count <= col_count + 1;             //col_count数值本身表示已完整进入的行数
            col_accum <= col_accum + pict_size_in;  //col_accum即为col_count * pict_size_in
        end                                         //也是此刻data_in数据在原始图像中的列序号（从零开始）
        else begin
            row_count <= row_count + 1;
        end
    end

    //由于linebuffer需要，在取数结束后计数器还需再计一行
    assign data_last = col_count > pict_size_in + 1 || 
                    (col_count == pict_size_in + 1 && row_count >= 1);


//数据读取---------------------------------------------------------------------------------------------------
    //四分计数器计数
    always @(posedge Clk1) begin
        if (Rst || (state == Idle)) begin
            sub_count <= 0;
        end
        else begin
            sub_count <= sub_count + 1;
        end
    end

    //权重/数据转移
    always @(posedge Clk1) begin
        case (sub_count)
            2'd0:   data0 <= read_rdata_in;
            2'd1:   data1 <= read_rdata_in;
            2'd2:   data2 <= read_rdata_in;
            2'd3:   data_bus <= {read_rdata_in, data2, data1, data0};   //地址小的在低位
        endcase
    end

    //读取地址计算
    assign addr_bias = row_count + col_accum;                           //偏移量=行序号+列基址

    always @(posedge Clk1) begin                                        //读取地址由触发器保持，避免加法运算占用访存时间
        if (Rst || (state == Idle)) begin                               //故阻塞赋值语句赋值的是次态
            read_addr <= weight_addr0_in;
        end
        else if (state == WeightFetch) begin                            //权重地址更新
            case (sub_count)                                            //此处赋值为读地址的次态；为实现加法位宽匹配，补0（无符号加法）
                2'd0:   read_addr <= weight_addr1_in + weight_count;    //{{(MaxAddrWidth-MaxPictWidth){1'b0}}, weight_count}
                2'd1:   read_addr <= weight_addr2_in + weight_count;
                2'd2:   read_addr <= weight_addr3_in + weight_count;
                2'd3:   begin
                        if (weight_count == 8)                          //最后一个权重读取完毕后，读取下一条指令的权重
                            read_addr <= data_addr0_in;
                        else                                            //否则，读取下一行的权重（同一条指令的下一行）
                            read_addr <= weight_addr0_in + weight_count + 1;
                    end                                                 //此处sub_count=3，读地址需+1，预判下个Clk0周期addr_bias加一后的值
            endcase
        end
        else begin                                                      //数据地址更新
            case (sub_count)
                2'd0:   read_addr <= data_addr1_in + addr_bias;
                2'd1:   read_addr <= data_addr2_in + addr_bias;
                2'd2:   read_addr <= data_addr3_in + addr_bias;
                2'd3:   read_addr <= data_addr0_in + addr_bias + 1;
            endcase
        end
    end

    assign read_addr_out = read_addr;                                   //读取地址输出


//信号投喂---------------------------------------------------------------------------------------------------
    assign weight_valid = weight_count >= 1;
    //assign data_valid = state == DataFetch;

    ConvAccum #(
        .DataWidth      (DataWidth),
        .KernelSize     (KernelSize),
        .InputDim       (InputDim),
        .MaxRowWidth    (MaxPictWidth),
        .MaxColWidth    (MaxPictWidth))
    UConvAccum
    (
        .Clk            (Clk0),
        .Rst            (Rst),
        .row_in         (pict_size_in),
        .col_in         (pict_size_in),
        .conv_first     (conv_first_in),

        .weight_in      (data_bus),
        .weight_valid   (weight_valid),

        .data_in        (data_bus),
        //.data_valid   (data_valid),
        .col_count      (col_count),
        .row_count      (row_count),

        .rd_addr_conv   (rd_addr_conv),
        .rd_data_conv   (rd_data_conv),

        .wr_addr_conv   (wr_addr_conv),
        .wr_data_conv   (wr_data_conv),
        .wr_en_conv     (wr_en_conv)
    );
    assign read_en_out = ~Rst && (state == WeightFetch || (state == DataFetch && col_count < pict_size_in));


//缓存控制---------------------------------------------------------------------------------------------------
    assign wr_data_ram = (conv_last_in)? 0 : wr_data_conv;              //最后一次卷积，不写入
    assign wr_addr_ram = (conv_last_in)? 0 : wr_addr_conv;              //_conv代表convaccum的输出，_ramdata代表接入ram的信号
    assign wr_en_ram = (conv_last_in)? 0 : wr_en_conv;

    DRAM UDRAM (
        .wr_data    (wr_data_ram),          // input [31:0]
        .wr_addr    (wr_addr_ram),          // input [15:0]
        .wr_en      (wr_en_ram),            // input
        .wr_clk     (Clk0),                 // input
        .wr_rst     (Rst),                  // input
        .rd_addr    (rd_addr_conv),         // input [15:0]
        .rd_data    (rd_data_conv),         // output [31:0]
        .rd_clk     (Clk0),                 // input
        .rd_rst     (Rst)                   // input
    );

/*
    DisRAM UDisRAM (
        .wr_data    (wr_data_ram),          // input [31:0]
        .wr_addr    (wr_addr_ram[9:0]),     // input [9:0]
        .wr_en      (wr_en_ram),            // input
        .wr_clk     (Clk0),                 // input
        .rd_addr    (rd_addr_conv[9:0]),    // input [9:0]
        .rd_data    (rd_data_conv),         // output [31:0]
        .rd_clk     (Clk0),                 // input
        .rst        (Rst)                   // input
    );
*/

    assign write_en_out = (conv_last_in)? wr_en_conv : 0;               //最后一次卷积，结果不存入RAM，直接输出
    assign write_data_out = (conv_last_in)? wr_data_conv : 0;

endmodule