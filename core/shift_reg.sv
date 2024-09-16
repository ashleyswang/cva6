// shift register with write all - shift left
module shift_reg #(
    parameter bus_width = 32
) (   
  input   logic             clk_i, 
  input   logic             rst_ni, 
  input   logic             write_en, 
  input   logic             shift_en,
  input   logic             shift_i,    // bit to shift in
  input   [bus_width-1:0]   data_i
  output  [bus_width-1:0]   data_o
);
                    
  reg [bus_width-1:0] data;
  assign data_o = data;

  always @(posedge clk_i, posedge rst_ni) begin
    if(rst_ni) data <= 0;
    else if(write_en) data <= data_i;
    else if(shift_en) data <= {data[bus_width-2:0], shift_i};
  end

endmodule