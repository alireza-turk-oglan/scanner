import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../domain/export_format.dart';

class Raster {
  Raster(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width, height;
}

Future<Raster> toRaster(ui.Image im) async {
  final bd = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
  return Raster(Uint8List.fromList(bd!.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes)), im.width, im.height);
}

/// کدگذاری JPG / PNG / TIFF روی Isolate جدا تا رابط قفل نشود (PDF در pdf_writer ساخته می‌شود).
Future<Uint8List> encodeRaster(Raster r, ExportFormat f, {int quality = 90}) => Isolate.run(() {
      final image = img.Image.fromBytes(
        width: r.width, height: r.height, bytes: r.rgba.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
      switch (f) {
        case ExportFormat.jpg:
          return img.encodeJpg(image.convert(numChannels: 3), quality: quality);
        case ExportFormat.png:
          return img.encodePng(image);
        case ExportFormat.tiff:
          return img.encodeTiff(image);
        case ExportFormat.pdf:
          throw ArgumentError('PDF با buildPdf ساخته می‌شود');
      }
    });
