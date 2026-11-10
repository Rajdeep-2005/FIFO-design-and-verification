////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_TEST.sv
// Description : Test class. Builds the environment (driver, monitor with
//               coverage, scoreboard), runs directed corner-case scenarios
//               followed by constrained-random phases, then prints the
//               result and the functional coverage.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

package fifo_test_pkg;

    import fifo_transaction_pkg::*;
    import fifo_driver_pkg::*;
    import fifo_monitor_pkg::*;
    import fifo_scoreboard_pkg::*;

    class FIFO_test;

        virtual fifo_if             vif;
        mailbox #(FIFO_transaction) mon2scb;
        FIFO_driver                 drv;
        FIFO_monitor                mon;
        FIFO_scoreboard             scb;

        int unsigned num_random = 1000;   // transactions per random phase

        function new(virtual fifo_if vif);
            this.vif = vif;
            mon2scb  = new();
            drv      = new(vif);
            mon      = new(vif, mon2scb);
            scb      = new(mon2scb);
        endfunction

        // ---- one directed cycle
        task op(bit wr, bit rd, int unsigned n = 1);
            FIFO_transaction tr;
            repeat (n) begin
                tr         = new();
                tr.rst_n   = 1'b1;
                tr.wr_en   = wr;
                tr.rd_en   = rd;
                tr.data_in = $urandom();
                drv.drive(tr);
            end
        endtask

        // ---- directed corner cases
        task directed_phase();
            $display("[TEST] %t : directed phase", $time);
            op(.wr(0), .rd(1));                    // read when empty   -> underflow
            op(.wr(1), .rd(1));                    // r+w when empty    -> write only + underflow
            op(.wr(0), .rd(1));                    // back to empty
            op(.wr(1), .rd(0), .n(FIFO_DEPTH-1));  // fill to almostfull
            op(.wr(0), .rd(0));                    // idle at almostfull
            op(.wr(1), .rd(1));                    // r+w at almostfull -> count unchanged
            op(.wr(1), .rd(0));                    // -> full
            op(.wr(0), .rd(0));                    // idle at full
            op(.wr(1), .rd(0), .n(2));             // write when full   -> overflow
            op(.wr(1), .rd(1));                    // r+w when full     -> read only + overflow
            op(.wr(1), .rd(0));                    // full again
            op(.wr(0), .rd(1), .n(FIFO_DEPTH-1));  // drain to almostempty
            op(.wr(0), .rd(0));                    // idle at almostempty
            op(.wr(1), .rd(1));                    // r+w at almostempty
            op(.wr(0), .rd(1));                    // -> empty
            op(.wr(0), .rd(1), .n(2));             // read when empty   -> underflow
            // reset in the middle of traffic
            op(.wr(1), .rd(0), .n(3));
            drv.reset(1);
            op(.wr(0), .rd(1));                    // FIFO must be empty after reset
        endtask

        // ---- constrained random
        task random_phase(int unsigned n, int wr_pct, int rd_pct);
            FIFO_transaction tr;
            $display("[TEST] %t : random phase  wr_en=%0d%%  rd_en=%0d%%",
                     $time, wr_pct, rd_pct);
            repeat (n) begin
                tr = new(wr_pct, rd_pct);
                if (!tr.randomize())
                    $fatal(1, "[TEST] randomization failed");
                drv.drive(tr);
            end
        endtask

        // ---- main
        task run();
            drv.init();

            fork
                mon.run();
                scb.run();
            join_none

            drv.reset(2);

            directed_phase();
            random_phase(num_random, 70, 30);   // mostly writes -> full side
            random_phase(num_random, 30, 70);   // mostly reads  -> empty side
            random_phase(num_random, 50, 50);   // balanced

            // let the last transactions reach the scoreboard
            op(.wr(0), .rd(0), .n(3));
            @(negedge vif.clk);

            scb.report();
            $display(" FUNCTIONAL COVERAGE = %0.2f %%", mon.cov.get_coverage());
            if (scb.error_count == 0)
                $display(" ***************  TEST PASSED  ***************");
            else
                $display(" ***************  TEST FAILED  ***************");
            $finish;
        endtask

    endclass

endpackage
