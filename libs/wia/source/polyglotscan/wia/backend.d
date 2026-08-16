module polyglotscan.wia.backend;

version (Windows):

import core.stdc.wchar_ : wcslen;
import core.sys.windows.com;
import core.sys.windows.oaidl;
import core.sys.windows.objbase;
import core.sys.windows.oleauto;
import core.sys.windows.windef;
import core.sys.windows.winnt;
import core.sys.windows.wtypes;
import core.thread : Thread;
import std.conv : to;
import std.string : fromStringz;
import std.utf : toUTF16z, toUTF8;
import std.exception : enforce;

import polyglotscan.core.backend;
import polyglotscan.core.raster;

pragma(lib, "ole32");
pragma(lib, "oleaut32");
pragma(lib, "uuid");

private __gshared ScanDevice[] wiaListCache;
private __gshared string wiaListErr;
private __gshared int wiaListDone;
private __gshared bool wiaListBusy;

private void wiaListThreadMain()
{
    try
    {
        ensureCom();
        wiaListCache = listDevicesImpl();
        wiaListDone = 1;
    }
    catch (Exception e)
    {
        wiaListErr = e.msg;
        wiaListDone = -1;
    }
}

private enum Stensor = 1;
private enum WiaDeviceTypeScanner = 1;

private void checkHr(HRESULT hr, string what)
{
    if (FAILED(hr))
        throw new ScanException(what ~ " failed, HRESULT=0x" ~ to!string(cast(uint) hr, 16));
}

private wstring bstrToW(BSTR s)
{
    if (s is null)
        return ""w;
    return s[0 .. SysStringByteLen(s) / 2].idup;
}

private string bstrToS(BSTR s)
{
    return toUTF8(bstrToW(s));
}

private VARIANT variantBstr(string s)
{
    VARIANT v;
    v.vt = VARENUM.VT_BSTR;
    v.bstrVal = SysAllocString(toUTF16z(s));
    return v;
}

private VARIANT variantI4(int n)
{
    VARIANT v;
    v.vt = VARENUM.VT_I4;
    v.lVal = n;
    return v;
}

private int getDispId(IDispatch obj, wstring name)
{
    DISPID id;
    auto n = name.ptr;
    auto hr = obj.GetIDsOfNames(&IID_NULL, cast(LPOLESTR*)&n, 1, 0x0400, &id);
    checkHr(hr, "GetIDsOfNames " ~ toUTF8(name));
    return id;
}

private VARIANT invoke(IDispatch obj, wstring name, ushort flags, VARIANT[] args = null)
{
    DISPPARAMS dp;
    VARIANT result;
    EXCEPINFO excep;
    UINT argErr;
    auto id = getDispId(obj, name);
    if (args.length)
    {
        // IDispatch args are in reverse order
        dp.cArgs = cast(uint) args.length;
        dp.rgvarg = args.ptr;
    }
    auto hr = obj.Invoke(id, &IID_NULL, 0x0400, flags, &dp, &result, &excep, &argErr);
    if (FAILED(hr))
    {
        auto msg = whatFrom(excep);
        throw new ScanException("WIA Invoke " ~ toUTF8(name) ~ " : " ~ msg);
    }
    return result;
}

private string whatFrom(ref EXCEPINFO excep)
{
    if (excep.bstrDescription)
        return bstrToS(excep.bstrDescription);
    return "dispatch error";
}

private IDispatch asDispatch(VARIANT v)
{
    if (v.vt == (VARENUM.VT_DISPATCH | VARENUM.VT_BYREF) && v.ppdispVal)
        return *v.ppdispVal;
    if (v.vt == VARENUM.VT_DISPATCH)
        return v.pdispVal;
    throw new ScanException("expected IDispatch variant, got vt=" ~ to!string(v.vt));
}

private IDispatch createDeviceManager()
{
    IDispatch mgr;
    GUID clsid;
    checkHr(CLSIDFromProgID(cast(const(wchar)*) "WIA.DeviceManager"w.ptr, cast(GUID*) &clsid),
            "CLSIDFromProgID WIA.DeviceManager");
    checkHr(CoCreateInstance(&clsid, null, CLSCTX_INPROC_SERVER | CLSCTX_LOCAL_SERVER,
            &IID_IDispatch, cast(void**)&mgr), "CoCreateInstance WIA.DeviceManager");
    return mgr;
}

private int intProp(IDispatch obj, wstring name)
{
    auto v = invoke(obj, name, DISPATCH_PROPERTYGET);
    scope (exit)
        VariantClear(&v);
    VARIANT i;
    VariantChangeType(&i, &v, 0, VARENUM.VT_I4);
    return i.lVal;
}

private string strProp(IDispatch obj, wstring name)
{
    auto v = invoke(obj, name, DISPATCH_PROPERTYGET);
    scope (exit)
        VariantClear(&v);
    if (v.vt == VARENUM.VT_BSTR)
        return bstrToS(v.bstrVal);
    VARIANT s;
    VariantChangeType(&s, &v, 0, VARENUM.VT_BSTR);
    scope (exit)
        VariantClear(&s);
    return bstrToS(s.bstrVal);
}

private IDispatch itemAt(IDispatch collection, int oneBased)
{
    VARIANT[1] args = [variantI4(oneBased)];
    auto v = invoke(collection, "Item", DISPATCH_PROPERTYGET, args);
    return asDispatch(v);
}

private IDispatch connect(IDispatch info)
{
    auto v = invoke(info, "Connect", DISPATCH_METHOD);
    return asDispatch(v);
}

private void setNamedProp(IDispatch item, string propName, int value)
{
    auto props = asDispatch(invoke(item, "Properties", DISPATCH_PROPERTYGET));
    VARIANT[1] key = [variantBstr(propName)];
    auto pv = invoke(props, "Item", DISPATCH_PROPERTYGET, key);
    auto prop = asDispatch(pv);
    VARIANT[1] val = [variantI4(value)];
    invoke(prop, "Value", DISPATCH_PROPERTYPUT, val);
}

private Raster transferToRaster(IDispatch item)
{
    auto vimg = invoke(item, "Transfer", DISPATCH_METHOD);
    auto imageFile = asDispatch(vimg);
    auto vdata = invoke(imageFile, "FileData", DISPATCH_PROPERTYGET);
    auto vec = asDispatch(vdata); // Vector
    auto vbin = invoke(vec, "BinaryData", DISPATCH_PROPERTYGET);
    scope (exit)
        VariantClear(&vbin);
    if (vbin.vt != (VARENUM.VT_ARRAY | VARENUM.VT_UI1) && vbin.vt != (VARENUM.VT_ARRAY | VARENUM.VT_I1))
    {
        // Some WIA builds return VT_VECTOR or a SAFEARRAY under FileData.BinaryData.
        throw new ScanException("WIA Transfer did not return a byte array (vt=" ~ to!string(vbin.vt) ~ ")");
    }
    SAFEARRAY* sa = vbin.parray;
    void* data;
    SafeArrayAccessData(sa, &data);
    scope (exit)
        SafeArrayUnaccessData(sa);
    LONG lb, ub;
    SafeArrayGetLBound(sa, 1, &lb);
    SafeArrayGetUBound(sa, 1, &ub);
    auto n = ub - lb + 1;
    auto bytes = (cast(ubyte*) data)[0 .. n].dup;
    return dibOrImageToRaster(bytes);
}

/// Parse a DIB/BMP from WIA, or fall back to treating it as packed gray.
Raster dibOrImageToRaster(const(ubyte)[] bytes)
{
    if (bytes.length >= 14 && bytes[0] == 'B' && bytes[1] == 'M')
        return parseBmp(bytes);
    if (bytes.length >= 40)
    {
        // Maybe a BITMAPINFOHEADER without file header.
        auto dib = new ubyte[](14 + bytes.length);
        dib[0] = 'B';
        dib[1] = 'M';
        auto fileSize = cast(uint) dib.length;
        dib[2] = cast(ubyte) fileSize;
        dib[3] = cast(ubyte)(fileSize >> 8);
        dib[4] = cast(ubyte)(fileSize >> 16);
        dib[5] = cast(ubyte)(fileSize >> 24);
        uint off = 14 + 40;
        dib[10] = cast(ubyte) off;
        dib[14 .. $] = bytes[];
        try
            return parseBmp(dib);
        catch (Exception)
        {
        }
    }
    throw new ScanException("unrecognized WIA image blob (" ~ to!string(bytes.length) ~ " bytes)");
}

private Raster parseBmp(const(ubyte)[] bytes)
{
    import std.bitmanip : read, peek, Endian;

    auto b = bytes;
    if (b.length < 54)
        throw new ScanException("BMP too small");
    auto off = peek!(uint, Endian.littleEndian)(b[10 .. 14]);
    auto headerSize = peek!(uint, Endian.littleEndian)(b[14 .. 18]);
    auto width = peek!(int, Endian.littleEndian)(b[18 .. 22]);
    auto height = peek!(int, Endian.littleEndian)(b[22 .. 26]);
    auto planes = peek!(ushort, Endian.littleEndian)(b[26 .. 28]);
    auto bpp = peek!(ushort, Endian.littleEndian)(b[28 .. 30]);
    auto compression = peek!(uint, Endian.littleEndian)(b[30 .. 34]);
    if (planes != 1 || compression != 0)
        throw new ScanException("only uncompressed BMP is supported from WIA");
    const absH = height < 0 ? -height : height;
    const bottomUp = height > 0;
    Raster r;
    r.width = width;
    r.height = absH;
    r.dpiX = 300;
    r.dpiY = 300;
    auto rowPad = (bpp == 8) ? ((width + 3) & ~3) : (bpp == 24) ? ((width * 3 + 3) & ~3)
        : (bpp == 32) ? (width * 4) : 0;
    if (rowPad == 0)
        throw new ScanException("unsupported BMP bit depth " ~ to!string(bpp));

    if (bpp == 8)
    {
        r.kind = PixelKind.gray8;
        r.samples = new ubyte[](cast(size_t) width * absH);
        foreach (y; 0 .. absH)
        {
            auto srcY = bottomUp ? (absH - 1 - y) : y;
            auto src = bytes[off + srcY * rowPad .. off + srcY * rowPad + width];
            r.samples[y * width .. (y + 1) * width] = src[];
        }
    }
    else if (bpp == 24 || bpp == 32)
    {
        r.kind = PixelKind.rgb8;
        r.samples = new ubyte[](cast(size_t) width * absH * 3);
        const spp = bpp / 8;
        size_t o;
        foreach (y; 0 .. absH)
        {
            auto srcY = bottomUp ? (absH - 1 - y) : y;
            auto src = bytes[off + srcY * rowPad .. off + (srcY + 1) * rowPad];
            foreach (x; 0 .. width)
            {
                auto p = src.ptr + x * spp;
                r.samples[o++] = p[2];
                r.samples[o++] = p[1];
                r.samples[o++] = p[0];
            }
        }
    }
    return r;
}

private ScanDevice[] listDevicesImpl()
{
    auto mgr = createDeviceManager();
    scope (exit)
        mgr.Release();
    auto infos = asDispatch(invoke(mgr, "DeviceInfos", DISPATCH_PROPERTYGET));
    const n = intProp(infos, "Count");
    ScanDevice[] devices;
    foreach (i; 1 .. n + 1)
    {
        auto info = itemAt(infos, i);
        string name = "WIA device";
        string id;
        try
            id = strProp(info, "DeviceID");
        catch (Exception)
            id = to!string(i);
        try
            name = strProp(info, "Name");
        catch (Exception)
        {
            try
            {
                auto props = asDispatch(invoke(info, "Properties", DISPATCH_PROPERTYGET));
                VARIANT[1] key = [variantBstr("Name")];
                auto pv = invoke(props, "Item", DISPATCH_PROPERTYGET, key);
                name = strProp(asDispatch(pv), "Value");
            }
            catch (Exception)
            {
            }
        }
        int type = 0;
        try
            type = intProp(info, "Type");
        catch (Exception)
        {
        }
        if (type != 0 && type != WiaDeviceTypeScanner)
            continue; // skip cameras if Type is filled in
        devices ~= ScanDevice("wia", id, name, name);
    }
    return devices;
}

private Raster acquireImpl(ScanDevice device, ScanSettings settings, bool preview)
{
    auto mgr = createDeviceManager();
    scope (exit)
        mgr.Release();
    auto infos = asDispatch(invoke(mgr, "DeviceInfos", DISPATCH_PROPERTYGET));
    const n = intProp(infos, "Count");
    IDispatch info;
    foreach (i; 1 .. n + 1)
    {
        auto cand = itemAt(infos, i);
        string id;
        try
            id = strProp(cand, "DeviceID");
        catch (Exception)
            id = to!string(i);
        if (id == device.id)
        {
            info = cand;
            break;
        }
    }
    enforce(info !is null, new ScanException("WIA device gone: " ~ device.id));
    auto dev = connect(info);
    auto items = asDispatch(invoke(dev, "Items", DISPATCH_PROPERTYGET));
    auto item = itemAt(items, 1);
    const dpi = preview ? settings.previewDpi : settings.dpi;
    foreach (prop; ["HorizontalResolution", "VerticalResolution"])
    {
        try
            setNamedProp(item, prop, dpi);
        catch (Exception)
        {
        }
    }
    // 4107 Current Intent: grayscale = 2
    try
        setNamedProp(item, "Current Intent", 2);
    catch (Exception)
    {
        try
            setNamedProp(item, "4107", 2);
        catch (Exception)
        {
        }
    }
    try
        setNamedProp(item, "Bits Per Pixel", 8);
    catch (Exception)
    {
    }
    auto raster = transferToRaster(item);
    raster.dpiX = dpi;
    raster.dpiY = dpi;
    return raster;
}

final class WiaBackend : ScanBackend
{
    string id() const
    {
        return "wia";
    }

    string displayName() const
    {
        return "WIA (Windows)";
    }

    ScanDevice[] listDevices()
    {
        import core.thread : Thread;
        import core.time : msecs;

        if (wiaListBusy)
            return wiaListCache;
        wiaListBusy = true;
        wiaListDone = 0;
        wiaListCache = null;
        wiaListErr = null;
        auto t = new Thread(&wiaListThreadMain);
        t.isDaemon = true;
        t.start();
        foreach (_; 0 .. 80)
        {
            if (wiaListDone != 0)
                break;
            Thread.sleep(100.msecs);
        }
        wiaListBusy = false;
        if (wiaListDone == 0)
            return null; // still running in the daemon thread
        if (wiaListErr.length)
            throw new ScanException(wiaListErr);
        return wiaListCache;
    }

    Raster preview(ScanDevice device, ScanSettings settings)
    {
        ensureCom();
        return acquireImpl(device, settings, true);
    }

    Raster acquire(ScanDevice device, ScanSettings settings)
    {
        ensureCom();
        return acquireImpl(device, settings, false);
    }
}

private void ensureCom()
{
    const hr = CoInitializeEx(null, COINIT.COINIT_APARTMENTTHREADED);
    if (hr != S_OK && hr != S_FALSE && hr != 0x80010106) // RPC_E_CHANGED_MODE
    {
        if (FAILED(hr))
            throw new ScanException("CoInitializeEx failed");
    }
}
