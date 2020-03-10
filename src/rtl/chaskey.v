//======================================================================
//
// chaskey.v
// ---------
// Top level wrapper for the Verilog 2001 implementation of Chaskey.
// This wrapper provides a 32-bit memory like interface.
//
//
// Copyright (c) 2012, Secworks Sweden AB
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

module chaskey(
               input wire           clk,
               input wire           reset_n,
               input wire           cs,
               input wire           we,
               input wire [7 : 0]   addr,
               input wire [31 : 0]  write_data,
               output wire [31 : 0] read_data
              );


  //----------------------------------------------------------------
  // API and Symbolic names.
  //----------------------------------------------------------------
  localparam ADDR_NAME0        = 8'h00;
  localparam ADDR_NAME1        = 8'h01;
  localparam ADDR_VERSION      = 8'h02;

  localparam ADDR_CTRL         = 8'h08;
  localparam CTRL_INIT_BIT     = 0;
  localparam CTRL_NEXT_BIT     = 1;
  localparam CTRL_FINALIZE_BIT = 2;

  localparam ADDR_STATUS       = 8'h09;
  localparam STATUS_READY_BIT  = 0;

  localparam ADDR_ROUNDS       = 8'h0a;

  localparam ADDR_FINAL_LEN    = 8'h0c;

  localparam ADDR_KEY0         = 8'h10;
  localparam ADDR_KEY1         = 8'h11;
  localparam ADDR_KEY2         = 8'h12;
  localparam ADDR_KEY3         = 8'h13;

  localparam ADDR_BLOCK0       = 8'h20;
  localparam ADDR_BLOCK1       = 8'h21;
  localparam ADDR_BLOCK2       = 8'h22;
  localparam ADDR_BLOCK3       = 8'h23;

  localparam ADDR_TAG0         = 8'h40;
  localparam ADDR_TAG1         = 8'h41;
  localparam ADDR_TAG2         = 8'h42;
  localparam ADDR_TAG3         = 8'h43;

  localparam CORE_NAME0        = 32'h63686173; // "chas"
  localparam CORE_NAME1        = 32'h6b657920; // "key "
  localparam CORE_VERSION      = 32'h302e3130; // "0.10"

  localparam DEFAULT_NUM_ROUNDS = 12;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg          init_reg;
  reg          init_new;

  reg          next_reg;
  reg          next_new;

  reg          finalize_reg;
  reg          finalize_new;

  reg [7 : 0]  final_len_reg;
  reg          final_len_we;

  reg [3 : 0]  num_rounds_reg;
  reg          num_rounds_we;

  reg [31 : 0] key_reg [0 : 3];
  reg          key_we;

  reg [31 : 0] block_reg [0 : 3];
  reg          block_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]   tmp_read_data;

  wire           core_ready;
  wire [127 : 0] core_key;
  wire [127 : 0] core_block;
  wire [127 : 0] core_tag;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data = tmp_read_data;

  assign core_block = {block_reg[0], block_reg[1], block_reg[2], block_reg[3]};
  assign core_key   = {key_reg[0], key_reg[1], key_reg[2], key_reg[3]};


  //----------------------------------------------------------------
  // Core instance.
  //----------------------------------------------------------------
  chaskey_core core(
                    .clk(clk),
                    .reset_n(reset_n),

                    .init(init_reg),
                    .next(next_reg),
                    .finalize(finalize_reg),
                    .final_length(final_len_reg),
                    .num_rounds(num_rounds_reg),
                    .key(core_key),
                    .block(core_block),
                    .tag(core_tag),
                    .ready(core_ready)
                   );


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with
  // synchronous active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      integer i;
      if (!reset_n)
        begin
          for (i = 0 ; i < 4 ; i = i + 1)
            begin
              key_reg[i]   <= 32'h0;
              block_reg[i] <= 32'h0;
            end
          init_reg       <= 1'h0;
          next_reg       <= 1'h0;
          finalize_reg   <= 1'h0;
          final_len_reg  <= 8'h0;
          num_rounds_reg <= DEFAULT_NUM_ROUNDS;
        end
      else
        begin
          init_reg     <= init_new;
          next_reg     <= next_new;
          finalize_reg <= finalize_new;

          if (final_len_we)
            final_len_reg <= write_data[7 : 0];

          if (num_rounds_we)
            num_rounds_reg <= write_data[3 : 0];

          if (key_we)
            key_reg[addr[1 : 0]] <= write_data;

          if (block_we)
            block_reg[addr[1 : 0]] <= write_data;
        end
    end // reg_update


  //----------------------------------------------------------------
  // api
  //----------------------------------------------------------------
  always @*
    begin : api
      tmp_read_data = 32'h0;
      init_new      = 1'h0;
      next_new      = 1'h0;
      finalize_new  = 1'h0;
      final_len_we  = 1'h0;
      num_rounds_we = 1'h0;
      key_we        = 1'h0;
      block_we      = 1'h0;

      if (cs)
        begin
          if (we)
            begin
              case (addr)
                ADDR_CTRL:
                  begin
                    init_new     = write_data[CTRL_INIT_BIT];
                    next_new     = write_data[CTRL_NEXT_BIT];
                    finalize_new = write_data[CTRL_FINALIZE_BIT];
                  end

                ADDR_ROUNDS:
                  num_rounds_we = 1'h1;

                ADDR_FINAL_LEN:
                  final_len_we  = 1'h1;
                default:
                  begin
                  end
              endcase // case (addr)

              if ((addr >= ADDR_KEY0) && (addr <= ADDR_KEY3))
                  key_we = 1'h1;

              if ((addr >= ADDR_BLOCK0) && (addr <= ADDR_BLOCK3))
                block_we = 1'h1;
            end

          else
            begin
              case (addr)
                ADDR_NAME0:
                  tmp_read_data = CORE_NAME0;

                ADDR_NAME1:
                  tmp_read_data = CORE_NAME1;

                ADDR_VERSION:
                  tmp_read_data = CORE_VERSION;

                ADDR_STATUS:
                  tmp_read_data = {31'h0, core_ready};

                ADDR_ROUNDS:
                  tmp_read_data = {28'h0, num_rounds_reg};

                default:
                  begin
                  end
              endcase // case (addr)

              if ((addr >= ADDR_TAG0) && (addr <= ADDR_TAG3))
                tmp_read_data = core_tag[(3 - (addr - ADDR_TAG0)) * 32 +: 32];
            end
        end
    end

endmodule // chaskey

//======================================================================
// EOF chaskey.v
//======================================================================
