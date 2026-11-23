# Graph Report - scanner  (2026-11-23)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1178 nodes · 1625 edges · 62 communities (49 shown, 13 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 17 edges (avg confidence: 0.85)
- Token cost: 5,878 input · 321 output

## Graph Freshness
- Built from commit: `a5d3cce2`
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
- Scanner Project

## God Nodes (most connected - your core abstractions)
1. `_` - 45 edges
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

## Communities (62 total, 13 thin omitted)

### Community 0 - "hardware_channel.cpp"
Cohesion: 0.06
Nodes (32): AnsiToUtf8(), CreateWiaMgr(), Decode(), GetCap(), HwError, code, msg, ItemSize() (+24 more)

### Community 1 - "card_composer.dart"
Cohesion: 0.04
Nodes (47): build, _busy, _c, _cache, _change, _chip, _chooseFolder, _clearPreviews (+39 more)

### Community 2 - "page_edits.dart"
Cohesion: 0.04
Nodes (44): applyEdit, base, bg, border, bottom, brightness, bytes, c (+36 more)

### Community 3 - "settings.dart"
Cohesion: 0.05
Nodes (38): add, bytes, createdAt, entries, _file, format, fromJson, id (+30 more)

### Community 4 - "_"
Cohesion: 0.05
Nodes (41): _, cardCols, cardEdgeMm, cardGapMm, _cardH, cardHeightMm, cardOutputDpi, cardRows (+33 more)

### Community 5 - "scanner_backend.dart"
Cohesion: 0.05
Nodes (35): NativeScannerBackend, cancel, ColorMode, colorModes, connected, contrast, deviceId, dpi (+27 more)

### Community 6 - "export_service.dart"
Cohesion: 0.05
Nodes (34): bd, buildFileName, c, dpi, e, format, fromName, i (+26 more)

### Community 7 - "page_editor.dart"
Cohesion: 0.06
Nodes (33): PageEdit, _BracketsPainter, _autoMargin, build, _changed, _cl, createState, _CropOverlay (+25 more)

### Community 8 - "shell.dart"
Cohesion: 0.06
Nodes (30): AppShell, _AppShellState, backend, build, _c, _card, _CaseBar, _CaseBarState (+22 more)

### Community 9 - "_"
Cohesion: 0.05
Nodes (30): _, a3, a4, a5, grid, heightMm, idCard, index (+22 more)

### Community 10 - "card_pipeline.dart"
Cohesion: 0.05
Nodes (34): bd, bytes, c, c2, canvas, CardImage, codec, cropCard (+26 more)

### Community 11 - "scan_session.dart"
Cohesion: 0.05
Nodes (34): area, atLimit, backend, _bmpBits, brightness, cancel, clear, color (+26 more)

### Community 12 - "main.dart"
Cohesion: 0.06
Nodes (27): _backend, build, createState, _hw, initState, library, main, _native (+19 more)

### Community 13 - "card_layout.dart"
Cohesion: 0.06
Nodes (28): a4Landscape, anchor, applyDefaultMargins, autoCrop, box, CardLayoutSpec, cardW, ComposedPage (+20 more)

### Community 14 - "scan_page.dart"
Cohesion: 0.07
Nodes (24): _applyEffective, build, _compose, createState, didUpdateWidget, dispose, edit, hw (+16 more)

### Community 15 - "widgets.dart"
Cohesion: 0.07
Nodes (23): autoDirection, autofocus, build, _c, controller, createState, _d, decoration (+15 more)

### Community 16 - "export_dialog.dart"
Cohesion: 0.07
Nodes (23): build, _busy, createState, customW, dispose, _export, format, initState (+15 more)

### Community 17 - "home_page.dart"
Cohesion: 0.07
Nodes (19): art, build, button, buttonColor, buttonIcon, color, _fa, hw (+11 more)

### Community 18 - "String?"
Cohesion: 0.10
Nodes (7): Windows Project CMake, Flutter Managed CMake, Runner Executable CMake, wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 19 - "card_detection.dart"
Cohesion: 0.08
Nodes (24): a, best, bg, border, c, detectCard, DetectedCard, dil (+16 more)

### Community 20 - "hardware_controller.dart"
Cohesion: 0.10
Nodes (15): capabilities, capabilitiesError, _hw, _loadCapabilities, loading, printers, refresh, scanners (+7 more)

### Community 21 - "pubspec.yaml"
Cohesion: 0.10
Nodes (19): dependencies, cupertino_icons, flutter, flutter_localizations, image, description, dev_dependencies, flutter_lints (+11 more)

### Community 22 - "hardware_channel.dart"
Cohesion: 0.11
Nodes (14): _ch, devices, getCapabilities, HardwareException, listPrinters, listScanners, messageFa, NativeHardware (+6 more)

### Community 23 - "jalali.dart"
Cohesion: 0.11
Nodes (17): _breaks, _cal, day, fileStamp, format, fromDateTime, j, JalaliDate (+9 more)

### Community 24 - "scan_channel.dart"
Cohesion: 0.11
Nodes (12): cancel, _ch, _events, getCapabilities, _hw, listDevices, name, NativeScan (+4 more)

### Community 25 - "State"
Cohesion: 0.16
Nodes (16): CardComposerView, _CardComposerViewState, _NumField, _NumFieldState, _PreviewViewport, _PreviewViewportState, _ExportDialog, _ExportDialogState (+8 more)

### Community 26 - "pdf_writer.dart"
Cohesion: 0.12
Nodes (13): buildPdf, f, jpeg, kids, mmToPt, obj, offsets, out (+5 more)

### Community 27 - "ScanReq"
Cohesion: 0.12
Nodes (16): RunJob(), ScanReq, ah, aw, ax, ay, brightness, color (+8 more)

### Community 28 - "scan_channel.cpp"
Cohesion: 0.16
Nodes (4): Get(), InitUi(), PostUi(), RegisterScanChannel()

### Community 29 - "Win32Window"
Cohesion: 0.18
Nodes (7): FlutterWindow::OnCreate(), Win32Window::GetClientArea(), Win32Window::OnCreate(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 31 - "card_test.dart"
Cohesion: 0.17
Nodes (6): main, out, _page, _spec, t, main

### Community 32 - "ScanCtx"
Cohesion: 0.19
Nodes (10): PickFolder(), ScanCtx, dir, job, lastPath, pageNo, pages, warnings (+2 more)

### Community 33 - "WriteGuid"
Cohesion: 0.23
Nodes (4): HrFa(), ScaleToRange(), WriteGuid(), WriteLong()

### Community 34 - "win32_window.cpp"
Cohesion: 0.21
Nodes (4): Win32Window::Show(), EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window()

### Community 35 - "encoders.dart"
Cohesion: 0.18
Nodes (6): bd, encodeRaster, height, Raster, rgba, toRaster

### Community 36 - "TransferCb"
Cohesion: 0.24
Nodes (3): TransferCb, ctx_, ref_

### Community 37 - "services.dart"
Cohesion: 0.18
Nodes (6): AppServices, caseName, chooseOutDir, library, resolveSaveDir, settings

### Community 38 - "StatelessWidget"
Cohesion: 0.18
Nodes (10): HomeScreen, _IdArt, _ModeCard, _PaperArt, _Seg, _StatusBar, SettingsPage, _Sidebar (+2 more)

### Community 39 - "WindowClassRegistrar"
Cohesion: 0.18
Nodes (4): Win32Window::Destroy(), WindowClassRegistrar, class_registered_, instance_

### Community 40 - "pages.dart"
Cohesion: 0.20
Nodes (6): build, DevicesPage, hw, _msg, PlaceholderPage, stage

### Community 41 - "FlutterWindow"
Cohesion: 0.20
Nodes (5): FlutterWindow::OnDestroy(), FlutterWindow, flutter_controller_, project_, Win32Window::OnDestroy()

### Community 45 - "ScanImpl"
Cohesion: 0.42
Nodes (5): Emit(), EmitError(), EmitType(), Put(), ScanImpl()

### Community 46 - "../core/jalali.dart"
Cohesion: 0.25
Nodes (5): capsSummaryFa, colorFa, parts, sourceFa, toPersianDigits

### Community 48 - "Rel"
Cohesion: 0.29
Nodes (3): PickItem(), Rel, p

### Community 51 - "HardwareController"
Cohesion: 0.40
Nodes (4): HardwareController, DocumentLibrary, ScanSession, AppSettings

### Community 52 - "../core/env.dart"
Cohesion: 0.40
Nodes (3): AboutPage, build, HelpPage

### Community 54 - "analysis_options.yaml"
Cohesion: 0.50
Nodes (3): include, linter, rules

### Community 56 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 57 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

## Knowledge Gaps
- **682 isolated node(s):** `code`, `msg`, `p`, `app`, `hwnd` (+677 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 843 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `win32_window.cpp`, `WindowClassRegistrar`, `FlutterWindow`, `.MessageHandler`, `String?`, `Point`, `Size`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **What connects `code`, `msg`, `p` to the rest of the system?**
  _682 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `hardware_channel.cpp` be split into smaller, more focused modules?**
  _Cohesion score 0.059227921734531994 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `_`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Should `card_composer.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0392156862745098 - nodes in this community are weakly interconnected._
- **Why does `_` connect `_` to `card_test.dart`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Should `page_edits.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._