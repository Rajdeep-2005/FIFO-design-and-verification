////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_TOP.sv
// Description : Top-level testbench module. Generates the clock, instantiates
//               the interface and the DUT, binds the assertions to the DUT and
//               starts the test.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module FIFO_TOP;

    import fifo_test_pkg::*;

    // Keep in sync with fifo_transaction_pkg
    localparam int FIFO_WIDTH = 16;
    localparam int FIFO_DEPTH = 8;

    // ---------------------------------------------------------------- clock
    bit clk = 1'b0;
    always #10 clk = ~clk;                // 20 ns period (50 MHz)

    // ------------------------------------------------------------ interface
    fifo_if #(.FIFO_WIDTH(FIFO_WIDTH)) fifoif (clk);

    // ------------------------------------------------------------------ DUT
    FIFO #(
        .FIFO_WIDTH (FIFO_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) dut (
        .clk         (fifoif.clk),
        .rst_n       (fifoif.rst_n),
        .wr_en       (fifoif.wr_en),
        .rd_en       (fifoif.rd_en),
        .data_in     (fifoif.data_in),
        .data_out    (fifoif.data_out),
        .wr_ack      (fifoif.wr_ack),
        .overflow    (fifoif.overflow),
        .underflow   (fifoif.underflow),
        .full        (fifoif.full),
        .empty       (fifoif.empty),
        .almostfull  (fifoif.almostfull),
        .almostempty (fifoif.almostempty)
    );

    // ---------------------------------------------------- bind assertions
    bind FIFO FIFO_ASSERTIONS #(
        .FIFO_WIDTH (FIFO_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH)
    ) u_fifo_sva (
        .clk         (clk),
        .rst_n       (rst_n),
        .wr_en       (wr_en),
        .rd_en       (rd_en),
        .data_in     (data_in),
        .data_out    (data_out),
        .wr_ack      (wr_ack),
        .overflow    (overflow),
        .underflow   (underflow),
        .full        (full),
        .empty       (empty),
        .almostfull  (almostfull),
        .almostempty (almostempty),
        .count       (count),
        .wr_ptr      (wr_ptr),
        .rd_ptr      (rd_ptr)
    );

    // ----------------------------------------------------------------- test
    FIFO_test test;

    initial begin
        $display("==================================================");
        $display("  Synchronous FIFO Verification  -  Author: Rajdeep");
        $display("==================================================");
        test = new(fifoif);
        test.run();
    end

    // safety net in case something hangs
    initial begin
        #1ms;
        $fatal(1, "[TOP] simulation timeout");
    end

endmodule
