module polyglotscan.fixture.backend;

import polyglotscan.core.backend;
import polyglotscan.core.raster;
import std.algorithm : clamp;
import std.path : baseName, extension;
import std.string : toLower;

final class FixtureBackend : ScanBackend
{
    private string _openPath;

    string id() const
    {
        return "fixture";
    }

    string displayName() const
    {
        return "File / sample";
    }

    void bindOpenPath(string path)
    {
        _openPath = path;
    }

    ScanDevice[] listDevices()
    {
        ScanDevice[] d;
        d ~= ScanDevice("fixture", "receipt", "Sample faded receipt (ALDI-like)", "synthetic");
        if (_openPath.length)
            d ~= ScanDevice("fixture", "file:" ~ _openPath, "Open image: " ~ baseName(_openPath), "");
        return d;
    }

    Raster preview(ScanDevice device, ScanSettings settings)
    {
        return acquireAt(device, settings.previewDpi);
    }

    Raster acquire(ScanDevice device, ScanSettings settings)
    {
        return acquireAt(device, settings.dpi);
    }

    private Raster acquireAt(ScanDevice device, int dpi)
    {
        if (device.id == "receipt")
            return makeFadedReceipt(dpi);
        if (device.id.length > 5 && device.id[0 .. 5] == "file:")
            return loadRaster(device.id[5 .. $], dpi);
        if (_openPath.length)
            return loadRaster(_openPath, dpi);
        return makeFadedReceipt(dpi);
    }
}

Raster makeFadedReceipt(int dpi)
{
    auto w = maxI(400, dpi * 80 / 25);
    auto h = maxI(600, dpi * 140 / 25);
    Raster r;
    r.width = w;
    r.height = h;
    r.dpiX = dpi;
    r.dpiY = dpi;
    r.kind = PixelKind.gray8;
    r.samples = new ubyte[](w * h);
    r.samples[] = 236;

    void bar(int x, int y, int bw, int bh, ubyte tone)
    {
        foreach (yy; y .. minI(y + bh, h))
            foreach (xx; x .. minI(x + bw, w))
            {
                auto i = yy * w + xx;
                r.samples[i] = minU(r.samples[i], tone);
            }
    }

    void textLine(int y, string s, ubyte tone)
    {
        int x = w / 10;
        foreach (ch; s)
        {
            auto glyphW = maxI(3, dpi / 40);
            auto glyphH = maxI(8, dpi / 12);
            if (ch != ' ')
                bar(x, y, glyphW, glyphH, tone);
            x += glyphW + maxI(1, dpi / 80);
        }
    }

    textLine(h / 12, "* ALDI *", 198);
    textLine(h / 8, "Thank you", 205);
    auto y = h / 5;
    string[] items = [
        "MILK 1.19", "BREAD 0.89", "EGGS 2.49", "BANANAS 0.54", "CHICKEN 6.99",
        "TOTAL 12.10", "VISA **** 1042"
    ];
    foreach (item; items)
    {
        textLine(y, item, 202);
        y += maxI(14, dpi / 8);
    }
    foreach (yy; h / 2 .. h / 2 + dpi / 6)
        foreach (xx; 0 .. w)
        {
            auto drop = cast(ubyte)((xx + yy) % 9);
            auto i = yy * w + xx;
            r.samples[i] = cast(ubyte) clamp(int(r.samples[i]) - drop, 180, 255);
        }
    return r;
}

Raster loadRaster(string path, int dpi)
{
    import std.file : exists;
    if (!exists(path))
        throw new ScanException("file not found: " ~ path);
    import arsd.jpeg : readJpeg;
    import arsd.png : readPng;
    import arsd.color : MemoryImage;

    MemoryImage img;
    auto ext = path.extension.toLower;
    if (ext == ".jpg" || ext == ".jpeg")
        img = readJpeg(path);
    else
        img = readPng(path);
    auto tc = img.getAsTrueColorImage();
    Raster r;
    r.width = tc.width;
    r.height = tc.height;
    r.dpiX = dpi;
    r.dpiY = dpi;
    r.kind = PixelKind.rgb8;
    r.samples = new ubyte[](tc.width * tc.height * 3);
    foreach (i, c; tc.imageData.colors)
    {
        auto o = i * 3;
        r.samples[o] = c.r;
        r.samples[o + 1] = c.g;
        r.samples[o + 2] = c.b;
    }
    return r;
}

private int maxI(int a, int b)
{
    return a > b ? a : b;
}

private int minI(int a, int b)
{
    return a < b ? a : b;
}

private ubyte minU(ubyte a, ubyte b)
{
    return a < b ? a : b;
}
