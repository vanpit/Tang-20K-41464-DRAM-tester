module uart_rx_wrapper(
    input logic                        clk,
    input logic                        rst_n,
    input logic                        uart_rx,
    output logic                       start_test,
    output logic                       uart_show_test_config,
    output logic                       uart_inc_repetitions,
    output logic                       uart_dec_repetitions,
    output logic                       uart_toggle_retention_test,
    output logic                       select_speed_00,
    output logic                       select_speed_01,
    output logic                       select_speed_10,
    output logic                       select_speed_11
);

parameter int                          CLK_FRE  = 27;          // Mhz
parameter int                          BAUD_RATE = 115200;     // Mhz

logic [7:0] rx_data;
logic rx_data_valid;
logic rx_data_ready;
logic next_start_test;
logic next_uart_show_test_config;
logic next_uart_inc_repetitions;
logic next_uart_dec_repetitions;
logic next_uart_toggle_retention_test;
logic next_select_speed_00;
logic next_select_speed_01;
logic next_select_speed_10;
logic next_select_speed_11;

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
        rx_data_ready <= 1'b0; // always ready to receive data
	end
	else begin
        rx_data_ready <= 1'b1; // always ready to receive data
        start_test <= next_start_test;
        uart_show_test_config <= next_uart_show_test_config;
        uart_inc_repetitions <= next_uart_inc_repetitions;
        uart_dec_repetitions <= next_uart_dec_repetitions;
        uart_toggle_retention_test <= next_uart_toggle_retention_test;
        select_speed_00 <= next_select_speed_00;
        select_speed_01 <= next_select_speed_01;
        select_speed_10 <= next_select_speed_10;
        select_speed_11 <= next_select_speed_11;
    end
end

always_comb begin
    // For now, just print the received data to the console
    next_start_test = 1'b0;
    next_uart_show_test_config = 1'b0;
    next_uart_inc_repetitions = 1'b0;
    next_uart_dec_repetitions = 1'b0;
    next_uart_toggle_retention_test = 1'b0;
    next_select_speed_00 = 1'b0;
    next_select_speed_01 = 1'b0;
    next_select_speed_10 = 1'b0;
    next_select_speed_11 = 1'b0;

    if (rx_data_valid) begin
        case (rx_data)
            "R", "r": next_start_test = 1'b1; // 'R' or 'r' to start the test
            "C", "c": next_uart_show_test_config = 1'b1; // 'C' or 'c' to show test config
            "q": next_uart_inc_repetitions = 1'b1; // 'q' to increase repetitions
            "Q": next_uart_dec_repetitions = 1'b1; // 'Q' to decrease repetitions
            "W", "w": next_uart_toggle_retention_test = 1'b1; // 'W' or 'w' to toggle retention test
            "1": begin
                next_select_speed_00 = 1'b1;
                next_select_speed_01 = 1'b0;
                next_select_speed_10 = 1'b0;
                next_select_speed_11 = 1'b0;
            end
            "2": begin
                next_select_speed_00 = 1'b0;
                next_select_speed_01 = 1'b1;
                next_select_speed_10 = 1'b0;
                next_select_speed_11 = 1'b0;
            end
            "3": begin
                next_select_speed_00 = 1'b0;
                next_select_speed_01 = 1'b0;
                next_select_speed_10 = 1'b1;
                next_select_speed_11 = 1'b0;
            end
            "4": begin
                next_select_speed_00 = 1'b0;
                next_select_speed_01 = 1'b0;
                next_select_speed_10 = 1'b0;
                next_select_speed_11 = 1'b1;
            end
            default: ;
        endcase
    end
end

uart_rx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(BAUD_RATE)
) uart_rx_inst
(
	.clk                        (clk                      ),
	.rst_n                      (rst_n                    ),
	.rx_data                    (rx_data                  ),
	.rx_data_valid              (rx_data_valid            ),
	.rx_data_ready              (rx_data_ready            ),
	.rx_pin                     (uart_rx                  )
);

endmodule