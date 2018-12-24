`timescale 1 ns / 100 ps

module div_tb;
  reg clk_tb;
  reg rst_tb;
  reg start_tb;
  reg ack_tb;
  reg [63:0] dividend_tb;
  reg [31:0] divisor_tb;
  wire [31:0] quotient_tb;
  wire [63:0] remainder_tb;

parameter CLK_PERIOD = 20;

// Instantiate the UUT
div UUT (
  clk_tb,
  rst_tb,
  start_tb,
  ack_tb,
  dividend_tb,
  divisor_tb,
  quotient_tb,
  remainder_tb
  );

//RST_GENERATOR
initial
  begin
    rst_tb = 1;
    #(2 * CLK_PERIOD) rst_tb = 0;
  end

//CLK_GENERATOR
initial
  begin  : CLK_GENERATOR
    clk_tb = 0;
    forever
       begin
        #(CLK_PERIOD/2) clk_tb = ~clk_tb;
       end 
  end

// APPLYING STIMULUS
initial
begin
  $dumpfile("simluation.vcd");
  $dumpvars;

  rst_tb = 0;
  dividend_tb = 10;
  divisor_tb = 3;
  start_tb = 0;
  ack_tb = 0;

  rst_tb = 1;
  #(2 * CLK_PERIOD);
  rst_tb = 0;

  //@(posedge clk_tb);
  #(2 * CLK_PERIOD);  // a little (2ns) after the clock edge
  start_tb = 1;   // After a little while provide START
  //@(posedge clk_tb); // After waiting for a clock
  #(2 * CLK_PERIOD);
  start_tb = 0; // After a little while remove START
end

endmodule
