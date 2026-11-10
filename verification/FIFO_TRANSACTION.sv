////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_TRANSACTION.sv
// Description : Transaction class (one clock cycle of FIFO activity) and the
//               parameters shared by the whole verification environment.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

package fifo_transaction_pkg;

    // Shared parameters (keep in sync with FIFO_TOP)
    parameter int FIFO_WIDTH = 16;
    parameter int FIFO_DEPTH = 8;

    class FIFO_transaction;

        // ---- stimulus (randomized)
        rand bit [FIFO_WIDTH-1:0] data_in;
        rand bit                  rst_n;
        rand bit                  wr_en;
        rand bit                  rd_en;

        // ---- DUT response (filled by the monitor)
        logic [FIFO_WIDTH-1:0] data_out;
        logic wr_ack, overflow, underflow;
        logic full, empty, almostfull, almostempty;

        // ---- knobs: probability (%) that wr_en / rd_en is 1
        int WR_EN_ON_DIST;
        int RD_EN_ON_DIST;

        function new(int WR = 70, int RD = 30);
            WR_EN_ON_DIST = WR;
            RD_EN_ON_DIST = RD;
        endfunction

        // ---- constraints
        constraint reset_c {
            rst_n dist {0 :/ 2, 1 :/ 98};        // reset asserted rarely
        }

        constraint wr_en_c {
            wr_en dist {1 := WR_EN_ON_DIST, 0 := (100 - WR_EN_ON_DIST)};
        }

        constraint rd_en_c {
            rd_en dist {1 := RD_EN_ON_DIST, 0 := (100 - RD_EN_ON_DIST)};
        }

        // ---- utilities
        function FIFO_transaction copy();
            FIFO_transaction t = new(WR_EN_ON_DIST, RD_EN_ON_DIST);
            t.data_in     = data_in;
            t.rst_n       = rst_n;
            t.wr_en       = wr_en;
            t.rd_en       = rd_en;
            t.data_out    = data_out;
            t.wr_ack      = wr_ack;
            t.overflow    = overflow;
            t.underflow   = underflow;
            t.full        = full;
            t.empty       = empty;
            t.almostfull  = almostfull;
            t.almostempty = almostempty;
            return t;
        endfunction

        function string convert2string();
            return $sformatf({"rst_n=%0b wr_en=%0b rd_en=%0b data_in=0x%0h | ",
                              "data_out=0x%0h wr_ack=%0b ovf=%0b udf=%0b ",
                              "full=%0b empty=%0b afull=%0b aempty=%0b"},
                             rst_n, wr_en, rd_en, data_in,
                             data_out, wr_ack, overflow, underflow,
                             full, empty, almostfull, almostempty);
        endfunction

    endclass

endpackage
