module button_start #(
    parameter integer DEBOUNCE_MAX = 500_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire input_button,   // fizyczny przycisk, active-low
    output reg  start_action
);

    wire button_pressed;
    assign button_pressed = input_button;

    reg btn_meta, btn_sync;
    reg btn_stable, btn_stable_d;
    reg [$clog2(DEBOUNCE_MAX):0] debounce_cnt;

    // synchronizacja
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_meta <= 1'b0;
            btn_sync <= 1'b0;
        end else begin
            btn_meta <= button_pressed;
            btn_sync <= btn_meta;
        end
    end

    // debounce
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_stable   <= 1'b0;
            debounce_cnt <= 0;
        end else begin
            if (btn_sync == btn_stable) begin
                debounce_cnt <= 0;
            end else begin
                if (debounce_cnt == DEBOUNCE_MAX - 1) begin
                    btn_stable   <= btn_sync;
                    debounce_cnt <= 0;
                end else begin
                    debounce_cnt <= debounce_cnt + 1'b1;
                end
            end
        end
    end

    // poprzedni stan stabilny przycisku
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            btn_stable_d <= 1'b0;
        else
            btn_stable_d <= btn_stable;
    end

    // impuls 1 takt tylko przy nowym naciśnięciu
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            start_action <= 1'b0;
        else
            start_action <= btn_stable & ~btn_stable_d;
    end

endmodule