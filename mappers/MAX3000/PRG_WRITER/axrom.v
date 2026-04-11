module axrom
(
	input romsel,
	input cpu_rw,
	input m2,
	input [4:0] cpu_data,
	input ppu_addr_10,
	input cpu_addr_14,

	output [17:15] prg_addr,
	output prg_addr_14,
	output reg ciram_a10,
	output prg_ce,
	output prg_oe,
	output prg_we,
	output power_led
);

	reg [2:0] r0;

	assign power_led = 1'b1;
	assign prg_addr_14 = cpu_addr_14; // A14 passthrough
	assign prg_ce = romsel;
	assign prg_oe = romsel | !cpu_rw;
	assign prg_we = romsel | cpu_rw;  // WE# active for all $8000-$FFFF writes

	// Bank register: updates from $4000-$7FFF writes (romsel=1, cpu_addr_14=1).
	// These writes never reach flash (romsel=1 keeps WE# high).
	always @ (negedge m2)
	begin
		if (cpu_rw == 0 && romsel == 1 && cpu_addr_14 == 1)
			r0 <= cpu_data[2:0];
	end

	// A14 from CPU (passthrough), A15-A17 from bank register.
	// 32KB banks, 8 banks = 256KB addressable.
	always @ (*)
	begin
		prg_addr[17:15] = r0[2:0];
		ciram_a10 = ppu_addr_10;
	end

endmodule
