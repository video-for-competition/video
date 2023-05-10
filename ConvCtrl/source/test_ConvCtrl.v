/*
    ConvAccum仿真
    验证conv_first功能以及RAM存储功能
*/
`timescale 100ps / 1ps
`define CLK1_PRD 10
`define CLK1_HALF (`CLK1_PRD / 2)
`define CLK0_PRD (4*`CLK1_PRD)
`define CLK0_HALF (`CLK0_PRD / 2)

module test_ConvCtrl();
    parameter PictureSize = 6;
    parameter DataWidth = 32;
    parameter KernelSize = 9;
    parameter AddrWidth = 16;
    parameter MaxPictWidth = 9;
    parameter MaxAddrWidth = 32;

    reg                         Clk0;
    reg                         Clk1;
    reg                         Rst;
    reg [MaxAddrWidth-1: 0]     weight_addr0_in;
    reg [MaxAddrWidth-1: 0]     weight_addr1_in;
    reg [MaxAddrWidth-1: 0]     weight_addr2_in;
    reg [MaxAddrWidth-1: 0]     weight_addr3_in;

    reg [MaxAddrWidth-1: 0]     data_addr0_in;
    reg [MaxAddrWidth-1: 0]     data_addr1_in;
    reg [MaxAddrWidth-1: 0]     data_addr2_in;
    reg [MaxAddrWidth-1: 0]     data_addr3_in;

    reg [MaxPictWidth-1: 0]     pict_size_in;
    reg                         conv_first_in;
    reg                         conv_last_in;
    reg                         inst_tag_in;

    reg [DataWidth-1: 0]        read_rdata_in;

    wire [MaxAddrWidth-1: 0]    read_addr_out;
    wire                        read_en_out;

    wire                        write_en_out;
    wire [DataWidth-1: 0]       write_data_out;

    ConvCtrl #(.DataWidth(DataWidth), .KernelSize(KernelSize))
    UConvCtrl
    (
        .Rst(Rst),
        .Clk0(Clk0),
        .Clk1(Clk1),

        .weight_addr0_in(weight_addr0_in),
        .weight_addr1_in(weight_addr1_in),
        .weight_addr2_in(weight_addr2_in),
        .weight_addr3_in(weight_addr3_in),

        .data_addr0_in  (data_addr0_in),
        .data_addr1_in  (data_addr1_in),
        .data_addr2_in  (data_addr2_in),
        .data_addr3_in  (data_addr3_in),

        .pict_size_in   (pict_size_in),
        .conv_first_in  (conv_first_in),
        .conv_last_in   (conv_last_in),
        .inst_tag_in    (inst_tag_in),

        .read_rdata_in  (read_rdata_in),

        .read_addr_out  (read_addr_out),
        .read_en_out    (read_en_out),
        .write_en_out   (write_en_out),
        .write_data_out (write_data_out)
    );

    //复位与输入信号控制--------------------------------------------------------
    initial begin
        //第一条指令
        Rst <= 1;
        weight_addr0_in <= 0;
        weight_addr1_in <= 9;
        weight_addr2_in <= 18;
        weight_addr3_in <= 27;

        data_addr0_in <= 128;
        data_addr1_in <= 128 + PictureSize*PictureSize;
        data_addr2_in <= 128 + 2*PictureSize*PictureSize;
        data_addr3_in <= 128 + 3*PictureSize*PictureSize;

        pict_size_in <= PictureSize;
        conv_first_in <= 1;
        conv_last_in <= 0;
        inst_tag_in <= 0;

        #(2*`CLK0_PRD);
        Rst <= 0;

        #(75*`CLK0_PRD);
        //第二条指令
        Rst <= 1;
        weight_addr0_in <= 36;
        weight_addr1_in <= 45;
        weight_addr2_in <= 54;
        weight_addr3_in <= 63;
        
        data_addr0_in <= 128 + 4*PictureSize*PictureSize;
        data_addr1_in <= 128 + 5*PictureSize*PictureSize;
        data_addr2_in <= 128 + 6*PictureSize*PictureSize;
        data_addr3_in <= 128 + 7*PictureSize*PictureSize;

        conv_first_in <= 0;
        inst_tag_in <= 1;

        #(2*`CLK0_PRD);
        Rst <= 0;

        #(75*`CLK0_PRD);
        //第三条指令
        Rst <= 1;
        weight_addr0_in <= 72;
        weight_addr1_in <= 81;
        weight_addr2_in <= 90;
        weight_addr3_in <= 99;

        data_addr0_in <= 128 + 8*PictureSize*PictureSize;
        data_addr1_in <= 128 + 9*PictureSize*PictureSize;
        data_addr2_in <= 128 + 10*PictureSize*PictureSize;
        data_addr3_in <= 128 + 11*PictureSize*PictureSize;

        conv_last_in <= 1;
        inst_tag_in <= 0;

        #(2*`CLK0_PRD);
        Rst <= 0;
    end

    //权重/数据输入--------------------------------------------------------------
    always begin
        read_rdata_in <= $random % 100;
        #(`CLK1_PRD);
    end


    //数据输出--------------------------------------------------------------------------------
    integer wcount = 0;                             //权重计数器
    integer wp1, wp2, wp3, wp4;                     //权重文件指针
    integer weight;                                 //权重变量，用于转化为有符号整数

    integer dcount = 0;                             //数据计数器
    integer chcount = 0;                            //通道计数器
    integer dp1, dp2, dp3, dp4;
    integer data;

    always begin                                    //使用always块，每个周期检测权重有效信号
        #(`CLK1_HALF);
        //权重输出
        if (read_en_out && ~Rst) begin
            if (wcount < 9) begin

                //将线网变量转化为有符号整数，一个方法是借助integer
                weight = read_rdata_in;

                case (chcount % 4)
                    0: begin
                        wp1 = $fopen("data/weight1.txt", "a");  //路径为data文件夹下的weight1.txt
                        $fwrite(wp1, "%d%s", weight, (wcount % 3 != 2)? ", " : ";\n");
                        $fclose(wp1);
                    end
                    1: begin
                        wp2 = $fopen("data/weight2.txt", "a");
                        $fwrite(wp2, "%d%s", weight, (wcount % 3 != 2)? ", " : ";\n");
                        $fclose(wp2);
                    end
                    2: begin
                        wp3 = $fopen("data/weight3.txt", "a");
                        $fwrite(wp3, "%d%s", weight, (wcount % 3 != 2)? ", " : ";\n");
                        $fclose(wp3);
                    end
                    3: begin
                        wp4 = $fopen("data/weight4.txt", "a");
                        $fwrite(wp4, "%d%s", weight, (wcount % 3 != 2)? ", " : ";\n");
                        $fclose(wp4);
                    end
                endcase
                chcount = chcount + 1;      //chcount：当前已经读完的数据个数（4个通道总计）
                if (chcount % 4 == 0)       //wcount：当前已经完整读完的权重组数（4个一组）
                    wcount = wcount + 1;
            end
            
            else begin
                data = read_rdata_in;

                case (chcount % 4)
                    0: begin
                        dp1 = $fopen("data/data1.txt", "a");
                        $fwrite(dp1, "%d%s", data, (dcount % PictureSize != PictureSize -1)? ", " : ";\n");
                        $fclose(dp1);
                    end
                    1: begin
                        dp2 = $fopen("data/data2.txt", "a");
                        $fwrite(dp2, "%d%s", data, (dcount % PictureSize != PictureSize -1)? ", " : ";\n");
                        $fclose(dp2);
                    end
                    2: begin
                        dp3 = $fopen("data/data3.txt", "a");
                        $fwrite(dp3, "%d%s", data, (dcount % PictureSize != PictureSize -1)? ", " : ";\n");
                        $fclose(dp3);
                    end
                    3: begin
                        dp4 = $fopen("data/data4.txt", "a");
                        $fwrite(dp4, "%d%s", data, (dcount % PictureSize != PictureSize -1)? ", " : ";\n");
                        $fclose(dp4);
                    end
                endcase
                chcount = chcount + 1;
                if (chcount % 4 == 0)
                    dcount = dcount + 1;
            end
        end
    
        if (dcount == PictureSize*PictureSize) begin
            wcount = 0;
            dcount = 0;
        end
        #(`CLK1_HALF);
    end

    
    //结果输出--------------------------------------------------------------------------------
    //注意：结果在Clk0时钟域内
    integer rcount = 0;
    integer rp;
    integer result;

    always begin
        #(`CLK0_HALF);
        if (write_en_out && ~Rst) begin
            result = write_data_out;
            rp = $fopen("data/result.txt", "a");
            $fwrite(rp, "%d%s", result, (rcount % PictureSize != PictureSize - 1)? ", " : ";\n");
            $fclose(rp);
            rcount = rcount + 1;
        end
        #(`CLK0_HALF);
    end


    //时钟与进程结束------------------------------------------------------------------------------
    always begin
        Clk0 = 1;
        #(`CLK0_HALF);
        Clk0 = 0;
        #(`CLK0_HALF);
    end

    always begin
        Clk1 = 1;
        #(`CLK1_HALF);
        Clk1 = 0;
        #(`CLK1_HALF);
    end
    
    always begin
        #(1);
        if ($stime >= 300*`CLK0_PRD)
            $finish;
    end


endmodule