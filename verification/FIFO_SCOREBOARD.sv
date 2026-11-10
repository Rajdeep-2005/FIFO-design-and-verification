////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_SCOREBOARD.sv
// Description : Reference model (queue based) + checker.
//               For every sampled cycle the reference model computes the
//               expected outputs and compares them with the DUT outputs.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

package fifo_scoreboard_pkg;

    import fifo_transaction_pkg::*;

    class FIFO_scoreboard;

        mailbox #(FIFO_transaction) mon2scb;

        // ---- reference model state
        logic [FIFO_WIDTH-1:0] queue_ref [$];
        int                    count;

        // ---- expected outputs
        logic [FIFO_WIDTH-1:0] data_out_ref;
        logic wr_ack_ref, overflow_ref, underflow_ref;
        logic full_ref, empty_ref, almostfull_ref, almostempty_ref;

        // ---- statistics
        int unsigned error_count   = 0;
        int unsigned correct_count = 0;
        int unsigned sample_count  = 0;

        function new(mailbox #(FIFO_transaction) mon2scb);
            this.mon2scb = mon2scb;
            reset_model();
        endfunction

        task run();
            FIFO_transaction tr;
            forever begin
                mon2scb.get(tr);
                check_data(tr);
            end
        endtask

        // -------------------------------------------------- reference model
        function void reset_model();
            queue_ref.delete();
            count         = 0;
            data_out_ref  = '0;
            wr_ack_ref    = 1'b0;
            overflow_ref  = 1'b0;
            underflow_ref = 1'b0;
            update_flags();
        endfunction

        function void update_flags();
            full_ref        = (count == FIFO_DEPTH);
            empty_ref       = (count == 0);
            almostfull_ref  = (count == FIFO_DEPTH-1);
            almostempty_ref = (count == 1);
        endfunction

        function void reference_model(FIFO_transaction tr);
            bit do_write, do_read;

            if (tr.rst_n !== 1'b1) begin
                reset_model();
                return;
            end

            // decisions use the state BEFORE this clock edge
            do_write = tr.wr_en && (count < FIFO_DEPTH);
            do_read  = tr.rd_en && (count != 0);

            wr_ack_ref    = do_write;
            overflow_ref  = tr.wr_en && (count == FIFO_DEPTH);
            underflow_ref = tr.rd_en && (count == 0);

            if (do_read)  data_out_ref = queue_ref.pop_front();
            if (do_write) queue_ref.push_back(tr.data_in);

            count = queue_ref.size();
            update_flags();
        endfunction

        // ----------------------------------------------------------- checker
        function void compare(string name, logic [FIFO_WIDTH-1:0] actual,
                              logic [FIFO_WIDTH-1:0] expected,
                              FIFO_transaction tr);
            if (actual !== expected) begin
                error_count++;
                $error("[SCB] %t : %s mismatch, DUT=0x%0h REF=0x%0h\n      %s",
                       $time, name, actual, expected, tr.convert2string());
            end
            else
                correct_count++;
        endfunction

        function void check_data(FIFO_transaction tr);
            sample_count++;
            reference_model(tr);
            compare("data_out",    tr.data_out,    data_out_ref,    tr);
            compare("wr_ack",      tr.wr_ack,      wr_ack_ref,      tr);
            compare("overflow",    tr.overflow,    overflow_ref,    tr);
            compare("underflow",   tr.underflow,   underflow_ref,   tr);
            compare("full",        tr.full,        full_ref,        tr);
            compare("empty",       tr.empty,       empty_ref,       tr);
            compare("almostfull",  tr.almostfull,  almostfull_ref,  tr);
            compare("almostempty", tr.almostempty, almostempty_ref, tr);
        endfunction

        function void report();
            $display("--------------------------------------------------");
            $display(" SCOREBOARD : cycles checked = %0d", sample_count);
            $display("              correct checks = %0d", correct_count);
            $display("              errors         = %0d", error_count);
            $display("--------------------------------------------------");
        endfunction

    endclass

endpackage
