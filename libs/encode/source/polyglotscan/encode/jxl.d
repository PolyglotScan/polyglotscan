module polyglotscan.encode.jxl;

import std.file : tempDir, write, read, remove, exists;
import std.path : buildPath;
import std.process : execute, Config;
import std.random : uniform;
import std.uuid : randomUUID;

import polyglotscan.core.raster;
import polyglotscan.encode.png : encodePng;

/// JPEG-XL via `cjxl` on PATH (libjxl tools). Optional `jxl-d` wiring is a later dub configuration.
ubyte[] encodeJxl(const Raster raster)
{
    const png = encodePng(raster);
    const stamp = randomUUID().toString();
    auto inPng = buildPath(tempDir, "polyglotscan-" ~ stamp ~ ".png");
    auto outJxl = buildPath(tempDir, "polyglotscan-" ~ stamp ~ ".jxl");
    scope (exit)
    {
        if (exists(inPng))
            remove(inPng);
        if (exists(outJxl))
            remove(outJxl);
    }
    write(inPng, png);
    auto run = execute(["cjxl", inPng, outJxl, "-q", "90"], null, Config.none);
    if (run.status != 0)
    {
        throw new ScanException(
            "JPEG-XL encode needs `cjxl` on PATH (libjxl) or a future jxl-d link. cjxl said: "
                ~ run.output);
    }
    return cast(ubyte[]) read(outJxl);
}

import polyglotscan.core.raster : ScanException;
