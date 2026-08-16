module polyglotscan.core.plugin;

import polyglotscan.core.raster : ScanDevice, ScanSettings;

/// Vendor overlay: identity matching and acquire hints. No partner SDKs here.
interface VendorPlugin
{
    string id() const;
    bool matches(ScanDevice device) const;
    ScanDevice decorate(ScanDevice device) const;
    void applyHints(ref ScanSettings settings) const;
}
