import 'dart:convert';
import 'dart:typed_data';

/// یک صفحه PDF: تصویر JPEG روی مستطیل (x,y,w,h) بر حسب پوینت (مبدأ پایین-چپ).
class PdfPageSpec {
  PdfPageSpec({required this.jpeg, required this.pxW, required this.pxH,
      required this.pageWpt, required this.pageHpt, required this.x, required this.y, required this.w, required this.h});
  final Uint8List jpeg;
  final int pxW, pxH;
  final double pageWpt, pageHpt, x, y, w, h;
}

double mmToPt(double mm) => mm / 25.4 * 72;

/// سازنده ساده PDF 1.4 با تصاویر JPEG (DCTDecode).
Uint8List buildPdf(List<PdfPageSpec> pages) {
  final out = BytesBuilder();
  final offsets = <int>[];
  void w(String s) => out.add(latin1.encode(s));
  String f(double v) => v.toStringAsFixed(2);
  void obj(int id, void Function() body) {
    offsets.add(out.length);
    w('$id 0 obj\n');
    body();
    w('endobj\n');
  }

  out.add([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  obj(1, () => w('<< /Type /Catalog /Pages 2 0 R >>\n'));
  final kids = [for (var i = 0; i < pages.length; i++) '${3 + 3 * i} 0 R'].join(' ');
  obj(2, () => w('<< /Type /Pages /Kids [$kids] /Count ${pages.length} >>\n'));
  for (var i = 0; i < pages.length; i++) {
    final p = pages[i];
    final pageId = 3 + 3 * i, contentId = pageId + 1, imageId = pageId + 2;
    obj(pageId, () => w(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${f(p.pageWpt)} ${f(p.pageHpt)}] '
        '/Resources << /XObject << /Im0 $imageId 0 R >> >> /Contents $contentId 0 R >>\n'));
    final content = 'q ${f(p.w)} 0 0 ${f(p.h)} ${f(p.x)} ${f(p.y)} cm /Im0 Do Q\n';
    obj(contentId, () {
      w('<< /Length ${content.length} >>\nstream\n$content');
      w('endstream\n');
    });
    obj(imageId, () {
      w('<< /Type /XObject /Subtype /Image /Width ${p.pxW} /Height ${p.pxH} /ColorSpace /DeviceRGB '
          '/BitsPerComponent 8 /Filter /DCTDecode /Length ${p.jpeg.length} >>\nstream\n');
      out.add(p.jpeg);
      w('\nendstream\n');
    });
  }
  final xrefPos = out.length;
  w('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    w('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  w('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xrefPos\n%%EOF\n');
  return out.toBytes();
}
