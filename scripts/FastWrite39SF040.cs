/* Fast SST39SF040 Write — uses custom firmware commands 57/58
 *
 * Usage:
 *   famicom-dumper script --port COM8 --cs-file scripts\FastWrite39SF040.cs --file rom.nes
 */

using System.Linq;
using System.Reflection;
using System.Diagnostics;

class FastWrite39SF040
{
    // ===== PROGRAMMER CONFIGURATION =====
    // A14 passthrough, 32KB banks, bank switch via $5000
    ushort bankSwitchAddr = 0x5000;
    byte   cmd1Bank       = 0;        // no bank switching for commands
    ushort cmd1Addr       = 0xD555;   // CPU addr -> flash 0x5555
    byte   cmd2Bank       = 0;
    ushort cmd2Addr       = 0xAAAA;   // CPU addr -> flash 0x2AAA
    ushort targetBase     = 0x8000;
    int    bankSize       = 0x8000;   // 32KB banks
    // =====================================

    MethodInfo sendMethod;
    MethodInfo recvMethod;
    object dumperObj;

    void InitRawCommands(IFamicomDumperConnection dumper)
    {
        dumperObj = dumper;
        var type = dumper.GetType();
        sendMethod = type.GetMethod("SendRawCommand");
        recvMethod = type.GetMethod("RecvRawCommand");
        if (sendMethod == null || recvMethod == null)
            throw new Exception("SendRawCommand/RecvRawCommand not found. Rebuild the client.");
    }

    void SendRaw(byte command, byte[] data)
    {
        sendMethod.Invoke(dumperObj, new object[] { command, data });
    }

    (byte Command, byte[] Data) RecvRaw()
    {
        var result = recvMethod.Invoke(dumperObj, null);
        var type = result.GetType();
        byte cmd = (byte)type.GetField("Item1").GetValue(result);
        byte[] data = (byte[])type.GetField("Item2").GetValue(result);
        return (cmd, data);
    }

    byte[] BuildWritePacket(byte targetBank, ushort baseAddr, byte[] data)
    {
        var header = new byte[] {
            (byte)(bankSwitchAddr & 0xFF), (byte)(bankSwitchAddr >> 8),
            cmd1Bank,
            (byte)(cmd1Addr & 0xFF), (byte)(cmd1Addr >> 8),
            cmd2Bank,
            (byte)(cmd2Addr & 0xFF), (byte)(cmd2Addr >> 8),
            targetBank,
            (byte)(baseAddr & 0xFF), (byte)(baseAddr >> 8),
            (byte)(data.Length & 0xFF), (byte)((data.Length >> 8) & 0xFF)
        };
        var packet = new byte[header.Length + data.Length];
        Array.Copy(header, 0, packet, 0, header.Length);
        Array.Copy(data, 0, packet, header.Length, data.Length);
        return packet;
    }

    byte[] BuildErasePacket()
    {
        return new byte[] {
            (byte)(bankSwitchAddr & 0xFF), (byte)(bankSwitchAddr >> 8),
            cmd1Bank,
            (byte)(cmd1Addr & 0xFF), (byte)(cmd1Addr >> 8),
            cmd2Bank,
            (byte)(cmd2Addr & 0xFF), (byte)(cmd2Addr >> 8)
        };
    }

    void Run(IFamicomDumperConnection dumper, string filename)
    {
        var rom = new NesFile(filename);
        var prg = rom.PRG.ToArray();
        int totalBanks = prg.Length / bankSize;

        Console.WriteLine("Fast SST39SF040 Write: " + (prg.Length / 1024) + "KB PRG, " + totalBanks + " banks");

        InitRawCommands(dumper);

        // Set bank 0
        dumper.WriteCpu(bankSwitchAddr, (byte)0);

        // Erase
        Console.Write("Erasing chip... ");
        SendRaw(58, BuildErasePacket());
        var eraseResp = RecvRaw();
        if (eraseResp.Command == 10)
            Console.WriteLine("OK");
        else
        {
            Console.WriteLine("FAILED (response: " + eraseResp.Command + ")");
            return;
        }

        // Verify erase
        Console.Write("Verify erase... ");
        dumper.WriteCpu(bankSwitchAddr, (byte)0);
        var check = dumper.ReadCpu(0x8000, 256);
        for (int i = 0; i < check.Length; i++)
        {
            if (check[i] != 0xFF)
            {
                Console.WriteLine("FAIL at 0x" + i.ToString("X4") + ": 0x" + check[i].ToString("X2"));
                return;
            }
        }
        Console.WriteLine("OK");

        // Program
        var sw = Stopwatch.StartNew();
        int maxChunk = 2043 - 13; // firmware max payload = 2043

        for (int bank = 0; bank < totalBanks; bank++)
        {
            Console.Write("Writing bank " + bank + "/" + totalBanks + "... ");
            int bankOffset = bank * bankSize;
            int remaining = bankSize;
            int pos = 0;

            while (remaining > 0)
            {
                int chunkLen = Math.Min(remaining, maxChunk);
                var chunk = new byte[chunkLen];
                Array.Copy(prg, bankOffset + pos, chunk, 0, chunkLen);

                bool allFF = true;
                for (int i = 0; i < chunkLen; i++)
                    if (chunk[i] != 0xFF) { allFF = false; break; }

                if (!allFF)
                {
                    var packet = BuildWritePacket((byte)bank, (ushort)(targetBase + pos), chunk);
                    SendRaw(57, packet);
                    var resp = RecvRaw();
                    if (resp.Command != 10)
                    {
                        Console.WriteLine("FAILED (response: " + resp.Command + ")");
                        return;
                    }
                }

                pos += chunkLen;
                remaining -= chunkLen;
            }
            Console.WriteLine("OK");
        }

        Console.WriteLine("Write complete in " + sw.Elapsed.TotalSeconds.ToString("F1") + "s");

        // Verify
        Console.WriteLine("Verifying...");
        bool allOk = true;
        for (int bank = 0; bank < totalBanks; bank++)
        {
            Console.Write("Verify bank " + bank + "/" + totalBanks + "... ");
            dumper.WriteCpu(bankSwitchAddr, (byte)bank);
            var readBack = dumper.ReadCpu(targetBase, bankSize);
            for (int i = 0; i < bankSize; i++)
            {
                if (readBack[i] != prg[bank * bankSize + i])
                {
                    Console.WriteLine("FAIL at 0x" + i.ToString("X4") + ": got 0x" + readBack[i].ToString("X2") + ", expected 0x" + prg[bank * bankSize + i].ToString("X2"));
                    allOk = false;
                    break;
                }
            }
            if (allOk) Console.WriteLine("OK");
            else break;
        }

        Console.WriteLine(allOk ? "Done! Power cycle the cart." : "Verification FAILED.");
    }
}
