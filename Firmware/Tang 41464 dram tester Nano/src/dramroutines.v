module dramroutines (
    input clk,
    input rst_n,
    output logic oscilloscope_trigger,
    output logic dram_power_sw,
    inout wire [3:0] dram_io,
    output logic dram_io_chip_oe,
    output logic dram_io_chip_dir,
    output logic dram_oe,
    output logic dram_we,
    output logic dram_ras,
    output logic dram_cas,
    output logic dram_oe_we_ras_cas_chip_ce,
    output logic [7:0] dram_addr,
    output logic dram_addr_chip_ce,
    input wire test_read,
    input wire test_write,
    output logic result_ok,
    output logic result_fail,
    output logic dram_ready,
    input logic [7:0] row_address,
    input logic [7:0] col_address,
    input logic reset_results,
    input logic test_in_progress,
    input logic [3:0] test_data,
    input logic [1:0] dram_speed_sel,
    input logic pll_lock
);

localparam int CLK_MHZ = 165; // Clock frequency in MHz (6.06ns period)

function automatic int ns_to_cycles(input int t_ns);
    ns_to_cycles = (t_ns * CLK_MHZ + 999) / 1000;
endfunction

localparam int CYCLE_START_CLK = ns_to_cycles(25);      // CYCLE_START_CLK: Number of cycles to wait before starting the RAS assert (to ensure stable state after test start)

logic [1:0] dram_speed_sel_meta;
logic [1:0] dram_speed_sel_sync;

logic [15:0] T_RAS_SEL, T_RCD_SEL, T_CAS_SEL, T_ASR_SEL, T_RAH_SEL;
logic [15:0] T_RAC_SEL, T_CAC_SEL, T_RRH_SEL, T_RC_SEL, WAIT_CYCLES_SEL;

always_comb begin
    case (dram_speed_sel_sync)
        2'b00: begin  // 80ns-"light" class DRAM
            T_RAS_SEL = ns_to_cycles(80);
            T_RCD_SEL = ns_to_cycles(20);
            T_CAS_SEL = ns_to_cycles(40);
            T_ASR_SEL = ns_to_cycles(10);
            T_RAH_SEL = ns_to_cycles(10);
            T_RAC_SEL = ns_to_cycles(80);
            T_CAC_SEL = ns_to_cycles(40);
            T_RRH_SEL = ns_to_cycles(10);
            T_RC_SEL  = ns_to_cycles(160);
            WAIT_CYCLES_SEL = ns_to_cycles(20);
        end
        2'b01: begin  // 100ns-"light" class DRAM
            T_RAS_SEL = ns_to_cycles(100);
            T_RCD_SEL = ns_to_cycles(25);
            T_CAS_SEL = ns_to_cycles(55);
            T_ASR_SEL = ns_to_cycles(10);
            T_RAH_SEL = ns_to_cycles(10);
            T_RAC_SEL = ns_to_cycles(100);
            T_CAC_SEL = ns_to_cycles(50);
            T_RRH_SEL = ns_to_cycles(10);
            T_RC_SEL  = ns_to_cycles(200);
            WAIT_CYCLES_SEL = ns_to_cycles(25);
        end
        2'b10: begin  // 120ns-"light" class DRAM
            T_RAS_SEL = ns_to_cycles(120);
            T_RCD_SEL = ns_to_cycles(30);
            T_CAS_SEL = ns_to_cycles(70);
            T_ASR_SEL = ns_to_cycles(10);
            T_RAH_SEL = ns_to_cycles(15);
            T_RAC_SEL = ns_to_cycles(120);
            T_CAC_SEL = ns_to_cycles(60);
            T_RRH_SEL = ns_to_cycles(10);
            T_RC_SEL  = ns_to_cycles(220);
            WAIT_CYCLES_SEL = ns_to_cycles(30);
        end
        2'b11: begin  // 150ns-"light" class DRAM
            T_RAS_SEL = ns_to_cycles(150);
            T_RCD_SEL = ns_to_cycles(40);
            T_CAS_SEL = ns_to_cycles(80);
            T_ASR_SEL = ns_to_cycles(15);
            T_RAH_SEL = ns_to_cycles(15);
            T_RAC_SEL = ns_to_cycles(150);
            T_CAC_SEL = ns_to_cycles(80);
            T_RRH_SEL = ns_to_cycles(15);
            T_RC_SEL  = ns_to_cycles(290);
            WAIT_CYCLES_SEL = ns_to_cycles(40);
        end
    endcase
end

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 120ns-"light" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(120);               // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(30);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(70);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(15);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(120);               // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(60);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(100);               // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 120ns-"STRICT" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(120);               // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(25);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(60);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(15);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(120);               // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(60);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(90);                // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 100ns-"light" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(100);               // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(25);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(55);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(10);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(100);               // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(50);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(90);                // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 100ns-"STRICT" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(100);               // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(20);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(50);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(10);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(100);               // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(50);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(90);                // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 80ns-"light" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(80);                // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(30);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(40);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(10);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(80);                // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(40);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(70);                // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

/*
// DRAM TIMING PARAMETERS (in cycles, calculated from ns values) for 80ns-"STRICT" class DRAM at 200MHz clock (5ns period)

localparam int T_RAS = ns_to_cycles(80);                // tRAS: Row Active Time (min time from RAS assert to RAS deassert)
localparam int T_RCD = ns_to_cycles(20);                // tRCD: Row to Column Delay (min time from RAS assert to CAS assert)
localparam int T_CAS = ns_to_cycles(40);                // tCAS: Column Access Strobe Time (min time from CAS assert to data valid) 
localparam int T_ASR = ns_to_cycles(10);                // tASR: Address Setup Time (min time from address stable to RAS assert)
localparam int T_RAH = ns_to_cycles(10);                // tRAH: Row Address Hold Time (min time from RAS assert to address change)
localparam int T_RAC = ns_to_cycles(80);                // tRAC: Row Access Cycle Time (min time from RAS assert to data valid)
localparam int T_CAC = ns_to_cycles(40);                // tCAC: Column Access Cycle Time (min time from CAS assert to data valid)
localparam int T_RRH = ns_to_cycles(10);                // tRRH: Row to Row Hold Time (min time from RAS deassert to address change or RAS assert)
localparam int T_RP  = ns_to_cycles(70);                // tRP: Row Precharge Time (min time from RAS deassert to next RAS assert)
*/

logic [15:0] RAS_ASSERT;
logic [15:0] RAS_DEASSERT;

logic [15:0] CAS_ASSERT;
logic [15:0] CAS_DEASSERT;

logic [15:0] ROW_ADDR_SET;
logic [15:0] COL_ADDR_SET;

logic [15:0] READ_OE_ASSERT;
logic [15:0] READ_OE_DEASSERT;

logic [15:0] WRITE_WE_ASSERT;
logic [15:0] WRITE_WE_DEASSERT;

logic [15:0] READ_DATA;

logic [15:0] READ_CYCLE_END;
logic [15:0] WRITE_CYCLE_END;

logic [15:0] WAIT_CYCLES;

assign RAS_ASSERT       = CYCLE_START_CLK;
assign RAS_DEASSERT     = RAS_ASSERT + T_RAS_SEL;

assign CAS_ASSERT       = RAS_ASSERT + T_RCD_SEL;
assign CAS_DEASSERT     = CAS_ASSERT + T_CAS_SEL;

assign ROW_ADDR_SET     = RAS_ASSERT - T_ASR_SEL;
assign COL_ADDR_SET     = RAS_ASSERT + T_RAH_SEL;

assign READ_OE_ASSERT   = CAS_ASSERT;
assign READ_OE_DEASSERT = CAS_DEASSERT;

assign WRITE_WE_ASSERT   = COL_ADDR_SET;
assign WRITE_WE_DEASSERT = RAS_DEASSERT + T_RRH_SEL;

assign READ_DATA = RAS_ASSERT +
                  ((T_RAC_SEL > (T_RCD_SEL + T_CAC_SEL)) ?
                   T_RAC_SEL : (T_RCD_SEL + T_CAC_SEL));


assign READ_CYCLE_END  = T_RC_SEL;
assign WRITE_CYCLE_END = T_RC_SEL;

assign WAIT_CYCLES = WAIT_CYCLES_SEL;            // Number of cycles to wait in WAIT_WR_TO_IDLE and WAIT_RD_TO_IDLE states before considering the DRAM ready again (to ensure proper precharge and idle state)

logic [3:0] dram_io_out;
logic [3:0] dram_io_in;

logic fpga_dram_io_dir;

assign dram_io = fpga_dram_io_dir ? dram_io_out : 4'bzzzz;
assign dram_io_in = dram_io;

typedef enum logic [2:0] {
    IDLE,
    READ,
    WRITE,
    CLEANUPWR1,
    CLEANUPWR2,
    WAIT_WR_TO_IDLE,
    CLEANUPRD1,
    WAIT_RD_TO_IDLE
} state_t;

logic next_dram_ras;
logic next_dram_cas;
logic next_dram_oe;
logic next_dram_we;
logic [7:0] next_dram_addr;
logic next_result_ok;
logic next_result_fail;

logic test_read_meta;
logic test_read_sync;

logic test_write_meta;
logic test_write_sync;

logic test_read_sync_r, test_write_sync_r;

wire test_read_pulse  = test_read_sync  & ~test_read_sync_r;
wire test_write_pulse = test_write_sync & ~test_write_sync_r;

logic [7:0] row_address_latch;
logic [7:0] col_address_latch;

logic [7:0] next_row_address_latch;
logic [7:0] next_col_address_latch;

logic [3:0] test_data_latch;
logic [3:0] next_test_data_latch;

logic reset_results_meta;
logic reset_results_sync;

state_t state, next_state;

logic [8:0] cycle_clk_counter;

logic test_in_progress_meta;
logic test_in_progress_sync;

always_ff @ (posedge clk or negedge rst_n or negedge pll_lock)
    begin: dram_clock_logic
    if (!rst_n || !pll_lock) begin
        state <= IDLE;
        cycle_clk_counter <= 1'b0;
        dram_ras <= 1'b1;                       // RAS DEASSERT
        dram_cas <= 1'b1;                       // CAS DEASSERT
        dram_oe <= 1'b1;                        // OE DEASSERT
        dram_we <= 1'b1;                        // WE DEASSERT
        dram_addr <= 8'h00;
        result_ok <= 1'b0;
        result_fail <= 1'b0;
        reset_results_meta <= 1'b0;
        reset_results_sync <= 1'b0;
        test_read_meta <= 1'b0;
        test_read_sync <= 1'b0;
        test_read_sync_r <= 1'b0;
        test_write_meta <= 1'b0;
        test_write_sync <= 1'b0;
        test_write_sync_r <= 1'b0;
        test_in_progress_meta <= 1'b0;
        test_in_progress_sync <= 1'b0;
        row_address_latch <= 8'h00;
        col_address_latch <= 8'h00;
        test_data_latch <= 4'h0;
        dram_speed_sel_meta <= 2'b00;
        dram_speed_sel_sync <= 2'b00;
    end else begin
        state <= next_state;
        dram_ras <= next_dram_ras;
        dram_cas <= next_dram_cas;
        dram_oe <= next_dram_oe;
        dram_we <= next_dram_we;
        dram_addr <= next_dram_addr;

        row_address_latch <= next_row_address_latch;
        col_address_latch <= next_col_address_latch;
        test_data_latch <= next_test_data_latch;

        if (reset_results_sync) begin
            result_ok <= 1'b0;
            result_fail <= 1'b0;
        end else begin
            result_ok <= next_result_ok;
            result_fail <= next_result_fail;
        end

        if (state == READ || state == WRITE || state == WAIT_WR_TO_IDLE || state == WAIT_RD_TO_IDLE)
            cycle_clk_counter <= cycle_clk_counter + 1'b1;
        else
            cycle_clk_counter <= 0;

        // SYNC CDC SIGNALS

        reset_results_meta <= reset_results;    // SYNC RESET RESULTS CDC SIGNAL SYNCHRONIZER
        reset_results_sync <= reset_results_meta;

        test_read_meta <= test_read;            // SYNC TEST READ CDC SIGNAL SYNCHRONIZER
        test_read_sync <= test_read_meta;
        test_read_sync_r <= test_read_sync;            // REGISTER TO DETECT PULSE

        test_write_meta <= test_write;          // SYNC TEST WRITE CDC SIGNAL SYNCHRONIZER
        test_write_sync <= test_write_meta;
        test_write_sync_r <= test_write_sync;            // REGISTER TO DETECT PULSE

        test_in_progress_meta <= test_in_progress;    // SYNC TEST IN PROGRESS CDC SIGNAL SYNCHRONIZER
        test_in_progress_sync <= test_in_progress_meta;

        dram_speed_sel_meta <= dram_speed_sel;    // SYNC DRAM SPEED SELECT CDC SIGNAL SYNCHRONIZER
        dram_speed_sel_sync <= dram_speed_sel_meta;
    end
end

always_comb begin
    next_state = state;
                                               // INIT output states
    dram_io_chip_oe = 1'b1;                    // IO CHIP OE disabled
    dram_io_chip_dir = 1'b1;                   // IO CHIP DIR Tang -> dram
    dram_oe_we_ras_cas_chip_ce = 1'b0;         // CONTROL CHIP CE enabled
    dram_addr_chip_ce = 1'b0;                  // ADDR CHIP CE enabled

    fpga_dram_io_dir = 1'b0;                   // FPGA I/O is INPUT

    dram_power_sw = test_in_progress_sync;     // DRAM power on

    next_dram_ras = dram_ras;                  // KEEP RAS STATE
    next_dram_cas = dram_cas;                  // KEEP CAS STATE
    next_dram_oe  = dram_oe;                   // KEEP OE STATE
    next_dram_we  = dram_we;                   // KEEP WE STATE
    next_dram_addr = dram_addr;                // KEEP RAS STATE

    next_result_ok = result_ok;                // KEEP result state
    next_result_fail = result_fail;            // KEEP result state

    dram_io_out = 4'b0000;                     // DATA lines LOW

    oscilloscope_trigger = 1'b0;               // OSCILLOSCOPE TRIGGER LO

    next_row_address_latch = row_address_latch;    // KEEP LATCHED ROW ADDR
    next_col_address_latch = col_address_latch;    // KEEP LATCHED COL
    next_test_data_latch = test_data_latch;        // KEEP LATCHED TEST DATA

    dram_ready = 1'b0;

    case (state)
        IDLE: begin
            fpga_dram_io_dir = 1'b0;           // FPGA I/O is INPUT

            oscilloscope_trigger = 1'b0;       // OSCILLOSCOPE TRIGGER LO (standby)
            
            next_dram_ras = 1'b1;              // RAS DEASSERT
            next_dram_cas = 1'b1;              // CAS DEASSERT
            next_dram_oe = 1'b1;               // OE DEASSERT
            next_dram_we = 1'b1;               // WE DEASSERT

            next_dram_addr = 8'b00000000;      // ADDR 0x00
            dram_io_chip_oe = 1'b1;            // IO CHIP OE disabled
            
            dram_ready = 1'b1;

            if (test_read_pulse) next_state = READ;
            else if (test_write_pulse) next_state = WRITE;

            if (test_read_pulse || test_write_pulse) begin
                next_row_address_latch = row_address;    // LATCH ROW ADDR
                next_col_address_latch = col_address;    // LATCH COL ADDR
                next_test_data_latch = test_data;        // LATCH TEST DATA
                next_result_ok = 1'b0;                  // CLEAR previous result
                next_result_fail = 1'b0;
            end
        end

        READ: begin
            fpga_dram_io_dir = 1'b0;                                                // FPGA I/O is INPUT

            dram_io_chip_dir = 1'b0;                                                // IO CHIP DIR dram -> Tang
            dram_io_chip_oe = 1'b0;                                                 // IO CHIP OE enabled
            next_dram_we = 1'b1;                                                    // WE DEASSERT

            oscilloscope_trigger = 1'b1;                                            // OSCILLOSCOPE TRIGGER HI

            if (cycle_clk_counter == RAS_ASSERT) next_dram_ras = 1'b0;              // RAS logic start here
            if (cycle_clk_counter == RAS_DEASSERT) next_dram_ras = 1'b1;

            if (cycle_clk_counter == CAS_ASSERT) next_dram_cas = 1'b0;              // CAS logic start here
            if (cycle_clk_counter == CAS_DEASSERT) next_dram_cas = 1'b1;

            if (cycle_clk_counter == ROW_ADDR_SET) next_dram_addr = row_address_latch;    // ADDR logic start here
            if (cycle_clk_counter == COL_ADDR_SET) next_dram_addr = col_address_latch;    // ADDR logic start here

            if (cycle_clk_counter == READ_OE_ASSERT) next_dram_oe = 1'b0;           // OE assert
            if (cycle_clk_counter == READ_OE_DEASSERT) next_dram_oe = 1'b1;         // OE deassert


            if (cycle_clk_counter == READ_DATA) begin                               // READ DATA and compare
                if (dram_io_in == test_data_latch) begin
                    next_result_ok = 1'b1;                                          // TEST PASSED
                    next_result_fail = 1'b0;
                end else begin
                    next_result_ok = 1'b0;                                          // TEST FAILED
                    next_result_fail = 1'b1;
                end
            end

            if (cycle_clk_counter == READ_CYCLE_END) next_state = CLEANUPRD1;
        end

        WRITE: begin
            fpga_dram_io_dir = 1'b1;                                                // FPGA I/O is OUTPUT

            dram_io_chip_dir = 1'b1;                                                // IO CHIP DIR Tang -> dram
            dram_io_chip_oe = 1'b0;                                                 // IO CHIP OE enabled
            next_dram_oe = 1'b1;                                                    // OE DEASSERT

            dram_io_out = test_data_latch;                                          // TEST DATA

            oscilloscope_trigger = 1'b1;                                            // OSCILLOSCOPE TRIGGER HI

            if (cycle_clk_counter == RAS_ASSERT) next_dram_ras = 1'b0;              // RAS logic start here
            if (cycle_clk_counter == RAS_DEASSERT) next_dram_ras = 1'b1;

            if (cycle_clk_counter == CAS_ASSERT) next_dram_cas = 1'b0;              // CAS logic start here
            if (cycle_clk_counter == CAS_DEASSERT) next_dram_cas = 1'b1;

            if (cycle_clk_counter == ROW_ADDR_SET) next_dram_addr = row_address_latch;    // ADDR logic start here
            if (cycle_clk_counter == COL_ADDR_SET) next_dram_addr = col_address_latch;    // ADDR logic start here

            if (cycle_clk_counter == WRITE_WE_ASSERT) next_dram_we = 1'b0;           // OE assert
            if (cycle_clk_counter == WRITE_WE_DEASSERT) next_dram_we = 1'b1;         // OE deassert

            next_result_ok = 1'b1;                                                  // WRITE is considered successful if timing is met and signals are asserted correctly, no need to check data lines as it's a write operation
            next_result_fail = 1'b0;

            if (cycle_clk_counter == WRITE_CYCLE_END) next_state = CLEANUPWR1;
        end

        // NOTE:
        // Cleanup/write idle states are intentionally conservative.
        // They may be simplified later, but are left as-is because
        // current implementation is stable and timing margin is sufficient.

        CLEANUPWR1: begin
            fpga_dram_io_dir = 1'b1;                                                // FPGA I/O is OUTPUT

            dram_io_chip_dir = 1'b1;                                                // IO CHIP DIR Tang -> dram
            dram_io_chip_oe = 1'b0;                                                 // IO CHIP OE enabled
            dram_io_out = 4'b0000;                                                  // DATA lines LOW
            next_dram_addr = 8'b00000000;                                           // ADDR 0x00
            next_dram_ras = 1'b1;                                                   // RAS deassert
            next_dram_cas = 1'b1;                                                   // CAS deassert
            next_dram_we = 1'b1;                                                    // WE deassert
            next_dram_oe = 1'b1;                                                    // OE deassert
            next_state = WAIT_WR_TO_IDLE;
        end

        CLEANUPWR2: begin
            fpga_dram_io_dir = 1'b0;                                                // FPGA I/O is INPUT

            dram_io_chip_dir = 1'b0;                                                // IO CHIP DIR dram -> Tang
            dram_io_chip_oe = 1'b1;                                                 // IO CHIP OE disabled
            next_state = IDLE;
        end

        WAIT_WR_TO_IDLE: begin
            fpga_dram_io_dir = 1'b0;                                                // FPGA I/O is INPUT

            dram_io_chip_dir = 1'b1;                                                // IO CHIP DIR Tang -> dram
            dram_io_chip_oe = 1'b0;                                                 // IO CHIP OE enabled
            if (cycle_clk_counter == WAIT_CYCLES) next_state = CLEANUPWR2;
        end

        CLEANUPRD1: begin
            next_state = WAIT_RD_TO_IDLE;
        end

        WAIT_RD_TO_IDLE: begin
            if (cycle_clk_counter == WAIT_CYCLES) next_state = IDLE;
        end

    endcase
end

endmodule
