// shift register with write all - shift left
module shiftreg #(parameter bus_width = 32)
                (   input   clk, reset, we, se,
                    input   shiftin,
                    input   [bus_width-1:0] datain
                    output  [bus_width-1:0] out);
                    
    reg [bus_width-1:0] data;
    assign out = data;

    always @(posedge clk, posedge reset) begin
        if(reset) data <= 0;
        else if(we) data <= datain;
        else if(se) data <= {data[bus_width-2:0], shiftin};
    end

endmodule