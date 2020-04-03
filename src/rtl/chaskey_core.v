//======================================================================
//
// chaskey_core.v
// ---------------
// Chaskey Message Authentication Code function.
//
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

module chaskey_core(
                    input wire            clk,
                    input wire            reset_n,

                    input wire            init,
                    input wire            next,
                    input wire            finalize,
                    input wire [7 : 0]    final_length,
                    input wire [3 : 0]    num_rounds,
                    output wire           ready,

                    input wire [127 : 0]  key,

                    input wire [127 : 0]  block,
                    output wire [127 : 0] tag
                   );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE   = 3'h0;
  localparam CTRL_ROUNDS = 3'h1;
  localparam CTRL_STATE  = 3'h2;
  localparam CTRL_DONE   = 3'h3;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [127 : 0] k_reg;
  reg [127 : 0] k1_reg;
  reg [127 : 0] k2_reg;
  reg           k_k1_k2_we;

  reg           ready_reg;
  reg           ready_new;
  reg           ready_we;

  reg [3 : 0]   round_ctr_reg;
  reg [3 : 0]   round_ctr_new;
  reg           round_ctr_we;
  reg           round_ctr_inc;
  reg           round_ctr_rst;

  reg [31 : 0]  h0_reg;
  reg [31 : 0]  h0_new;
  reg [31 : 0]  h1_reg;
  reg [31 : 0]  h1_new;
  reg [31 : 0]  h2_reg;
  reg [31 : 0]  h2_new;
  reg [31 : 0]  h3_reg;
  reg [31 : 0]  h3_new;
  reg           h0_h3_we;

  reg [31 : 0]  v0_reg;
  reg [31 : 0]  v0_new;
  reg [31 : 0]  v1_reg;
  reg [31 : 0]  v1_new;
  reg [31 : 0]  v2_reg;
  reg [31 : 0]  v2_new;
  reg [31 : 0]  v3_reg;
  reg [31 : 0]  v3_new;
  reg           v0_v3_we;

  reg [3 : 0]   num_rounds_reg;
  reg           num_rounds_we;

  reg [2 : 0]   core_ctrl_reg;
  reg [2 : 0]   core_ctrl_new;
  reg           core_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg init_round;
  reg update_round;
  reg init_state;
  reg update_state;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready = ready_reg;
  assign tag   = {h0_reg, h1_reg, h2_reg, h3_reg};


  //----------------------------------------------------------------
  // Internal functions.
  //----------------------------------------------------------------
  function [127 : 0] times2(input [127 : 0] op);
    begin
      if (op[127])
        times2 = {op[126 : 0], 1'h0} ^ 128'h87;
      else
        times2 = {op[126 : 0], 1'h0};
    end
  endfunction


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin: reg_update
      if (!reset_n)
        begin
          k_reg          <= 128'h0;
          k1_reg         <= 128'h0;
          k2_reg         <= 128'h0;
          h0_reg         <= 32'h0;
          h1_reg         <= 32'h0;
          h2_reg         <= 32'h0;
          h3_reg         <= 32'h0;
          v0_reg         <= 32'h0;
          v1_reg         <= 32'h0;
          v2_reg         <= 32'h0;
          v3_reg         <= 32'h0;
          ready_reg      <= 1'h1;
          num_rounds_reg <= 4'h0;
          round_ctr_reg  <= 4'h0;
          core_ctrl_reg  <= CTRL_IDLE;
        end
      else
        begin
          if (ready_we)
            ready_reg <= ready_new;

          if (num_rounds_we)
            num_rounds_reg <= num_rounds;

          if (k_k1_k2_we)
            begin
              k_reg  <= key;
              k1_reg <= times2(key);
              k2_reg <= times2(times2(key));
            end

          if (h0_h3_we)
            begin
              h0_reg <= h0_new;
              h1_reg <= h1_new;
              h2_reg <= h2_new;
              h3_reg <= h3_new;
            end

          if (v0_v3_we)
            begin
              v0_reg <= v0_new;
              v1_reg <= v1_new;
              v2_reg <= v2_new;
              v3_reg <= v3_new;
            end

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (core_ctrl_we)
            core_ctrl_reg <= core_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // chaskey_round_logic
  // The datapath implenentiing the chaskey round logic (pi).
  //----------------------------------------------------------------
  always @*
    begin : chaskey_round_logic
      reg [31 : 0] v0_prim0;
      reg [31 : 0] v0_prim1;
      reg [31 : 0] v0_prim2;

      reg [31 : 0] v1_prim0;
      reg [31 : 0] v1_prim1;
      reg [31 : 0] v1_prim2;
      reg [31 : 0] v1_prim3;

      reg [31 : 0] v2_prim0;
      reg [31 : 0] v2_prim1;
      reg [31 : 0] v2_prim2;

      reg [31 : 0] v3_prim0;
      reg [31 : 0] v3_prim1;
      reg [31 : 0] v3_prim2;
      reg [31 : 0] v3_prim3;

      v0_new   = 32'h0;
      v1_new   = 32'h0;
      v2_new   = 32'h0;
      v3_new   = 32'h0;
      v0_v3_we = 1'h0;

      v0_prim0 = v0_reg + v1_reg;
      v0_prim1 = {v0_prim0[15 : 0], v0_prim0[31 : 16]};
      v0_prim2 = v0_prim1 + v3_prim2;

      v1_prim0 = {v1_reg[26 : 0], v1_reg[31 : 27]};
      v1_prim1 = v1_prim0 ^ v0_prim0;
      v1_prim2 = {v1_reg[24 : 0], v1_reg[31 : 25]};
      v1_prim3 = v1_prim2 ^ v2_prim1;

      v2_prim0 = v2_reg + v3_reg;
      v2_prim1 = v2_prim0 + v1_prim1;
      v2_prim2 = {v2_prim1[15 : 0], v2_prim1[31 : 16]};

      v3_prim0 = {v3_reg[23 : 0], v3_reg[31 : 24]};
      v3_prim1 = v3_prim0 ^ v2_prim0;
      v3_prim2 = {v3_prim1[18 : 0], v3_prim1[31 : 19]};
      v3_prim3 = v3_prim2 ^ v0_prim2;


      if (init_round)
        begin
          v0_new   = h0_reg;
          v1_new   = h1_reg;
          v2_new   = h2_reg;
          v2_new   = h3_reg;
          v0_v3_we = 1'h1;
        end


      if (update_round)
        begin
          v0_new   = v0_prim2;
          v1_new   = v1_prim3;
          v2_new   = v2_prim2;
          v3_new   = v3_prim3;
          v0_v3_we = 1'h1;
        end
    end // chaskey_core_dp


  //----------------------------------------------------------------
  // chaskey_state_logic
  // The datapath implementiing the chaskey statelogic.
  //----------------------------------------------------------------
  always @*
    begin : chaskey_state_logic
      h0_new   = 32'h0;
      h1_new   = 32'h0;
      h2_new   = 32'h0;
      h3_new   = 32'h0;
      h0_h3_we = 1'h0;


      if (init_state)
        begin

        end


      if (update_state)
        begin
          h0_new   = v0_reg;
          h1_new   = v1_reg;
          h2_new   = v2_reg;
          h3_new   = v3_reg;
          h0_h3_we = 1'h1;

        end
    end // chaskey_core_dp


  //----------------------------------------------------------------
  // round_ctr
  //
  // The round counter with reset and increase logic.
  //----------------------------------------------------------------
  always @*
    begin : round_ctr
      round_ctr_new = 4'h0;
      round_ctr_we  = 1'h0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1'h1;
        end

      else if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'h1;
          round_ctr_we  = 1'h1;
        end
    end // round_ctr


  //----------------------------------------------------------------
  // chaskey_core_ctrl
  //
  // Control FSM for aes core.
  //----------------------------------------------------------------
  always @*
    begin : chaskey_core_ctrl
      ready_new     = 1'h0;
      ready_we      = 1'h0;
      k_k1_k2_we    = 1'h0;
      init_round    = 1'h0;
      update_round  = 1'h0;
      init_state    = 1'h0;
      update_state  = 1'h0;
      num_rounds_we = 1'h0;
      round_ctr_inc = 1'h0;
      round_ctr_rst = 1'h0;
      core_ctrl_new = CTRL_IDLE;
      core_ctrl_we  = 1'h0;

      case (core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                ready_new     = 1'h0;
                ready_we      = 1'h1;
                k_k1_k2_we    = 1'h1;
                num_rounds_we = 1'h1;
                core_ctrl_new = CTRL_DONE;
                core_ctrl_we  = 1'h0;
              end

            if (next)
              begin
                ready_new     = 1'h0;
                ready_we      = 1'h1;
                core_ctrl_new = CTRL_DONE;
                core_ctrl_we  = 1'h0;
              end

            if (finalize)
              begin
                ready_new     = 1'h0;
                ready_we      = 1'h1;
                core_ctrl_new = CTRL_DONE;
                core_ctrl_we  = 1'h0;
              end
          end


        CTRL_ROUNDS:
          begin
            if (round_ctr_reg < num_rounds_reg)
              begin
                core_ctrl_new = CTRL_DONE;
                core_ctrl_we  = 1'h1;
              end
          end


        CTRL_DONE:
          begin
            ready_new     = 1'h1;
            ready_we      = 1'h1;
            update_state  = 1'h1;
            core_ctrl_new = CTRL_IDLE;
            core_ctrl_we  = 1'h1;
          end

        default:
          begin
          end
      endcase // case (core_ctrl_reg)
    end // chaskey_core_ctrl

endmodule // chaskey_core

//======================================================================
// EOF chaskey_core.v
//======================================================================
