////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_MONITOR.sv
// Description : Functional coverage collector + monitor.
//               The monitor samples the interface once per clock, sends a
//               copy of each transaction to the scoreboard (mailbox) and
//               samples functional coverage.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

package fifo_monitor_pkg;

    import fifo_transaction_pkg::*;

    // =========================================================================
    // Functional coverage
    //   Every output flag is crossed with wr_en and rd_en.
    //   Combinations that cannot happen in a correct FIFO are illegal_bins,
    //   so hitting one of them is reported as an error by the simulator.
    // =========================================================================
    class FIFO_coverage;

        FIFO_transaction cvg_txn;

        covergroup FIFO_cg;
            cp_wr_en       : coverpoint cvg_txn.wr_en;
            cp_rd_en       : coverpoint cvg_txn.rd_en;
            cp_wr_ack      : coverpoint cvg_txn.wr_ack;
            cp_overflow    : coverpoint cvg_txn.overflow;
            cp_underflow   : coverpoint cvg_txn.underflow;
            cp_full        : coverpoint cvg_txn.full;
            cp_empty       : coverpoint cvg_txn.empty;
            cp_almostfull  : coverpoint cvg_txn.almostfull;
            cp_almostempty : coverpoint cvg_txn.almostempty;

            // wr_ack is impossible without wr_en
            wr_ack_X : cross cp_wr_en, cp_rd_en, cp_wr_ack {
                illegal_bins no_wr_ack = binsof(cp_wr_en) intersect {0} &&
                                         binsof(cp_wr_ack) intersect {1};
            }
            // overflow is impossible without wr_en
            overflow_X : cross cp_wr_en, cp_rd_en, cp_overflow {
                illegal_bins no_wr_ovf = binsof(cp_wr_en) intersect {0} &&
                                         binsof(cp_overflow) intersect {1};
            }
            // underflow is impossible without rd_en
            underflow_X : cross cp_wr_en, cp_rd_en, cp_underflow {
                illegal_bins no_rd_udf = binsof(cp_rd_en) intersect {0} &&
                                         binsof(cp_underflow) intersect {1};
            }
            // a cycle with rd_en can never end with the FIFO full
            full_X : cross cp_wr_en, cp_rd_en, cp_full {
                illegal_bins rd_full = binsof(cp_rd_en) intersect {1} &&
                                       binsof(cp_full) intersect {1};
            }
            // a cycle with wr_en can never end with the FIFO empty
            // (a write is always accepted when the FIFO is not full)
            empty_X : cross cp_wr_en, cp_rd_en, cp_empty {
                illegal_bins wr_empty = binsof(cp_wr_en) intersect {1} &&
                                        binsof(cp_empty) intersect {1};
            }
            almostfull_X  : cross cp_wr_en, cp_rd_en, cp_almostfull;
            almostempty_X : cross cp_wr_en, cp_rd_en, cp_almostempty;
        endgroup

        function new();
            FIFO_cg = new();
        endfunction

        // Coverage is only meaningful while out of reset
        function void sample_data(FIFO_transaction tr);
            cvg_txn = tr;
            if (tr.rst_n === 1'b1)
                FIFO_cg.sample();
        endfunction

        function real get_coverage();
            return FIFO_cg.get_inst_coverage();
        endfunction

    endclass

    // =========================================================================
    // Monitor
    // =========================================================================
    class FIFO_monitor;

        virtual fifo_if                 vif;
        mailbox #(FIFO_transaction)     mon2scb;
        FIFO_coverage                   cov;

        function new(virtual fifo_if vif, mailbox #(FIFO_transaction) mon2scb);
            this.vif     = vif;
            this.mon2scb = mon2scb;
            this.cov     = new();
        endfunction

        task run();
            FIFO_transaction tr;
            forever begin
                @(vif.mon_cb);
                tr = new();
                tr.data_in     = vif.mon_cb.data_in;
                tr.rst_n       = vif.mon_cb.rst_n;
                tr.wr_en       = vif.mon_cb.wr_en;
                tr.rd_en       = vif.mon_cb.rd_en;
                tr.data_out    = vif.mon_cb.data_out;
                tr.wr_ack      = vif.mon_cb.wr_ack;
                tr.overflow    = vif.mon_cb.overflow;
                tr.underflow   = vif.mon_cb.underflow;
                tr.full        = vif.mon_cb.full;
                tr.empty       = vif.mon_cb.empty;
                tr.almostfull  = vif.mon_cb.almostfull;
                tr.almostempty = vif.mon_cb.almostempty;

                cov.sample_data(tr);
                mon2scb.put(tr);
            end
        endtask

    endclass

endpackage
