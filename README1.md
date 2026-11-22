<!-- @format -->

## تنظیمات زمان کامپایل (app.env)

# Test

```bash
flutter test --dart-define-from-file=app.env
```

# Run on Windows

```bash
flutter run -d windows --dart-define-from-file=app.env
```

# Build Normal (Release)

```bash
flutter build windows --release --dart-define-from-file=app.env
```

# Build Release (Obfuscated)

```bash
flutter build windows --release --obfuscate --dart-define-from-file=app.env --split-debug-info=debug-info
```

# De-obfuscation For debug

```bash
flutter symbolize -i crash.txt -d "debug-info/app.windows-x64.symbols"
```
