// ============================================================================
// Dual-Clock Asynchronous FIFO (Gray-coded pointers + 2-FF synchronizers)
// Synthesizable in Xilinx Vivado
// ----------------------------------------------------------------------------
// Parameters:
//   DSIZE : data width
//   ASIZE : address width (FIFO depth = 2**ASIZE)
// ----------------------------------------------------------------------------
// - Full/Empty detection uses "Style #1" (Cummings SNUG paper).
// - Gray coding avoids multi-bit CDC hazards.
// - 2-flop synchronizers (with ASYNC_REG attribute) avoid metastability.
// ============================================================================

`timescale 1ns/1ps

module async_fifo #(
  parameter integer DSIZE = 8,
  parameter integer ASIZE = 4
)(
  // Write domain
  input  wire                 wclk,
  input  wire                 wrst_n,
  input  wire                 winc,
  input  wire [DSIZE-1:0]     wdata,
  output wire                 wfull,

  // Read domain
  input  wire                 rclk,
  input  wire                 rrst_n,
  input  wire                 rinc,
  output wire [DSIZE-1:0]     rdata,
  output wire                 rempty
);

  localparam integer PTR_W = ASIZE+1; // pointer width
  localparam integer DEPTH = (1<<ASIZE);

  // ---------------------- Binary ? Gray conversion -------------------------
  function [PTR_W-1:0] bin2gray(input [PTR_W-1:0] b);
    bin2gray = (b>>1) ^ b;
  endfunction

  // ---------------------- Write Pointer Logic ------------------------------
  reg  [PTR_W-1:0] wbin, wbin_next;
  reg  [PTR_W-1:0] wgray, wgray_next;
  wire winc_ok = winc & ~wfull;

  always @* begin
    wbin_next  = wbin + winc_ok;
    wgray_next = bin2gray(wbin_next);
  end

  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin  <=0;
      wgray <= 0;
    end else begin
      wbin  <= wbin_next;
      wgray <= wgray_next;
    end
  end

  // ---------------------- Read Pointer Logic -------------------------------
  reg  [PTR_W-1:0] rbin, rbin_next;
  reg  [PTR_W-1:0] rgray, rgray_next;
  wire rinc_ok = rinc & ~rempty;

  always @* begin
    rbin_next  = rbin + rinc_ok;
    rgray_next = bin2gray(rbin_next);
  end

  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin  <= 0;
      rgray <= 0;
    end else begin
      rbin  <= rbin_next;
      rgray <= rgray_next;
    end
  end

  // ---------------------- Dual-Port Memory --------------------------------
  (* ram_style = "auto" *) reg [DSIZE-1:0] mem [0:DEPTH-1];

  always @(posedge wclk) begin
    if (winc_ok) begin
      mem[wbin[ASIZE-1:0]] <= wdata;
    end
  end

  reg [DSIZE-1:0] rdata_q;
  always @(posedge rclk) begin
    rdata_q <= mem[rbin[ASIZE-1:0]];
  end

  assign rdata = rdata_q;

  // ---------------------- Pointer Synchronization --------------------------
  wire [PTR_W-1:0] wgray_sync_in_rclk;
  wire [PTR_W-1:0] rgray_sync_in_wclk;

  sync2 #(.WIDTH(PTR_W)) u_sync_w2r (
    .clk   (rclk),
    .rst_n (rrst_n),
    .d     (wgray),
    .q     (wgray_sync_in_rclk)
  );

  sync2 #(.WIDTH(PTR_W)) u_sync_r2w (
    .clk   (wclk),
    .rst_n (wrst_n),
    .d     (rgray),
    .q     (rgray_sync_in_wclk)
  );

  // ---------------------- Full & Empty Flags -------------------------------
  wire [PTR_W-1:0] rgray_wclk = rgray_sync_in_wclk;
  reg wfull_r;
  wire wfull_next;

  assign wfull_next = (wgray_next == {~rgray_wclk[PTR_W-1:PTR_W-2],
                                      rgray_wclk[PTR_W-3:0]});

  always @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wfull_r <= 1'b0;
    end else begin
      wfull_r <= wfull_next;
    end
  end

  assign wfull = wfull_r;

  wire [PTR_W-1:0] wgray_rclk = wgray_sync_in_rclk;
  reg rempty_r;
  wire rempty_next;

  assign rempty_next = (rgray_next == wgray_rclk);

  always @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rempty_r <= 1'b1;
    end else begin
      rempty_r <= rempty_next;
    end
  end

  assign rempty = rempty_r;

endmodule


// ============================================================================
// 2-Flip-Flop Synchronizer for CDC (parameterized width)
// ============================================================================
module sync2 #(
  parameter integer WIDTH = 4
)(
  input  wire                 clk,
  input  wire                 rst_n,
  input  wire [WIDTH-1:0]     d,
  output wire [WIDTH-1:0]     q
);
  (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s1;
  (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] s2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1 <= 0;
      s2 <= 0;
    end else begin
      s1 <= d;
      s2 <= s1;
    end
  end

  assign q = s2;
endmodule
