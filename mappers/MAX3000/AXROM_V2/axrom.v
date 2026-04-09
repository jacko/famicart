module axrom
(
	input romsel,
	input cpu_rw,
	input m2,
	input [4:0] cpu_data,
	input cpu_addr_14,
	input ppu_addr_10, //  high-impedance

	output reg [17:15] prg_addr,
	output prg_addr_14,
	output reg ciram_a10,
	output prg_ce,
	output prg_oe,
	output prg_we,
	output power_led
);

    reg [4:0] r0;

    assign prg_addr_14 = cpu_addr_14;
    assign power_led = 1'b1;
    assign prg_ce = romsel;
    assign prg_oe = romsel | !cpu_rw;
    assign prg_we = romsel | cpu_rw;

    always @ (negedge m2)
    begin
        if (cpu_rw == 0) // write
        begin
            if (romsel == 0) // $8000-$FFF
                r0 <= cpu_data;
        end
    end

    always @ (*)
    begin
        if (romsel == 0) // read $8000-$FFFF
            prg_addr[17:15] = r0[2:0];
        ciram_a10 = r0[4];
    end

endmodule