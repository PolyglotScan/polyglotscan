module polyglotscan.encode.io;

import std.file : write;
import std.path : extension;
import std.string : toLower;

import polyglotscan.core.raster;
import polyglotscan.encode.jpeg : encodeJpeg;
import polyglotscan.encode.jxl : encodeJxl;
import polyglotscan.encode.pdf : encodePdf;
import polyglotscan.encode.png : encodePng;

ubyte[] encodeByExtension(const Raster raster, string path)
{
    auto ext = extension(path).toLower;
    switch (ext)
    {
    case ".png":
        return encodePng(raster);
    case ".jpg":
    case ".jpeg":
        return encodeJpeg(raster);
    case ".jxl":
        return encodeJxl(raster);
    case ".pdf":
        return encodePdf(raster);
    default:
        throw new ScanException("unknown export type: " ~ ext ~ " (use .png .jpg .jxl .pdf)");
    }
}

void saveRaster(const Raster raster, string path)
{
    write(path, encodeByExtension(raster, path));
}
