module polyglotscan.core.backend;

import polyglotscan.core.raster;

/// Vendor-neutral scanner driver. Implementations live in sibling packages.
interface ScanBackend
{
    string id() const;
    string displayName() const;

    ScanDevice[] listDevices();

    /// Low-res or same-settings acquire for the preview pane.
    Raster preview(ScanDevice device, ScanSettings settings);

    /// Final acquire. Callers keep this raster and binarize in `polyglotscan-image`.
    Raster acquire(ScanDevice device, ScanSettings settings);
}

final class BackendRegistry
{
    private ScanBackend[] _backends;

    void add(ScanBackend backend)
    {
        foreach (existing; _backends)
        {
            if (existing.id == backend.id)
                return;
        }
        _backends ~= backend;
    }

    ScanBackend[] all()
    {
        return _backends.dup;
    }

    ScanBackend byId(string id)
    {
        foreach (b; _backends)
        {
            if (b.id == id)
                return b;
        }
        return null;
    }

    ScanDevice[] listAllDevices()
    {
        ScanDevice[] devices;
        foreach (b; _backends)
        {
            try
            {
                devices ~= b.listDevices();
            }
            catch (Exception)
            {
                // A sleeping MFP must not empty the combo box.
            }
        }
        return devices;
    }
}
