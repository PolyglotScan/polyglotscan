module polyglotscan.encode.decode;

import arsd.image;

import polyglotscan.core.raster;

Raster loadRasterFromMemory(const(ubyte)[] bytes, int dpi = 300)
{
    auto img = loadImageFromMemory(cast(immutable(ubyte)[]) bytes.idup).getAsTrueColorImage();
    Raster r;
    r.width = img.width;
    r.height = img.height;
    r.dpiX = dpi;
    r.dpiY = dpi;
    r.kind = PixelKind.rgb8;
    r.samples = new ubyte[](cast(size_t) r.width * r.height * 3);
    size_t o;
    foreach (y; 0 .. r.height)
    {
        foreach (x; 0 .. r.width)
        {
            auto c = img.getPixel(x, y);
            r.samples[o++] = c.r;
            r.samples[o++] = c.g;
            r.samples[o++] = c.b;
        }
    }
    return r;
}

Raster loadRasterFromFile(string path, int dpi = 300)
{
    import std.file : read;

    return loadRasterFromMemory(cast(ubyte[]) read(path), dpi);
}
