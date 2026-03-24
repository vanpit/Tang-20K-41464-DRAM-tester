module uart_tx_wrapper(
    input logic                        clk,
    input logic                        rst_n,
    output logic                       uart_tx,
    input logic                        start_send,
    input logic[7:0]                   display_option,
    input logic[15:0]                  fail_address,
    input logic                        fail_test,               // 0 - pattern, 1 - MATS+
    input logic[1:0]                   dram_timing_selector,
    input logic[15:0]                  uart_repetition_counter,
    input logic[15:0]                  uart_repetition_progress,
    input logic                        use_retention_test_selector,
    output logic                       uart_tx_busy
);

parameter int                          CLK_FRE  = 27;          // Mhz
parameter int                          BAUD_RATE = 115200;     // Mhz

import uart_tx_opts_pkg::*;

logic[7:0]                       tx_data;
logic[7:0]                       next_tx_data;
logic[7:0]                       tx_str;
logic                            tx_data_valid;
logic                            next_tx_data_valid;
wire                             tx_data_ready;
logic[7:0]                       tx_cnt;
logic[7:0]                       next_tx_cnt;
logic                            start_send_r;

localparam logic [7:0] EXAMPLE_TX_STR = 8'h54;

localparam MSG_RUNNING_LEN = 17;
localparam [MSG_RUNNING_LEN * 8 - 1:0] msg_running = {"Test started...", 16'h0d0a};

localparam MSG_PASS_LEN = 18;
localparam [MSG_PASS_LEN * 8 - 1:0] msg_pass = {16'h0d0a, "Result: PASSED", 16'h0d0a};

localparam MSG_FAIL_LEN = 32;
localparam [MSG_FAIL_LEN * 8 - 1:0] msg_fail = {16'h0d0a, "Result: FAILED ???? @ 0x????", 16'h0d0a};

localparam MSG_CONFIG_LEN = 65;
localparam [MSG_CONFIG_LEN * 8 - 1:0] msg_config = {"Test profile: ??0 ns | Repetitions: 0x???? | Retention test: ?", 16'h0d0a};

localparam MSG_PROGRESS_LEN = 18;
localparam [MSG_PROGRESS_LEN * 8 - 1:0] msg_progress = {"Progress: 0x????", 16'h0d};

typedef enum logic [1:0] {
    IDLE,
    SEND
} uartstate_t;

uartstate_t uart_state;
uartstate_t next_uart_state;

logic start_send_pulse;
assign start_send_pulse = start_send & ~start_send_r;

logic [7:0] display_option_latched, next_display_option_latched;
logic [15:0] fail_address_latched, next_fail_address_latched;
logic fail_test_latched, next_fail_test_latched;

assign uart_tx_busy = (uart_state != IDLE);

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
        uart_state <= IDLE;
        tx_data <= 8'd0;
        tx_data_valid <= 1'b0;
        tx_cnt <= 8'd0;
        start_send_r <= 1'b0;
        display_option_latched <= 8'd0;
        fail_address_latched <= 16'd0;
        fail_test_latched <= 1'b0;
	end
	else begin
        tx_data_valid <= next_tx_data_valid;
        tx_data <= next_tx_data;
        tx_cnt <= next_tx_cnt;
        uart_state <= next_uart_state;
        start_send_r <= start_send;
        display_option_latched <= next_display_option_latched;
        fail_address_latched <= next_fail_address_latched;
        fail_test_latched <= next_fail_test_latched;
    end
end

always_comb begin
    next_uart_state = uart_state;
    next_tx_data_valid = 1'b0;
    next_tx_data = tx_data;
    next_tx_cnt = tx_cnt;
    next_display_option_latched = display_option_latched;
    next_fail_address_latched = fail_address_latched;
    next_fail_test_latched = fail_test_latched;

    case(uart_state)
        IDLE: begin
            if(start_send_pulse) begin
                next_display_option_latched = display_option;
                next_fail_address_latched = fail_address;
                next_fail_test_latched = fail_test;
                next_tx_cnt = get_str_size(display_option);
                next_tx_data = get_char(display_option, next_tx_cnt);
                next_tx_data_valid = 1'b1;
                next_uart_state = SEND;
            end
        end

        SEND: begin
            if (tx_data_valid && tx_data_ready) begin
                if (tx_cnt > 8'd1) begin
                    next_tx_cnt = tx_cnt - 8'd1;
                    next_tx_data = get_char(display_option_latched, tx_cnt - 8'd1);
                    next_tx_data_valid = 1'b1;
                    next_uart_state = SEND;
                end else begin
                    next_tx_cnt = 8'd0;
                    next_tx_data_valid = 1'b0;
                    next_uart_state = IDLE;
                end
            end else begin
                next_tx_data_valid = 1'b1;
            end
        end
    endcase
end

function automatic logic [7:0] get_char(
    input logic [7:0] opt,
    input logic [7:0] idx
);
    begin
        case (opt)
            DISP_OPT_MSG_RUNNING: get_char = msg_running[(idx-1)*8 +: 8];
            DISP_OPT_MSG_PASS:    get_char = msg_pass[(idx-1)*8 +: 8];
            DISP_OPT_MSG_FAIL:    begin
                case (idx)
                    15: get_char = fail_test_latched ? "M" : "P"; // 'M' for MATS+ failure, 'P' for pattern test failure
                    14: get_char = fail_test_latched ? "A" : "T"; // 'A' for MATS+ failure, 'T' for pattern test failure
                    13: get_char = fail_test_latched ? "T" : "R"; // 'T' for MATS+ failure, 'R' for pattern test failure
                    12: get_char = fail_test_latched ? "S" : "N"; // 'S' for MATS+ failure, 'N' for pattern test failure
                    6: get_char = hex_to_ascii(fail_address_latched[15:12]);
                    5: get_char = hex_to_ascii(fail_address_latched[11:8]);
                    4: get_char = hex_to_ascii(fail_address_latched[7:4]);
                    3: get_char = hex_to_ascii(fail_address_latched[3:0]);
                    default: get_char = msg_fail[(idx-1)*8 +: 8];
                endcase
            end
            DISP_OPT_MSG_CONFIG:  begin
                case (idx)
                    50: begin
                        case (dram_timing_selector)
                            2'b00: get_char = " ";
                            2'b01: get_char = "1";
                            2'b10: get_char = "1";
                            2'b11: get_char = "1";
                            default: get_char = "?";
                        endcase
                    end
                    49: begin
                        case (dram_timing_selector)
                            2'b00: get_char = "8";
                            2'b01: get_char = "0";
                            2'b10: get_char = "2";
                            2'b11: get_char = "5";
                            default: get_char = "?";
                        endcase
                    end
                    26: get_char = hex_to_ascii(uart_repetition_counter[15:12]);
                    25: get_char = hex_to_ascii(uart_repetition_counter[11:8]);
                    24: get_char = hex_to_ascii(uart_repetition_counter[7:4]);
                    23: get_char = hex_to_ascii(uart_repetition_counter[3:0]);
                    3: get_char = use_retention_test_selector ? "Y" : "N";
                    default: get_char = msg_config[(idx-1)*8 +: 8];
                endcase
            end
            DISP_OPT_MSG_PROGRESS: begin
                case (idx)
                    6: get_char = hex_to_ascii(uart_repetition_progress[15:12]);
                    5: get_char = hex_to_ascii(uart_repetition_progress[11:8]);
                    4: get_char = hex_to_ascii(uart_repetition_progress[7:4]);
                    3: get_char = hex_to_ascii(uart_repetition_progress[3:0]);
                    default: get_char = msg_progress[(idx-1)*8 +: 8];
                endcase
            end
            default:                get_char = EXAMPLE_TX_STR;
        endcase
    end
endfunction

function automatic logic [7:0] get_str_size(
    input logic [7:0] opt
);
    begin
        case (opt)
            DISP_OPT_MSG_RUNNING:  get_str_size = MSG_RUNNING_LEN;
            DISP_OPT_MSG_PASS:     get_str_size = MSG_PASS_LEN;
            DISP_OPT_MSG_FAIL:     get_str_size = MSG_FAIL_LEN;
            DISP_OPT_MSG_CONFIG:   get_str_size = MSG_CONFIG_LEN;
            DISP_OPT_MSG_PROGRESS: get_str_size = MSG_PROGRESS_LEN;
            default:               get_str_size = 8'd1;
        endcase
    end
endfunction

function automatic logic [7:0] hex_to_ascii(input logic [3:0] nibble);
begin
    if (nibble < 10)
        hex_to_ascii = "0" + nibble;
    else
        hex_to_ascii = "A" + nibble - 10;
end
endfunction

uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(BAUD_RATE)
) uart_tx_inst
(
	.clk                        (clk                      ),
	.rst_n                      (rst_n                    ),
	.tx_data                    (tx_data                  ),
	.tx_data_valid              (tx_data_valid            ),
	.tx_data_ready              (tx_data_ready            ),
	.tx_pin                     (uart_tx                  )
);

endmodule