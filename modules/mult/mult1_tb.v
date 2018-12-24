`timescale 1 ns / 100 ps

module mult1_tb;
  reg clk_tb;
  reg rst_tb;
  reg start_tb;
  reg ack_tb;
  reg [31:0] multiplicand_tb;
  reg [31:0] multiplier_tb;
  wire [63:0] product_tb;

parameter CLK_PERIOD = 20;

// Instantiate the UUT
mult1 UUT (
  clk_tb,
  rst_tb,
  start_tb,
  ack_tb,
  multiplicand_tb,
  multiplier_tb,
  product_tb
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
  multiplicand_tb = 10;
  multiplier_tb = 3;
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
