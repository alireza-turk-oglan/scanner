#pragma once
#include <flutter/binary_messenger.h>

// ثبت کانال persian_scanner/hardware (شناسایی اسکنر WIA/TWAIN و چاپگر).
void RegisterHardwareChannel(flutter::BinaryMessenger* messenger);
