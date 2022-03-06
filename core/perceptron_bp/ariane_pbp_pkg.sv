/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File:   ariane_pkg.sv
 * Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
 * Date:   8.4.2017
 *
 * Description: Contains all the necessary defines for Ariane
 *              in one package.
 */

// this is needed to propagate the
// configuration in case Ariane is
// instantiated in OpenPiton
`ifdef PITON_ARIANE
  `include "l15.tmp.h"
`endif

package ariane_pbp_pkg;

    // perceptron branch predictor
    // this is the struct we get back from ex stage and we will use it to update
    // all the necessary data structures
    // bp_resolve_t
    typedef struct packed {
        logic                   valid;           // prediction with all its values is valid
        logic [riscv::VLEN-1:0] pc;              // PC of predict or mis-predict
        logic [riscv::VLEN-1:0] target_address;  // target address at which to jump, or not
        logic                   is_mispredict;   // set if this was a mis-predict
        logic                   is_taken;        // branch is taken
        cf_t                    cf_type;         // Type of control flow change
    } bp_resolve_t;

    typedef struct packed {
        logic                   valid;
        logic [riscv::VLEN-1:0] pc;             // update at PC
        logic [riscv::VLEN-1:0] target_address;
    } btb_update_t;

    typedef struct packed {
        logic                   valid;
        logic [riscv::VLEN-1:0] target_address;
    } btb_prediction_t;

    typedef struct packed {
        logic                   valid;
        logic [riscv::VLEN-1:0] ra;
    } ras_t;

    typedef struct packed {
        logic                   valid;
        logic [riscv::VLEN-1:0] pc;          // update at PC
        logic                   taken;
    } bht_update_t;

    typedef struct packed {
        logic       valid;
        logic       taken;
    } bht_prediction_t;

endpackage
