////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_IF.sv
// Description : Interface connecting the FIFO DUT and the class-based
//               testbench.
//
//  Timing scheme (no races):
//   - Driver changes inputs on the NEGEDGE of clk.
//   - DUT samples inputs on the POSEDGE of clk.
//   - Monitor samples through mon_cb on the NEGEDGE with #1step input skew,
//     i.e. just before the driver applies the next stimulus. So each sample
//     holds the inputs of one cycle and the outputs the DUT produced for them.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

interface fifo_if #(
    parameter int FIFO_WIDTH = 16
) (
    input logic clk
);

    // DUT inputs
    logic [FIFO_WIDTH-1:0] data_in;
    logic                  rst_n;
    logic                  wr_en;
    logic                  rd_en;

    // DUT outputs
    logic [FIFO_WIDTH-1:0] data_out;
    logic                  wr_ack;
    logic                  overflow;
    logic                  underflow;
    logic                  full;
    logic                  empty;
    logic                  almostfull;
    logic                  almostempty;

    // Monitor clocking block
    clocking mon_cb @(negedge clk);
        default input #1step;
        input data_in, rst_n, wr_en, rd_en;
        input data_out, wr_ack, overflow, underflow;
        input full, empty, almostfull, almostempty;
    endclocking

endinterface
