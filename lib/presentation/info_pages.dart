import 'package:flutter/material.dart';

import '../core/env.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget h(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 6), child: Text(t, style: Theme.of(context).textTheme.titleMedium));
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('راهنما', style: Theme.of(context).textTheme.headlineSmall),
      h('شروع کار'),
      const Text('۱. اسکنر را روشن و به کامپیوتر وصل کنید. در نوار پایین صفحه خانه باید «آماده به کار» ببینید.\n'
          '۲. اگر چند دستگاه دارید، از همان نوار اسکنر و چاپگر پیش‌فرض را انتخاب کنید.\n'
          '۳. «اسکن مدارک هویتی» یا «اسکن معمولی» را بزنید.'),
      h('اسکن کارت ملی و مدارک'),
      const Text('روی کارت را روی شیشه بگذارید و «اسکن روی کارت» را بزنید، سپس پشت کارت. '
          'در زبانه «چیدمان و خروجی» برش را دستی تنظیم کنید و خروجی را انتخاب کنید: جداگانه، ترکیب در یک تصویر یا روی صفحه A4 با اندازه واقعی.'),
      h('اسکن معمولی و چندصفحه‌ای'),
      const Text('برای یک صفحه «اسناد و صفحات» و برای چند صفحه «اسکن چندصفحه‌ای» را انتخاب کنید. '
          'با ADF همه صفحات خودکار اسکن می‌شود. هر صفحه را می‌توان ویرایش، چرخاند، جابه‌جا یا دوباره اسکن کرد. خروجی: PDF، JPG، PNG یا TIFF.'),
      h('اگر اسکنر پیدا نشد'),
      const Text('کابل و روشن بودن دستگاه و نصب درایور را بررسی کنید. اگر دستگاه فقط درایور TWAIN دارد، اسکن با آن هنوز پشتیبانی نمی‌شود.'),
      h('حریم خصوصی'),
      const Text('برنامه کاملاً آفلاین است و هیچ تصویری به اینترنت فرستاده نمی‌شود. فایل‌ها فقط در پوشه‌ای که شما انتخاب می‌کنید ذخیره می‌شوند.'),
    ]);
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        Text('درباره برنامه', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const ListTile(leading: Icon(Icons.scanner), title: Text('اسکنر حرفه‌ای'), subtitle: Text('اسکن • مدیریت • چاپ')),
        const ListTile(leading: Icon(Icons.numbers), title: Text('نسخه'), subtitle: Text('0.5.0 (در حال توسعه)')),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('مقدارهای فعال app.env'),
          subtitle: Text(
            'کارت: ${Env.cardWidthMm} × ${Env.cardHeightMm} mm — فاصله: ${Env.cardGapMm} — لبه برش: ${Env.cardEdgeMm}\n'
            'سطر × ستون: ${Env.cardRows} × ${Env.cardCols} — DPI: ${Env.defaultDpi} — حاشیه: ${Env.pageMarginMm}\n'
            'اگر با app.env یکی نیست، برنامه را متوقف و دوباره با --dart-define-from-file=app.env اجرا کنید.',
            textDirection: TextDirection.ltr,
          ),
        ),
        const ListTile(leading: Icon(Icons.wifi_off), title: Text('کاملاً آفلاین'), subtitle: Text('هیچ داده‌ای به اینترنت ارسال نمی‌شود.')),
      ]);
}
