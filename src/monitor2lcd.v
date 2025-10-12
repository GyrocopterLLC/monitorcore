// Convert monitor video output to 800x480 40pin LCD

// `timescale 1ns / 1ps

module monitor2lcd(
    // input           CLK, // snes clock, ~21.5 MHz
    input           RESETN,

    // input           DOTCLK, // roughly CLK / 4
    // input           HDE,
    // input           VDE,
    // input [14:0]    RGB5,
    // input [8:0]     XS, // {OUT_X[7:0], DOTCLK}
    // input [8:0]     YS, // {FIELD, OUT_Y[7:0]}

    input           LCD_PIXELCLK, // 800x480 lcd pixel clock, ~31.2 MHz
    output          LCD_VSYNC,
    output          LCD_HSYNC,
    output          LCD_DE,
    output [23:0]   LCD_DATA,

    input           OVERLAY,
    output [7:0]    OVERLAY_X,
    output [7:0]    OVERLAY_Y,
    input [14:0]    OVERLAY_COLOR
);

localparam  SNES_H =        256,
            SNES_V =        224,
            SNES_HMAX =     SNES_H-1,
            SNES_VMAX =     SNES_V-1,

            LCD_H =         800,
            LCD_HPW =       48,
            LCD_HBP =       40, 
            LCD_HFP =       112,
            LCD_HBLANK =    LCD_HPW + LCD_HBP + LCD_HFP,
            LCD_HTOTAL =    LCD_H + LCD_HBLANK,

            LCD_V =         480,
            LCD_VPW =       3,
            LCD_VBP =       29,
            LCD_VFP =       8,
            LCD_VBLANK =    LCD_VPW + LCD_VBP + LCD_VFP,
            LCD_VTOTAL =    LCD_V + LCD_VBLANK;


// resulting timing:
// with input clock = 31.2 MHz (32.051ns)
// HTOTAL = 1000
// HTIME = 1000 * 32.051ns = 32.051 us
// VTOTAL = 520
// VTIME = 520 * 32.051 us = 16.666 ms
// frame rate = 60.0 fps.


// LCD video timing generation
// Provides pixel / line counts to use with the scaling output
reg [$clog2(LCD_HTOTAL)-1:0] cx;
reg [$clog2(LCD_VTOTAL)-1:0] cy;

always @(posedge LCD_PIXELCLK or negedge RESETN) begin
    if(~RESETN) begin
        cx <= 'd0;
        cy <= 'd0;
    end
    else begin
        cx <= cx == LCD_HTOTAL-1'b1 ? 0 : cx + 1'b1;
        cy <= cx == LCD_HTOTAL-1'b1 ? cy == LCD_VTOTAL-1'b1 ? 0: cy + 1'b1 : cy;
    end
end


// Using inputs of cx, cy figure out which pixel of the overlay 256x224 
// input stream should be shown.

// Uses fractional scaling counters (xcnt, ycnt)

reg [10:0] xcnt = 11'd0;
reg [10:0] ycnt = 11'd0;
reg active = 1'b0;
localparam YOUTMAX = LCD_V; // display is 800x480, so maximum vertical is 480
localparam XOUTMAX = 640; // scales to 4:3 
localparam XSTART = ((LCD_H - XOUTMAX) / 2) + LCD_HPW + LCD_HBP;
localparam XSTOP = XSTART + XOUTMAX;
reg [7:0] xout = 8'd0;
reg [7:0] yout = 8'd0;

reg [9:0] cy_r = 10'd0;

wire [9:0] cy_active = (cy > (LCD_VPW + LCD_VBP)) ? (cy - (LCD_VPW + LCD_VBP)) : 0;

always @(posedge LCD_PIXELCLK) begin
    reg active_t;
    reg [10:0] xcnt_next;
    reg [10:0] ycnt_next;
    xcnt_next = xcnt + 256;
    ycnt_next = ycnt + 224;

    active_t = 0;
    if (cx == XSTART - 1) begin
        active_t = 1;
        active <= 1;
    end else if (cx == XSTOP - 1) begin
        active_t = 0;
        active <= 0;
    end

    if (active_t | active) begin        // increment xout
        xcnt <= xcnt_next;
        if (xcnt_next >= XOUTMAX) begin
            xcnt <= xcnt_next - XOUTMAX;
            xout <= xout + 1;
        end
    end

    cy_r <= cy_active;
    if (cy_active[0] != cy_r[0]) begin         // increment yout at new lines
        ycnt <= ycnt_next;
        if (ycnt_next >= YOUTMAX) begin
            ycnt <= ycnt_next - YOUTMAX;
            yout <= yout + 1;
        end
    end

    if (cx == 0) begin
        xout <= 0;
        xcnt <= 0;
    end
    
    if (cy_active == 0) begin
        yout <= 0;
        ycnt <= 0;
    end 

end

assign OVERLAY_X = xout;
assign OVERLAY_Y = yout;

reg [23:0] rgb_out;

always @(posedge LCD_PIXELCLK) begin
    if(active) begin
        rgb_out <= {OVERLAY_COLOR[4:0],3'b0,OVERLAY_COLOR[9:5],3'b0,OVERLAY_COLOR[14:10],3'b0};
    end else begin
        rgb_out <= 24'h303030;
    end
end

assign LCD_VSYNC = (cy < LCD_VPW);
assign LCD_HSYNC = (cx < LCD_HPW);
wire lcd_hde = (cx >= (LCD_HPW+LCD_HBP)) && (cx < (LCD_HPW+LCD_HBP+LCD_H));
wire lcd_vde = (cy >= (LCD_VPW+LCD_VBP)) && (cy < (LCD_VPW+LCD_VBP+LCD_V));
assign LCD_DE = lcd_hde & lcd_vde;
assign LCD_DATA = rgb_out;

endmodule