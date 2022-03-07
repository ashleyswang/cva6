// Copyright 2018 - 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.


// perceptron branch predictor - indexable table mapping pc to weight vector
module pbp #(
    parameter int unsigned NR_ENTRIES = 1024 
    parameter int unsigned GHR_LENGTH = 10
)(
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic                        flush_i,
    input  logic                        debug_mode_i,
    input  logic [riscv::VLEN-1:0]      vpc_i,
    input  ariane_pkg::pbp_update_t     pbp_update_i,
    // we potentially need INSTR_PER_FETCH predictions/cycle
    output ariane_pkg::bht_prediction_t [ariane_pkg::INSTR_PER_FETCH-1:0] bht_prediction_o
);
    // indexable perceptron table
    logic [GHR_LENGTH-1:0]  perceptron_table  [NR_ENTRIES-1:0];

    logic c_shift_en, c_shift_i;
    logic [GHR_LENGTH-1:0] c_data;

    logic s_shift_en, s_shift_i; 
    logic [GHR_LENGTH-1:0] s_data;

    logic y_frontend, y_instrdec, y_issue, y_exec;
    int outcome;

    // committed global history register
    shift_reg #(
      .bus_width      ( GHR_LENGTH     )  
    ) c_ghr (
      .clk_i,
      .rst_ni,
      .write_en       ( 1'b0           ), 
      .shift_en       ( ~pbh_update_i.is_mispredict & pbp_update_i.valid ), 
      .shift_i        ( ~pbh_update_i.is_mispredict & y_exec             ),  // = branched or not branched 
      .data_i         ( 'b0            ),
      .data_o         ( c_data         )       
    );
    
    // speculative global history register
    shift_reg #(
      .bus_width      ( GHR_LENGTH )  
    ) s_ghr (
      .clk_i,
      .rst_ni,
      .write_en       ( pbp_update_i.is_mispredict ), 
      .shift_en       ( 1'b1       ), 
      .shift_i        ( y_frontend ),             // = branched or not branched 
      .data_i         ( c_data     ),
      .data_o         ( s_data     )       
    );
    
    // hash for index and get perceptron
    assign d_index = vpc_i % NR_ENTRIES;
    assign d_perceptron = perceptron_table[d_index];
   
    // prediction assignment
    assign bht_prediction_o.taken = y_frontend;
    
    // initial
    initial begin
      y_frontend = 0;
    end

    // make prediction
    always_ff @(posedge clk) begin
      // pipeline through rest of the stages
      y_exec = y_issue;
      y_issue = y_instrdec;
      y_instrdec = y_frontend;
      // bias
      outcome = d_perceptron[0]
      // dependent terms
      for (int i = 1; i < GHR_LENGTH; i++) begin : gen_pbp_output
        if (s_data[i])
          outcome += d_perceptron[i];
        else 
          outcome -= d_perceptron[i];
      end
      y_frontend = (outcome > 0);
    end
    
    // update perceptron
    always_ff @(posedge clk) begin : update_perceptron
      // gate with (is valid branch?)
      if (pbp_update_i.valid && !debug_mode_i) begin
        // if t == xi (6.Training)
        upd_mask = pbp_update_i.is_mispredict ? c_data : ~c_data;
        // rehash for index
        e_index = pbp_update_i.pc % NR_ENTRIES;
        // update weights (6.Training)
        for (int i = 0; i < GHR_LENGTH; i++) begin
          if (upd_mask[i])
            perceptron_table[e_index][i] += 1;
          else 
            perceptron_table[e_index][i] -= 1;
        end
      end
    end

endmodule