module polyglotscan.encode.pdf;

import std.conv : to;
import std.format : format;
import std.zlib : compress;

import polyglotscan.core.raster;
import polyglotscan.image.ops : toGray8;

/// Image-only PDF 1.4 wrapping a Flate DeviceGray page. No OCR layer yet.
ubyte[] encodePdf(const Raster raster)
{
    auto gray = toGray8(raster);
    const w = gray.width;
    const h = gray.height;
    const wPt = w * 72.0 / (gray.dpiX > 0 ? gray.dpiX : 72);
    const hPt = h * 72.0 / (gray.dpiY > 0 ? gray.dpiY : 72);

    ubyte[] raw;
    raw.length = gray.height * (1 + gray.width); // PNG-style is not PDF; PDF image is unfiltered samples
    raw = gray.samples.dup;
    auto flate = compress(raw);

    auto content = format("q %0.2f 0 0 %0.2f 0 0 cm /Im0 Do Q\n", wPt, hPt);

    string obj1 = "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n";
    string obj2 = "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n";
    string obj3 = format(
        "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 %0.2f %0.2f] " ~
            "/Resources << /XObject << /Im0 5 0 R >> >> /Contents 4 0 R >> endobj\n",
        wPt, hPt);
    string obj4 = format("4 0 obj << /Length %s >> stream\n%s\nendstream endobj\n",
        content.length, content);

    auto header5 = format(
        "5 0 obj << /Type /XObject /Subtype /Image /Width %s /Height %s " ~
            "/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /Length %s >> stream\n",
        w, h, flate.length);

    ubyte[] pdf = cast(ubyte[]) "%PDF-1.4\n";
    size_t[6] xref;
    xref[1] = pdf.length;
    pdf ~= cast(ubyte[]) obj1;
    xref[2] = pdf.length;
    pdf ~= cast(ubyte[]) obj2;
    xref[3] = pdf.length;
    pdf ~= cast(ubyte[]) obj3;
    xref[4] = pdf.length;
    pdf ~= cast(ubyte[]) obj4;
    xref[5] = pdf.length;
    pdf ~= cast(ubyte[]) header5;
    pdf ~= flate;
    pdf ~= cast(ubyte[]) "\nendstream endobj\n";

    auto startxref = pdf.length;
    auto xrefTable = "xref\n0 6\n0000000000 65535 f \n";
    foreach (i; 1 .. 6)
        xrefTable ~= format("%010d 00000 n \n", xref[i]);
    xrefTable ~= format("trailer << /Size 6 /Root 1 0 R >>\nstartxref\n%s\n%%%%EOF\n", startxref);
    pdf ~= cast(ubyte[]) xrefTable;
    return pdf;
}
