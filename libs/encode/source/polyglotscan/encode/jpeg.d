module polyglotscan.encode.jpeg;

import arsd.jpeg;
import arsd.color : TrueColorImage, Color;
import std.file : tempDir, write, read, remove, exists;
import std.path : buildPath;
import std.uuid : randomUUID;

import polyglotscan.core.raster;
import polyglotscan.image.ops : toGray8;

ubyte[] encodeJpeg(const Raster raster, int quality = 90)
{
    auto gray = toGray8(raster);
    auto img = new TrueColorImage(gray.width, gray.height);
    foreach (y; 0 .. gray.height)
    {
        foreach (x; 0 .. gray.width)
        {
            auto p = gray.samples[y * gray.width + x];
            img.imageData.colors[y * gray.width + x] = Color(p, p, p);
        }
    }
    auto tmp = buildPath(tempDir, "polyglotscan-" ~ randomUUID().toString() ~ ".jpg");
    scope (exit)
        if (exists(tmp))
            remove(tmp);
    JpegParams params;
    params.quality = quality;
    writeJpeg(tmp, img, params);
    return cast(ubyte[]) read(tmp);
}
