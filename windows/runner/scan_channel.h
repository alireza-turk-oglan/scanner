#pragma once
#include <flutter/binary_messenger.h>

// کانال persian_scanner/scan: startScan / cancelScan و رویدادهای scanEvent به Dart.
void RegisterScanChannel(flutter::BinaryMessenger* messenger);
