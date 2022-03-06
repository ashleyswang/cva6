// Copyright 2018 - 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Florian Zaruba, ETH Zurich
// Date: 08.02.2018
// Migrated: Luis Vitorio Cargnini, IEEE
// Date: 09.06.2018

// perceptron branch predictor - indexable table mapping pc to weight vector
module pbp #(
    parameter int unsigned GHR_LENGTH = 10,
    parameter int unsigned NR_ENTRIES = 1024 
)(
    input  logic                        clk_i,              // clock input
    input  logic                        rst_ni,             // reset input
    input  logic                        flush_i,            // flush input
    input  logic                        debug_mode_i,
    input  logic [riscv::VLEN-1:0]      vpc_i,              // program counter bits - decode

    // input  ariane_pkg::pbp_update_t     pbp_update_i,       // previous bht result with (valid - correctness?, update at PC, taken/not taken)
    input  logic                        valid,            // is this a valid branch - execute
    input  logic [riscv::VLEN-1:0]      pc,                 // update at pc (pc for feedback) - execute
    input  logic                        is_mispredict,      // is mispredict - execute
    input  logic [GHR_LENGTH-1:0]       history,

    // DON'T FORGET TO CHANGE BACK TO ARRAY 
    output ariane_pkg::bht_prediction_t bht_prediction_o
);
    // indexable perceptron table
    logic [GHR_LENGTH-1:0]  perceptron_table  [NR_ENTRIES-1:0];

    logic c_shift_en;
    logic c_shift_i;
    logic [GHR_LENGTH-1:0] c_data;

    logic s_shift_en;
    logic s_shift_i; 
    logic [GHR_LENGTH-1:0] s_data;
    
    // committed global history register
    shift_reg #(
      .length           ( GHR_LENGTH )  
    ) c_ghr (
      .clk              ( clk_i      ),
      .reset            ( rst_ni     ),
      .we               ( 1'b0       ), 
      .se               ( c_shift_en ), 
      .shift_in         ( c_shift_i  ),
      .data_in          ( 'b0        ),
      .out              ( c_data     )       
    );
    
    // speculative global history register
    shift_reg #(
      .length           ( GHR_LENGTH )
    ) s_ghr (
      .clk              ( clk_i      ),
      .reset            ( rst_ni     ),
      .we               ( pbp_update_i.is_mispredict ), 
      .se               ( s_shift_en ),  
      .shift_in         ( s_shift_i  ), 
      .data_in          ( c_data     ), 
      .out              ( s_data     )     
    );
    
    // get perceptron for pc
    assign d_index = vpc_i % NR_ENTRIES;
    assign d_perceptron = perceptron_table[d_index];
   
    // prediction assignment 
    assign bht_prediction_o.taken = outcome;
    always_ff @(posedge clk) begin
      outcome = 0;
      for (int i = 0; i < GHR_LENGTH; i++) begin : gen_pbp_output
        if (s_data[i])
          outcome += d_perceptron[i];
        else 
          outcome -= d_perceptron[i];
      end
    end
    
    // update perceptron
    always_ff @(posedge clk) begin : update_perceptron
      if (pbp_update_i.valid && !debug_mode_i) begin
        upd_mask = pbp_update_i.is_mispredict ? ~pbp_update_i.history 
                                              : pbp_update_i.history;
        e_index = pbp_update_i.pc % NR_ENTRIES;        
        for (int i = 0; i < GHR_LENGTH; i++) begin
          if (upd_mask[i])
            perceptron_table[e_index] += 1;
          else 
            perceptron_table[e_index] -= 1;
        end
      end
    end

endmodule