module app;

import dlangui;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import dlangui.dialogs.msgbox;
import polyglotscan.core;
import polyglotscan.encode;
import polyglotscan.epson;
import polyglotscan.escl;
import polyglotscan.fixture;
import polyglotscan.image;
import polyglotscan.twain;
import polyglotscan.wia;
import preview;
import std.conv : to;
import std.exception : enforce;
import std.format : format;
import std.datetime.stopwatch : StopWatch, AutoStart;

enum APP_NAME = "PolyglotScan"d;
enum ACTION_PREVIEW = 1001;
enum ACTION_SCAN = 1002;
enum ACTION_SAVE = 1003;
enum ACTION_OPEN = 1004;
enum ACTION_ABOUT = 1005;
enum ACTION_DEBUG = 1006;
enum ACTION_REFRESH = 1009;

mixin APP_ENTRY_POINT;

__gshared BackendRegistry registry;
__gshared FixtureBackend fixture;
__gshared EpsonPlugin epsonPlugin;
__gshared ScanDevice[] devices;
__gshared int selectedDevice;
__gshared Raster lastScan;
__gshared BinarizeSettings binarize;
__gshared string lastError;

extern (C) int UIAppMain(string[] args)
{
    Platform.instance.uiLanguage = "en";
    Platform.instance.uiTheme = "theme_dark";
    FontManager.minAnitialiasedFontSize = 0;

    binarize.enabled = true;
    binarize.threshold = 175;
    binarize.adaptive = false;

    registry = new BackendRegistry();
    fixture = new FixtureBackend();
    epsonPlugin = new EpsonPlugin();
    registry.add(fixture);
    registry.add(new TwainBackend());
    registry.add(new WiaBackend());
    registry.add(new EsclBackend());

    auto window = Platform.instance.createWindow(APP_NAME, null, WindowFlag.Resizable, 1400, 900);
    auto root = new VerticalLayout();
    root.layoutWidth = FILL_PARENT;
    root.layoutHeight = FILL_PARENT;

    auto menu = new MainMenu(buildMenu());
    root.addChild(menu);

    auto toolbar = new HorizontalLayout();
    toolbar.layoutWidth = FILL_PARENT;
    auto deviceBox = new ComboBox("devices", ["Refreshing…"d]);
    deviceBox.minWidth = 280;
    auto previewBtn = new Button("previewBtn", "Preview"d);
    auto scanBtn = new Button("scanBtn", "Scan"d);
    auto saveBtn = new Button("saveBtn", "Save…"d);
    auto openBtn = new Button("openBtn", "Open image…"d);
    auto refreshBtn = new Button("refreshBtn", "Refresh devices"d);
    auto sampleBtn = new Button("sampleBtn", "Sample receipt"d);
    auto loupeBtn = new CheckBox("loupe", "Loupe"d);
    auto dpiBox = new ComboBox("dpi", ["150 dpi"d, "200 dpi"d, "300 dpi"d, "600 dpi"d]);
    dpiBox.selectedItemIndex = 2;
    toolbar.addChild(new TextWidget(null, "Device"d));
    toolbar.addChild(deviceBox);
    toolbar.addChild(refreshBtn);
    toolbar.addChild(previewBtn);
    toolbar.addChild(scanBtn);
    toolbar.addChild(saveBtn);
    toolbar.addChild(openBtn);
    toolbar.addChild(sampleBtn);
    toolbar.addChild(dpiBox);
    toolbar.addChild(loupeBtn);
    root.addChild(toolbar);

    auto adjust = new HorizontalLayout();
    adjust.layoutWidth = FILL_PARENT;
    auto binEnable = new CheckBox("binarize", "Black && white (software)"d);
    binEnable.checked = true;
    auto adaptive = new CheckBox("sauvola", "Sauvola (faded receipts)"d);
    auto otsuBtn = new Button("otsu", "Otsu auto"d);
    auto thrLabel = new TextWidget("thrLabel", "Threshold 175"d);
    auto slider = new ScrollBar("thr", Orientation.Horizontal);
    slider.minWidth = 280;
    slider.setRange(0, 255);
    slider.position = binarize.threshold;
    slider.layoutWidth = FILL_PARENT;
    adjust.addChild(binEnable);
    adjust.addChild(adaptive);
    adjust.addChild(otsuBtn);
    adjust.addChild(thrLabel);
    adjust.addChild(slider);
    root.addChild(adjust);

    auto canvas = new PreviewCanvas();
    canvas.binarize = binarize;
    root.addChild(canvas);

    auto status = new TextWidget("status", "Ready. Sample receipt does not need a scanner."d);
    status.layoutWidth = FILL_PARENT;
    root.addChild(status);

    void setStatus(dstring s)
    {
        status.text = s;
        if (window)
            window.invalidate();
    }

    void applyBinarizeUi()
    {
        binarize.enabled = binEnable.checked;
        binarize.adaptive = adaptive.checked;
        binarize.threshold = cast(ubyte) slider.position;
        thrLabel.text = "Threshold "d ~ to!dstring(binarize.threshold)
            ~ (binarize.adaptive ? " (Sauvola ignores global T)"d : ""d);
        canvas.setBinarize(binarize);
    }

    void populateDevices()
    {
        setStatus("Listing devices (WIA has an 8s timeout; Epson WIA can stall)…"d);
        devices = registry.listAllDevices();
        foreach (ref d; devices)
        {
            if (epsonPlugin.matches(d))
                d = epsonPlugin.decorate(d);
        }
        dstring[] labels;
        foreach (d; devices)
            labels ~= to!dstring(d.name ~ "  [" ~ d.backendId ~ "]");
        if (!labels.length)
            labels ~= "(no devices)"d;
        deviceBox.items = labels;
        deviceBox.selectedItemIndex = 0;
        selectedDevice = 0;
        setStatus(to!dstring(format("%s device(s)", devices.length)));
    }

    ScanDevice currentDevice()
    {
        if (!devices.length || selectedDevice < 0 || selectedDevice >= devices.length)
            throw new ScanException("no scanner selected");
        return devices[selectedDevice];
    }

    int currentDpi()
    {
        immutable int[] dpis = [150, 200, 300, 600];
        auto i = dpiBox.selectedItemIndex;
        if (i < 0 || i >= dpis.length)
            return 300;
        return dpis[i];
    }

    void runAcquire(bool previewPass)
    {
        try
        {
            auto dev = currentDevice();
            auto backend = registry.byId(dev.backendId);
            enforce(backend !is null, "backend missing");
            ScanSettings req;
            req.previewDpi = 150;
            req.dpi = currentDpi();
            req.acquireKind = PixelKind.gray8;
            if (epsonPlugin.matches(dev))
                epsonPlugin.applyHints(req);
            setStatus((previewPass ? "Previewing "d : "Scanning "d) ~ to!dstring(dev.name) ~ "…"d);
            auto sw = StopWatch(AutoStart.yes);
            lastScan = previewPass ? backend.preview(dev, req) : backend.acquire(dev, req);
            canvas.setSource(lastScan);
            applyBinarizeUi();
            setStatus(to!dstring(format("%s %sx%s in %.1fs", previewPass ? "Preview" : "Scan",
                    lastScan.width, lastScan.height, sw.peek.total!"msecs" / 1000.0)));
        }
        catch (Exception e)
        {
            lastError = e.msg;
            setStatus("Error: "d ~ to!dstring(e.msg));
            window.showMessageBox(UIString.fromRaw("Scan failed"d), UIString.fromRaw(to!dstring(e.msg)));
        }
    }

    deviceBox.itemClick = delegate(Widget src, int itemIndex) {
        selectedDevice = itemIndex;
        return true;
    };
    refreshBtn.click = delegate(Widget w) { populateDevices(); return true; };
    previewBtn.click = delegate(Widget w) { runAcquire(true); return true; };
    scanBtn.click = delegate(Widget w) { runAcquire(false); return true; };
    sampleBtn.click = delegate(Widget w) {
        auto r = makeFadedReceipt(200);
        lastScan = r;
        canvas.setSource(r);
        applyBinarizeUi();
        setStatus("Sample faded receipt — move Threshold or enable Sauvola. Wheel zooms."d);
        return true;
    };
    loupeBtn.checkChange = delegate(Widget w, bool checked) {
        canvas.loupe = checked;
        canvas.invalidate();
        return true;
    };
    binEnable.checkChange = delegate(Widget w, bool c) { applyBinarizeUi(); return true; };
    adaptive.checkChange = delegate(Widget w, bool c) { applyBinarizeUi(); return true; };
    otsuBtn.click = delegate(Widget w) {
        if (lastScan.width == 0)
        {
            setStatus("Preview or load an image first."d);
            return true;
        }
        auto t = histogramGray(lastScan).otsu;
        slider.position = t;
        applyBinarizeUi();
        setStatus("Otsu picked "d ~ to!dstring(t));
        return true;
    };
    slider.scrollEvent = delegate(AbstractSlider src, ScrollEvent ev) {
        applyBinarizeUi();
        return true;
    };
    openBtn.click = delegate(Widget w) {
        auto dlg = new FileDialog(UIString.fromRaw("Open scanned image"d), window, null, FileDialogFlag.Open);
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("Images"d), "*.png;*.jpg;*.jpeg"));
        dlg.dialogResult = delegate(Dialog d, const Action result) {
            auto path = (cast(FileDialog) d).filename;
            if (!path.length)
                return;
            fixture.bindOpenPath(path);
            populateDevices();
            try
            {
                lastScan = loadRaster(path, 300);
                canvas.setSource(lastScan);
                applyBinarizeUi();
                setStatus("Opened "d ~ to!dstring(path));
            }
            catch (Exception e)
            {
                window.showMessageBox(UIString.fromRaw("Open failed"d), UIString.fromRaw(to!dstring(e.msg)));
            }
        };
        dlg.show();
        return true;
    };
    saveBtn.click = delegate(Widget w) {
        if (lastScan.width == 0)
        {
            window.showMessageBox(UIString.fromRaw("Nothing to save"d),
                    UIString.fromRaw("Run Preview, Scan, Sample, or Open first."d));
            return true;
        }
        auto dlg = new FileDialog(UIString.fromRaw("Save scan"d), window, null, FileDialogFlag.Save);
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("PNG"d), "*.png"));
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("JPEG"d), "*.jpg"));
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("JPEG-XL"d), "*.jxl"));
        dlg.addFilter(FileFilterEntry(UIString.fromRaw("PDF"d), "*.pdf"));
        dlg.dialogResult = delegate(Dialog d, const Action result) {
            auto path = (cast(FileDialog) d).filename;
            if (!path.length)
                return;
            try
            {
                auto outR = applyBinarize(lastScan, binarize);
                saveRaster(outR, path);
                setStatus("Saved "d ~ to!dstring(path));
            }
            catch (Exception e)
            {
                window.showMessageBox(UIString.fromRaw("Save failed"d), UIString.fromRaw(to!dstring(e.msg)));
            }
        };
        dlg.show();
        return true;
    };

    menu.menuItemClick = delegate(MenuItem item) {
        if (item is null || item.action is null)
            return false;
        switch (item.action.id)
        {
        case ACTION_ABOUT:
            window.showMessageBox(UIString.fromRaw("About PolyglotScan"d),
                    UIString.fromRaw("PolyglotScan "d ~ to!dstring(appVersion) ~ "\nNative D scanner UI. Not affiliated with Seiko Epson Corporation.\nhttps://github.com/PolyglotScan/polyglotscan"d));
            return true;
        case ACTION_DEBUG:
            window.showMessageBox(UIString.fromRaw("Debug dump"d), UIString.fromRaw(to!dstring(debugDump())));
            return true;
        case ACTION_SAVE:
            saveBtn.click(saveBtn);
            return true;
        case ACTION_OPEN:
            openBtn.click(openBtn);
            return true;
        default:
            return false;
        }
    };
    root.keyToAction = delegate(Widget source, uint keyCode, uint flags) {
        return menu.findKeyAction(keyCode, flags);
    };

    window.mainWidget = root;
    window.show();
    populateDevices();
    sampleBtn.click(sampleBtn);
    return Platform.instance.enterMessageLoop();
}

MenuItem buildMenu()
{
    auto main = new MenuItem();
    auto file = new MenuItem(new Action(1, "File"c));
    file.add(new Action(ACTION_OPEN, "Open image…"c, null, KeyCode.KEY_O, KeyFlag.Control));
    file.add(new Action(ACTION_SAVE, "Save…"c, null, KeyCode.KEY_S, KeyFlag.Control));
    auto scan = new MenuItem(new Action(2, "Scan"c));
    scan.add(new Action(ACTION_PREVIEW, "Preview"c));
    scan.add(new Action(ACTION_SCAN, "Scan"c, null, KeyCode.KEY_R, KeyFlag.Control));
    scan.add(new Action(ACTION_REFRESH, "Refresh devices"c, null, KeyCode.F5, 0));
    auto help = new MenuItem(new Action(3, "Help"c));
    help.add(new Action(ACTION_ABOUT, "About"c));
    help.add(new Action(ACTION_DEBUG, "Debug dump"c));
    main.add(file);
    main.add(scan);
    main.add(help);
    return main;
}

string debugDump()
{
    import std.array : appender;
    auto a = appender!string();
    a.put(versionLine());
    a.put("\nbackend count: ");
    a.put(to!string(registry.all().length));
    a.put("\ndevices:\n");
    foreach (d; devices)
    {
        a.put(" - ");
        a.put(d.backendId);
        a.put(" | ");
        a.put(d.name);
        a.put("\n");
    }
    a.put("lastError: ");
    a.put(lastError);
    a.put("\n");
    return a.data;
}
