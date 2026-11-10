////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_ASSERTIONS.sv
// Description : SystemVerilog Assertions for the FIFO. This module is attached
//               to the DUT with a `bind` statement (see FIFO_TOP.sv), so the
//               RTL stays clean and the assertions can see internal signals
//               (count, wr_ptr, rd_ptr).
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module FIFO_ASSERTIONS #(
    parameter int FIFO_WIDTH = 16,
    parameter int FIFO_DEPTH = 8
) (
    input logic                  clk,
    input logic                  rst_n,
    input logic                  wr_en,
    input logic                  rd_en,
    input logic [FIFO_WIDTH-1:0] data_in,
    input logic [FIFO_WIDTH-1:0] data_out,
    input logic                  wr_ack,
    input logic                  overflow,
    input logic                  underflow,
    input logic                  full,
    input logic                  empty,
    input logic                  almostfull,
    input logic                  almostempty,
    // internal DUT signals
    input logic [$clog2(FIFO_DEPTH):0]   count,
    input logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr,
    input logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr
);

    localparam int ADDR_W = $clog2(FIFO_DEPTH);

    function automatic logic [ADDR_W-1:0] next_ptr(logic [ADDR_W-1:0] p);
        return (p == ADDR_W'(FIFO_DEPTH-1)) ? '0 : p + 1'b1;
    endfunction

    // =========================================================================
    // Reset checks: everything must be cleared while rst_n is low
    // (the testbench always holds reset across at least one posedge)
    // =========================================================================
    property reset_values_p;
        @(posedge clk)
            !rst_n |-> (count == 0) && (wr_ptr == 0) && (rd_ptr == 0) &&
                       !full && empty && !almostfull && !almostempty &&
                       !wr_ack && !overflow && !underflow && (data_out == '0);
    endproperty

    // =========================================================================
    // Flags must always match count
    // =========================================================================
    property full_flag_p;
        @(posedge clk) disable iff (!rst_n) full == (count == FIFO_DEPTH);
    endproperty

    property empty_flag_p;
        @(posedge clk) disable iff (!rst_n) empty == (count == 0);
    endproperty

    property almostfull_flag_p;
        @(posedge clk) disable iff (!rst_n) almostfull == (count == FIFO_DEPTH-1);
    endproperty

    property almostempty_flag_p;
        @(posedge clk) disable iff (!rst_n) almostempty == (count == 1);
    endproperty

    property count_range_p;
        @(posedge clk) disable iff (!rst_n) count <= FIFO_DEPTH;
    endproperty

    reset_values_a     : assert property (reset_values_p)     else $error("outputs/internals not cleared in reset");
    full_flag_a        : assert property (full_flag_p)        else $error("full flag wrong");
    empty_flag_a       : assert property (empty_flag_p)       else $error("empty flag wrong");
    almostfull_flag_a  : assert property (almostfull_flag_p)  else $error("almostfull flag wrong");
    almostempty_flag_a : assert property (almostempty_flag_p) else $error("almostempty flag wrong");
    count_range_a      : assert property (count_range_p)      else $error("count out of range");

    // =========================================================================
    // Concurrent properties: flags, pointers, count
    // =========================================================================

    // ---- output flags
    property wr_ack_p;
        @(posedge clk) disable iff (!rst_n)
            (wr_en && !full) |=> wr_ack;
    endproperty

    property no_wr_ack_p;
        @(posedge clk) disable iff (!rst_n)
            !(wr_en && !full) |=> !wr_ack;
    endproperty

    property overflow_p;
        @(posedge clk) disable iff (!rst_n)
            (wr_en && full) |=> overflow;
    endproperty

    property no_overflow_p;
        @(posedge clk) disable iff (!rst_n)
            !(wr_en && full) |=> !overflow;
    endproperty

    property underflow_p;
        @(posedge clk) disable iff (!rst_n)
            (rd_en && empty) |=> underflow;
    endproperty

    property no_underflow_p;
        @(posedge clk) disable iff (!rst_n)
            !(rd_en && empty) |=> !underflow;
    endproperty

    // ---- pointers
    property wr_ptr_inc_p;
        @(posedge clk) disable iff (!rst_n)
            (wr_en && !full) |=> (wr_ptr == next_ptr($past(wr_ptr)));
    endproperty

    property wr_ptr_hold_p;
        @(posedge clk) disable iff (!rst_n)
            !(wr_en && !full) |=> $stable(wr_ptr);
    endproperty

    property rd_ptr_inc_p;
        @(posedge clk) disable iff (!rst_n)
            (rd_en && !empty) |=> (rd_ptr == next_ptr($past(rd_ptr)));
    endproperty

    property rd_ptr_hold_p;
        @(posedge clk) disable iff (!rst_n)
            !(rd_en && !empty) |=> $stable(rd_ptr) && $stable(data_out);
    endproperty

    // ---- count
    property count_write_priority_p;   // r+w on empty -> only write
        @(posedge clk) disable iff (!rst_n)
            (wr_en && rd_en && empty) |=> (count == $past(count) + 1'b1);
    endproperty

    property count_read_priority_p;    // r+w on full -> only read
        @(posedge clk) disable iff (!rst_n)
            (wr_en && rd_en && full) |=> (count == $past(count) - 1'b1);
    endproperty

    property count_rw_p;               // r+w otherwise -> unchanged
        @(posedge clk) disable iff (!rst_n)
            (wr_en && rd_en && !empty && !full) |=> $stable(count);
    endproperty

    property count_w_p;
        @(posedge clk) disable iff (!rst_n)
            (wr_en && !rd_en && !full) |=> (count == $past(count) + 1'b1);
    endproperty

    property count_r_p;
        @(posedge clk) disable iff (!rst_n)
            (!wr_en && rd_en && !empty) |=> (count == $past(count) - 1'b1);
    endproperty

    property count_idle_p;
        @(posedge clk) disable iff (!rst_n)
            (!wr_en && !rd_en) |=> $stable(count);
    endproperty

    // ---- assert
    wr_ack_a                : assert property (wr_ack_p);
    no_wr_ack_a             : assert property (no_wr_ack_p);
    overflow_a              : assert property (overflow_p);
    no_overflow_a           : assert property (no_overflow_p);
    underflow_a             : assert property (underflow_p);
    no_underflow_a          : assert property (no_underflow_p);
    wr_ptr_inc_a            : assert property (wr_ptr_inc_p);
    wr_ptr_hold_a           : assert property (wr_ptr_hold_p);
    rd_ptr_inc_a            : assert property (rd_ptr_inc_p);
    rd_ptr_hold_a           : assert property (rd_ptr_hold_p);
    count_write_priority_a  : assert property (count_write_priority_p);
    count_read_priority_a   : assert property (count_read_priority_p);
    count_rw_a              : assert property (count_rw_p);
    count_w_a               : assert property (count_w_p);
    count_r_a               : assert property (count_r_p);
    count_idle_a            : assert property (count_idle_p);

    // ---- cover (make sure every scenario was actually exercised)
    wr_ack_c                : cover property (wr_ack_p);
    overflow_c              : cover property (overflow_p);
    underflow_c             : cover property (underflow_p);
    wr_ptr_inc_c            : cover property (wr_ptr_inc_p);
    rd_ptr_inc_c            : cover property (rd_ptr_inc_p);
    count_write_priority_c  : cover property (count_write_priority_p);
    count_read_priority_c   : cover property (count_read_priority_p);
    count_rw_c              : cover property (count_rw_p);
    count_w_c               : cover property (count_w_p);
    count_r_c               : cover property (count_r_p);
    full_to_empty_c         : cover property (@(posedge clk) disable iff (!rst_n)
                                              full ##[1:$] empty);
    wr_ptr_wrap_c           : cover property (@(posedge clk) disable iff (!rst_n)
                                              (wr_ptr == ADDR_W'(FIFO_DEPTH-1)) && wr_en && !full);

endmodule
