// shift register with write all - shift left
module shift_reg #(parameter length = 32)
                (   input   clk, reset, we, se,
                    input   shift_in,
                    input   [length-1:0] data_in
                    output  [length-1:0] out);
                    
    reg [length-1:0] data;
    assign out = data;

    always @(posedge clk, posedge reset) begin
        if(reset) data <= 0;
        else if(we) data <= data_in;
        else if(se) data <= {data[length-2:0], shift_in};
    end

endmodule