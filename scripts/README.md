# FamiCart Scripts

Scripts for programming and dumping SST39SF040 flash via famicom-dumper.
Requires [custom firmware](https://github.com/jacko/famicom-dumper) with commands 57/58.

## Write ROM (erase + program + verify)

```
famicom-dumper script --port COM8 --cs-file scripts\FastWrite39SF040.cs --file rom.nes
```

## Dump PRG ROM

```
famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes - UNROM
famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes - AOROM
famicom-dumper script --port COM8 --cs-file scripts\DumpPRG.cs --file dump.nes - UNROM 128
```

## Notes

- Flash the PRG_WRITER CPLD firmware before programming
- Flash the game-specific CPLD firmware (UNROM_V2 or AXROM_V2) before playing
- No power cycle needed between write and dump
- Adjust script paths to match your setup
