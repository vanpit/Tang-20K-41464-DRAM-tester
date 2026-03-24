module main (
    input wire clk,
    input wire input_button,
    output logic oscilloscope_trigger,
    output logic uart_tx,
    input logic uart_rx,
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
    output logic led_ok,
    output logic led_fail,
    output logic led_ready
);

import uart_tx_opts_pkg::*;

logic rst_n;
logic [7:0] rst_cnt = '0;

logic clk_dramroutines;
logic pll_lock;

wire btn_start_test;
wire dram_ready;

wire result_ok;
wire result_fail;

localparam logic [15:0] START_TEST_ADDRESS = 16'h0000;                                // test start address
localparam logic [15:0] DRAM_LAST_CELL = 256 * 256 - 1;                               // last DRAM CELL is 256x256 DRAM size minus ONE
//localparam logic [15:0] DRAM_LAST_CELL = START_TEST_ADDRESS + 9 ;                   // last DRAM CELL is 256x256 DRAM size minus ONE

logic [15:0] dram_cell_address;
logic [7:0] row_address;
logic [7:0] col_address;

logic [15:0] dram_cell_linear_counter;
logic [15:0] next_dram_cell_linear_counter;

localparam logic [15:0] ADDR_SEED = 16'h0000;
localparam logic [15:0] ADDR_STEP = 16'h9E37; // musi być nieparzysty

logic test_mode_mats;
logic next_test_mode_mats;
logic [1:0] mats_phase;
logic [1:0] next_mats_phase;

//assign dram_cell_address = dram_cell_linear_counter;
assign dram_cell_address = test_mode_mats
                         ? dram_cell_linear_counter
                         : (ADDR_SEED + dram_cell_linear_counter * ADDR_STEP);

assign row_address = dram_cell_address[15:8];
assign col_address = dram_cell_address[7:0];
logic [7:0] row_address_latch;
logic [7:0] col_address_latch;
logic [7:0] next_row_address_latch;
logic [7:0] next_col_address_latch;

localparam logic [19:0] RETENTION_COUNTER_CYCLES_4MS = 33000 * 4; // 4ms retention interval at 33MHz clock

logic [15:0] warmup_counter;
logic [19:0] retention_test_counter;
logic [19:0] next_retention_test_counter;
logic [3:0] test_data;
logic [3:0] test_data_latch;
logic [3:0] next_test_data_latch;

logic test_read;
logic test_write;
logic test_in_progress;
logic test_completed;

logic next_test_read;
logic next_test_write;
logic next_test_completed;

logic display_result_ok;
logic display_result_fail;
logic reset_results;

logic [2:0] test_pattern_counter;

logic [2:0] next_test_pattern_counter;

logic dram_ready_sync_r;
logic dram_op_pending;
logic next_dram_op_pending;

logic start_test_sequence;

logic result_ok_meta;
logic result_ok_sync;

logic result_fail_meta;
logic result_fail_sync;

logic dram_ready_meta;
logic dram_ready_sync;

logic uart_start_send;
logic [7:0] display_option;

logic uart_tx_busy;

logic [15:0] fail_address;
logic [15:0] next_fail_address;
logic fail_test; // 0 - pattern test fail, 1 - MATS+ test fail
logic next_fail_test; 

wire uart_start_test;
wire uart_show_test_config;
wire uart_inc_repetitions;
wire uart_dec_repetitions;
wire uart_toggle_retention_test;
wire uart_select_speed_00;
wire uart_select_speed_01;
wire uart_select_speed_10;
wire uart_select_speed_11;

logic [1:0] dram_speed_sel, dram_timing_selector;

logic [15:0] repetition_counter;
logic [15:0] next_repetition_counter;
logic [15:0] repetition_counter_selector;

logic use_retention_test;
logic use_retention_test_selector;

logic cycle_completed_pulse;

typedef enum logic [3:0] {
    INIT,
    READ_OP_START,
    READ_OP_COMPLETED,
    WRITE_OP_START,
    WRITE_OP_COMPLETED,
    SWITCH_PATTERN,
    TEST_COMPLETED,
    TEST_FAILED,
    STANDBY
} teststage_t;

teststage_t test_stage;
teststage_t next_test_stage;

localparam logic [3:0] TEST_PATTERNS [0:7] = '{
    4'b0101,
    4'b1010,
    4'b0011,
    4'b1100,
    4'b0110,
    4'b1001,
    4'b1111,
    4'b0000
};

assign test_data =
    dram_cell_address[3:0] ^
    dram_cell_address[7:4] ^
    dram_cell_address[11:8] ^
    dram_cell_address[15:12] ^
    TEST_PATTERNS[test_pattern_counter];

always_ff @(posedge clk)
begin: initresetlogic
    if (rst_cnt == 8'h00)
    begin
        rst_n <= 1'b0;
        rst_cnt <= rst_cnt + 1;
    end else if (rst_cnt == 8'hFF) begin
        rst_n <= 1'b1;
        led_ready <= 1'b0;
    end else begin
        rst_cnt <= rst_cnt + 1'b1;
    end
end


always_ff @(posedge clk or negedge rst_n or negedge pll_lock)
begin: dramsweep
        if (!rst_n || !pll_lock) begin
            reset_results <= 1'b0;
            test_read <= 1'b0;
            test_write <= 1'b0;
            test_in_progress <= 1'b0;
            dram_cell_linear_counter <= 16'h0000;
            display_result_ok <= 1'b0;
            display_result_fail <= 1'b0;
            test_completed <= 1'b0;
            warmup_counter <= 16'h0000;
            test_pattern_counter <= 3'b000;
            dram_op_pending <= 1'b0;
            dram_ready_meta <= 1'b0;
            dram_ready_sync <= 1'b0;
            dram_ready_sync_r <= 1'b0;
            start_test_sequence <= 1'b0;
            result_ok_meta <= 1'b0;
            result_ok_sync <= 1'b0;
            result_fail_meta <= 1'b0;
            result_fail_sync <= 1'b0;
            row_address_latch <= 8'h00;
            col_address_latch <= 8'h00;
            test_data_latch <= 4'h0;
            uart_start_send <= 1'b0;
            dram_speed_sel <= 2'b00;
            dram_timing_selector <= 2'b00;
            repetition_counter <= 16'h0000;
            repetition_counter_selector <= 16'h0000;
            use_retention_test_selector <= 1'b1;
            use_retention_test <= 1'b1;
            retention_test_counter <= 20'h00000;
            display_option <= 8'h00;
            fail_address <= 16'h0000;
            fail_test <= 1'b0;
            test_mode_mats <= 1'b0;
            mats_phase <= 2'b00;
            test_stage <= STANDBY;

        end else begin

            dram_cell_linear_counter <= next_dram_cell_linear_counter;
            test_stage <= next_test_stage;
            test_write <= next_test_write;
            test_read <= next_test_read;
            test_completed <= next_test_completed;
            dram_op_pending <= next_dram_op_pending;
            test_pattern_counter <= next_test_pattern_counter;
            row_address_latch <= next_row_address_latch;
            col_address_latch <= next_col_address_latch;
            test_data_latch <= next_test_data_latch;
            repetition_counter <= next_repetition_counter;
            retention_test_counter <= next_retention_test_counter;
            uart_start_send <= 1'b0;
            test_mode_mats <= next_test_mode_mats;
            mats_phase <= next_mats_phase;
            fail_address <= next_fail_address;
            fail_test <= next_fail_test;

            start_test_sequence <= 1'b0;

            dram_ready_sync_r <= dram_ready_sync;                                              // SYNC DRAM READY SIGNAL DELAY REGISTER
            if (dram_ready_sync & ~dram_ready_sync_r) dram_op_pending <= 1'b0;                 // dram operation in progress indicator
            
            if (!result_fail_sync && !result_ok_sync) reset_results <= 1'b0;

            if (cycle_completed_pulse) begin

                display_option <= DISP_OPT_MSG_PROGRESS;
                uart_start_send <= 1'b1;

            end else if (uart_toggle_retention_test && !test_in_progress) begin

                use_retention_test_selector <= ~use_retention_test_selector;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_select_speed_00 && !test_in_progress) begin

                dram_timing_selector <= 2'b00; // Cycle through DRAM speed settings on each config request
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_select_speed_01 && !test_in_progress) begin

                dram_timing_selector <= 2'b01;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_select_speed_10 && !test_in_progress) begin

                dram_timing_selector <= 2'b10;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_select_speed_11 && !test_in_progress) begin

                dram_timing_selector <= 2'b11;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_inc_repetitions && !test_in_progress) begin

                if (repetition_counter_selector < 16'h00FF) repetition_counter_selector <= repetition_counter_selector + 16'h0011;
                else if (repetition_counter_selector < 16'hFFFF) repetition_counter_selector <= repetition_counter_selector + 16'h0100;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_dec_repetitions && !test_in_progress) begin

                if (repetition_counter_selector > 16'h00FF) repetition_counter_selector <= repetition_counter_selector - 16'h0100;
                else if (repetition_counter_selector > 16'h0000) repetition_counter_selector <= repetition_counter_selector - 16'h0011;
                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested

            end else if (uart_show_test_config && !test_in_progress) begin

                display_option <= DISP_OPT_MSG_CONFIG; // Set display option to "Config" when config is requested
                uart_start_send <= 1'b1; // Start UART transmission when config is requested                

            end else if ((btn_start_test || uart_start_test) && !test_in_progress) begin

                warmup_counter <= 16'hFFFF;
                test_in_progress <= 1'b1;
                start_test_sequence <= 1'b1;

                dram_speed_sel <= dram_timing_selector;
                repetition_counter <= repetition_counter_selector;
                use_retention_test <= use_retention_test_selector;

                display_option <= DISP_OPT_MSG_RUNNING; // Set display option to "Running" when test starts
                uart_start_send <= 1'b1; // Start UART transmission when test starts

            end else if (test_in_progress) begin

                if (warmup_counter > 1'b0) warmup_counter <= warmup_counter - 1'b1;

                if (result_fail_sync && !uart_tx_busy) begin

                    display_result_ok <= 1'b0;
                    display_result_fail <= 1'b1;
                    reset_results <= 1'b1;
                    test_in_progress <= 1'b0;
                    display_option <= DISP_OPT_MSG_FAIL; // Set display option to "Fail" when test fails
                    uart_start_send <= 1'b1; // Start UART transmission when test fails

                end else if (test_completed && result_ok_sync && !uart_tx_busy) begin

                    display_result_ok <= 1'b1;
                    display_result_fail <= 1'b0;
                    reset_results <= 1'b1;
                    test_in_progress <= 1'b0;
                    display_option <= DISP_OPT_MSG_PASS; // Set display option to "Pass" when test passes
                    uart_start_send <= 1'b1; // Start UART transmission when test passes

                end else begin

                    if (repetition_counter > 16'h0000) begin
                        display_result_ok <= repetition_counter[0];
                        display_result_fail <= !repetition_counter[0];
                    end else begin
                        display_result_ok <= 1'b1;
                        display_result_fail <= 1'b1;
                    end

                end

            end

            // SYNC CDC SIGNALS

            result_ok_meta <= result_ok;                    // SYNC RESULT OK CDC SIGNAL SYNCHRONIZER
            result_ok_sync <= result_ok_meta;

            result_fail_meta <= result_fail;                // SYNC RESULT FAIL CDC SIGNAL SYNCHRONIZER
            result_fail_sync <= result_fail_meta;

            dram_ready_meta <= dram_ready;                  // SYNC DRAM READY CDC SIGNAL SYNCHRONIZER
            dram_ready_sync <= dram_ready_meta;

        end
end

always_comb begin

    next_test_completed = test_completed;
    next_test_stage = test_stage;
    next_dram_op_pending = dram_op_pending;
    next_dram_cell_linear_counter = dram_cell_linear_counter;
    next_test_pattern_counter = test_pattern_counter;
    next_row_address_latch = row_address_latch;
    next_col_address_latch = col_address_latch;
    next_test_data_latch = test_data_latch;
    next_repetition_counter = repetition_counter;
    next_test_mode_mats = test_mode_mats;
    next_mats_phase = mats_phase;

    if (retention_test_counter > 20'h00000) begin
        next_retention_test_counter = retention_test_counter - 1'b1;
    end else begin
        next_retention_test_counter = 20'h00000;
    end

    cycle_completed_pulse = 1'b0;

    next_test_read = test_read;
    next_test_write = test_write;

    if (!dram_ready_sync) begin
        next_test_read = 1'b0;
        next_test_write = 1'b0;
    end

    if (start_test_sequence) next_test_stage = INIT;

    if (test_in_progress && result_fail_sync) begin
        next_fail_address = dram_cell_address;
        next_fail_test = test_mode_mats;
        next_test_stage = TEST_FAILED;
    end else begin
        next_fail_address = fail_address;
        next_fail_test = fail_test;
    end

    if (test_in_progress && !dram_op_pending && warmup_counter == 16'h0000 && retention_test_counter == 20'h00000 && !uart_tx_busy) begin

        case (test_stage)

            INIT: begin

                next_test_completed = 1'b0;
                next_dram_cell_linear_counter  = START_TEST_ADDRESS;
                next_test_pattern_counter = 3'b000;
                next_test_mode_mats = 1'b0;
                next_mats_phase = 2'b00;
                next_test_stage = WRITE_OP_START;

            end

            WRITE_OP_START: begin

                next_row_address_latch = row_address;
                next_col_address_latch = col_address;
                
                if (!test_mode_mats) begin
                    next_test_data_latch = test_data;
                end else begin
                    case (mats_phase)
                        2'b00: next_test_data_latch = 4'b0000; // fill 0
                        2'b01: next_test_data_latch = 4'b1111; // write 1
                        2'b10: next_test_data_latch = 4'b0000; // write 0
                        default: next_test_data_latch = 4'b0000;
                    endcase
                end

                next_test_write = 1'b1;
                next_dram_op_pending = 1'b1;
                next_test_stage = WRITE_OP_COMPLETED;

            end

            WRITE_OP_COMPLETED: begin

                if (!test_mode_mats) begin
                    if (dram_cell_linear_counter < DRAM_LAST_CELL) begin
                        next_dram_cell_linear_counter = dram_cell_linear_counter + 16'd1;
                        next_test_stage = WRITE_OP_START;
                    end else begin
                        if (use_retention_test) next_retention_test_counter = RETENTION_COUNTER_CYCLES_4MS;
                        next_dram_cell_linear_counter = START_TEST_ADDRESS;
                        next_test_stage = READ_OP_START;
                    end
                end else begin
                    case (mats_phase)

                        // phase 0: fill 0 all, go UP
                        2'b00: begin
                            if (dram_cell_linear_counter < DRAM_LAST_CELL) begin
                                next_dram_cell_linear_counter = dram_cell_linear_counter + 16'd1;
                                next_test_stage = WRITE_OP_START;
                            end else begin
                                next_dram_cell_linear_counter = START_TEST_ADDRESS;
                                next_mats_phase = 2'b01;
                                next_test_stage = READ_OP_START;
                            end
                        end

                        // phase 1: after read0, write1, continue UP
                        2'b01: begin
                            if (dram_cell_linear_counter < DRAM_LAST_CELL) begin
                                next_dram_cell_linear_counter = dram_cell_linear_counter + 16'd1;
                                next_test_stage = READ_OP_START;
                            end else begin
                                next_dram_cell_linear_counter = DRAM_LAST_CELL;
                                next_mats_phase = 2'b10;
                                next_test_stage = READ_OP_START;
                            end
                        end

                        // phase 2: after read1, write0, continue DOWN
                        2'b10: begin
                            if (dram_cell_linear_counter > 16'd0) begin
                                next_dram_cell_linear_counter = dram_cell_linear_counter - 16'd1;
                                next_test_stage = READ_OP_START;
                            end else begin
                                next_test_mode_mats = 1'b0;
                                next_mats_phase = 2'b00;

                                if (repetition_counter > 16'h0000) begin
                                    next_repetition_counter = repetition_counter - 16'd1;
                                    next_dram_cell_linear_counter = START_TEST_ADDRESS;
                                    next_test_pattern_counter = 3'b000;
                                    next_test_stage = WRITE_OP_START;
                                    cycle_completed_pulse = 1'b1;
                                end else begin
                                    next_test_stage = TEST_COMPLETED;
                                end
                            end
                        end

                        default: begin
                            next_test_stage = TEST_FAILED;
                        end
                    endcase
                end
            end
            
            READ_OP_START: begin
                next_row_address_latch = row_address;
                next_col_address_latch = col_address;

                if (!test_mode_mats) begin
                    next_test_data_latch = test_data;
                end else begin
                    case (mats_phase)
                        2'b01: next_test_data_latch = 4'b0000; // read 0
                        2'b10: next_test_data_latch = 4'b1111; // read 1
                        default: next_test_data_latch = 4'b0000;
                    endcase
                end

                next_test_read = 1'b1;
                next_dram_op_pending = 1'b1;
                next_test_stage = READ_OP_COMPLETED;
            end

            READ_OP_COMPLETED: begin

                if (!test_mode_mats) begin
                    if (dram_cell_linear_counter < DRAM_LAST_CELL) begin
                        next_dram_cell_linear_counter = dram_cell_linear_counter + 16'd1;
                        next_test_stage = READ_OP_START;
                    end else begin
                        next_dram_cell_linear_counter = START_TEST_ADDRESS;
                        next_test_stage = SWITCH_PATTERN;
                    end
                end else begin
                    case (mats_phase)
                        2'b01: begin
                            // read 0 passed, now write 1
                            next_test_stage = WRITE_OP_START;
                        end

                        2'b10: begin
                            // read 1 passed, now write 0
                            next_test_stage = WRITE_OP_START;
                        end

                        default: begin
                            next_test_stage = TEST_FAILED;
                        end
                    endcase
                end
            end

            SWITCH_PATTERN: begin

                if (next_test_pattern_counter < 3'h7) begin
                    next_test_pattern_counter = next_test_pattern_counter + 1'b1;
                    next_test_stage = WRITE_OP_START;
                end else begin
                    next_test_pattern_counter = 3'h0;

                    // start MATS+
                    next_test_mode_mats = 1'b1;
                    next_mats_phase = 2'b00;
                    next_dram_cell_linear_counter = START_TEST_ADDRESS;
                    next_test_pattern_counter = 3'b000;
                    next_test_stage = WRITE_OP_START;
                end
            end

            TEST_COMPLETED: begin

                next_test_completed = 1'b1;
                next_test_stage = STANDBY;

            end

            TEST_FAILED: begin

                next_test_completed = 1'b1;
                next_test_stage = STANDBY;

            end

            STANDBY: begin
                next_test_completed = 1'b0;
            end

        endcase

    end

end

assign led_ok   = ~display_result_ok;
assign led_fail = ~display_result_fail;

button_start #(
    .DEBOUNCE_MAX(500_000)
) button_start_inst (
    .clk                            (clk                                ),
    .rst_n                          (rst_n                              ),
    .input_button                   (input_button                       ),
    .start_action                   (btn_start_test                     )
);

uart_rx_wrapper #(
    .CLK_FRE                        (33                                 ),
    .BAUD_RATE                      (115200                             )
) uart_rx_wrapper_inst (
    .clk                            (clk                                ),
    .rst_n                          (rst_n                              ),
    .uart_rx                        (uart_rx                            ),
    .start_test                     (uart_start_test                    ),
    .uart_show_test_config          (uart_show_test_config              ),
    .uart_inc_repetitions           (uart_inc_repetitions               ),
    .uart_dec_repetitions           (uart_dec_repetitions               ),
    .uart_toggle_retention_test     (uart_toggle_retention_test         ),
    .select_speed_00                (uart_select_speed_00               ),
    .select_speed_01                (uart_select_speed_01               ),
    .select_speed_10                (uart_select_speed_10               ),
    .select_speed_11                (uart_select_speed_11               )
);

uart_tx_wrapper #(
    .CLK_FRE                        (33                                 ),
    .BAUD_RATE                      (115200                             )
) uart_tx_wrapper_inst (
    .clk                            (clk                                ),
    .rst_n                          (rst_n                              ),
    .uart_tx                        (uart_tx                            ),
    .start_send                     (uart_start_send                    ),
    .display_option                 (display_option                     ),
    .fail_address                   (fail_address                       ),
    .fail_test                      (fail_test                          ), // 0 - pattern test fail, 1 - MATS+ test fail
    .dram_timing_selector           (dram_timing_selector               ),
    .uart_repetition_counter        (repetition_counter_selector        ),
    .uart_repetition_progress       (repetition_counter                 ),
    .use_retention_test_selector    (use_retention_test_selector        ),
    .uart_tx_busy                   (uart_tx_busy                       )
);

dramroutines dramroutines_inst
(
    .clk                            (clk_dramroutines                   ),
    .rst_n                          (rst_n                              ),
    .oscilloscope_trigger           (oscilloscope_trigger               ),
    .dram_power_sw                  (dram_power_sw                      ),
    .dram_io                        (dram_io                            ),
    .dram_io_chip_oe                (dram_io_chip_oe                    ),
    .dram_io_chip_dir               (dram_io_chip_dir                   ),
    .dram_oe                        (dram_oe                            ),
    .dram_we                        (dram_we                            ),
    .dram_ras                       (dram_ras                           ),
    .dram_cas                       (dram_cas                           ),
    .dram_oe_we_ras_cas_chip_ce     (dram_oe_we_ras_cas_chip_ce         ),
    .dram_addr                      (dram_addr                          ),
    .dram_addr_chip_ce              (dram_addr_chip_ce                  ),
    .test_write                     (test_write                         ),
    .test_read                      (test_read                          ),
    .result_ok                      (result_ok                          ),
    .result_fail                    (result_fail                        ),
    .dram_ready                     (dram_ready                         ),
    .row_address                    (row_address_latch                  ),
    .col_address                    (col_address_latch                  ),
    .test_data                      (test_data_latch                    ),
    .reset_results                  (reset_results                      ),
    .test_in_progress               (test_in_progress                   ),
    .dram_speed_sel                 (dram_speed_sel                     ),
    .pll_lock                       (pll_lock                           )
);

Gowin_rPLL your_instance_name(
    .clkout                         (clk_dramroutines                   ),                     // output clkout
    .lock                           (pll_lock                           ),                     // output lock
    .clkin                          (clk                                )                      // input clkin
);

endmodule