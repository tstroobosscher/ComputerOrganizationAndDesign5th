`timescale 1 ns / 100 ps

module float_add_tb;
  reg clk_tb;
  reg rst_tb;
  reg start_tb;
  reg ack_tb;
  reg [31:0] fl_in_1_tb;
  reg [31:0] fl_in_2_tb;
  wire [31:0] res_tb;

parameter CLK_PERIOD = 20;

// Instantiate the UUT
float_add UUT (
  clk_tb,
  rst_tb,
  start_tb,
  ack_tb,
  fl_in_1_tb,
  fl_in_2_tb,
  res_tb
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
  $dumpfile("simulation.vcd");
  $dumpvars;

  rst_tb = 0;

  // 0.5
  fl_in_1_tb = {1'b0, 8'b01111110, 23'b0};

  // 0.125
  fl_in_2_tb = {1'b0, 8'b01111100, 23'b0};

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
