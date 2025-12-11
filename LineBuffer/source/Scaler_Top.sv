`timescale 1ns / 1ps

module Scaler_Top (
    input clk,
    input rstn,

    // 외부 입력
    input       i_vsync,
    input       i_hsync,
    input       i_de,
    input [9:0] i_r_data,
    input [9:0] i_g_data,
    input [9:0] i_b_data,

    // 외부 출력
    output reg       o_vsync,
    output reg       o_hsync,
    output reg       o_de,
    output reg [9:0] o_r_data,
    output reg [9:0] o_g_data,
    output reg [9:0] o_b_data
);

    localparam logic [5:0] VACT = 6'd4;  // 입력 세로 해상도
    localparam logic [5:0] HACT = 6'd10;  // 입력 가로 해상도

    // 1: Bypass, 2: 1/2 Downscale, 3: 1/3 Downscale
    localparam int SCALE_RATIO = 1;

    // 출력 해상도 계산
    localparam int H_OUT = (HACT + SCALE_RATIO - 1) / SCALE_RATIO;

    localparam ADDR_WIDTH = 6;  // SRAM은 1 line만 저장. -> 10 pixel (HACT). 넉넉히 6bit
    localparam DATA_WIDTH = 30;  // RGB 10bit씩


    // 내부 연결 wire
    logic w_cs1, w_cs2;
    logic w_we1, w_we2;
    logic [ADDR_WIDTH-1:0] w_addr1, w_addr2;
    logic [DATA_WIDTH-1:0] w_din1, w_din2;
    logic [DATA_WIDTH-1:0] w_dout1, w_dout2;  // SRAM에서 나온 데이터


    Scaler_Ctrl #(
        .HACT       (HACT),
        .VACT       (VACT),
        .SCALE_RATIO(SCALE_RATIO),  // 1,2,3 ...
        .H_OUT      (H_OUT)         // 출력 픽셀 수 (TOP에서 계산)
    ) U_SCALER_CNTL (
        .clk (clk),
        .rstn(rstn),

        .i_de    (i_de),
        .i_r_data(i_r_data),
        .i_g_data(i_g_data),
        .i_b_data(i_b_data),
        .i_vsync (i_vsync),
        .i_hsync (i_hsync),

        .o_r_data(o_r_data),
        .o_g_data(o_g_data),
        .o_b_data(o_b_data),
        .o_vsync (o_vsync),
        .o_hsync (o_hsync),
        .o_de    (o_de),

        .o_cs1  (w_cs1),
        .o_we1  (w_we1),
        .o_addr1(w_addr1),
        .o_din1 (w_din1),
        .i_dout1(w_dout1),

        .o_cs2  (w_cs2),
        .o_we2  (w_we2),
        .o_addr2(w_addr2),
        .o_din2 (w_din2),
        .i_dout2(w_dout2)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_RAM1 (
        .clk   (clk),
        .i_cs  (w_cs1),
        .i_we  (w_we1),
        .i_addr(w_addr1),
        .i_din (w_din1),
        .o_dout(w_dout1)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_RAM2 (
        .clk   (clk),
        .i_cs  (w_cs2),
        .i_we  (w_we2),
        .i_addr(w_addr2),
        .i_din (w_din2),
        .o_dout(w_dout2)
    );

endmodule
