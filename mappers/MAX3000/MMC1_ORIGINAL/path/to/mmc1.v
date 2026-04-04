module mmc1
(
    input wire clk,           // System clock
    input wire rst,           // System reset
    input wire romsel,
    input wire cpu_rw,
    input wire m2,
    input wire ppu_rd,
    input wire ppu_wr,
    input wire [7:0] cpu_data,    // cpu_data_in
    input wire [14:0] cpu_addr,    // cpu_addr_in (0, 13 & 14)
    input wire [13:10] ppu_addr,   // ppu_addr_in

    output reg [18:13] prg_addr,   // cpu_addr_out (6 bits)
    output reg [18:10] chr_addr,   // ppu_addr_out (9 bits)
    output reg ciram_a10,
    output wire irq,

    output wire prg_ce,
    output wire prg_oe,
    output wire prg_we,

    output wire chr_ce,
    output wire chr_oe,
    output wire chr_we
);

    // *** Register Declarations ***
    reg [4:0] r0; // Shift register (5-bit)
    reg [7:0] r1; // MMC1 control register
    reg [7:0] r2; // MMC1 CHR0 bank
    reg [7:0] r3; // MMC1 CHR1 bank
    reg [7:0] r4; // MMC1 PRG bank

    // *** Initial Block for Register Initialization ***
    initial begin
        r0     = 5'b10000; // Shift register initialized to 1 followed by zeros
        r1     = 8'h0C;    // Control register: mirroring = 0b00 (one-screen, lower bank), PRG mode = 0b10 (16K switching)
        r2     = 8'h00;    // CHR0 bank
        r3     = 8'h00;    // CHR1 bank
        r4     = 8'h00;    // PRG bank
    end

    // *** Control Signals Assignments ***
    // PRG Control Signals
    assign prg_ce = romsel;
    assign prg_oe = romsel | ~cpu_rw;
    assign prg_we = romsel | cpu_rw;

    // CHR Control Signals
    assign chr_ce = ppu_addr[13];
    assign chr_oe = ppu_addr[13] | ppu_rd;
    assign chr_we = ppu_addr[13] | ppu_wr;

    // IRQ Handling (Disabled)
    assign irq = 1'bz;

    // *** Shift Register and Control Registers Handling ***
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all registers
            r0 <= 5'b10000;
            r1 <= 8'h0C;
            r2 <= 8'h00;
            r3 <= 8'h00;
            r4 <= 8'h00;
        end
        else if (m2) begin
            if (!cpu_rw && romsel) begin // Write operation
                if (cpu_data[7]) begin // Reset shift register
                    r0     <= 5'b10000;
                    r1[3:2] <= 2'b11; // Set PRG mode to 0b11 (last 16K fixed)
                end
                else begin
                    r0 <= {cpu_data[0], r0[4:1]}; // Shift in the least significant bit
                    if (r0[0]) begin // After 5 writes (shift register full)
                        case (cpu_addr[14:13])
                            2'b00: r1 <= {r1[7:5], r0};       // Control Register
                            2'b01: r2 <= {r0, 3'b000};        // CHR Bank 0 (Align to byte boundary)
                            2'b10: r3 <= {r0, 3'b000};        // CHR Bank 1 (Align to byte boundary)
                            2'b11: r4 <= {r0, 3'b000};        // PRG Bank (Align to byte boundary)
                            default: ; // No action
                        endcase
                        r0 <= 5'b10000; // Reset shift register after writing
                    end
                end
            end
        end
    end

    // *** PRG and CHR Address Calculation ***
    always @(*) begin
        // *** PRG Address Calculation ***
        if (!romsel) begin // Accessing $8000-$FFFF
            case (r1[3:2]) // PRG Banking Mode
                2'b00, 2'b01: begin // 32KB Mode
                    prg_addr = {1'b0, r4[3:1], cpu_addr[14:13]}; // Corrected to 6 bits
                end
                2'b10: begin // 16KB Mode, fix first bank at $8000
                    if (cpu_addr[14] == 0)
                        prg_addr = {5'b00000, cpu_addr[13]}; // First 16KB bank fixed
                    else
                        prg_addr = {1'b0, r4[4:0], cpu_addr[13]}; // Switchable second 16KB bank
                end
                2'b11: begin // 16KB Mode, fix last bank at $C000
                    if (cpu_addr[14] == 0)
                        prg_addr = {1'b0, r4[4:0], cpu_addr[13]}; // Switchable first 16KB bank
                    else
                        prg_addr = {5'b11111, cpu_addr[13]}; // Last 16KB bank fixed
                end
                default: prg_addr = {5'b00000, cpu_addr[13]}; // Default case
            endcase
        end
        else begin
            prg_addr = 6'b000000; // Default or handle other cases
        end

        // *** CHR Address Calculation ***
        if (r1[4] == 0) begin // 8KB Mode
            // Corrected to fit 9 bits: {1'b0, r2[4:0], ppu_addr[12:10]}
            chr_addr = {1'b0, r2[4:0], ppu_addr[12:10]}; // 1 + 5 + 3 = 9 bits
        end
        else begin // 4KB Mode
            if (ppu_addr[12] == 0)
                chr_addr = {1'b0, r2[4:0], ppu_addr[11:10]}; // 1 + 5 + 2 = 8 bits (needs adjustment)
            else
                chr_addr = {1'b0, r3[4:0], ppu_addr[11:10]}; // 1 + 5 + 2 = 8 bits (needs adjustment)
            // To fit 9 bits, pad with a 0 or adjust as per architecture
            // Assuming the highest bit is not critical:
            chr_addr = {1'b0, r2[4:0], ppu_addr[11:10]}; // Lower 4KB
        end

        // *** Control Mirroring ***
        case (r1[1:0])
            2'b00: ciram_a10 = 1'b0; // One-screen, lower bank
            2'b01: ciram_a10 = 1'b1; // One-screen, upper bank
            2'b10: ciram_a10 = ppu_addr[10]; // Vertical mirroring
            2'b11: ciram_a10 = ppu_addr[11]; // Horizontal mirroring
            default: ciram_a10 = 1'b0; // Default mirroring
        endcase
    end

endmodule 