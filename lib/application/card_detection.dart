import 'dart:math' as math;
import 'dart:typed_data';

import '../core/env.dart';

/// مستطیل جهت‌دار کارت در مختصات تصویر کوچک‌شده. theta = زاویه محور u (نزدیک‌ترین به افق).
class DetectedCard {
  const DetectedCard(this.cx, this.cy, this.w, this.h, this.theta);
  final double cx, cy, w, h, theta;
}

/// تشخیص کارت روی پس‌زمینه یکدست (شیشه/درب اسکنر) با PCA روی بزرگ‌ترین ناحیه.
/// [rgba] تصویر ۴کاناله به اندازه W×H. اگر کارت پیدا نشد null.
DetectedCard? detectCard(Uint8List rgba, int W, int H, {int? threshold}) {
  final thr = threshold ?? Env.detectThreshold;
  final n = W * H;
  final lum = Uint8List(n);
  for (var i = 0; i < n; i++) {
    lum[i] = (rgba[4 * i] * 299 + rgba[4 * i + 1] * 587 + rgba[4 * i + 2] * 114) ~/ 1000;
  }
  // پس‌زمینه = میانه پیکسل‌های لبه تصویر
  final border = <int>[];
  for (var x = 0; x < W; x++) {
    border..add(lum[x])..add(lum[(H - 1) * W + x]);
  }
  for (var y = 0; y < H; y++) {
    border..add(lum[y * W])..add(lum[y * W + W - 1]);
  }
  border.sort();
  final bg = border[border.length ~/ 2];

  final mask = Uint8List(n);
  for (var i = 0; i < n; i++) {
    mask[i] = (lum[i] - bg).abs() > thr ? 1 : 0;
  }

  // گسترش (dilate) با تصویر انتگرالی تا متن و نقش داخل کارت به هم وصل شوند
  final r = math.max(2, (W * 0.025).round());
  final iw = W + 1;
  final integ = Int32List((W + 1) * (H + 1));
  for (var y = 0; y < H; y++) {
    var rs = 0;
    for (var x = 0; x < W; x++) {
      rs += mask[y * W + x];
      integ[(y + 1) * iw + x + 1] = integ[y * iw + x + 1] + rs;
    }
  }
  final dil = Uint8List(n);
  for (var y = 0; y < H; y++) {
    final y0 = math.max(0, y - r), y1 = math.min(H, y + r + 1);
    for (var x = 0; x < W; x++) {
      final x0 = math.max(0, x - r), x1 = math.min(W, x + r + 1);
      final s = integ[y1 * iw + x1] - integ[y0 * iw + x1] - integ[y1 * iw + x0] + integ[y0 * iw + x0];
      dil[y * W + x] = s > 0 ? 1 : 0;
    }
  }

  // بزرگ‌ترین مؤلفه همبند
  final labels = Int32List(n);
  final stack = Int32List(n);
  var best = 0, bestArea = 0, cur = 0;
  for (var i = 0; i < n; i++) {
    if (dil[i] == 1 && labels[i] == 0) {
      cur++;
      var sp = 0, area = 0;
      stack[sp++] = i;
      labels[i] = cur;
      while (sp > 0) {
        final p = stack[--sp];
        area++;
        final x = p % W, y = p ~/ W;
        if (x > 0 && dil[p - 1] == 1 && labels[p - 1] == 0) { labels[p - 1] = cur; stack[sp++] = p - 1; }
        if (x < W - 1 && dil[p + 1] == 1 && labels[p + 1] == 0) { labels[p + 1] = cur; stack[sp++] = p + 1; }
        if (y > 0 && dil[p - W] == 1 && labels[p - W] == 0) { labels[p - W] = cur; stack[sp++] = p - W; }
        if (y < H - 1 && dil[p + W] == 1 && labels[p + W] == 0) { labels[p + W] = cur; stack[sp++] = p + W; }
      }
      if (area > bestArea) { best = cur; bestArea = area; }
    }
  }
  if (bestArea > 0.95 * n || bestArea < 0.02 * n) return null;

  var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    if (labels[i] == best) {
      final x = i % W + 0.5, y = i ~/ W + 0.5;
      sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y;
    }
  }
  final a = bestArea.toDouble();
  final mx = sx / a, my = sy / a;
  final mu20 = sxx / a - mx * mx, mu02 = syy / a - my * my, mu11 = sxy / a - mx * my;
  var th = 0.5 * math.atan2(2 * mu11, mu20 - mu02);
  if (th > math.pi / 4) th -= math.pi / 2;
  if (th < -math.pi / 4) th += math.pi / 2;
  final c = math.cos(th), s = math.sin(th);

  var uMin = 1e18, uMax = -1e18, vMin = 1e18, vMax = -1e18;
  for (var i = 0; i < n; i++) {
    if (labels[i] == best) {
      final dx = i % W + 0.5 - mx, dy = i ~/ W + 0.5 - my;
      final u = dx * c + dy * s, v = -dx * s + dy * c;
      if (u < uMin) uMin = u;
      if (u > uMax) uMax = u;
      if (v < vMin) vMin = v;
      if (v > vMax) vMax = v;
    }
  }
  // جبران گسترش مربعی (در راستای چرخیده بیشتر از r است)
  final shrink = r * (c.abs() + s.abs());
  uMin += shrink; uMax -= shrink; vMin += shrink; vMax -= shrink;
  if (uMax - uMin < 10 || vMax - vMin < 10) return null;
  final uc = (uMin + uMax) / 2, vc = (vMin + vMax) / 2;
  return DetectedCard(mx + uc * c - vc * s, my + uc * s + vc * c, uMax - uMin, vMax - vMin, th);
}
