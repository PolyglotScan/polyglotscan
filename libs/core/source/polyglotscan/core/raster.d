module polyglotscan.core.raster;

/// Packed image buffer owned by scan/image/encode layers. No UI types here.
enum PixelKind
{
    unknown,
    binary, /// 1 bit per pixel, packed MSB-first, row padded to bytes
    gray8,
    rgb8,
    rgba8
}

struct Raster
{
    int width;
    int height;
    int dpiX = 300;
    int dpiY = 300;
    PixelKind kind = PixelKind.unknown;
    ubyte[] samples;

    bool empty() const
    {
        return width <= 0 || height <= 0 || samples.length == 0;
    }

    size_t stride() const
    {
        final switch (kind)
        {
        case PixelKind.unknown:
            return 0;
        case PixelKind.binary:
            return (width + 7) / 8;
        case PixelKind.gray8:
            return width;
        case PixelKind.rgb8:
            return width * 3;
        case PixelKind.rgba8:
            return width * 4;
        }
    }

    Raster dup() const
    {
        Raster r;
        r.width = width;
        r.height = height;
                r.dpiX = dpiX;
        r.dpiY = dpiY;
        r.kind = kind;
        r.samples = samples.dup;
        return r;
    }
}

struct ScanSettings
{
    int dpi = 300;
    int previewDpi = 150;
    PixelKind acquireKind = PixelKind.gray8;
    bool duplex;
    string esclBaseUrl; /// e.g. http://192.168.1.20/eSCL
}

struct ScanDevice
{
    string backendId;
    string id;
    string name;
    string vendorHint;
}

class ScanException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}
