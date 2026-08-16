module polyglotscan.escl.backend;

import std.algorithm : canFind;
import std.conv : to;
import std.process : environment;

import polyglotscan.core.backend;
import polyglotscan.core.raster;

/**
 * eSCL (AirScan / Mopria) plugin point.
 *
 * HTTP (std.net.curl) is not linked on this Windows build — that would pull curl.lib.
 * WinHTTP + mDNS `_uscan._tcp` are listed as missing layers.
 * Pass `POLYGLOTSCAN_ESCL=http://printer/eSCL` to list a placeholder device.
 */
final class EsclBackend : ScanBackend
{
    string id() const
    {
        return "escl";
    }

    string displayName() const
    {
        return "eSCL (AirScan)";
    }

    ScanDevice[] listDevices()
    {
        auto url = environment.get("POLYGLOTSCAN_ESCL", "");
        if (url.length)
            return [ScanDevice("escl", url, "eSCL " ~ url, url)];
        return null;
    }

    Raster preview(ScanDevice device, ScanSettings settings)
    {
        return acquireAt(device, settings, settings.previewDpi);
    }

    Raster acquire(ScanDevice device, ScanSettings settings)
    {
        return acquireAt(device, settings, settings.dpi);
    }

    private Raster acquireAt(ScanDevice device, ScanSettings settings, int dpi)
    {
        auto base = settings.esclBaseUrl.length ? settings.esclBaseUrl : device.id;
        throw new ScanException(
            "eSCL HTTP needs WinHTTP (missing layer). Base would be " ~ base
                ~ " at " ~ to!string(dpi) ~ " dpi. Use TWAIN/WIA or Open image.");
    }
}
