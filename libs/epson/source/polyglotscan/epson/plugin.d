module polyglotscan.epson.plugin;

import polyglotscan.core.plugin;
import polyglotscan.core.raster;
import std.algorithm : canFind;
import std.string : toLower;

/// Matches Epson identities on standard scan APIs. Does not link Epson Scan SDK.
final class EpsonPlugin : VendorPlugin
{
    string id() const
    {
        return "epson";
    }

    bool matches(ScanDevice device) const
    {
        auto blob = (device.name ~ " " ~ device.vendorHint ~ " " ~ device.id).toLower;
        return blob.canFind("epson") || blob.canFind("ecotank") || blob.canFind("et-");
    }

    ScanDevice decorate(ScanDevice device) const
    {
        if (!matches(device))
            return device;
        device.vendorHint = "Epson";
        if (device.backendId == "wia")
            device.name ~= " (WIA — prefer TWAIN if listed)";
        else if (device.backendId == "twain")
            device.name ~= " (Epson TWAIN)";
        return device;
    }

    void applyHints(ref ScanSettings settings) const
    {
        // Never ask firmware for 1-bit. Software binarize is the point.
        settings.acquireKind = PixelKind.gray8;
        if (settings.dpi < 200)
            settings.dpi = 300;
    }
}
