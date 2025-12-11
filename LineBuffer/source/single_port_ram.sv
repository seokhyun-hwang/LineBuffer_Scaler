`timescale 1ns / 1ps

module single_port_ram #(
    parameter ADDR_WIDTH = 6,
    parameter DATA_WIDTH = 30,
    parameter RAM_DEPTH  = 1 << ADDR_WIDTH
) (
    input clk,
    input i_cs,
    input i_we,
    input [ADDR_WIDTH-1:0] i_addr,
    input [DATA_WIDTH-1:0] i_din,
    output [DATA_WIDTH-1:0] o_dout
);

    logic [DATA_WIDTH-1:0] r_mem[0:RAM_DEPTH-1];

    initial begin
        for (int i = 0; i < RAM_DEPTH; i++) begin
            // r_mem[i] = {DATA_WIDTH{1'b0}};
            r_mem[i] = 0;
        end
    end

    // output : when cs=1, we=0
    assign o_dout = (i_cs && !i_we) ? r_mem[i_addr] : 'b0;

    // Memory write input
    // cs=1, we=1
    always_ff @(posedge clk) begin
        if (i_cs && i_we) r_mem[i_addr] <= i_din;
    end
endmodule


// module single_port_ram #(
//     parameter ADDR_WIDTH = 6,
//     parameter DATA_WIDTH = 30,
//     parameter RAM_DEPTH  = 1 << ADDR_WIDTH
// ) (
//     input                   clk,
//     input                   i_cs,
//     input                   i_we,
//     input  [ADDR_WIDTH-1:0] i_addr,
//     input  [DATA_WIDTH-1:0] i_din,
//     output [DATA_WIDTH-1:0] o_dout
// );


//     reg [DATA_WIDTH-1:0]    r_mem   [0:RAM_DEPTH-1];
//     reg [DATA_WIDTH-1:0]    r_tmp_data;

//     // output : when cs=1, we=0
//     assign o_dout = (i_cs && !i_we) ? r_tmp_data : 'b0;

//     // Memory write input
//     // cs=1, we=1
//     always @(posedge clk) begin
//         if (i_cs && i_we) r_mem[i_addr] <= i_din;
//     end

//     // Memory read input
//     // cs=1, we=0
//     // always @(posedge clk) begin
//     //     if (i_cs && !i_we) r_tmp_data <= r_mem[i_addr];
//     // end
//     always @(*) begin
//         if (i_cs && !i_we) r_tmp_data <= r_mem[i_addr];
//     end
// endmodule
