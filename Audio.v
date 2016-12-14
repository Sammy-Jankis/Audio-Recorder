module Audio(
	input CLOCK_50,		//FPGA Clock
	input CLOCK_27,		//Clock for division in PLL
	input RST, 				//RESET
	inout I2C_SDAT,		//I2C Data
	output I2C_SCLK,		//I2C Clock
	output AUD_ADCLRCK,	//ADC CODEC Clock
	input AUD_ADCDAT,		//ADC CODEC Data
	output AUD_DACLRCK,	//DAC CODEC Clock
	output AUD_DACDAT,	//DAC CODEC Data
	inout AUD_BCLK,		//CODEC Bit-rate Clock
	output AUD_XCK,		//CODEC Clock
	
	//SRAM PORTS
	output SRAM_CE_n,
	output SRAM_OE_n,
	output SRAM_LB_n,
	output SRAM_UB_n,
	output SRAM_WE_n,
	output [19:0] SRAM_ADDR,
	inout [15:0] SRAM_DQ,
	
	//Audio and interface ports
	output reg [15:0] audio_inR, audio_inL,
	input REC,											//Toggle Recording
	input PB,
	input HIGH, LOW, RUN_THRU, STOP,
	output reg [3:0] LED
	);
	
	//Registers and wires
	reg 			chipselect_n;
	reg 			write_n;
	reg 			read_n;
	reg [19:0]	address;
	reg [15:0] 	writedata;
	wire [15:0] readdata;
	reg [3:0] 	SEL_Cont;
	reg 			LRCK_DLY;
	reg 			ADC_STBR, ADC_STBL;
	reg [3:0]	S;
	reg 			REC_DLY, RUN_THRU_DLY, STOP_DLY, PB_DLY, HIGH_DLY, LOW_DLY; 	//Delays for Strobes
	reg [1:0]	LOWCHECK; 																		//LOWCHECK for Halfspeed SRAM address incrementation
	
	//Parameters for state machine
	parameter IDLE = 4'b0000;
	parameter LEFT = 4'b0001;
	parameter READ_IDLE = 4'b0010;
	parameter DACL =  4'b0011;
	parameter DACR = 4'b0100;
	parameter READ_IDLEH = 4'b0101;
	parameter DACLH = 4'b0110;
	parameter DACRH = 4'b0111;
	parameter READ_IDLEL = 4'b1000;
	parameter DACLL = 4'b1001;
	parameter DACRL = 4'b1010;
	parameter RIGHT = 4'b1011;
	parameter RUN   = 4'b1100;
	parameter RUNL  = 4'b1101;
	parameter RUNR  = 4'b1111;
	
	wire DLY_RST;
	
	Reset_Delay inst0(	
		.CLK(CLOCK_50),
		.RESET(DLY_RST) 
);	
	
	wire AUD_LRCK;
	
	assign	AUD_ADCLRCK	= AUD_DACLRCK;		//Tie DAC and ADC Clocks
	assign	AUD_XCK		=	AUD_CTRL_CLK;	//Assign CODEC clock using PLL output
	
	VGA_Audio_PLL 	inst1(	
	.areset(~DLY_RST),
	.inclk0(CLOCK_27),
	.c0(VGA_CTRL_CLK),
	.c1(AUD_CTRL_CLK),
	.c2(VGA_CLK)
); 
		
	I2C_Config inst2(
		.CLK(CLOCK_50),
		.RST(RST),
		
		.I2C_SCLK(I2C_SCLK),
		.I2C_SDAT(I2C_SDAT)
		);
	
	audio_clock inst3(
		.AUD_BCK(AUD_BCLK),
		.AUD_LRCK(AUD_DACLRCK),
		
		.CLK_18_4(AUD_CTRL_CLK),
		.RST(DLY_RST)
		);
		
	reg [15:0] audio_outL, audio_outR;
	
	SRAM inst4(
	
	//Simplified variables
	.clk(CLOCK_50),
	.reset(RST),
	.chipselect_n(chipselect_n),
	.byteenable_n(2'b00),
	.write_n(write_n),
	.read_n(read_n),
	.address(address),
	.writedata(writedata),
	.readdata(readdata),
	
	//SRAM variables
	.SRAM_DQ(SRAM_DQ),
	.SRAM_ADDR(SRAM_ADDR),
	.SRAM_UB_n(SRAM_UB_n),
	.SRAM_LB_n(SRAM_LB_n),
	.SRAM_WE_n(SRAM_WE_n),
	.SRAM_CE_n(SRAM_CE_n),
	.SRAM_OE_n(SRAM_OE_n)
	);

//Audio In
always@(negedge AUD_BCLK or negedge RST)
begin
	if(!RST) SEL_Cont <= 4'h0;
	else
	begin
	   SEL_Cont <= SEL_Cont+1'b1; 
	   if (AUD_DACLRCK) 
			audio_inL[~(SEL_Cont)] <= AUD_ADCDAT; //Fill audio_inL with line in data
	   else 
			audio_inR[~(SEL_Cont)] <= AUD_ADCDAT; //Fill audio_inR with line in data
	end
end

//LR Strobes
always @ (posedge CLOCK_50 or negedge RST)
begin
	if(!RST)
	begin
		//Set Strobes to 0
		LRCK_DLY <= 0;	
		ADC_STBR <= 0;
		ADC_STBL <= 0;
	end
	else
	begin
		LRCK_DLY <= AUD_DACLRCK;
		ADC_STBR <= 0;
		ADC_STBL <= 0;
		if((LRCK_DLY == 0) && (AUD_DACLRCK == 1))
		begin
			ADC_STBL <= 1;	//If LR Clock goes low to high
		end
		if((LRCK_DLY == 1) && (AUD_DACLRCK == 0))
		begin
			ADC_STBR <= 1;	//If LR Clock goes high to low
		end
	end
end
	
//Switch/FX interface and SRAM read/write
always @ (posedge CLOCK_50 or negedge RST)
begin
	if(!RST)
	begin
		address			<= 0;
		write_n 			<= 1;
		chipselect_n 	<= 1;
		writedata 		<= 0;
		audio_outR 		<= 0;
		audio_outL 		<= 0;
		LED [0] 			<= 0;
		LED [1] 			<= 0;
		LED [2]			<= 0;
		S 					<= IDLE;
	end
	else
	begin
	//Strobes
		write_n 			<= 1;			
		chipselect_n 	<= 1;		
		read_n 			<= 1;				
		REC_DLY 			<= REC;			
		PB_DLY 			<= PB;
		STOP_DLY 		<= STOP;
		RUN_THRU_DLY 	<= RUN_THRU;
		
		case(S)
			IDLE: 
			begin
				address <= 0;
				//Recording
				if((REC == 0) && (REC_DLY == 1) && (PB == 1) && (HIGH == 0) && (LOW == 0))
				begin
					LED [0]	<= 1;
					S 			<= LEFT;
				end
				
				//Playback Normal
				if((REC == 1) && (PB == 0) && (PB_DLY == 1) && (HIGH == 0) && (LOW == 0))
				begin
					S 			<= READ_IDLE;
					LED [1]	<= 1;
				end
					
				//Playback Highspeed
				if((PB == 0) && (PB_DLY == 1) && (HIGH == 1) && (LOW == 0) && (REC == 1))
				begin
					S 			<= READ_IDLEH;
					LED [1]	<= 1;
				end
					
				//Playback Halfspeed
				if((PB == 0) && (PB_DLY == 1) && (HIGH == 0) && (LOW == 1) && (REC == 1))
				begin
					S 			<= READ_IDLEL;
					LED [1]	<= 1;
				end
					
				//Pass Thru
				if((RUN_THRU == 0) && (RUN_THRU_DLY == 1) && (PB == 1))
				begin
					S 			<= RUN;
					LED [2]	<= 1;
				end
			end
			
			//Left channel recording
			LEFT: 
			begin
				if(ADC_STBL == 1) 
				begin
					write_n 			<= 0;
					chipselect_n 	<= 0;
					writedata 		<= audio_inL;
					S 					<= RIGHT;
					if(address != 0)
					begin
						if(address == 20'hFFFFF)
						begin
							S 			<= IDLE;
							LED [0] 	<= 0;
							REC_DLY 		<= 1;
						end
						else
							address <= address + 1;
					end
				end
			end
			
			//Right channel recording
			RIGHT: 
			begin
				if(ADC_STBR == 1)
				begin
					write_n 			<= 0;
					chipselect_n 	<= 0;
					writedata 		<= audio_inR;
					S 					<= LEFT;
					if(address == 20'hFFFFF)
					begin
						S 			<= IDLE;
						LED [0] 	<= 0;
						REC_DLY 	<= 1;
					end
					else
						address <= address + 1;
				end
			end
			
			//Normal Read_Idle
			READ_IDLE: 
			begin
				if(ADC_STBL == 1)
				begin
					read_n 			<= 0;
					chipselect_n 	<= 0;
					S 					<= DACL;
				end
				if(ADC_STBR == 1)
				begin
					read_n 			<= 0;
					chipselect_n 	<= 0;
					S 					<= DACR;
				end
			end
			
			//Normal Read Left Channel
			DACL: begin
				audio_outL <= readdata;
				if(address == 20'hFFFFF)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
					PB_DLY	<= 1;
				end
				else
				begin	
					address <= address + 1;
					S <= READ_IDLE;
				end
			end
			
			//Normal Read Right Channel
			DACR: 
			begin
				audio_outR <= readdata;
				if(address == 20'hFFFFF)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
					PB_DLY	<= 1;
				end
				else
				begin
					address <= address + 1;
					S <= READ_IDLE;
				end
			end
			
			//Highspeed Read_Idle
			READ_IDLEH: 
			begin
				if(ADC_STBL == 1)
				begin
					read_n 			<= 0;
					chipselect_n 	<= 0;
					S 					<= DACLH;
				end
				if(ADC_STBR == 1)
				begin
					read_n 			<= 0;
					chipselect_n 	<= 0;
					S 					<= DACRH;
				end
			end
			
			//Highspeed Read Left Channel
			DACLH: 
			begin
				audio_outL <= readdata;
				if(address == 20'hFFFFF)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
					PB_DLY	<= 1;
				end
				else
				begin	
					address <= address + 1;
					S <= READ_IDLEH;
				end
			end
			
			//Highspeed Read Right Channel
			DACRH: 
			begin
				audio_outR <= readdata;
				if(address >= 20'hFFFFD)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
					PB_DLY	<= 1;
				end
				else
				begin
					address <= address + 2'b11;	//Skip 3 address bits for double time
					S <= READ_IDLEH;
				end
			end
			
			//Halfspeed Read_Idle
			READ_IDLEL: 
			begin
				if(ADC_STBL == 1)
				begin
					read_n 			<= 0;
					chipselect_n 	<= 0;
					S 					<= DACLL;
				end
				if(ADC_STBR == 1)
				begin
					read_n 			<= 0;
					chipselect_n	<= 0;
					S					<= DACRL;
				end
			end
			
			//Halfspeed Read Left Channel
			DACLL: 
			begin
				audio_outL <= readdata;
				if(address == 20'hFFFFF)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
				end
				else
				begin	
					address 	<= address + 1;
					S 			<= READ_IDLEL;
				end
			end
			
			//Halfspeed Read Right Channel
			DACRL: 
			begin
				audio_outR <= readdata;
				if(address == 20'hFFFFF)
				begin
					S 			<= IDLE;
					LED [1] 	<= 0;
				end
				else
				begin
					if(LOWCHECK == 1)
					begin
						address 	<= address + 1;
						LOWCHECK <= 0;
					end
					else
					begin
						address 	<= address - 1;	//Use LOWCHECK to detrmine if bits have been repeated; if not, then repeat last pair for halfspeed
						LOWCHECK <= 1;
					end
					S <= READ_IDLEL;
				end
			end
			
			//Pass Thru
			RUN:
			begin
				if(ADC_STBL)
					audio_outL 	<= audio_inL;
				if(ADC_STBR)
					audio_outR 	<= audio_inR;
				if((STOP == 0) && (STOP_DLY == 1))
				begin
					S 				<= IDLE;
					LED [2] 		<= 0;
				end
				if((REC == 0) && (REC_DLY == 1) && (PB ==1) && (PB_DLY == 1))
				begin
					S 				<= RUNL;
					LED [0] 		<= 1;
				end
			end
			
			//Left channel recording during pass thru
			RUNL: 
			begin
				if(ADC_STBL == 1) 
				begin
					write_n 			<= 0;
					chipselect_n 	<= 0;
					writedata 		<= audio_inL;
					audio_outL 		<= audio_inL;
					S 					<= RUNR;
					if(address != 0)
					begin
						if(address == 20'hFFFFF)
						begin
							S 			<= RUN;
							LED [0] 	<= 0;
						end
						else
							address 	<= address + 1;
					end
				end
			end
			
			//Right channel recording during pass thru
			RUNR: 
			begin
				if(ADC_STBR == 1)
				begin
					write_n 			<= 0;
					chipselect_n 	<= 0;
					writedata 		<= audio_inR;
					audio_outR 		<= audio_inR;
					S 					<= RUNL;
					if(address == 20'hFFFFF)
					begin
						S 				<= RUN;
						LED [0] 		<= 0;
					end
					else
						address 		<= address + 1;
				end
			end
		endcase
	end
end

//Audio Out
assign AUD_DACDAT = (AUD_DACLRCK)? audio_outL[~SEL_Cont]: audio_outR[~SEL_Cont] ;


endmodule
