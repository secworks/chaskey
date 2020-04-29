//======================================================================
//
// tb_prince_core.v
// --------------
// Testbench for the chaskey MAC.
//
// Author: Joachim Strombergson
// Copyright (c) 2020, Assured AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_chaskey_core();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;
  parameter DUMP_WAIT = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD = 2 * CLK_HALF_PERIOD;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0] cycle_ctr;
  reg [31 : 0] error_ctr;
  reg [31 : 0] tc_ctr;
  reg          tb_monitor;

  reg            tb_clk;
  reg            tb_reset_n;
  reg            tb_init;
  reg            tb_next;
  reg            tb_finalize;
  reg [7 : 0]    tb_final_length;
  reg [3 : 0]    tb_num_rounds;
  wire           tb_ready;
  reg [127 : 0]  tb_key;
  reg [127 : 0]  tb_block;
  wire [127 : 0] tb_tag;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  chaskey_core dut(
                .clk(tb_clk),
                .reset_n(tb_reset_n),

                .init(tb_init),
                .next(tb_next),
                .finalize(tb_finalize),
                .final_length(tb_final_length),
                .num_rounds(tb_num_rounds),
                .ready(tb_ready),

                .key(tb_key),

                .block(tb_block),
                .tag(tb_tag)
               );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;
      #(CLK_PERIOD);
      if (tb_monitor)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("State of DUT");
      $display("------------");
      $display("Cycle: %08d", cycle_ctr);
      $display("Inputs and outputs:");
      $display("");
      $display("Internal states:");
      $display("core_ctrl_reg: 0x%02x, core_ctrl_new: 0x%02x, core_ctrl_we: 0x%01x",
               dut.core_ctrl_reg, dut.core_ctrl_new, dut.core_ctrl_we);
      $display("");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** DUT before reset:");
      dump_dut_state();
      $display("*** Toggling reset.");
      tb_reset_n = 0;
      #(2 * CLK_PERIOD);
      tb_reset_n = 1;
      $display("*** DUT after reset:");
      dump_dut_state();
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_result()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_result;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_result


  //----------------------------------------------------------------
  // wait_ready()
  //
  // Wait for the ready flag in the dut to be set.
  //
  // Note: It is the callers responsibility to call the function
  // when the dut is actively processing and will in fact at some
  // point set the flag.
  //----------------------------------------------------------------
  task wait_ready;
    begin
      #(2 * CLK_PERIOD);
      while (!tb_ready)
        begin
          #(CLK_PERIOD);
          if (DUMP_WAIT)
            begin
              dump_dut_state();
            end
        end
    end
  endtask // wait_ready


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr       = 0;
      error_ctr       = 0;
      tc_ctr          = 0;
      tb_monitor      = 0;

      tb_clk          = 0;
      tb_reset_n      = 1;
      tb_init         = 0;
      tb_next         = 0;
      tb_finalize     = 0;
      tb_final_length = 0;
      tb_num_rounds   = 8;
      tb_key          = 128'h0;
      tb_block        = 128'h0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // test_chaskey_round_logic
  // Test the round logic separately.
  //----------------------------------------------------------------
  task test_chaskey_round_logic;
    begin : test_chaskey_round_logic
      integer rl_errors;

      $display("--- TC test_chaskey_round_logic started.");
      $display("--- Forcing registers to test round logic.");

      rl_errors = 0;

      dut.v0_reg = 32'hffaa5488;
      dut.v1_reg = 32'haaff0054;
      dut.v2_reg = 32'h5500ffa9;
      dut.v3_reg = 32'h0055aafe;

      #(CLK_PERIOD);

      if (dut.chaskey_round_logic.v0_prim2 != 32'h55d8ff50)
        begin
          $display("Error for v0_prim2. Expected 0x55d8ff50. Got 0x%08x",
                   dut.chaskey_round_logic.v0_prim2);
          rl_errors = rl_errors + 1;
        end

      if (dut.chaskey_round_logic.v1_prim3 != 32'hee0f2c0a)
        begin
          $display("Error for v1_prim3. Expected 0xee0f2c0a. Got 0x%08x",
                   dut.chaskey_round_logic.v1_prim3);
          rl_errors = rl_errors + 1;
        end

      if (dut.chaskey_round_logic.v2_prim2 != 32'h08f04aa0)
        begin
          $display("Error for v2_prim2. Expected 0x08f04aa0. Got 0x%08x",
                   dut.chaskey_round_logic.v2_prim2);
          rl_errors = rl_errors + 1;
        end

      if (dut.chaskey_round_logic.v3_prim3 != 32'hdf4c1f4f)
        begin
          $display("Error for v2_prim2. Expected 0xdf4c1f4f. Got 0x%08x",
                   dut.chaskey_round_logic.v3_prim3);
          rl_errors = rl_errors + 1;
        end

      if (rl_errors == 0)
        $display("--- TC test_chaskey_round_logic completed without errors.");
      else
        begin
          error_ctr = error_ctr + rl_errors;
          $display("--- TC test_chaskey_round_logic completed with %d errors.",
                   rl_errors);
        end
    end
  endtask // test_chaskey_round_logic


  //----------------------------------------------------------------
  // chaskey_core_test
  //
  // Test vectors from:
  //----------------------------------------------------------------
  initial
    begin : chaskey_core_test
      $display("*** Simulation of CHASKEY core started.");
      $display("");

      init_sim();
      reset_dut();
      test_chaskey_round_logic();

      display_test_result();
      $display("");
      $display("*** Simulation of CHASKEY core completed.");
      $finish;
    end // chaskey_core_test
endmodule // tb_chaskey_core

//======================================================================
// EOF tb_chaskey_core.v
//======================================================================
