module polyglotscan.image.ops;

import polyglotscan.core.raster;

/// Rec. 601 luma, integer.
ubyte luma(ubyte r, ubyte g, ubyte b)
{
    return cast(ubyte)((77 * r + 150 * g + 29 * b) >> 8);
}

Raster toGray8(const Raster src)
{
    if (src.kind == PixelKind.gray8)
        return src.dup;

    Raster dst;
    dst.width = src.width;
    dst.height = src.height;
    dst.dpiX = src.dpiX;
    dst.dpiY = src.dpiY;
    dst.kind = PixelKind.gray8;
    dst.samples = new ubyte[](cast(size_t) src.width * src.height);

    final switch (src.kind)
    {
    case PixelKind.unknown:
        throw new ScanException("cannot convert unknown pixel kind to gray");
    case PixelKind.binary:
        size_t o;
        foreach (y; 0 .. src.height)
        {
            auto row = src.samples[y * src.stride() .. $];
            foreach (x; 0 .. src.width)
            {
                const bit = (row[x >> 3] & (0x80 >> (x & 7))) != 0;
                dst.samples[o++] = bit ? 0 : 255;
            }
        }
        break;
    case PixelKind.gray8:
        break;
    case PixelKind.rgb8:
        size_t i, o;
        foreach (_; 0 .. src.width * src.height)
        {
            dst.samples[o++] = luma(src.samples[i], src.samples[i + 1], src.samples[i + 2]);
            i += 3;
        }
        break;
    case PixelKind.rgba8:
        size_t i, o;
        foreach (_; 0 .. src.width * src.height)
        {
            dst.samples[o++] = luma(src.samples[i], src.samples[i + 1], src.samples[i + 2]);
            i += 4;
        }
        break;
    }
    return dst;
}

/// Pixels darker than `threshold` (0–255) become black. Light ALDI ink needs a *higher* value.
Raster thresholdGray(const Raster gray, ubyte threshold)
{
    auto src = gray.kind == PixelKind.gray8 ? gray : toGray8(gray);
    Raster dst;
    dst.width = src.width;
    dst.height = src.height;
    dst.dpiX = src.dpiX;
    dst.dpiY = src.dpiY;
    dst.kind = PixelKind.gray8;
    dst.samples = new ubyte[](src.samples.length);
    foreach (i, p; src.samples)
        dst.samples[i] = p < threshold ? 0 : 255;
    return dst;
}

/// Local adaptive binarization. Better than a global cutoff on faded thermal paper.
Raster sauvolaGray(const Raster gray, int window = 31, double k = 0.2, double R = 128)
{
    import std.algorithm : max, min;
    import std.math : sqrt;

    auto src = gray.kind == PixelKind.gray8 ? gray : toGray8(gray);
    const w = src.width;
    const h = src.height;
    const radius = max(1, window / 2);

    auto integral = new double[](cast(size_t)(w + 1) * (h + 1));
    auto integralSq = new double[](cast(size_t)(w + 1) * (h + 1));
    integral[] = 0;
    integralSq[] = 0;
    const stride = w + 1;

    foreach (y; 0 .. h)
    {
        double row = 0;
        double rowSq = 0;
        foreach (x; 0 .. w)
        {
            const p = cast(double) src.samples[y * w + x];
            row += p;
            rowSq += p * p;
            const idx = (y + 1) * stride + (x + 1);
            integral[idx] = integral[y * stride + (x + 1)] + row;
            integralSq[idx] = integralSq[y * stride + (x + 1)] + rowSq;
        }
    }

    double rectSum(const double[] sat, int x0, int y0, int x1, int y1)
    {
        return sat[y1 * stride + x1] - sat[y0 * stride + x1] - sat[y1 * stride + x0] + sat[y0 * stride + x0];
    }

    Raster dst;
    dst.width = w;
    dst.height = h;
    dst.dpiX = src.dpiX;
    dst.dpiY = src.dpiY;
    dst.kind = PixelKind.gray8;
    dst.samples = new ubyte[](src.samples.length);

    foreach (y; 0 .. h)
    {
        const y0 = max(0, y - radius);
        const y1 = min(h, y + radius + 1);
        foreach (x; 0 .. w)
        {
            const x0 = max(0, x - radius);
            const x1 = min(w, x + radius + 1);
            const count = cast(double)((x1 - x0) * (y1 - y0));
            const mean = rectSum(integral, x0, y0, x1, y1) / count;
            const meanSq = rectSum(integralSq, x0, y0, x1, y1) / count;
            const stddev = sqrt(max(0.0, meanSq - mean * mean));
            const T = mean * (1.0 + k * ((stddev / R) - 1.0));
            dst.samples[y * w + x] = src.samples[y * w + x] < T ? 0 : 255;
        }
    }
    return dst;
}

struct Histogram
{
    uint[256] bins;
    ubyte otsu;
}

Histogram histogramGray(const Raster gray)
{
    auto src = gray.kind == PixelKind.gray8 ? gray : toGray8(gray);
    Histogram h;
    foreach (p; src.samples)
        h.bins[p]++;

    // Otsu: useful default when the user has not touched the slider yet.
    const total = src.samples.length;
    double sum = 0;
    foreach (i, c; h.bins)
        sum += i * c;

    double sumB = 0;
    ulong wB = 0;
    double maxVar = 0;
    ubyte best = 128;
    foreach (t; 0 .. 256)
    {
        wB += h.bins[t];
        if (wB == 0)
            continue;
        const wF = total - wB;
        if (wF == 0)
            break;
        sumB += t * h.bins[t];
        const mB = sumB / wB;
        const mF = (sum - sumB) / wF;
        const v = cast(double) wB * wF * (mB - mF) * (mB - mF);
        if (v > maxVar)
        {
            maxVar = v;
            best = cast(ubyte) t;
        }
    }
    h.otsu = best;
    return h;
}

struct BinarizeSettings
{
    bool enabled = true;
    bool adaptive;
    ubyte threshold = 175;
    double sauvolaK = 0.2;
    int window = 31;
}

Raster applyBinarize(const Raster src, BinarizeSettings settings)
{
    auto gray = toGray8(src);
    if (!settings.enabled)
        return gray;
    if (settings.adaptive)
        return sauvolaGray(gray, settings.window, settings.sauvolaK);
    return thresholdGray(gray, settings.threshold);
}

/// ARGB 0xAARRGGBB for dlangui ColorDrawBuf.
uint[] toArgb32(const Raster src)
{
    auto gray = toGray8(src);
    auto outp = new uint[](gray.width * gray.height);
    foreach (i, p; gray.samples)
        outp[i] = 0xFF000000u | (uint(p) << 16) | (uint(p) << 8) | uint(p);
    return outp;
}

Raster binaryPacked(const Raster bwGray)
{
    auto src = bwGray.kind == PixelKind.gray8 ? bwGray : toGray8(bwGray);
    Raster dst;
    dst.width = src.width;
    dst.height = src.height;
    dst.dpiX = src.dpiX;
    dst.dpiY = src.dpiY;
    dst.kind = PixelKind.binary;
    const stride = (src.width + 7) / 8;
    dst.samples = new ubyte[](cast(size_t) stride * src.height);
    foreach (y; 0 .. src.height)
    {
        auto row = dst.samples[y * stride .. (y + 1) * stride];
        row[] = 0;
        foreach (x; 0 .. src.width)
        {
            if (src.samples[y * src.width + x] < 128)
                row[x >> 3] |= cast(ubyte)(0x80 >> (x & 7));
        }
    }
    return dst;
}

unittest
{
    Raster g;
    g.width = 4;
    g.height = 1;
    g.kind = PixelKind.gray8;
    g.samples = [10, 10, 200, 200];
    auto bw = thresholdGray(g, 128);
    assert(bw.samples == [0, 0, 255, 255]);
    auto hist = histogramGray(g);
    assert(hist.bins[10] == 2);
    assert(hist.bins[200] == 2);
}
