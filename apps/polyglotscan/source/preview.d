module preview;

import dlangui;
import polyglotscan.core.raster : Raster;
import polyglotscan.image.ops : BinarizeSettings, applyBinarize, toArgb32;
import std.conv : to;
import std.format : format;

/// Pan / wheel-zoom / optional loupe. The actual reason this app exists.
final class PreviewCanvas : Widget
{
    Raster source;
    BinarizeSettings binarize;
    float zoom = 1.0f;
    int panX;
    int panY;
    bool loupe;
    bool dragging;
    int lastX, lastY;
    ColorDrawBuf imageBuf;
    dstring statusLine = "Open the sample receipt or run Preview on a scanner."d;

    this()
    {
        super("preview");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        padding(Rect(1, 1, 1, 1));
        backgroundColor = 0xFF1A1A1A;
        focusGroup = true;
        clickable = true;
        focusable = true;
    }

    void setSource(Raster r)
    {
        source = r;
        panX = 0;
        panY = 0;
        if (zoom < 0.2f)
            zoom = 1.0f;
        rebuild();
        invalidate();
    }

    void setBinarize(BinarizeSettings s)
    {
        binarize = s;
        rebuild();
        invalidate();
    }

    void rebuild()
    {
        if (source.width <= 0)
        {
            destroy(imageBuf);
            imageBuf = null;
            return;
        }
        auto shown = applyBinarize(source, binarize);
        auto argb = toArgb32(shown);
        if (imageBuf is null || imageBuf.width != shown.width || imageBuf.height != shown.height)
        {
            destroy(imageBuf);
            imageBuf = new ColorDrawBuf(shown.width, shown.height);
        }
        foreach (y; 0 .. shown.height)
        {
            auto line = imageBuf.scanLine(y);
            line[0 .. shown.width] = argb[y * shown.width .. (y + 1) * shown.width];
        }
        statusLine = to!dstring(shown.width) ~ "×"d ~ to!dstring(shown.height) ~ "  "d
            ~ to!dstring(shown.dpiX) ~ " dpi  zoom "d ~ to!dstring(format("%.0f%%", zoom * 100));
    }

    override bool onMouseEvent(MouseEvent event)
    {
        if (event.action == MouseAction.Wheel)
        {
            auto factor = event.wheelDelta > 0 ? 1.15f : 1.0f / 1.15f;
            zoom = clampZoom(zoom * factor);
            rebuild();
            invalidate();
            return true;
        }
        if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left)
        {
            dragging = true;
            lastX = event.x;
            lastY = event.y;
            setFocus();
            return true;
        }
        if (event.action == MouseAction.ButtonUp && event.button == MouseButton.Left)
        {
            dragging = false;
            return true;
        }
        if (event.action == MouseAction.Move)
        {
            if (dragging)
            {
                panX += event.x - lastX;
                panY += event.y - lastY;
                lastX = event.x;
                lastY = event.y;
                invalidate();
            }
            else if (loupe)
            {
                lastX = event.x;
                lastY = event.y;
                invalidate();
            }
            return true;
        }
        return super.onMouseEvent(event);
    }

    override bool onKeyEvent(KeyEvent event)
    {
        if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.SPACE)
        {
            zoom = 1.0f;
            panX = 0;
            panY = 0;
            rebuild();
            invalidate();
            return true;
        }
        return super.onKeyEvent(event);
    }

    override void onDraw(DrawBuf buf)
    {
        super.onDraw(buf);
        Rect rc = _pos;
        applyMargins(rc);
        applyPadding(rc);
        auto saver = ClipRectSaver(buf, rc);
        buf.fillRect(rc, 0xFF1A1A1A);
        if (imageBuf is null)
        {
            font.drawText(buf, rc.left + 16, rc.top + 16,
                    "Preview fills this pane. Wheel zoom · drag pan · Space reset · Loupe in the toolbar."d,
                    0xFFB0B0B0);
            return;
        }
        int dw = cast(int)(imageBuf.width * zoom);
        int dh = cast(int)(imageBuf.height * zoom);
        int x0 = rc.left + panX + (rc.width - dw) / 2;
        int y0 = rc.top + panY + (rc.height - dh) / 2;
        buf.drawRescaled(Rect(x0, y0, x0 + dw, y0 + dh), imageBuf,
                Rect(0, 0, imageBuf.width, imageBuf.height));
        font.drawText(buf, rc.left + 8, rc.bottom - 22, statusLine, 0xFFE0E0E0);
        if (loupe)
        {
            auto mx = lastX;
            auto my = lastY;
            int mag = 12;
            int srcX = cast(int)((mx - x0) / zoom);
            int srcY = cast(int)((my - y0) / zoom);
            int box = 140;
            auto dest = Rect(mx + 16, my + 16, mx + 16 + box, my + 16 + box);
            if (dest.right > rc.right)
                dest = Rect(mx - 16 - box, dest.top, mx - 16, dest.bottom);
            buf.fillRect(Rect(dest.left - 1, dest.top - 1, dest.right + 1, dest.bottom + 1), 0xFFFFFFFF);
            auto sx0 = srcX - mag;
            auto sy0 = srcY - mag;
            auto sx1 = srcX + mag;
            auto sy1 = srcY + mag;
            if (sx0 < 0) { sx1 -= sx0; sx0 = 0; }
            if (sy0 < 0) { sy1 -= sy0; sy0 = 0; }
            if (sx1 > imageBuf.width) sx1 = imageBuf.width;
            if (sy1 > imageBuf.height) sy1 = imageBuf.height;
            if (sx1 > sx0 && sy1 > sy0)
                buf.drawRescaled(dest, imageBuf, Rect(sx0, sy0, sx1, sy1));
        }
    }

    private float clampZoom(float z)
    {
        if (z < 0.1f)
            return 0.1f;
        if (z > 16f)
            return 16f;
        return z;
    }
}
