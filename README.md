# Synchronous FIFO Verification

**Author:** Rajdeep

A parameterized synchronous FIFO written in SystemVerilog and verified with a
class-based SystemVerilog testbench. The testbench has a driver, a monitor, a
queue-based scoreboard, functional coverage and SVA assertions. It runs directed
corner cases first and then constrained-random traffic.

---

## FIFO design

### Parameters

| Parameter    | Default | Description                       |
|--------------|---------|-----------------------------------|
| `FIFO_WIDTH` | 16      | Width of data in/out and memory   |
| `FIFO_DEPTH` | 8       | Number of words (must be ≥ 2)     |

### Ports

| Port          | Dir    | Description                                                        |
|---------------|--------|--------------------------------------------------------------------|
| `clk`         | Input  | Clock                                                              |
| `rst_n`       | Input  | Active-low **asynchronous** reset                                  |
| `wr_en`       | Input  | Write enable. Data is written if the FIFO is not full              |
| `rd_en`       | Input  | Read enable. Data is read if the FIFO is not empty                 |
| `data_in`     | Input  | Write data                                                         |
| `data_out`    | Output | Read data (registered)                                             |
| `wr_ack`      | Output | Registered. The write in the previous cycle succeeded              |
| `overflow`    | Output | Registered. A write was rejected because the FIFO was full         |
| `underflow`   | Output | Registered. A read was rejected because the FIFO was empty         |
| `full`        | Output | FIFO is full (`count == FIFO_DEPTH`)                               |
| `empty`       | Output | FIFO is empty (`count == 0`)                                       |
| `almostfull`  | Output | One more write will make the FIFO full (`count == FIFO_DEPTH-1`)   |
| `almostempty` | Output | One more read will make the FIFO empty (`count == 1`)              |

### Simultaneous read and write

| FIFO state       | Result                                      |
|------------------|---------------------------------------------|
| Empty            | Only the write happens (and `underflow` = 1) |
| Full             | Only the read happens (and `overflow` = 1)   |
| Neither          | Both happen, `count` does not change         |

---

## Repository structure

```plaintext
FIFO-Verification/
│
├── design/
│   └── FIFO.sv                 # RTL of the synchronous FIFO
│
├── verification/
│   ├── FIFO_IF.sv              # Interface + monitor clocking block
│   ├── FIFO_TRANSACTION.sv     # Transaction class, constraints, shared parameters
│   ├── FIFO_DRIVER.sv          # Drives transactions on the negedge of clk
│   ├── FIFO_MONITOR.sv         # Monitor + functional coverage (covergroup, crosses)
│   ├── FIFO_SCOREBOARD.sv      # Queue-based reference model + checker
│   ├── FIFO_TEST.sv            # Test: directed + constrained-random phases
│   ├── FIFO_ASSERTIONS.sv      # SVA, bound to the DUT with `bind`
│   └── FIFO_TOP.sv             # Top module: clock, interface, DUT, bind, test
│
└── README.md
```

---

## Testbench architecture

```plaintext
                 +-------------------------- FIFO_TOP ---------------------------+
                 |                                                               |
   FIFO_test --> |  FIFO_driver --(negedge)--> fifo_if --> FIFO (DUT)            |
                 |                                 |          ^                  |
                 |                                 |          | bind             |
                 |                                 |      FIFO_ASSERTIONS        |
                 |                                 v                             |
                 |                FIFO_monitor (mon_cb @negedge, #1step)         |
                 |                    |                     |                    |
                 |              FIFO_coverage         mailbox                    |
                 |                                          v                    |
                 |                                   FIFO_scoreboard             |
                 +---------------------------------------------------------------+
```

**Timing (race-free).** The driver changes inputs on the **negedge**. The DUT
samples them on the **posedge**. The monitor samples on the next **negedge**
through a clocking block with `#1step` input skew, so each sample holds the
inputs of one cycle and the outputs the DUT produced for them.

### Test phases (`FIFO_TEST.sv`)
1. **Reset**: 2 cycles.
2. **Directed corner cases**: underflow, read+write on empty, fill to
   almostfull, full, overflow, read+write on full, drain to almostempty,
   empty, and a reset in the middle of traffic.
3. **Constrained random**: three phases of 1000 cycles each, with different
   `wr_en`/`rd_en` probabilities (70/30, 30/70, 50/50) so both the full side
   and the empty side are exercised. Reset is asserted randomly (2%).

### Scoreboard
A SystemVerilog queue is the reference model. For every cycle it works out
the expected `data_out`, `wr_ack`, `overflow`, `underflow`, `full`, `empty`,
`almostfull` and `almostempty`. It compares each one with the DUT using `!==`,
so X/Z values are caught too.

### Functional coverage
Every output flag is crossed with `wr_en` and `rd_en`. Combinations that a
correct FIFO can never produce are declared as `illegal_bins`:
- `wr_ack = 1` with `wr_en = 0`
- `overflow = 1` with `wr_en = 0`
- `underflow = 1` with `rd_en = 0`
- `full = 1` after a cycle with `rd_en = 1`
- `empty = 1` after a cycle with `wr_en = 1`

### Assertions (`FIFO_ASSERTIONS.sv`)
Bound to the DUT with `bind`, so they can check internal signals without
changing the RTL:
- Reset values of all outputs, `count`, `wr_ptr` and `rd_ptr`
- `full` / `empty` / `almostfull` / `almostempty` always match `count`
- `wr_ack`, `overflow` and `underflow` are set **and** cleared correctly
- `wr_ptr` / `rd_ptr` increment and wrap on a valid write/read, otherwise they hold
- `count` behaviour for write-only, read-only, idle and the three read+write cases
- Cover properties for every scenario, including full→empty and pointer wrap

---

## Bugs found and fixed in the RTL

| # | Bug in the original design                                              | Fix                                         |
|---|-------------------------------------------------------------------------|---------------------------------------------|
| 1 | `almostfull` was asserted at `FIFO_DEPTH-2`                              | Asserted at `FIFO_DEPTH-1`                  |
| 2 | `wr_ack` and `overflow` were not reset                                   | Cleared on reset                            |
| 3 | `underflow` was combinational, while `overflow` was registered           | Made registered, like `overflow`            |
| 4 | Read+write on an empty/full FIFO did not update `count`                  | Count follows the accepted operation only   |
| 5 | `data_out` was not reset                                                 | Cleared on reset                            |
| 6 | Memory was written inside the async-reset block (bad for synthesis)      | Memory moved to its own `always_ff`         |
| 7 | Pointer wrap only worked when `FIFO_DEPTH` was a power of 2              | Pointers wrap explicitly at `FIFO_DEPTH-1`  |

## Bugs fixed in the testbench

- The monitor and the stimulus both used `#20` delays, which caused a race. Now the driver uses the negedge and the monitor uses a `#1step` clocking block.
- The scoreboard incremented the wrong counter for `almostempty`.
- Coverage could never reach 100%: the `wr_en=1 / empty=1` cross bins are impossible and are now `illegal_bins`.
- Assertions were mixed into the RTL, and an `` `ifdef `` inside a bare `if` broke the code when `SIM` was not defined. They now live in a separate module that is bound to the DUT.
- `underflow` used blocking assignments inside a sequential block. It now uses non-blocking assignments.

---

## Running the simulation (QuestaSim)

From the `FIFO-Verification/` folder:

```bash
vlib work
```

```bash
vlog -sv +cover=bcesft design/FIFO.sv verification/FIFO_IF.sv verification/FIFO_TRANSACTION.sv verification/FIFO_DRIVER.sv verification/FIFO_MONITOR.sv verification/FIFO_SCOREBOARD.sv verification/FIFO_TEST.sv verification/FIFO_ASSERTIONS.sv verification/FIFO_TOP.sv
```

```bash
vsim -c -coverage -assertdebug FIFO_TOP -do "run -all; coverage report -details -output coverage_report.txt; quit -f"
```

Compile order matters: interface, then the packages (transaction → driver →
monitor → scoreboard → test), then the modules.

### Expected output
```plaintext
 SCOREBOARD : cycles checked = ...
              errors         = 0
 FUNCTIONAL COVERAGE = 100.00 %
 ***************  TEST PASSED  ***************
```

---

## Tools
- SystemVerilog (IEEE 1800-2017)
- QuestaSim / ModelSim for simulation, coverage and assertions
