////////////////////////////////////////////////////////////////////////////////
// Author      : Rajdeep
// File        : FIFO_DRIVER.sv
// Description : Drives transactions onto the interface on the negedge of clk.
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

package fifo_driver_pkg;

    import fifo_transaction_pkg::*;

    class FIFO_driver;

        virtual fifo_if vif;

        function new(virtual fifo_if vif);
            this.vif = vif;
        endfunction

        // Put every input in a known state at time 0 (reset asserted).
        // Non-blocking so the DUT's always_ff sees the rst_n negedge.
        task init();
            vif.rst_n   <= 1'b0;
            vif.wr_en   <= 1'b0;
            vif.rd_en   <= 1'b0;
            vif.data_in <= '0;
        endtask

        // Hold reset for 'cycles' clocks, then release it.
        task reset(int unsigned cycles = 2);
            repeat (cycles) begin
                @(negedge vif.clk);
                vif.rst_n   <= 1'b0;
                vif.wr_en   <= 1'b0;
                vif.rd_en   <= 1'b0;
                vif.data_in <= '0;
            end
            @(negedge vif.clk);
            vif.rst_n <= 1'b1;
        endtask

        // Drive one transaction (one clock cycle).
        task drive(FIFO_transaction tr);
            @(negedge vif.clk);
            vif.rst_n   <= tr.rst_n;
            vif.wr_en   <= tr.wr_en;
            vif.rd_en   <= tr.rd_en;
            vif.data_in <= tr.data_in;
        endtask

    endclass

endpackage
