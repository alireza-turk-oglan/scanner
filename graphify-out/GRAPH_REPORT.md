# Graph Report - scanner  (2026-11-25)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1208 nodes · 1662 edges · 65 communities (53 shown, 12 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8de91e26`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- hardware_channel.cpp
- card_composer.dart
- page_edits.dart
- settings.dart
- _
- scanner_backend.dart
- export_service.dart
- page_editor.dart
- shell.dart
- _
- card_pipeline.dart
- scan_session.dart
- main.dart
- card_layout.dart
- scan_page.dart
- widgets.dart
- export_dialog.dart
- home_page.dart
- String?
- card_detection.dart
- hardware_controller.dart
- pubspec.yaml
- hardware_channel.dart
- jalali.dart
- scan_channel.dart
- State
- pdf_writer.dart
- ScanReq
- scan_channel.cpp
- Win32Window
- flutter_window.cpp
- card_test.dart
- ScanCtx
- WriteGuid
- win32_window.cpp
- encoders.dart
- TransferCb
- services.dart
- StatelessWidget
- WindowClassRegistrar
- pages.dart
- FlutterWindow
- .MessageHandler
- settings_page.dart
- export_test.dart
- ScanImpl
- ../core/jalali.dart
- package:flutter_test/flutter_test.dart
- Rel
- package:flutter/material.dart
- UiProc
- HardwareController
- ../core/env.dart
- generated_plugin_registrant.h
- analysis_options.yaml
- printer_info.dart
- Point
- Size
- app.env
- ScanArea
- Rect
- Scanner Project
- _PreviewViewport
- Scanner Project

## God Nodes (most connected - your core abstractions)
1. `_` - 57 edges
2. `Win32Window` - 27 edges
3. `_` - 26 edges
4. `ScanReq` - 19 edges
5. `ScanImpl()` - 14 edges
6. `FlutterWindow` - 12 edges
7. `TwainSession` - 12 edges
8. `TransferCb` - 12 edges
9. `ScanCtx` - 12 edges
10. `RegisterHardwareChannel()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `FlutterWindow::OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `FlutterWindow::OnCreate()` --calls--> `RegisterHardwareChannel()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/hardware_channel.cpp
- `FlutterWindow::OnCreate()` --calls--> `RegisterScanChannel()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/scan_channel.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Runner Executable CMake` --references--> `Flutter Managed CMake`  [INFERRED]
  windows/runner/CMakeLists.txt → windows/flutter/CMakeLists.txt

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Custom Platform Channels** — windows_runner_hardware_channel_cpp_windows_runner_hardware_channel, windows_runner_scan_channel_cpp_windows_runner_scan_channel [INFERRED 0.80]

## Communities (65 total, 12 thin omitted)

### Community 0 - "hardware_channel.cpp"
Cohesion: 0.07
Nodes (32): AnsiToUtf8(), CreateWiaMgr(), Decode(), GetCap(), HwError, code, msg, ItemSize() (+24 more)

### Community 1 - "card_composer.dart"
Cohesion: 0.04
Nodes (53): _, _birthH, birthScanHeightMm, birthScanWidthMm, _birthW, cardCols, cardEdgeMm, cardGapMm (+45 more)

### Community 2 - "page_edits.dart"
Cohesion: 0.04
Nodes (48): _boxMm, build, _busy, _c, _cache, _change, _chip, _chooseFolder (+40 more)

### Community 3 - "settings.dart"
Cohesion: 0.05
Nodes (34): cardW, defaultDpi, defaultFormat, defaultMargin, defaultPaper, defaultPattern, _file, fromJson (+26 more)

### Community 4 - "_"
Cohesion: 0.05
Nodes (37): bd, buildFileName, c, dpi, e, format, fromName, i (+29 more)

### Community 5 - "scanner_backend.dart"
Cohesion: 0.05
Nodes (37): fileTag, firstPageFa, IdDocType, IdDocTypeX, labelFa, scanFirstFa, scanSecondFa, secondPageFa (+29 more)

### Community 6 - "export_service.dart"
Cohesion: 0.05
Nodes (41): applyEdit, base, bg, border, bottom, brightness, bytes, c (+33 more)

### Community 7 - "page_editor.dart"
Cohesion: 0.05
Nodes (35): NativeScannerBackend, cancel, ColorMode, colorModes, connected, contrast, deviceId, dpi (+27 more)

### Community 8 - "shell.dart"
Cohesion: 0.05
Nodes (34): bd, bytes, c, c2, canvas, CardImage, codec, cropCard (+26 more)

### Community 9 - "_"
Cohesion: 0.05
Nodes (35): area, atLimit, backend, _bmpBits, brightness, cancel, clear, color (+27 more)

### Community 10 - "card_pipeline.dart"
Cohesion: 0.06
Nodes (24): backend, build, _c, _card, _content, createState, dispose, hw (+16 more)

### Community 11 - "scan_session.dart"
Cohesion: 0.06
Nodes (25): autoDirection, AutoDirField, _AutoDirFieldState, autofocus, build, _c, controller, createState (+17 more)

### Community 12 - "main.dart"
Cohesion: 0.06
Nodes (29): PageEdit, _autoMargin, build, _changed, _cl, createState, _CropOverlay, _CropOverlayState (+21 more)

### Community 13 - "card_layout.dart"
Cohesion: 0.07
Nodes (25): build, _busy, createState, customW, dispose, _export, _ExportDialog, _ExportDialogState (+17 more)

### Community 14 - "scan_page.dart"
Cohesion: 0.07
Nodes (19): art, build, button, buttonColor, buttonIcon, color, _fa, hw (+11 more)

### Community 15 - "widgets.dart"
Cohesion: 0.10
Nodes (7): Windows Project CMake, Flutter Managed CMake, Runner Executable CMake, wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 16 - "export_dialog.dart"
Cohesion: 0.08
Nodes (23): a4Landscape, anchor, applyDefaultMargins, autoCrop, box, CardLayoutSpec, cardW, ComposedPage (+15 more)

### Community 17 - "home_page.dart"
Cohesion: 0.08
Nodes (24): a, best, bg, border, c, detectCard, DetectedCard, dil (+16 more)

### Community 18 - "String?"
Cohesion: 0.09
Nodes (16): add, bytes, createdAt, entries, _file, format, fromJson, id (+8 more)

### Community 19 - "card_detection.dart"
Cohesion: 0.09
Nodes (18): _, a3, a4, a5, grid, heightMm, idCard, index (+10 more)

### Community 20 - "hardware_controller.dart"
Cohesion: 0.11
Nodes (13): _backend, build, createState, _hw, initState, library, main, _native (+5 more)

### Community 21 - "pubspec.yaml"
Cohesion: 0.10
Nodes (15): capabilities, capabilitiesError, _hw, _loadCapabilities, loading, printers, refresh, scanners (+7 more)

### Community 22 - "hardware_channel.dart"
Cohesion: 0.10
Nodes (19): dependencies, cupertino_icons, flutter, flutter_localizations, image, description, dev_dependencies, flutter_lints (+11 more)

### Community 23 - "jalali.dart"
Cohesion: 0.11
Nodes (14): _ch, devices, getCapabilities, HardwareException, listPrinters, listScanners, messageFa, NativeHardware (+6 more)

### Community 24 - "scan_channel.dart"
Cohesion: 0.11
Nodes (17): _breaks, _cal, day, fileStamp, format, fromDateTime, j, JalaliDate (+9 more)

### Community 25 - "State"
Cohesion: 0.11
Nodes (12): cancel, _ch, _events, getCapabilities, _hw, listDevices, name, NativeScan (+4 more)

### Community 26 - "pdf_writer.dart"
Cohesion: 0.12
Nodes (14): build, createState, _delete, DocumentsPage, _DocumentsPageState, _folder, _info, library (+6 more)

### Community 27 - "ScanReq"
Cohesion: 0.14
Nodes (3): Get(), InitUi(), RegisterScanChannel()

### Community 28 - "scan_channel.cpp"
Cohesion: 0.12
Nodes (12): PageSpec, all, defaultDpi, idCard, mode, multiPage, pageSizeMm, pagesPerSession (+4 more)

### Community 29 - "Win32Window"
Cohesion: 0.12
Nodes (16): RunJob(), ScanReq, ah, aw, ax, ay, brightness, color (+8 more)

### Community 30 - "flutter_window.cpp"
Cohesion: 0.13
Nodes (13): buildPdf, f, jpeg, kids, mmToPt, obj, offsets, out (+5 more)

### Community 31 - "card_test.dart"
Cohesion: 0.20
Nodes (12): _NumField, _NumFieldState, _PageEditor, _PageEditorState, AppShell, _AppShellState, _CaseBar, _CaseBarState (+4 more)

### Community 32 - "ScanCtx"
Cohesion: 0.18
Nodes (7): FlutterWindow::OnCreate(), Win32Window::GetClientArea(), Win32Window::OnCreate(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 34 - "win32_window.cpp"
Cohesion: 0.15
Nodes (6): bd, encodeRaster, height, Raster, rgba, toRaster

### Community 35 - "encoders.dart"
Cohesion: 0.17
Nodes (6): main, out, _page, _spec, t, main

### Community 36 - "TransferCb"
Cohesion: 0.19
Nodes (10): PickFolder(), ScanCtx, dir, job, lastPath, pageNo, pages, warnings (+2 more)

### Community 37 - "services.dart"
Cohesion: 0.23
Nodes (4): HrFa(), ScaleToRange(), WriteGuid(), WriteLong()

### Community 38 - "StatelessWidget"
Cohesion: 0.21
Nodes (4): Win32Window::Show(), EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window()

### Community 39 - "WindowClassRegistrar"
Cohesion: 0.17
Nodes (3): main, main, main

### Community 40 - "pages.dart"
Cohesion: 0.24
Nodes (3): TransferCb, ctx_, ref_

### Community 41 - "FlutterWindow"
Cohesion: 0.18
Nodes (6): AppServices, caseName, chooseOutDir, library, resolveSaveDir, settings

### Community 42 - ".MessageHandler"
Cohesion: 0.18
Nodes (10): HomeScreen, _IdArt, _ModeCard, _PaperArt, _Seg, _StatusBar, SettingsPage, _Sidebar (+2 more)

### Community 43 - "settings_page.dart"
Cohesion: 0.31
Nodes (6): Emit(), EmitError(), EmitType(), PostUi(), Put(), ScanImpl()

### Community 44 - "export_test.dart"
Cohesion: 0.18
Nodes (4): Win32Window::Destroy(), WindowClassRegistrar, class_registered_, instance_

### Community 45 - "ScanImpl"
Cohesion: 0.20
Nodes (6): build, DevicesPage, hw, _msg, PlaceholderPage, stage

### Community 46 - "../core/jalali.dart"
Cohesion: 0.20
Nodes (5): FlutterWindow::OnDestroy(), FlutterWindow, flutter_controller_, project_, Win32Window::OnDestroy()

### Community 49 - "package:flutter/material.dart"
Cohesion: 0.25
Nodes (5): capsSummaryFa, colorFa, parts, sourceFa, toPersianDigits

### Community 50 - "UiProc"
Cohesion: 0.29
Nodes (3): PickItem(), Rel, p

### Community 51 - "HardwareController"
Cohesion: 0.33
Nodes (5): ExportFormat, ExportFormatX, ext, fromName, labelFa

### Community 53 - "generated_plugin_registrant.h"
Cohesion: 0.40
Nodes (4): HardwareController, DocumentLibrary, ScanSession, AppSettings

### Community 55 - "printer_info.dart"
Cohesion: 0.50
Nodes (3): include, linter, rules

### Community 57 - "Size"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 58 - "app.env"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **707 isolated node(s):** `code`, `msg`, `p`, `app`, `hwnd` (+702 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 869 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_` connect `card_composer.dart` to `scan_channel.cpp`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **What connects `code`, `msg`, `p` to the rest of the system?**
  _707 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `hardware_channel.cpp` be split into smaller, more focused modules?**
  _Cohesion score 0.06704260651629072 - nodes in this community are weakly interconnected._
- **Why does `_` connect `card_detection.dart` to `encoders.dart`, `scan_channel.cpp`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Should `card_composer.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.03636363636363636 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `ScanCtx` to `StatelessWidget`, `export_test.dart`, `../core/jalali.dart`, `package:flutter_test/flutter_test.dart`, `widgets.dart`, `Size`, `app.env`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Should `page_edits.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.038461538461538464 - nodes in this community are weakly interconnected._