module	Reset_Delay(
input CLK, 
output reg RESET
);


reg	[19:0] Cont;

//Delay for AV
always@(posedge CLK)
begin
	if(Cont != 20'hFFFFF)
	begin
		Cont		<=	Cont + 1'b1;
		RESET	<=	1'b0;
	end
	else
	RESET		<=	1'b1;
end

endmodule