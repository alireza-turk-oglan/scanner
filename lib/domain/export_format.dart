enum ExportFormat { pdf, jpg, png, tiff }

extension ExportFormatX on ExportFormat {
  String get ext => switch (this) {
        ExportFormat.pdf => 'pdf',
        ExportFormat.jpg => 'jpg',
        ExportFormat.png => 'png',
        ExportFormat.tiff => 'tif',
      };
  String get labelFa => switch (this) {
        ExportFormat.pdf => 'PDF',
        ExportFormat.jpg => 'JPG',
        ExportFormat.png => 'PNG',
        ExportFormat.tiff => 'TIFF',
      };
  static ExportFormat fromName(String n) =>
      ExportFormat.values.firstWhere((f) => f.name == n || f.ext == n, orElse: () => ExportFormat.pdf);
}
