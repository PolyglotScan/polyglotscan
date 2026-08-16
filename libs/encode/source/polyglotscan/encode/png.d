module polyglotscan.encode.png;

import std.algorithm : min;
import std.bitmanip : nativeToBigEndian;
import std.digest.crc : CRC32;
import std.zlib : compress;

import polyglotscan.core.raster;
import polyglotscan.image.ops : toGray8;

private ubyte[] chunk(string type, const(ubyte)[] data)
{
    ubyte[] outp;
    outp ~= nativeToBigEndian(cast(uint) data.length);
    auto typed = new ubyte[](4 + data.length);
    typed[0 .. 4] = cast(ubyte[]) type;
    typed[4 .. $] = data;
    outp ~= typed;
    CRC32 crc;
    crc.put(typed);
    auto digest = crc.finish();
    outp ~= [digest[3], digest[2], digest[1], digest[0]];
    return outp;
}

/// 8-bit gray PNG (filter 0 + zlib).
ubyte[] encodePng(const Raster raster)
{
    auto gray = toGray8(raster);
    ubyte[] raw;
    raw.length = gray.height * (1 + gray.width);
    size_t o;
    foreach (y; 0 .. gray.height)
    {
        raw[o++] = 0;
        auto row = gray.samples[y * gray.width .. (y + 1) * gray.width];
        raw[o .. o + row.length] = row[];
        o += row.length;
    }

    ubyte[] ihdr;
    ihdr ~= nativeToBigEndian(cast(uint) gray.width);
    ihdr ~= nativeToBigEndian(cast(uint) gray.height);
    ihdr ~= [8, 0, 0, 0, 0]; // bit depth 8, color type 0 (gray)

    ubyte[] png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    png ~= chunk("IHDR", ihdr);
    auto pHYs = nativeToBigEndian(cast(uint)(gray.dpiX * 39.37007874))
        ~ nativeToBigEndian(cast(uint)(gray.dpiY * 39.37007874))
        ~ [cast(ubyte) 1]; // pixels per metre, unit is metre
    png ~= chunk("pHYs", pHYs);
    png ~= chunk("IDAT", compress(raw));
    png ~= chunk("IEND", null);
    return png;
}
