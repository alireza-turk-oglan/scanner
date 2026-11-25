import '../core/env.dart';

/// نوع مدرک در حالت اسکن مدارک هویتی؛ هر نوع ناحیه اسکن مخصوص خودش را دارد.
enum IdDocType { nationalCard, birthCert, passport }

extension IdDocTypeX on IdDocType {
  String get labelFa => switch (this) {
    IdDocType.nationalCard => 'کارت ملی',
    IdDocType.birthCert => 'شناسنامه',
    IdDocType.passport => 'پاسپورت',
  };
  String get firstPageFa => switch (this) {
    IdDocType.nationalCard => 'روی کارت',
    IdDocType.birthCert => 'صفحه اول',
    IdDocType.passport => 'صفحه اطلاعات',
  };
  String get secondPageFa => switch (this) {
    IdDocType.nationalCard => 'پشت کارت',
    IdDocType.birthCert => 'صفحه دوم',
    IdDocType.passport => 'صفحه دیگر',
  };
  String get scanFirstFa => switch (this) {
    IdDocType.nationalCard => 'اسکن روی کارت',
    IdDocType.birthCert => 'اسکن صفحه اول شناسنامه',
    IdDocType.passport => 'اسکن صفحه اطلاعات پاسپورت',
  };
  String get scanSecondFa => switch (this) {
    IdDocType.nationalCard => 'اسکن پشت کارت',
    IdDocType.birthCert => 'اسکن صفحه دوم شناسنامه',
    IdDocType.passport => 'اسکن صفحه دیگر پاسپورت',
  };

  /// بخش نوع سند در نام فایل خروجی.
  String get fileTag => switch (this) {
    IdDocType.nationalCard => 'IDCard',
    IdDocType.birthCert => 'BirthCert',
    IdDocType.passport => 'Passport',
  };

  /// اندازه پیش‌فرض ناحیه اسکن (از app.env)؛ مقدار قابل تنظیم کاربر در AppSettings است.
  ({double w, double h}) get defaultScanMm => switch (this) {
    IdDocType.nationalCard => (w: Env.cardScanWidthMm, h: Env.cardScanHeightMm),
    IdDocType.birthCert => (w: Env.birthScanWidthMm, h: Env.birthScanHeightMm),
    IdDocType.passport => (w: Env.passportScanWidthMm, h: Env.passportScanHeightMm),
  };
}
