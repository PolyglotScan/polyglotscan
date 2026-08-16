module polyglotscan.twain.backend;

version (Windows):

import core.sys.windows.windef;
import core.sys.windows.winuser;
import core.sys.windows.winbase;
import core.stdc.stdlib : malloc, free;
import core.stdc.string : memcpy, memset, strncpy;
import std.string : fromStringz, toStringz;
import std.conv : to;

import polyglotscan.core.backend;
import polyglotscan.core.raster;
import polyglotscan.wia.backend : dibOrImageToRaster;

extern (Windows)
{
    alias DSMENTRYPROC = TW_UINT16 function(pTW_IDENTITY, pTW_IDENTITY, TW_UINT32, TW_UINT16, TW_UINT16, TW_MEMREF);
}

alias TW_UINT16 = ushort;
alias TW_UINT32 = uint;
alias TW_INT16 = short;
alias TW_INT32 = int;
alias TW_BOOL = ushort;
alias TW_HANDLE = HANDLE;
alias TW_MEMREF = void*;
alias TW_STR32 = char[34];

enum {
    DG_CONTROL = 0x0001,
    DG_IMAGE = 0x0002,
    DAT_CAPABILITY = 0x0001,
    DAT_EVENT = 0x0002,
    DAT_IDENTITY = 0x0003,
    DAT_PARENT = 0x0004,
    DAT_PENDINGXFERS = 0x0005,
    DAT_USERINTERFACE = 0x0009,
    DAT_IMAGEINFO = 0x0101,
    DAT_IMAGENATIVEXFER = 0x0104,
    MSG_GET = 0x0001,
    MSG_GETCURRENT = 0x0002,
    MSG_SET = 0x0006,
    MSG_RESET = 0x0007,
    MSG_QUERYSUPPORT = 0x0008,
    MSG_XFERREADY = 0x0101,
    MSG_CLOSEDSREQ = 0x0102,
    MSG_CLOSEDSOK = 0x0103,
    MSG_DEVICEEVENT = 0x0400,
    MSG_OPENDSM = 0x0301,
    MSG_CLOSEDSM = 0x0302,
    MSG_OPENDS = 0x0401,
    MSG_CLOSEDS = 0x0402,
    MSG_GETFIRST = 0x0004,
    MSG_GETNEXT = 0x0005,
    MSG_ENABLEDS = 0x0405,
    MSG_DISABLEDS = 0x0406,
    MSG_PROCESSEVENT = 0x0601,
    MSG_ENDXFER = 0x0701,
    CAP_XFERCOUNT = 0x0001,
    ICAP_PIXELTYPE = 0x0101,
    ICAP_UNITS = 0x0102,
    ICAP_XFERMECH = 0x0103,
    ICAP_XRESOLUTION = 0x1118,
    ICAP_YRESOLUTION = 0x1119,
    ICAP_BITDEPTH = 0x112b,
    TWUN_INCHES = 0,
    TWPT_BW = 0,
    TWPT_GRAY = 1,
    TWPT_RGB = 2,
    TWSX_NATIVE = 0,
    TWON_DONTCARE16 = 0xffff,
    TWTY_INT16 = 0x0001,
    TWTY_UINT16 = 0x0004,
    TWTY_FIX32 = 0x0007,
    TWRC_SUCCESS = 0,
    TWRC_FAILURE = 1,
    TWRC_CHECKSTATUS = 2,
    TWRC_CANCEL = 3,
    TWRC_DSEVENT = 4,
    TWRC_NOTDSEVENT = 5,
    TWRC_XFERDONE = 6,
    TWRC_ENDOFLIST = 7,
    TWCC_SUCCESS = 0,
    DH_TWAIN = 3, // DG_CONTROL / DAT_NULL unused
}

struct TW_VERSION
{
    TW_UINT16 MajorNum;
    TW_UINT16 MinorNum;
    TW_UINT16 Language;
    TW_UINT16 Country;
    TW_STR32 Info;
}

struct TW_IDENTITY
{
    TW_UINT32 Id;
    TW_VERSION Version;
    TW_UINT16 ProtocolMajor;
    TW_UINT16 ProtocolMinor;
    TW_UINT32 SupportedGroups;
    TW_STR32 Manufacturer;
    TW_STR32 ProductFamily;
    TW_STR32 ProductName;
}

alias pTW_IDENTITY = TW_IDENTITY*;

struct TW_USERINTERFACE
{
    TW_BOOL ShowUI;
    TW_BOOL ModalUI;
    TW_HANDLE hParent;
}

struct TW_PENDINGXFERS
{
    TW_UINT16 Count;
    TW_UINT32 EOJ;
}

struct TW_FIX32
{
    TW_INT16 Whole;
    TW_UINT16 Frac;
}

struct TW_ONEVALUE
{
    TW_UINT16 ItemType;
    TW_UINT32 Item;
}

struct TW_CAPABILITY
{
    TW_UINT16 Cap;
    TW_UINT16 ConType;
    TW_HANDLE hContainer;
}

struct TW_EVENT
{
    TW_MEMREF pEvent;
    TW_UINT16 TWMessage;
}

enum TWON_ONEVALUE = 5;

private TW_FIX32 toFix32(double v)
{
    TW_FIX32 f;
    const sign = v < 0;
    if (sign)
        v = -v;
    f.Whole = cast(TW_INT16) v;
    f.Frac = cast(TW_UINT16)((v - f.Whole) * 65536.0 + 0.5);
    if (sign)
        f.Whole = cast(TW_INT16)-f.Whole;
    return f;
}

private string c32(ref TW_STR32 s)
{
    auto p = s.ptr;
    size_t n;
    while (n < s.length && p[n] != 0)
        n++;
    return p[0 .. n].idup;
}

private void put32(ref TW_STR32 s, string v)
{
    s[] = 0;
    auto n = v.length < 33 ? v.length : 33;
    s[0 .. n] = v[0 .. n];
}

private HWND messageHwnd;
private DSMENTRYPROC dsmEntry;
private HMODULE dsmLib;
private TW_IDENTITY appId;
private bool dsmOpen;

private void fillAppId()
{
    memset(&appId, 0, appId.sizeof);
    appId.Version.MajorNum = 0;
    appId.Version.MinorNum = 1;
    appId.ProtocolMajor = 2;
    appId.ProtocolMinor = 4;
    appId.SupportedGroups = DG_CONTROL | DG_IMAGE;
    put32(appId.Manufacturer, "PolyglotScan");
    put32(appId.ProductFamily, "PolyglotScan");
    put32(appId.ProductName, "PolyglotScan");
}

private HWND ensureParentWindow()
{
    if (messageHwnd)
        return messageHwnd;
    messageHwnd = CreateWindowExW(0, "STATIC", "PolyglotScan TWAIN", WS_POPUP, 0, 0, 0, 0,
        HWND_MESSAGE, null, GetModuleHandleW(null), null);
    if (!messageHwnd)
        messageHwnd = GetDesktopWindow();
    return messageHwnd;
}

private void loadDsm()
{
    if (dsmEntry)
        return;
    dsmLib = LoadLibraryW("TWAINDSM.dll");
    if (!dsmLib)
        dsmLib = LoadLibraryW("twain_32.dll");
    if (!dsmLib)
        throw new ScanException("TWAIN DSM not found (TWAINDSM.dll / twain_32.dll)");
    dsmEntry = cast(DSMENTRYPROC) GetProcAddress(dsmLib, "DSM_Entry");
    if (!dsmEntry)
        throw new ScanException("DSM_Entry missing");
    fillAppId();
}

private TW_UINT16 entry(pTW_IDENTITY dest, TW_UINT32 dg, TW_UINT16 dat, TW_UINT16 msg, TW_MEMREF data)
{
    return dsmEntry(&appId, dest, dg, dat, msg, data);
}

private void openDsm()
{
    loadDsm();
    if (dsmOpen)
        return;
    auto hwnd = ensureParentWindow();
    auto rc = entry(null, DG_CONTROL, DAT_PARENT, MSG_OPENDSM, cast(TW_MEMREF)&hwnd);
    if (rc != TWRC_SUCCESS)
        throw new ScanException("MSG_OPENDSM failed rc=" ~ to!string(rc));
    dsmOpen = true;
}

private TW_HANDLE globalAllocContainer(TW_ONEVALUE value)
{
    auto h = GlobalAlloc(GMEM_MOVEABLE, TW_ONEVALUE.sizeof);
    auto p = cast(TW_ONEVALUE*) GlobalLock(h);
    *p = value;
    GlobalUnlock(h);
    return h;
}

private void setCapUint16(pTW_IDENTITY ds, TW_UINT16 cap, TW_UINT16 value)
{
    TW_ONEVALUE ov;
    ov.ItemType = TWTY_UINT16;
    ov.Item = value;
    TW_CAPABILITY c;
    c.Cap = cap;
    c.ConType = TWON_ONEVALUE;
    c.hContainer = globalAllocContainer(ov);
    scope (exit)
        GlobalFree(c.hContainer);
    entry(ds, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &c);
}

private void setCapFix32(pTW_IDENTITY ds, TW_UINT16 cap, double value)
{
    auto f = toFix32(value);
    TW_ONEVALUE ov;
    ov.ItemType = TWTY_FIX32;
    ov.Item = *cast(TW_UINT32*)&f;
    TW_CAPABILITY c;
    c.Cap = cap;
    c.ConType = TWON_ONEVALUE;
    c.hContainer = globalAllocContainer(ov);
    scope (exit)
        GlobalFree(c.hContainer);
    entry(ds, DG_CONTROL, DAT_CAPABILITY, MSG_SET, &c);
}

private ScanDevice[] listImpl()
{
    openDsm();
    ScanDevice[] devices;
    TW_IDENTITY ds;
    auto rc = entry(null, DG_CONTROL, DAT_IDENTITY, MSG_GETFIRST, &ds);
    while (rc == TWRC_SUCCESS)
    {
        auto name = c32(ds.ProductName);
        auto mfg = c32(ds.Manufacturer);
        devices ~= ScanDevice("twain", to!string(ds.Id) ~ ":" ~ name, name, mfg ~ " " ~ name);
        memset(&ds, 0, ds.sizeof);
        rc = entry(null, DG_CONTROL, DAT_IDENTITY, MSG_GETNEXT, &ds);
    }
    return devices;
}

private TW_IDENTITY findDs(ScanDevice device)
{
    openDsm();
    TW_IDENTITY ds;
    auto rc = entry(null, DG_CONTROL, DAT_IDENTITY, MSG_GETFIRST, &ds);
    while (rc == TWRC_SUCCESS)
    {
        auto name = c32(ds.ProductName);
        auto key = to!string(ds.Id) ~ ":" ~ name;
        if (key == device.id || name == device.name)
            return ds;
        memset(&ds, 0, ds.sizeof);
        rc = entry(null, DG_CONTROL, DAT_IDENTITY, MSG_GETNEXT, &ds);
    }
    throw new ScanException("TWAIN source not found: " ~ device.id);
}

private Raster nativeXfer(pTW_IDENTITY ds)
{
    TW_HANDLE hDib;
    auto rc = entry(ds, DG_IMAGE, DAT_IMAGENATIVEXFER, MSG_GET, &hDib);
    if (rc != TWRC_XFERDONE && rc != TWRC_SUCCESS)
        throw new ScanException("DAT_IMAGENATIVEXFER rc=" ~ to!string(rc));
    auto size = GlobalSize(hDib);
    auto p = cast(ubyte*) GlobalLock(hDib);
    scope (exit)
    {
        GlobalUnlock(hDib);
        GlobalFree(hDib);
    }
    auto blob = p[0 .. size].dup;
    TW_PENDINGXFERS pend;
    entry(ds, DG_CONTROL, DAT_PENDINGXFERS, MSG_ENDXFER, &pend);
    return dibOrImageToRaster(blob);
}

private Raster acquireImpl(ScanDevice device, ScanSettings settings, bool preview)
{
    auto ds = findDs(device);
    auto rc = entry(null, DG_CONTROL, DAT_IDENTITY, MSG_OPENDS, &ds);
    if (rc != TWRC_SUCCESS)
        throw new ScanException("MSG_OPENDS failed");
    scope (exit)
        entry(&ds, DG_CONTROL, DAT_IDENTITY, MSG_CLOSEDS, null);

    setCapUint16(&ds, CAP_XFERCOUNT, 1);
    setCapUint16(&ds, ICAP_PIXELTYPE, TWPT_GRAY);
    setCapUint16(&ds, ICAP_XFERMECH, TWSX_NATIVE);
    const dpi = preview ? settings.previewDpi : settings.dpi;
    setCapFix32(&ds, ICAP_XRESOLUTION, dpi);
    setCapFix32(&ds, ICAP_YRESOLUTION, dpi);

    TW_USERINTERFACE ui;
    ui.ShowUI = 0;
    ui.ModalUI = 0;
    ui.hParent = ensureParentWindow();
    rc = entry(&ds, DG_CONTROL, DAT_USERINTERFACE, MSG_ENABLEDS, &ui);
    if (rc != TWRC_SUCCESS && rc != TWRC_CHECKSTATUS)
        throw new ScanException("MSG_ENABLEDS failed rc=" ~ to!string(rc));
    scope (exit)
        entry(&ds, DG_CONTROL, DAT_USERINTERFACE, MSG_DISABLEDS, &ui);

    // Pump until XFERREADY or timeout.
    bool ready;
    foreach (_; 0 .. 10_000)
    {
        MSG msg;
        if (PeekMessageW(&msg, null, 0, 0, PM_REMOVE))
        {
            TW_EVENT ev;
            ev.pEvent = &msg;
            ev.TWMessage = 0;
            auto prc = entry(&ds, DG_CONTROL, DAT_EVENT, MSG_PROCESSEVENT, &ev);
            if (ev.TWMessage == MSG_XFERREADY)
            {
                ready = true;
                break;
            }
            if (ev.TWMessage == MSG_CLOSEDSREQ || ev.TWMessage == MSG_CLOSEDSOK)
                throw new ScanException("TWAIN source closed");
            if (prc == TWRC_NOTDSEVENT)
            {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        }
        else
        {
            // Some sources go straight to transfer without events when ShowUI is false.
            ready = true;
            break;
        }
    }
    if (!ready)
        throw new ScanException("TWAIN timed out waiting to transfer");

    auto raster = nativeXfer(&ds);
    raster.dpiX = dpi;
    raster.dpiY = dpi;
    return raster;
}

final class TwainBackend : ScanBackend
{
    string id() const
    {
        return "twain";
    }

    string displayName() const
    {
        return "TWAIN";
    }

    ScanDevice[] listDevices()
    {
        return listImpl();
    }

    Raster preview(ScanDevice device, ScanSettings settings)
    {
        return acquireImpl(device, settings, true);
    }

    Raster acquire(ScanDevice device, ScanSettings settings)
    {
        return acquireImpl(device, settings, false);
    }
}
