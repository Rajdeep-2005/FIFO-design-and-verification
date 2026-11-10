////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO.sv
// Description : Parameterized synchronous FIFO (single clock, active-low
//               asynchronous reset).
//
//  - wr_ack    : registered, 1 when the write in the previous cycle succeeded
//  - overflow  : registered, 1 when a write was rejected because FIFO was full
//  - underflow : registered, 1 when a read was rejected because FIFO was empty
//  - full / empty / almostfull / almostempty : combinational from count
//  - Simultaneous read & write:
//        empty -> only the write happens
//        full  -> only the read happens
//        else  -> both happen, count unchanged
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module FIFO #(
    parameter int FIFO_WIDTH = 16,
    parameter int FIFO_DEPTH = 8          // must be >= 2
) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [FIFO_WIDTH-1:0] data_in,
    output logic [FIFO_WIDTH-1:0] data_out,
    output logic                  wr_ack,
    output logic                  overflow,
    output logic                  underflow,
    output logic                  full,
    output logic                  empty,
    output logic                  almostfull,
    output logic                  almostempty
);

    localparam int ADDR_W = $clog2(FIFO_DEPTH);

    logic [FIFO_WIDTH-1:0] mem [FIFO_DEPTH];
    logic [ADDR_W-1:0]     wr_ptr, rd_ptr;
    logic [ADDR_W:0]       count;

    // A write/read is accepted only when the FIFO is not full/empty
    logic do_write, do_read;
    assign do_write = wr_en && !full;
    assign do_read  = rd_en && !empty;

    // ---------------------------------------------------------------- memory
    always_ff @(posedge clk) begin
        if (do_write)
            mem[wr_ptr] <= data_in;
    end

    // ---------------------------------------------------------- write side
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= '0;
            wr_ack   <= 1'b0;
            overflow <= 1'b0;
        end
        else begin
            wr_ack   <= do_write;
            overflow <= wr_en && full;
            if (do_write)
                wr_ptr <= (wr_ptr == ADDR_W'(FIFO_DEPTH-1)) ? '0 : wr_ptr + 1'b1;
        end
    end

    // ----------------------------------------------------------- read side
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr    <= '0;
            data_out  <= '0;
            underflow <= 1'b0;
        end
        else begin
            underflow <= rd_en && empty;
            if (do_read) begin
                data_out <= mem[rd_ptr];
                rd_ptr   <= (rd_ptr == ADDR_W'(FIFO_DEPTH-1)) ? '0 : rd_ptr + 1'b1;
            end
        end
    end

    // --------------------------------------------------------------- count
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= '0;
        else begin
            case ({do_write, do_read})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;        // 00 or 11 -> no change
            endcase
        end
    end

    // --------------------------------------------------------------- flags
    assign full        = (count == FIFO_DEPTH);
    assign empty       = (count == 0);
    assign almostfull  = (count == FIFO_DEPTH-1);
    assign almostempty = (count == 1);

endmodule
