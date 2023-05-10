module Adder
#(parameter DataWidth = 32)
(
   aclk,
   s_axis_a_tvalid,
   s_axis_a_tdata,
   s_axis_b_tvalid,
   s_axis_b_tdata,
   m_axis_result_tvalid,
   m_axis_result_tdata
   );

   input                         aclk;
   input                         s_axis_a_tvalid;
   input [DataWidth-1: 0]        s_axis_a_tdata;
   input                         s_axis_b_tvalid;
   input [DataWidth-1: 0]        s_axis_b_tdata;
   output reg                    m_axis_result_tvalid;
   output reg [DataWidth-1: 0]   m_axis_result_tdata;

   always @(posedge aclk) begin
      if (~s_axis_a_tvalid | ~s_axis_b_tvalid) begin
         m_axis_result_tvalid <= 0;
         m_axis_result_tdata <= 0;
      end
      else begin
         m_axis_result_tvalid <= 1;
         m_axis_result_tdata <= s_axis_a_tdata + s_axis_b_tdata;
      end
   end

endmodule