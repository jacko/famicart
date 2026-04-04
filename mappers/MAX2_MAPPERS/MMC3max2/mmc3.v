module mmc3
(
    input romsel,
    input cpu_rw,
    input m2,
    input ppu_rd,
    input ppu_wr,
    input [7:0] cpu_data, // cpu_data_in
    input [14:0] cpu_addr, // cpu_addr_in (0, 13 & 14)
    input [13:10] ppu_addr, // ppu_addr_in

    output reg [18:13] prg_addr, // cpu_addr_out
    output reg [18:10] chr_addr, // ppu_addr_out
    output reg ciram_a10,
    output reg irq,

    output prg_ce,
    output prg_oe,
    output prg_we,

    output chr_ce,
    output chr_oe,
    output chr_we
);

    // Common registers
    reg [7:0] r [0:9]; // r0 to r9

    // IRQ related registers
    reg [7:0] irq_scanline_counter;
    reg [2:0] a12_low_time;
    reg irq_scanline_reload;
    reg irq_scanline_reload_clear;
    reg irq_scanline_enabled;
    reg irq_scanline_value;
    reg irq_scanline_ready;

    // PRG Control
    assign prg_ce = romsel;
    assign prg_oe = romsel | !cpu_rw;
    assign prg_we = romsel | cpu_rw;

    // CHR Control
    assign chr_ce = ppu_addr[13];
    assign chr_oe = ppu_addr[13] | ppu_rd;
    assign chr_we = 1'b1;
	
    // Register Write Logic
    //always @(negedge m2) begin
    //    if (!cpu_rw && !romsel) begin // Write operation in $8000-$FFFF
    //        case ({cpu_addr[14:13], cpu_addr[0]})
	//				3'b000: {r[8][4:0]} <= {cpu_data[7], cpu_data[6], cpu_data[2:0]};
                //3'b000: {r[8][4], r[8][3:0]} <= {cpu_data[7], cpu_data[6], cpu_data[2:0]};
    //            3'b001: r[r[8][2:0]] <= cpu_data;
    //            3'b010: r[8][5] <= cpu_data[0];
    //            3'b011: r[8][7:6] <= cpu_data[7:6];
    //            3'b100: r[9] <= cpu_data; // IRQ latch
    //            3'b101: irq_scanline_reload <= 1;
    //            3'b110: irq_scanline_enabled <= 0;
    //            3'b111: irq_scanline_enabled <= 1;
    //        endcase
    //    end

	    // Register Write Logic
		 always @ (posedge romsel)
		 begin
			  if (cpu_rw == 0)
			  begin // Write operation in $8000-$FFFF
					case ({cpu_addr[14:13], cpu_addr[0]})
						3'b000: {r[8][4:0]} <= {cpu_data[7], cpu_data[6], cpu_data[2:0]};
						 //3'b000: {r[8][4], r[8][3:0]} <= {cpu_data[7], cpu_data[6], cpu_data[2:0]};
						 3'b001: r[r[8][2:0]] <= cpu_data;
						 3'b010: r[8][5] <= cpu_data[0];
						 3'b011: r[8][7:6] <= cpu_data[7:6];
						 3'b100: r[9] <= cpu_data; // IRQ latch
						 3'b101: irq_scanline_reload <= 1;
						 3'b110: irq_scanline_enabled <= 0;
						 3'b111: irq_scanline_enabled <= 1;
					endcase
			  end

			  // Clear reload flag if set
			  if (irq_scanline_reload_clear)
					irq_scanline_reload <= 0;
		end


    // Address Calculation
    always @(*) begin
        // PRG Address Calculation
        //if (!romsel) begin
            case ({cpu_addr[14:13], r[8][3]}) // PRG mode
                3'b000: prg_addr[18:13] = r[6][5:0];
                3'b001: prg_addr[18:13] = 6'b111110;
                3'b010, 3'b011: prg_addr[18:13] = r[7][5:0];
                3'b100: prg_addr[18:13] = 6'b111110;
                3'b101: prg_addr[18:13] = r[6][5:0];
                default: prg_addr[18:13] = 6'b111111;
            endcase
        //end

		   if (ppu_addr[12] == r[8][4]) // CHR mode	
				chr_addr[17:10] <= {r[ppu_addr[11]][7:1], ppu_addr[10]};
			else
				chr_addr[17:10] <= r[2+ppu_addr[11:10]];

			chr_addr[18] <= 0; //1'b0;
			ciram_a10 = r[8][5] ? ppu_addr[11] : ppu_addr[10];
		
        // CHR Address Calculation
            //if (ppu_addr[11])
            //    chr_addr[17:10] = {r[1][7:1], ppu_addr[10]};
            //else
            //    chr_addr[17:10] = {r[0][7:1], ppu_addr[10]};
            // chr_addr[17:10] = (ppu_addr[11]) ? {r[1][7:1], ppu_addr[10]} : {r[0][7:1], ppu_addr[10]};
        //end else begin
        //    case (ppu_addr[11:10])
        //        2'b00: chr_addr[17:10] = r[2];
        //        2'b01: chr_addr[17:10] = r[3];
        //        2'b10: chr_addr[17:10] = r[4];
         //        2'b11: chr_addr[17:10] = r[5];
         //   endcase
    end

	// reenable IRQ only when PPU A12 is low
	always @ (*)
	begin
		if (!irq_scanline_enabled)
		begin
			irq_scanline_ready = 0;
			irq <= 1'bz;
		end else if (irq_scanline_enabled && !irq_scanline_value)
			irq_scanline_ready = 1;
		else if (irq_scanline_ready && irq_scanline_value)
			irq <= 1'b0;
	end

	// IRQ counter
	always @ (posedge ppu_addr[12])
	begin
		if (a12_low_time == 3)
		begin
			if ((irq_scanline_reload && !irq_scanline_reload_clear) || (irq_scanline_counter == 0))
			begin
				irq_scanline_counter = r[9];
				if (irq_scanline_reload) irq_scanline_reload_clear <= 1;
			end else
				irq_scanline_counter = irq_scanline_counter-1;
			if (irq_scanline_counter == 0 && irq_scanline_enabled)
				irq_scanline_value = 1;
			else
				irq_scanline_value = 0;
		end
		if (!irq_scanline_reload) irq_scanline_reload_clear <= 0;		
	end

	// A12 must be low for 3 rises of M2
	always @ (posedge m2, posedge ppu_addr[12])
	begin
		if (ppu_addr[12])
			a12_low_time <= 0;
		else if (a12_low_time < 3)
			a12_low_time <= a12_low_time + 1;
	end

endmodule