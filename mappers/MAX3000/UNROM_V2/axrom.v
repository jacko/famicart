module axrom
(
	input romsel,
	input cpu_rw,
	input m2,
	input [4:0] cpu_data,
	input ppu_addr_10,
	input cpu_addr_14,

	output reg [17:14] prg_addr,
	output reg ciram_a10,
	output prg_ce,
	output prg_oe,
	output prg_we,
	output power_led
);

	// common register
	reg [2:0] r0;

	assign power_led = 1'b1;
	assign prg_ce = romsel;
	assign prg_oe = romsel | !cpu_rw;
	assign prg_we = romsel | cpu_rw;

	always @ (negedge m2)
	begin
		if (cpu_rw == 0 && romsel == 0)
			r0 <= cpu_data[2:0];
	end

	always @ (*)
	begin
		if(romsel == 0)
			prg_addr[17:14] = cpu_addr_14 ? 4'b0111 : {1'b0, r0[2:0]};
			
		ciram_a10 = ppu_addr_10;	
	end

endmodule