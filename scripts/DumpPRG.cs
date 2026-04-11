/* Dump PRG ROM using programmer firmware
 *
 * Sets bank via $C000 writes, reads from $8000 (lower window).
 * Works with the pure programmer CPLD firmware (no fixed bank).
 *
 * Usage:
 *   famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes -- UNROM
 *   famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes -- AOROM
 *   famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes -- UNROM 256
 *
 * Arguments after --:
 *   mapper name: UNROM or AOROM (required)
 *   size in KB (optional, default: 128 for UNROM, 256 for AOROM)
 */

using System.Linq;

class DumpPRG
{
    void Run(IFamicomDumperConnection dumper, string filename, string[] args)
    {
        // Parse mapper name
        string mapperName = "UNROM";
        if (args != null && args.Length > 0)
            mapperName = args[0].ToUpper();

        int mapper;
        int defaultSizeKB;
        bool verticalMirroring;

        switch (mapperName)
        {
            case "UNROM":
            case "UXROM":
                mapper = 2;
                defaultSizeKB = 128;
                verticalMirroring = true;  // vertical mirroring
                break;
            case "AOROM":
            case "AXROM":
                mapper = 7;
                defaultSizeKB = 256;
                verticalMirroring = false; // single-screen (handled by mapper)
                break;
            default:
                Console.WriteLine("Unknown mapper: " + mapperName);
                Console.WriteLine("Supported: UNROM, AOROM");
                return;
        }

        // Parse optional size override
        int sizeKB = defaultSizeKB;
        if (args != null && args.Length > 1)
            int.TryParse(args[1], out sizeKB);

        int bankSize = 0x8000; // 32KB per bank (A14 passthrough)
        int totalBanks = sizeKB * 1024 / bankSize;
        var data = new List<byte>();

        Console.WriteLine("Dump PRG: " + mapperName + " (mapper " + mapper + "), " + sizeKB + "KB, " + totalBanks + " banks");

        for (int bank = 0; bank < totalBanks; bank++)
        {
            Console.Write("Reading bank " + bank + "/" + totalBanks + "... ");
            dumper.WriteCpu(0x5000, (byte)bank);
            var bankData = dumper.ReadCpu(0x8000, bankSize);
            data.AddRange(bankData);

            // Show first bytes
            Console.Write("OK [");
            for (int i = 0; i < Math.Min(8, bankData.Length); i++)
            {
                if (i > 0) Console.Write("-");
                Console.Write(bankData[i].ToString("X2"));
            }
            Console.WriteLine("]");
        }

        // Write NES file with iNES header
        using (var fs = new System.IO.FileStream(filename, System.IO.FileMode.Create))
        {
            var header = new byte[16];
            header[0] = 0x4E; // N
            header[1] = 0x45; // E
            header[2] = 0x53; // S
            header[3] = 0x1A;
            header[4] = (byte)(sizeKB / 16); // PRG ROM size in 16KB units
            header[5] = 0;    // CHR ROM size (0 = CHR RAM)
            header[6] = (byte)(((mapper & 0x0F) << 4) | (verticalMirroring ? 0x01 : 0x00));
            header[7] = (byte)(mapper & 0xF0);
            fs.Write(header, 0, 16);
            fs.Write(data.ToArray(), 0, data.Count);
        }

        Console.WriteLine("Saved " + filename + " (" + data.Count / 1024 + "KB PRG, mapper " + mapper + ")");
    }
}
