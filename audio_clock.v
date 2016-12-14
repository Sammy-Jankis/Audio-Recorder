module audio_clock (	
   output reg AUD_BCK,
   output AUD_LRCK,
   input CLK_18_4,
   input RST
);				

//Parameters for Clock
parameter	REF_CLK		=	18432000;	// 18.432 MHz
parameter	SAMPLE_RATE	=	48000;		// 48 KHz
parameter	DATA_WIDTH	=	16;			// 16 Bits
parameter	CHANNEL_NUM	=	2;				// Dual Channel


//Registers
reg [3:0] BCK_DIV;
reg [8:0] LRCK_1X_DIV;
//Optional different frequencies
reg [7:0] LRCK_2X_DIV;
reg [6:0] LRCK_4X_DIV;
//Used Clock
reg LRCK_1X;
//Unused Clocks
reg LRCK_2X;
reg LRCK_4X;


//AUD_BCK
always@(posedge CLK_18_4 or negedge RST)
begin
	if(!RST)
	begin
	  BCK_DIV <= 4'h0;
	  AUD_BCK <= 1'b0;
	end
	else
	begin
	  if (BCK_DIV >= REF_CLK/(SAMPLE_RATE*DATA_WIDTH*CHANNEL_NUM*2)-1 )
	  begin
		BCK_DIV		<= 4'h0;
		AUD_BCK 		<= ~AUD_BCK;
	  end
	  else BCK_DIV <= BCK_DIV+1'b1;
	end
end

//  AUD_LRCK
always@(posedge CLK_18_4 or negedge RST)
begin
	if(!RST)
	begin
		LRCK_1X_DIV	<=	0;
		LRCK_2X_DIV	<=	0;
		LRCK_4X_DIV	<=	0;
		LRCK_1X		<=	0;
		LRCK_2X		<=	0;
		LRCK_4X		<=	0;
	end
	else
	begin
	
		//LRCK 1X
		if(LRCK_1X_DIV >= REF_CLK/(SAMPLE_RATE*2)-1 )
		begin
			LRCK_1X_DIV <=	0;
			LRCK_1X	<= ~LRCK_1X;
		end
		else LRCK_1X_DIV <= LRCK_1X_DIV+1'b1;
		
		
		// LRCK 2X
		if(LRCK_2X_DIV >= REF_CLK/(SAMPLE_RATE*4)-1 )
		begin
			LRCK_2X_DIV <= 0;
			LRCK_2X	<= ~LRCK_2X;
		end
		else LRCK_2X_DIV <= LRCK_2X_DIV+1'b1;		
		// LRCK 4X
		if(LRCK_4X_DIV >= REF_CLK/(SAMPLE_RATE*8)-1 )
		begin
			LRCK_4X_DIV <= 0;
			LRCK_4X	<= ~LRCK_4X;
		end
		else LRCK_4X_DIV <= LRCK_4X_DIV+1'b1;		
	end
end

assign	AUD_LRCK = LRCK_1X;

endmodule
			
					

