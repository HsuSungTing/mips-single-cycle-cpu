
module test_cpu;
	
	reg reset;
	reg clk;
	
	CPU cpu1(reset, clk);
	
	initial begin
	    reset = 0;//added
		#10reset = 1; clk = 1;
		#20 reset = 0;
	end
	
	always #40 clk = ~clk;
		
endmodule
