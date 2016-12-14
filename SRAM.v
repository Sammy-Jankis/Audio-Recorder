module	SRAM(
	
	clk,
	reset,
	
	//Simplified Variables
	chipselect_n,
	byteenable_n,
	write_n,
	read_n,
	address,
	writedata,
	readdata,
	
	// SRAM Ports
	SRAM_DQ,
	SRAM_ADDR,
	SRAM_UB_n,
	SRAM_LB_n,
	SRAM_WE_n,
	SRAM_CE_n,
	SRAM_OE_n
);

parameter DATA_BITS		= 16;
parameter ADDR_BITS		= 20;

input								clk;
input								reset;

input								chipselect_n;
input	[(DATA_BITS/8-1):0]	byteenable_n;
input								write_n;
input								read_n;
input	[(ADDR_BITS-1):0]		address;
input	[(DATA_BITS-1):0]		writedata;
output	[(DATA_BITS-1):0]	readdata;

output							SRAM_CE_n;
output							SRAM_OE_n;
output				 			SRAM_LB_n;
output				 			SRAM_UB_n;
output							SRAM_WE_n;
output	[(ADDR_BITS-1):0]	SRAM_ADDR;
inout	[(DATA_BITS-1):0]		SRAM_DQ;

assign	SRAM_DQ 						=	SRAM_WE_n ? 'hz : writedata;
assign	readdata						=	SRAM_DQ;
assign	SRAM_ADDR					=	address;
assign	SRAM_WE_n					=	write_n;
assign	SRAM_OE_n					=	read_n;
assign	SRAM_CE_n					=	chipselect_n;
assign	{SRAM_UB_n,SRAM_LB_n}	=	byteenable_n;

endmodule