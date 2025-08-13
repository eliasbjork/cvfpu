`timescale 1ns / 1ps

// Import the fpnew package
import fpnew_pkg::*;

module fpnew_tb;
  // Parameters
  parameter int unsigned WIDTH = 32;

  // Clock and reset
  logic clk;
  logic rst_ni;

  // Input signals
  logic [2:0][WIDTH-1:0] operands_i;
  roundmode_e rnd_mode_i;
  operation_e op_i;
  logic op_mod_i;
  fp_format_e src_fmt_i;
  fp_format_e dst_fmt_i;
  int_format_e int_fmt_i;
  logic vectorial_op_i;
  logic tag_i;
  logic simd_mask_i;
  logic in_valid_i;
  logic flush_i;
  logic out_ready_i;

  // Output signals
  logic [WIDTH-1:0] result_o;
  status_t status_o;
  logic tag_o;
  logic in_ready_o;
  logic out_valid_o;
  logic busy_o;

  //THIS IS CUSTOM CODE EXJOBB CX
  localparam fpu_implementation_t CUSTOM_SNITCH = '{
      PipeRegs: '{
          // ADDMUL, DIVSQRT, NONCOMP, CONV (each array indexed by format)
          '{default: 32'd1},  // ADDMUL: 1 reg per active format
          '{default: 32'd0},  // DIVSQRT: leave 0 (iterative unit handles own staging)
          '{default: 32'd1},  // NONCOMP
          '{default: 32'd1}  // CONV
      },
      UnitTypes: '{
          '{default: PARALLEL},  // ADDMUL
          '{default: MERGED},  // DIVSQRT
          '{default: PARALLEL},  // NONCOMP
          '{default: MERGED}
      },  // CONV
      PipeConfig: BEFORE
  };

  // Instantiate DUT
  fpnew_top #(
      .Features(RV32F),
      .Implementation(CUSTOM_SNITCH),
      .TagType(logic)
  ) dut (
      .clk_i(clk),
      .rst_ni(rst_ni),
      .operands_i(operands_i),
      .rnd_mode_i(rnd_mode_i),
      .op_i(op_i),
      .op_mod_i(op_mod_i),
      .src_fmt_i(src_fmt_i),
      .dst_fmt_i(dst_fmt_i),
      .int_fmt_i(int_fmt_i),
      .vectorial_op_i(vectorial_op_i),
      .tag_i(tag_i),
      .simd_mask_i(simd_mask_i),
      .in_valid_i(in_valid_i),
      .in_ready_o(in_ready_o),
      .flush_i(flush_i),
      .result_o(result_o),
      .status_o(status_o),
      .tag_o(tag_o),
      .out_valid_o(out_valid_o),
      .out_ready_i(out_ready_i),
      .busy_o(busy_o)
  );

  // Clock generation
  initial begin
    clk = 1;
    forever #5 clk = ~clk;
  end
  integer fail_count = 0;
  integer cycles = 0;
  // Test sequence
  initial begin

    $dumpfile("fpnew_tb.vcd");
    $dumpvars();
    // Initialize
    rst_ni = 0;
    operands_i = '0;
    rnd_mode_i = RNE;
    op_i = ADD;
    op_mod_i = 0;
    src_fmt_i = FP32;
    dst_fmt_i = FP32;
    int_fmt_i = INT32;
    vectorial_op_i = 0;
    tag_i = 0;
    simd_mask_i = 1;
    in_valid_i = 0;
    flush_i = 0;
    out_ready_i = 1;

    // Reset
    #20 rst_ni = 1;
    #20;

  // ---------- TESTS ----------
  // All tests use the same handshake: drive in_valid_i with operands, wait in_ready_o,
  // drop in_valid_i on the next posedge clk, wait out_valid_o, then sample result_o.

  // FMA GROUP
  // ADD: a*b + c with a forced to +1.0 => effectively b + c (use operands[1] and [2])
  op_i = ADD; op_mod_i = 0; rnd_mode_i = RNE; src_fmt_i = FP32; dst_fmt_i = FP32;
  operands_i[0] = '0;
  operands_i[1] = 32'h3F800000; // b = 1.0 (FP32)
  operands_i[2] = 32'h40000000; // c = 2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  cycles = 0;
    while (!out_valid_o) begin
      cycles++;
      @(posedge clk);
    end
    $display("Latency (handshake->out_valid) = %0d cycles", cycles);
  begin
    logic [WIDTH-1:0] exp = 32'h40400000; // 3.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[ADD] 1.0 + 2.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // MUL: a*b + c with c forced to +0.0 => effectively a * b (use operands[0] and [1])
  op_i = MUL; op_mod_i = 0; rnd_mode_i = RNE;
  operands_i = '0;
  operands_i[0] = 32'h40400000; // a = 3.0 (FP32)
  operands_i[1] = 32'h40000000; // b = 2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // Expect 3.0 * 2.0 = 6.0
    logic [WIDTH-1:0] exp = 32'h40C00000; // 6.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[MUL] 3.0 * 2.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // FMADD: a*b + c (use operands[0], [1], [2])
  op_i = FMADD; op_mod_i = 0; rnd_mode_i = RNE;
  operands_i[0] = 32'h40400000; // a = 3.0 (FP32)
  operands_i[1] = 32'h40000000; // b = 2.0 (FP32)
  operands_i[2] = 32'h40800000; // c = 4.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    logic [WIDTH-1:0] exp = 32'h41200000; // 3.0*2.0 + 4.0 = 10.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[FMADD] 3.0*2.0 + 4.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // OTHER OPERATIONS
  // SUB: 2.0 - 1.0 = 1.0
  op_i = ADD;
  op_mod_i = 1; // subtract
  operands_i = '0;
  operands_i[1] = 32'h40000000; // b = 2.0 (FP32)
  operands_i[2] = 32'h3F800000; // c = 1.0 (FP32)
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // ADD with op_mod=1 subtracts c from b: result = b - c
    logic [WIDTH-1:0] exp = 32'h3F800000; // 1.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[SUB] 2.0 - 1.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // ADDS: 1.25 + 0.75 = 2.0
  op_i = ADDS;
  op_mod_i = 0;
  operands_i = '0;
  operands_i[1] = 32'h3FA00000; // b = 1.25 (FP32)
  operands_i[2] = 32'h3F400000; // c = 0.75 (FP32)
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // ADDS: FMA path with a forced to +1.0: result = b + c
    logic [WIDTH-1:0] exp = 32'h40000000; // 2.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[ADDS] 1.25 (+) 0.75 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // FNMSUB: -(2.0*3.0) + 1.0 = -5.0
  op_i = FNMSUB; op_mod_i = 0;
  operands_i[0] = 32'h40000000; // a = 2.0 (FP32)
  operands_i[1] = 32'h40400000; // b = 3.0 (FP32)
  operands_i[2] = 32'h3F800000; // c = 1.0 (FP32)
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // FNMSUB: -(a*b) + c
    logic [WIDTH-1:0] exp = 32'hC0A00000; // -5.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[FNMSUB] -(2.0*3.0)+1.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // FNMADD: -(2.0*3.0) - 1.0 = -7.0
  op_i = FNMSUB; op_mod_i = 1;
  operands_i[0] = 32'h40000000; // a = 2.0 (FP32)
  operands_i[1] = 32'h40400000; // b = 3.0 (FP32)
  operands_i[2] = 32'h3F800000; // c = 1.0 (FP32)
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // FNMADD: -(a*b) - c (via FNMSUB with op_mod=1)
    logic [WIDTH-1:0] exp = 32'hC0E00000; // -7.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[FNMADD] -(2.0*3.0)-1.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // DIV: 6.0 / 2.0 = 3.0
  op_i = DIV; op_mod_i = 0; rnd_mode_i = RNE;

  operands_i[0] = 32'h40C00000; // dividend = 6.0 (FP32)
  operands_i[1] = 32'h40000000; // divisor  = 2.0 (FP32)
  operands_i[2] = '0;
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // DIV: result = dividend / divisor
    logic [WIDTH-1:0] exp = 32'h40400000; // 3.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[DIV] 6.0 / 2.0 => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // SQRT: sqrt(4.0) = 2.0
  op_i = SQRT; op_mod_i = 0; rnd_mode_i = RNE;
  operands_i = '0;
  operands_i[0] = 32'h40800000; // 4.0 (FP32)
  in_valid_i = 1;
  wait (in_ready_o); @(posedge clk); in_valid_i = 0;
  wait (out_valid_o);
  begin
    // SQRT: result = sqrt(operand)
    logic [WIDTH-1:0] exp = 32'h40000000; // 2.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[SQRT] sqrt(4.0) => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // SGNJ family on a=-1.5, b=+2.0
  op_i = SGNJ; op_mod_i = 0;
  rnd_mode_i = RNE; // SGNJ (copy sign of b)
  operands_i = '0;
  operands_i[0] = 32'hBFC00000; // a = -1.5 (FP32)
  operands_i[1] = 32'h40000000; // b = +2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // SGNJ: copy sign of b to magnitude of a
    logic [WIDTH-1:0] exp = 32'h3FC00000; // +1.5 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[SGNJ] copy sign(b) to a => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RTZ; // SGNJN (negate sign of b)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // SGNJN: negate sign of b, apply to magnitude of a
  logic [WIDTH-1:0] exp = 32'hBFC00000; // -1.5 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[SGNJN] negate sign(b) -> a => %h (exp=%h) %s",
             result_o, exp, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RDN; // SGNJX (xor signs), use b negative to flip
  operands_i[1] = 32'hC0000000; // b = -2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // SGNJX: xor signs of a and b, apply to magnitude of a
    logic [WIDTH-1:0] exp = 32'h3FC00000; // +1.5 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[SGNJX] xor sign(a,b) -> a => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // MIN/MAX on 1.0 and -2.0
  op_i = MINMAX; rnd_mode_i = RNE; // MIN
  operands_i[0] = 32'h3F800000; // 1.0 (FP32)
  operands_i[1] = 32'hC0000000; // -2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // MINMAX with RNE selects MIN
    logic [WIDTH-1:0] exp = 32'hC0000000; // -2.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[MIN] min(1.0,-2.0) => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RTZ; // MAX
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // MINMAX with RTZ selects MAX
  logic [WIDTH-1:0] exp = 32'h3F800000; // 1.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[MAX] max(1.0,-2.0) => %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // CMP: LE, LT, EQ and inverted NE
  op_i = CMP; op_mod_i = 0; rnd_mode_i = RNE; // LE
  operands_i[0] = 32'h40000000; // 2.0 (FP32)
  operands_i[1] = 32'h40400000; // 3.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // CMP with RNE implements LE (<=)
    bit got = result_o[0]; bit expb = 1'b1; bit pass = (got == expb);
    if(!pass) fail_count++;
    $display("[CMP.LE] 2.0 <= 3.0 => %0d (exp=%0d) %s", got, expb, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RTZ; // LT
  operands_i[0] = 32'h40400000; // 3.0 (FP32)
  operands_i[1] = 32'h40000000; // 2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // CMP with RTZ implements LT (<)
    bit got = result_o[0]; bit expb = 1'b0; bit pass = (got == expb);
    if(!pass) fail_count++;
    $display("[CMP.LT] 3.0 < 2.0 => %0d (exp=%0d) %s", got, expb, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RDN; // EQ
  operands_i[0] = 32'h40400000; // 3.0 (FP32)
  operands_i[1] = 32'h40400000; // 3.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // CMP with RDN implements EQ (==)
    bit got = result_o[0]; bit expb = 1'b1; bit pass = (got == expb);
    if(!pass) fail_count++;
    $display("[CMP.EQ] 3.0 == 3.0 => %0d (exp=%0d) %s", got, expb, pass ? "PASS" : "FAIL");
  end

  rnd_mode_i = RDN; op_mod_i = 1; // NE (invert EQ)
  operands_i[0] = 32'h40400000; // 3.0 (FP32)
  operands_i[1] = 32'h40000000; // 2.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // CMP with RDN + op_mod=1 implements NE (!=) by inverting EQ
    bit got = result_o[0]; bit expb = 1'b1; bit pass = (got == expb);
    if(!pass) fail_count++;
    $display("[CMP.NE] 3.0 != 2.0 => %0d (exp=%0d) %s", got, expb, pass ? "PASS" : "FAIL");
  end
  op_mod_i = 0; // restore

  // CLASSIFY: +0.0 and +inf
  op_i = CLASSIFY; rnd_mode_i = RNE;
  operands_i[0] = 32'h00000000; // +0.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // CLASSIFY returns a bitmask of FP class; here we check the low bits of the mask
    logic [15:0] got = result_o[15:0]; logic [15:0] expm = 16'h0010;
    bit pass = (got === expm);
    if(!pass) fail_count++;
  $display("[CLASSIFY] +0.0 mask LSBs => 0x%0h (exp=0x%0h) %s",
       got, expm, pass ? "PASS" : "FAIL");
  end

  operands_i[0] = 32'h7F800000; // +inf (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    logic [15:0] got = result_o[15:0]; logic [15:0] expm = 16'h0080;
    bit pass = (got === expm);
    if(!pass) fail_count++;
  $display("[CLASSIFY] +inf mask LSBs => 0x%0h (exp=0x%0h) %s",
       got, expm, pass ? "PASS" : "FAIL");
  end

  // F2F: FP32 -> FP32 (identity)
  op_i = F2F; rnd_mode_i = RNE;
  src_fmt_i = FP32; dst_fmt_i = FP32;
  operands_i = '0;
  operands_i[0] = 32'h40600000; // 3.5 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // F2F: FP32 -> FP32 (identity cast)
    logic [WIDTH-1:0] exp = 32'h40600000; // 3.5 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[F2F 32->32] %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  src_fmt_i = FP32; dst_fmt_i = FP32;
  operands_i[0] = 32'h3FA00000; // 1.25 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
    // F2F: FP32 -> FP32 (identity cast)
    logic [WIDTH-1:0] exp = 32'h3FA00000; // 1.25 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[F2F 32->32 B] %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end

  // F2I: FP32 -> INT32
  op_i = F2I; int_fmt_i = INT32; src_fmt_i = FP32; dst_fmt_i = FP32;
  operands_i = '0;
  operands_i[0] = 32'h40A00000; // 5.0 (FP32)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
  // F2I: convert FP32 to signed INT32
    int signed got_i = $signed(result_o);
    int signed exp_i = 5;
    bit pass = (got_i == exp_i);
    if(!pass) fail_count++;
    $display("[F2I 32->I32] %0d (exp=%0d) %s", got_i, exp_i, pass ? "PASS" : "FAIL");
  end

  // I2F: INT32 -> FP32
  op_i = I2F; int_fmt_i = INT32; dst_fmt_i = FP32;
  operands_i = '0;
  operands_i[0] = 32'hFFFFFFF9; // -7 (two's complement, 32-bit)
  in_valid_i = 1; wait (in_ready_o); @(posedge clk); in_valid_i = 0; wait (out_valid_o);
  begin
  // I2F: convert signed INT32 to FP32
    logic [WIDTH-1:0] exp = 32'hC0E00000; // -7.0 (FP32)
    bit pass = (result_o === exp);
    if(!pass) fail_count++;
    $display("[I2F I32->32] %h (exp=%h) %s", result_o, exp, pass ? "PASS" : "FAIL");
  end
    #100;
    $display("[SUMMARY] %0d tests failed", fail_count);
    $finish;
  end

endmodule
