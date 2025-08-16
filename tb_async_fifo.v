`timescale 1ns/1ps

module tb_async_fifo;
  localparam DSIZE = 8;
  localparam ASIZE = 4;
  localparam DEPTH = 1<<ASIZE;

  // ---------------------- Clocks ----------------------
  reg wclk = 0, rclk = 0;
  always #3.5 wclk = ~wclk; // ~143 MHz
  always #5.0 rclk = ~rclk; // 100 MHz

  // ---------------------- Async resets ----------------
  reg wrst_n = 0, rrst_n = 0;
  initial begin
    wrst_n = 0; rrst_n = 0;
    #10  wrst_n = 1;
    #15  rrst_n = 1;
  end

  // ---------------------- DUT signals -----------------
  reg  [DSIZE-1:0] wdata;
  reg              winc, rinc;
  wire [DSIZE-1:0] rdata;
  wire             wfull, rempty;

  async_fifo #(.DSIZE(DSIZE), .ASIZE(ASIZE)) dut (
    .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty)
  );

  // ---------------------- Scoreboard model -----------------
  reg [DSIZE-1:0] model [0:1023];
  integer wptr_m = 0;
  integer rptr_m = 0;

  // ---------------------- Write stimulus -------------------
  initial begin
    winc  = 0;
    wdata = 0;
    @(posedge wrst_n);
    repeat (100) begin
      @(posedge wclk);
      if (!wfull && ($urandom%2)) begin
        wdata = $urandom;
        winc  = 1;
        model[wptr_m] = wdata;
        wptr_m = wptr_m + 1;
      end else begin
        winc = 0;
      end
    end
  end

  // ---------------------- Read stimulus --------------------
  initial begin
    rinc = 0;
    @(posedge rrst_n);
    repeat (120) begin
      @(posedge rclk);
      if (!rempty && ($urandom%2 == 0)) begin
        rinc = 1;
      end else begin
        rinc = 0;
      end
    end
  end

  // ---------------------- Checker --------------------------
  // rinc_d is delayed rinc, because rdata is valid one cycle later
  reg rinc_d;
  always @(posedge rclk) rinc_d <= rinc;

    always @(posedge rclk) begin
      if (rinc) begin
        if (rdata !== model[rptr_m]) begin
          $display("[%0t] Mismatch: expected %0h, got %0h",
                   $time, model[rptr_m], rdata);
          $fatal;
        end
        rptr_m <= rptr_m + 1;
      end
    end

 

  // ---------------------- Simulation End -------------------
  initial begin
    #2000;
    $display("TEST PASSED");
    $finish;
  end
endmodule
