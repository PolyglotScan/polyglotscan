module polyglotscan.core.session;

import polyglotscan.core.backend;
import polyglotscan.core.raster;
import polyglotscan.core.version_;

/// In-memory session: last grayscale plus last displayed (binarized) raster.
struct ScanSession
{
    ScanDevice device;
    ScanSettings settings;
    Raster gray; /// immutable acquire; UI clones for display
    string lastError;
    string lastBackendId;

    string debugDump() const
    {
        import std.format : format;

        return format(
            "%s\nbackend=%s\ndevice=%s (%s)\nsize=%sx%s dpi=%s grayBytes=%s\nlastError=%s\n",
            versionLine(),
            lastBackendId.length ? lastBackendId : "(none)",
            device.name,
            device.id,
            gray.width,
            gray.height,
            gray.dpiX,
            gray.samples.length,
            lastError.length ? lastError : "(none)"
        );
    }
}
