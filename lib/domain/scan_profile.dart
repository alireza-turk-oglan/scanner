import 'layout_engine.dart';

/// هر حالت اسکن فقط یک پروفایل روی هسته مشترک است.
enum ScanMode { idCard, multiPage, standard }

class ScanProfile {
  const ScanProfile({
    required this.mode,
    required this.titleFa,
    required this.pageSizeMm,
    required this.pagesPerSession, // null = نامحدود
    required this.defaultDpi,
  });
  final ScanMode mode;
  final String titleFa;
  final PageSpec pageSizeMm;
  final int? pagesPerSession;
  final int defaultDpi;

  static const idCard = ScanProfile(
      mode: ScanMode.idCard,
      titleFa: 'کارت ملی و مدارک هویتی',
      pageSizeMm: PageSpec.idCard,
      pagesPerSession: 2,
      defaultDpi: 300);
  static const multiPage = ScanProfile(
      mode: ScanMode.multiPage,
      titleFa: 'اسناد چندصفحه‌ای',
      pageSizeMm: PageSpec.a4,
      pagesPerSession: null,
      defaultDpi: 300);
  static const standard = ScanProfile(
      mode: ScanMode.standard,
      titleFa: 'اسکن استاندارد',
      pageSizeMm: PageSpec.a4,
      pagesPerSession: 1,
      defaultDpi: 300);
  static const all = [idCard, multiPage, standard];
}
