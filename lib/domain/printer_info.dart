class PrinterInfo {
  const PrinterInfo({
    required this.id,
    required this.name,
    required this.driver,
    required this.isDefault,
    required this.isNetwork,
    required this.isOffline,
    required this.statusFa,
    required this.duplex,
    required this.color,
  });
  final String id, name, driver, statusFa;
  final bool isDefault, isNetwork, isOffline, duplex, color;
}
