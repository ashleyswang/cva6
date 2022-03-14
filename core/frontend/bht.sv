// perceptron branch predictor - indexable table mapping pc to weight vector
module bht #(
    parameter int unsigned GHR_LENGTH = 10,
    parameter int unsigned NR_ENTRIES = 1024,
    parameter int signed THRESHOLD = 3
)(
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic                        flush_i,
    input  logic                        debug_mode_i,
    input  logic [ariane_pkg::INSTR_PER_FETCH-1:0]  is_branch_i,
    input  logic [riscv::VLEN-1:0]      vpc_i,
    input  ariane_pkg::bht_update_t     bht_update_i,
    // we potentially need INSTR_PER_FETCH predictions/cycle
    output ariane_pkg::bht_prediction_t [ariane_pkg::INSTR_PER_FETCH-1:0] bht_prediction_o
);

    logic [$clog2(NR_ENTRIES)-1:0]  index_p, index_u;
    logic [$clog2(ariane_pkg::INSTR_PER_FETCH-1)-1:0] rindex_u;

    logic signed [31:0] outcome [ariane_pkg::INSTR_PER_FETCH-1:0];
    logic [GHR_LENGTH-1:0] ghr_d_spec, ghr_q_spec, ghr_d_comm, ghr_q_comm, upd_mask;
    logic signed [GHR_LENGTH-1:0][31:0] perceptron_block;
    logic signed [31:0] perceptron_bias;
    
    struct packed {
        logic                                   valid;
        logic signed [GHR_LENGTH-1:0][31:0]     perceptron_weights;
        logic signed [31:0]                     bias;
    } pbp_d[NR_ENTRIES-1:0][ariane_pkg::INSTR_PER_FETCH-1:0], pbp_q[NR_ENTRIES-1:0][ariane_pkg::INSTR_PER_FETCH-1:0];

    assign index_p = (vpc_i >> 2) % NR_ENTRIES;
    assign index_u = (bht_update_i.pc >> 2) % NR_ENTRIES;
    assign rindex_u = bht_update_i.pc [1];
    assign upd_mask = bht_update_i.taken ? ghr_q_comm : ~ghr_q_comm;

    for (genvar i = 0; i < ariane_pkg::INSTR_PER_FETCH; i++) begin : gen_output
        assign bht_prediction_o[i].valid = 1'b1;
        assign bht_prediction_o[i].taken = (outcome[i] > 0);
    end

    always_comb begin
        pbp_d = pbp_q;
        ghr_d_spec = ghr_q_spec;
        ghr_d_comm = ghr_q_comm;
        perceptron_block = pbp_q[index_u][rindex_u].perceptron_weights;
        perceptron_bias = pbp_q[index_u][rindex_u].bias;

        if (bht_update_i.valid && !debug_mode_i) begin
            // shift in resolved branch result into committed global history buffer
            for (int unsigned i = 1; i < GHR_LENGTH; i++) begin
                ghr_d_comm[i] = ghr_q_comm[i-1];
            end
            ghr_d_comm[0] = bht_update_i.taken;

            // update weights and bias in perceptron
            for (int unsigned i = 0; i < GHR_LENGTH; i++) begin
                if (upd_mask[i])
                    pbp_d[index_u][rindex_u].perceptron_weights[i] = (perceptron_block[i] >= THRESHOLD) ? THRESHOLD : perceptron_block[i] + 1;
                else
                    pbp_d[index_u][rindex_u].perceptron_weights[i] = (perceptron_block[i] <= -THRESHOLD) ? -THRESHOLD : perceptron_block[i] - 1;
            end
            if (bht_update_i.taken)
                pbp_d[index_u][rindex_u].bias = (perceptron_bias >= THRESHOLD) ? THRESHOLD : perceptron_bias + 1;
            else
                pbp_d[index_u][rindex_u].bias = (perceptron_bias <= THRESHOLD) ? THRESHOLD : perceptron_bias - 1;
            
            if (bht_update_i.mispredict)
                ghr_d_spec = ghr_d_comm;
        end

        for (int unsigned i = 0; i < ariane_pkg::INSTR_PER_FETCH; i++) begin
            outcome[i] = pbp_q[index_p][i].bias;
            for (int unsigned j = 0; j < GHR_LENGTH; j++) begin
                if (ghr_q_spec[j])
                    outcome[i] += pbp_q[index_p][i].perceptron_weights[j];
                else
                    outcome[i] -= pbp_q[index_p][i].perceptron_weights[j];
            end
            if (is_branch_i[i]) begin
                for (int unsigned j = 1; j < GHR_LENGTH; j++) begin
                    ghr_d_spec[j] = ghr_q_spec[j-1];
                end
                ghr_d_spec[0] = (outcome[i] > 0);
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni || flush_i) begin
            for (int unsigned i = 0; i < NR_ENTRIES; i++) begin
                for (int unsigned j = 0; j < ariane_pkg::INSTR_PER_FETCH; j++) begin
                    pbp_q[i][j] = '0;
                end
            end
            ghr_q_comm <= '0;
            ghr_q_spec <= '0;
        end else begin
            pbp_q <= pbp_d;
            ghr_q_comm <= ghr_d_comm;
            ghr_q_spec <= ghr_d_spec;
        end
    end
endmodule