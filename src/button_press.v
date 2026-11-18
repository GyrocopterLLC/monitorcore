// Pushbutton short/long press detector
//
// Takes a raw active-low pushbutton input, synchronizes and debounces it,
// then drives:
//   SHORT_PRESS - pulse of BTN_HOLD_MS, starting on release, if the button
//                 was held less than LONG_MS
//   LONG_PRESS  - level: goes high once the button has been held for LONG_MS
//                 and stays high until the (debounced) release; no short
//                 pulse follows on release
//   BTN_HOLD_MS - duration of the SHORT_PRESS pulse

module button_press #(
    parameter CLK_FREQ    = 50_000_000,   // Hz
    parameter DEBOUNCE_MS = 20,
    parameter LONG_MS     = 1000,
    parameter BTN_HOLD_MS = 100
)(
    input       CLK,
    input       RESETN,
    input       BTN_N,          // raw button, active low
    output reg  SHORT_PRESS,    // BTN_HOLD_MS pulse after short press
    output reg  LONG_PRESS      // high while held past LONG_MS
);

localparam  DB_CYCLES   = CLK_FREQ / 1000 * DEBOUNCE_MS,
            LONG_CYCLES = CLK_FREQ / 1000 * LONG_MS,
            HOLD_CYCLES = CLK_FREQ / 1000 * BTN_HOLD_MS,
            DB_W        = $clog2(DB_CYCLES + 1),
            LONG_W      = $clog2(LONG_CYCLES + 1),
            HOLD_W      = $clog2(HOLD_CYCLES + 1);

// 2-flop synchronizer (idle high)
reg [1:0] sync = 2'b11;
always @(posedge CLK) sync <= {sync[0], BTN_N};
wire raw_pressed = ~sync[1];

// Debounce: accept a new state only after it is stable for DB_CYCLES
reg              pressed = 1'b0;
reg [DB_W-1:0]   db_cnt  = 0;

always @(posedge CLK) begin
    if (!RESETN) begin
        pressed <= 1'b0;
        db_cnt  <= 0;
    end else if (raw_pressed == pressed) begin
        db_cnt  <= 0;
    end else if (db_cnt == DB_CYCLES - 1) begin
        pressed <= raw_pressed;
        db_cnt  <= 0;
    end else begin
        db_cnt  <= db_cnt + 1'b1;
    end
end

// Hold timer / press classification
reg              pressed_d  = 1'b0;
reg              short_fired = 1'b0;
reg              long_fired = 1'b0;
reg [LONG_W-1:0] long_cnt   = 0;
reg [HOLD_W-1:0] hold_cnt   = 0;

always @(posedge CLK) begin
    short_fired <= 1'b0;
    pressed_d   <= pressed;

    if (!RESETN) begin
        pressed_d  <= 1'b0;
        long_fired <= 1'b0;
        LONG_PRESS <= 1'b0;
        long_cnt   <= 0;
    end else if (pressed) begin
        if (!long_fired) begin
            if (long_cnt == LONG_CYCLES - 1) begin
                LONG_PRESS <= 1'b1;
                long_fired <= 1'b1;
            end else begin
                long_cnt <= long_cnt + 1'b1;
            end
        end
    end else begin
        if (pressed_d && !long_fired)
            short_fired <= 1'b1;        // released before long threshold
        long_fired <= 1'b0;
        LONG_PRESS <= 1'b0;             // released: drop long-press level
        long_cnt   <= 0;
    end
end

always @(posedge CLK) begin
    if(!RESETN) begin
        SHORT_PRESS <= 1'b0;
        hold_cnt <= 0;
    end else begin
    
        if(short_fired) begin
            SHORT_PRESS <= 1'b1;
            hold_cnt <= 0;
        end else if(SHORT_PRESS) begin
            if (hold_cnt == HOLD_CYCLES - 1) begin
                SHORT_PRESS <= 1'b0;
            end else begin
                hold_cnt <= hold_cnt + 1'b1;
            end
        end
    end
end

endmodule
