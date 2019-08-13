// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2018.3.1 (win64) Build 2489853 Tue Mar 26 04:20:25 MDT 2019
// Date        : Mon Aug  5 21:52:06 2019
// Host        : CT-WS1 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               r:/Development/Projects/PIC16C6XX/PIC16C6XX.srcs/sources_1/ip/pic_uart_fifo/pic_uart_fifo_stub.v
// Design      : pic_uart_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_3,Vivado 2018.3.1" *)
module pic_uart_fifo(rst, wr_clk, rd_clk, din, wr_en, rd_en, dout, full, 
  empty, wr_rst_busy, rd_rst_busy)
/* synthesis syn_black_box black_box_pad_pin="rst,wr_clk,rd_clk,din[13:0],wr_en,rd_en,dout[13:0],full,empty,wr_rst_busy,rd_rst_busy" */;
  input rst;
  input wr_clk;
  input rd_clk;
  input [13:0]din;
  input wr_en;
  input rd_en;
  output [13:0]dout;
  output full;
  output empty;
  output wr_rst_busy;
  output rd_rst_busy;
endmodule
