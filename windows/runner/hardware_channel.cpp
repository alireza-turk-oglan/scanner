// مرحله ۲: شناسایی دستگاه‌ها و قابلیت‌ها (بدون اسکن؛ اسکن در مرحله ۳).
// توجه: این کد در محیط بدون ویندوز نوشته شده و باید اولین بار روی سیستم شما کامپایل شود.
#include "hardware_channel.h"

#include <windows.h>
#include <winspool.h>
#include <objbase.h>
#include <wia.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <memory>
#include <set>
#include <string>
#include <vector>

// twain.h را از twain.org دریافت و کنار همین فایل بگذارید؛ در غیر این صورت TWAIN غیرفعال می‌ماند.
#if __has_include("twain.h")
#include "twain.h"
#define HAVE_TWAIN 1
#else
#define HAVE_TWAIN 0
#endif

#pragma comment(lib, "winspool.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

struct HwError {
  std::string code;
  std::string msg;  // فارسی
};

template <class T>
struct Rel {
  T* p = nullptr;
  Rel() = default;
  Rel(const Rel&) = delete;
  Rel& operator=(const Rel&) = delete;
  ~Rel() { if (p) p->Release(); }
  T** operator&() { return &p; }
  T* operator->() { return p; }
  explicit operator bool() const { return p != nullptr; }
};

std::string Utf8(const std::wstring& w) {
  if (w.empty()) return {};
  int n = WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), nullptr, 0, nullptr, nullptr);
  std::string s(n, '\0');
  WideCharToMultiByte(CP_UTF8, 0, w.data(), (int)w.size(), s.data(), n, nullptr, nullptr);
  return s;
}

std::wstring Wide(const std::string& s) {
  if (s.empty()) return {};
  int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring w(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), w.data(), n);
  return w;
}

std::string AnsiToUtf8(const char* a) {
  int n = MultiByteToWideChar(CP_ACP, 0, a, -1, nullptr, 0);
  if (n <= 1) return {};
  std::wstring w(n - 1, L'\0');
  MultiByteToWideChar(CP_ACP, 0, a, -1, w.data(), n);
  return Utf8(w);
}

void Put(EncodableMap& m, const char* k, EncodableValue v) {
  m[EncodableValue(std::string(k))] = std::move(v);
}

const int kStdDpis[] = {75, 100, 150, 200, 300, 400, 600, 1200, 2400};

// ───────────────────────────── WIA ─────────────────────────────

void CreateWiaMgr(Rel<IWiaDevMgr2>& mgr) {
  HRESULT hr = CoCreateInstance(__uuidof(WiaDevMgr2), nullptr, CLSCTX_LOCAL_SERVER,
                                __uuidof(IWiaDevMgr2), (void**)&mgr);
  if (FAILED(hr))
    throw HwError{"WIA_UNAVAILABLE", "سرویس WIA ویندوز در دسترس نیست. سرویس «Windows Image Acquisition» را بررسی کنید."};
}

bool ReadLong(IWiaPropertyStorage* ps, PROPID id, LONG* out) {
  PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
  PROPVARIANT v; PropVariantInit(&v);
  bool ok = ps->ReadMultiple(1, &s, &v) == S_OK && (v.vt == VT_I4 || v.vt == VT_UI4);
  if (ok) *out = v.lVal;
  PropVariantClear(&v);
  return ok;
}

// مقادیر مجاز یک ویژگی عددی WIA: فهرست یا بازه.
struct Valid { bool ok = false, isRange = false; std::vector<LONG> v; };

Valid ReadValid(IWiaPropertyStorage* ps, PROPID id) {
  Valid r;
  PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
  ULONG flags = 0; PROPVARIANT v; PropVariantInit(&v);
  if (ps->GetPropertyAttributes(1, &s, &flags, &v) == S_OK && (v.vt & VT_VECTOR) && v.cal.pElems) {
    if (flags & WIA_PROP_LIST) {
      LONG count = v.cal.pElems[WIA_LIST_COUNT];
      for (LONG i = 0; i < count; i++) r.v.push_back(v.cal.pElems[WIA_LIST_VALUES + i]);
      r.ok = true;
    } else if (flags & WIA_PROP_RANGE) {
      r.isRange = true; r.ok = true;
      r.v = {v.cal.pElems[WIA_RANGE_MIN], v.cal.pElems[WIA_RANGE_MAX], v.cal.pElems[WIA_RANGE_STEP]};
    }
  }
  PropVariantClear(&v);
  return r;
}

void ListWia(EncodableList& out, EncodableList& warnings) {
  Rel<IWiaDevMgr2> mgr;
  try { CreateWiaMgr(mgr); } catch (const HwError& e) { warnings.push_back(EncodableValue(e.msg)); return; }
  Rel<IEnumWIA_DEV_INFO> en;
  if (FAILED(mgr->EnumDeviceInfo(WIA_DEVINFO_ENUM_LOCAL, &en))) {
    warnings.push_back(EncodableValue(std::string("خواندن فهرست دستگاه‌های WIA ممکن نشد.")));
    return;
  }
  for (;;) {
    Rel<IWiaPropertyStorage> ps; ULONG got = 0;
    if (en->Next(1, &ps, &got) != S_OK || got != 1) break;
    LONG type = 0;
    // نوع دستگاه در HIWORD است (StiDeviceTypeScanner = 1)؛ دوربین‌ها حذف می‌شوند.
    if (ReadLong(ps.p, WIA_DIP_DEV_TYPE, &type) && ((type >> 16) & 0xFFFF) != 1) continue;
    PROPSPEC spec[2]; PROPVARIANT var[2];
    for (int i = 0; i < 2; i++) { spec[i].ulKind = PRSPEC_PROPID; PropVariantInit(&var[i]); }
    spec[0].propid = WIA_DIP_DEV_ID; spec[1].propid = WIA_DIP_DEV_NAME;
    if (ps->ReadMultiple(2, spec, var) == S_OK && var[0].vt == VT_BSTR && var[0].bstrVal) {
      std::wstring id = var[0].bstrVal;
      std::wstring name = (var[1].vt == VT_BSTR && var[1].bstrVal) ? var[1].bstrVal : id;
      EncodableMap m;
      Put(m, "id", EncodableValue("wia:" + Utf8(id)));
      Put(m, "name", EncodableValue(Utf8(name)));
      Put(m, "driver", EncodableValue(std::string("WIA")));
      Put(m, "connected", EncodableValue(true));
      out.push_back(EncodableValue(m));
    }
    FreePropVariantArray(2, var);
  }
}

EncodableMap WiaCaps(const std::wstring& id) {
  Rel<IWiaDevMgr2> mgr; CreateWiaMgr(mgr);
  BSTR b = SysAllocString(id.c_str());
  Rel<IWiaItem2> root;
  HRESULT hr = mgr->CreateDevice(0, b, &root);
  SysFreeString(b);
  if (FAILED(hr))
    throw HwError{"WIA_OPEN", "اتصال به اسکنر برقرار نشد. روشن بودن و اتصال دستگاه را بررسی کنید."};

  Rel<IWiaPropertyStorage> rps;
  root->QueryInterface(__uuidof(IWiaPropertyStorage), (void**)&rps);

  bool flatbed = true, adf = false, duplex = false;
  LONG caps = 0; bool hasRaw = false;
  if (rps && ReadLong(rps.p, WIA_DPS_DOCUMENT_HANDLING_CAPABILITIES, &caps)) {
    hasRaw = true;
    flatbed = (caps & 0x01) != 0; adf = (caps & 0x02) != 0; duplex = (caps & 0x04) != 0;
  }
  double wMm = 0, hMm = 0;
  LONG bw = 0, bh = 0;
  if (rps && ReadLong(rps.p, WIA_DPS_HORIZONTAL_BED_SIZE, &bw) && ReadLong(rps.p, WIA_DPS_VERTICAL_BED_SIZE, &bh) && bw > 0 && bh > 0) {
    wMm = bw * 0.0254; hMm = bh * 0.0254;  // هزارم اینچ
  }

  std::set<int> dpis; std::set<LONG> types;
  Rel<IEnumWiaItem2> kids;
  if (SUCCEEDED(root->EnumChildItems(nullptr, &kids))) {
    for (;;) {
      Rel<IWiaItem2> it; ULONG got = 0;
      if (kids->Next(1, &it, &got) != S_OK || got != 1) break;
      Rel<IWiaPropertyStorage> ips;
      if (FAILED(it->QueryInterface(__uuidof(IWiaPropertyStorage), (void**)&ips))) continue;
      Valid x = ReadValid(ips.p, WIA_IPS_XRES);
      if (x.ok && !x.isRange) for (LONG d : x.v) dpis.insert((int)d);
      if (x.ok && x.isRange) {
        LONG mn = x.v[0], mx = x.v[1], st = std::max<LONG>(1, x.v[2]);
        for (int d : kStdDpis) if (d >= mn && d <= mx && (d - mn) % st == 0) dpis.insert(d);
      }
      Valid t = ReadValid(ips.p, WIA_IPA_DATATYPE);
      if (t.ok && !t.isRange) for (LONG d : t.v) types.insert(d);
    }
  }

  EncodableMap m;
  EncodableList d, s, c;
  for (int v : dpis) d.push_back(EncodableValue(v));
  if (flatbed) s.push_back(EncodableValue(std::string("flatbed")));
  if (adf) s.push_back(EncodableValue(std::string("adf")));
  if (adf && duplex) s.push_back(EncodableValue(std::string("adfDuplex")));
  if (types.count(WIA_DATA_COLOR)) c.push_back(EncodableValue(std::string("color")));
  if (types.count(WIA_DATA_GRAYSCALE)) c.push_back(EncodableValue(std::string("gray")));
  if (types.count(WIA_DATA_THRESHOLD)) c.push_back(EncodableValue(std::string("blackWhite")));
  Put(m, "dpis", d); Put(m, "sources", s); Put(m, "colorModes", c);
  if (hasRaw) Put(m, "rawHandling", EncodableValue((int)caps));
  if (wMm > 0) { Put(m, "maxWidthMm", EncodableValue(wMm)); Put(m, "maxHeightMm", EncodableValue(hMm)); }
  return m;
}

// ───────────────────────────── TWAIN ─────────────────────────────
#if HAVE_TWAIN
typedef TW_UINT16(FAR PASCAL* DSMENTRY)(pTW_IDENTITY, pTW_IDENTITY, TW_UINT32, TW_UINT16, TW_UINT16, TW_MEMREF);

struct TwainSession {
  HMODULE lib = nullptr; DSMENTRY dsm = nullptr; TW_IDENTITY app{}; HWND hwnd = nullptr; bool open = false;
  ~TwainSession() {
    if (open) dsm(&app, nullptr, DG_CONTROL, DAT_PARENT, MSG_CLOSEDSM, &hwnd);
    if (lib) FreeLibrary(lib);
  }
  bool Open() {
    lib = LoadLibraryW(L"TWAINDSM.dll");
    if (!lib) return false;
    dsm = (DSMENTRY)GetProcAddress(lib, "DSM_Entry");
    if (!dsm) return false;
    app.Id = 0;
    app.Version.MajorNum = 1; app.Version.MinorNum = 0;
    app.Version.Language = TWLG_ENGLISH_USA; app.Version.Country = TWCY_USA;
    strcpy_s(app.Version.Info, "1.0");
    app.ProtocolMajor = TWON_PROTOCOLMAJOR; app.ProtocolMinor = TWON_PROTOCOLMINOR;
    app.SupportedGroups = DF_APP2 | DG_CONTROL | DG_IMAGE;
    strcpy_s(app.Manufacturer, "PersianScanner");
    strcpy_s(app.ProductFamily, "PersianScanner");
    strcpy_s(app.ProductName, "PersianScanner");
    hwnd = GetDesktopWindow();
    open = dsm(&app, nullptr, DG_CONTROL, DAT_PARENT, MSG_OPENDSM, &hwnd) == TWRC_SUCCESS;
    return open;
  }
};

void ListTwain(EncodableList& out, EncodableList& warnings) {
  TwainSession s;
  if (!s.Open()) {
    warnings.push_back(EncodableValue(std::string("TWAIN DSM پیدا نشد؛ فقط اسکنرهای WIA نمایش داده می‌شوند.")));
    return;
  }
  TW_IDENTITY src{};
  TW_UINT16 rc = s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETFIRST, &src);
  while (rc == TWRC_SUCCESS) {
    EncodableMap m;
    std::string name = AnsiToUtf8(src.ProductName);
    Put(m, "id", EncodableValue("twain:" + name));
    Put(m, "name", EncodableValue(name));
    Put(m, "driver", EncodableValue(std::string("TWAIN")));
    Put(m, "connected", EncodableValue(true));
    out.push_back(EncodableValue(m));
    rc = s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETNEXT, &src);
  }
}

double Decode(TW_UINT16 t, const void* p) {
  switch (t) {
    case TWTY_INT8: return *(const int8_t*)p;
    case TWTY_UINT8: return *(const uint8_t*)p;
    case TWTY_INT16: return *(const int16_t*)p;
    case TWTY_UINT16: case TWTY_BOOL: return *(const uint16_t*)p;
    case TWTY_INT32: return *(const int32_t*)p;
    case TWTY_UINT32: return *(const uint32_t*)p;
    case TWTY_FIX32: { auto* f = (const TW_FIX32*)p; return f->Whole + f->Frac / 65536.0; }
  }
  return 0;
}
size_t ItemSize(TW_UINT16 t) {
  switch (t) {
    case TWTY_INT8: case TWTY_UINT8: return 1;
    case TWTY_INT16: case TWTY_UINT16: case TWTY_BOOL: return 2;
    case TWTY_INT32: case TWTY_UINT32: case TWTY_FIX32: return 4;
  }
  return 0;
}

// مقدار قابلیت را می‌خواند. اگر بازه باشد isRange=true و vals = {min,max,step}.
bool GetCap(TwainSession& s, TW_IDENTITY& ds, TW_UINT16 cap, std::vector<double>& vals, bool& isRange) {
  TW_CAPABILITY c{}; c.Cap = cap; c.ConType = TWON_DONTCARE16; c.hContainer = nullptr;
  if (s.dsm(&s.app, &ds, DG_CONTROL, DAT_CAPABILITY, MSG_GET, &c) != TWRC_SUCCESS || !c.hContainer) return false;
  void* p = GlobalLock(c.hContainer);
  isRange = false;
  if (p) {
    switch (c.ConType) {
      case TWON_ONEVALUE: { auto* o = (pTW_ONEVALUE)p; vals.push_back(Decode(o->ItemType, &o->Item)); break; }
      case TWON_ENUMERATION: {
        auto* e = (pTW_ENUMERATION)p; size_t sz = ItemSize(e->ItemType);
        for (TW_UINT32 i = 0; sz && i < e->NumItems; i++) vals.push_back(Decode(e->ItemType, e->ItemList + i * sz));
        break; }
      case TWON_ARRAY: {
        auto* a = (pTW_ARRAY)p; size_t sz = ItemSize(a->ItemType);
        for (TW_UINT32 i = 0; sz && i < a->NumItems; i++) vals.push_back(Decode(a->ItemType, a->ItemList + i * sz));
        break; }
      case TWON_RANGE: {
        auto* r = (pTW_RANGE)p; isRange = true;
        vals = {Decode(r->ItemType, &r->MinValue), Decode(r->ItemType, &r->MaxValue), Decode(r->ItemType, &r->StepSize)};
        break; }
    }
    GlobalUnlock(c.hContainer);
  }
  GlobalFree(c.hContainer);
  return true;
}

EncodableMap TwainCaps(const std::string& name) {
  TwainSession s;
  if (!s.Open()) throw HwError{"TWAIN_UNAVAILABLE", "TWAIN DSM روی این سیستم نصب نیست."};
  TW_IDENTITY ds{}; bool found = false;
  TW_UINT16 rc = s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETFIRST, &ds);
  while (rc == TWRC_SUCCESS) {
    if (AnsiToUtf8(ds.ProductName) == name) { found = true; break; }
    rc = s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_GETNEXT, &ds);
  }
  if (!found) throw HwError{"TWAIN_NOT_FOUND", "دستگاه TWAIN انتخاب‌شده دیگر پیدا نمی‌شود."};
  if (s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_OPENDS, &ds) != TWRC_SUCCESS)
    throw HwError{"TWAIN_OPEN", "اتصال به اسکنر برقرار نشد. روشن بودن و درایور دستگاه را بررسی کنید."};

  std::set<int> dpis; EncodableList src, col;
  std::vector<double> v; bool range = false;
  if (GetCap(s, ds, ICAP_XRESOLUTION, v, range)) {
    if (range && v.size() == 3) {
      double st = std::max(1.0, v[2]);
      for (int d : kStdDpis) if (d >= v[0] && d <= v[1] && std::fmod(d - v[0], st) == 0) dpis.insert(d);
    } else for (double d : v) dpis.insert((int)std::lround(d));
  }
  src.push_back(EncodableValue(std::string("flatbed")));
  bool adf = false;
  v.clear();
  if (GetCap(s, ds, CAP_FEEDERENABLED, v, range)) { adf = true; src.push_back(EncodableValue(std::string("adf"))); }
  v.clear();
  if (adf && GetCap(s, ds, CAP_DUPLEX, v, range) && !v.empty() && v[0] != 0) src.push_back(EncodableValue(std::string("adfDuplex")));
  v.clear();
  if (GetCap(s, ds, ICAP_PIXELTYPE, v, range))
    for (double t : v) {
      if (t == 2) col.push_back(EncodableValue(std::string("color")));
      if (t == 1) col.push_back(EncodableValue(std::string("gray")));
      if (t == 0) col.push_back(EncodableValue(std::string("blackWhite")));
    }
  s.dsm(&s.app, nullptr, DG_CONTROL, DAT_IDENTITY, MSG_CLOSEDS, &ds);

  EncodableMap m; EncodableList d;
  for (int x : dpis) d.push_back(EncodableValue(x));
  Put(m, "dpis", d); Put(m, "sources", src); Put(m, "colorModes", col);
  return m;
}
#else
void ListTwain(EncodableList&, EncodableList& warnings) {
  warnings.push_back(EncodableValue(std::string("پشتیبانی TWAIN در این ساخت فعال نیست (فایل twain.h اضافه نشده)؛ فقط WIA استفاده می‌شود.")));
}
EncodableMap TwainCaps(const std::string&) {
  throw HwError{"TWAIN_DISABLED", "پشتیبانی TWAIN در این ساخت فعال نیست."};
}
#endif

// ───────────────────────────── چاپگرها ─────────────────────────────

std::string PrinterStatusFa(DWORD st, DWORD attr) {
  if ((attr & PRINTER_ATTRIBUTE_WORK_OFFLINE) || (st & PRINTER_STATUS_OFFLINE)) return "آفلاین";
  if (st & PRINTER_STATUS_PAPER_JAM) return "گیر کردن کاغذ";
  if (st & PRINTER_STATUS_PAPER_OUT) return "کاغذ تمام شده";
  if (st & PRINTER_STATUS_DOOR_OPEN) return "درب باز است";
  if (st & PRINTER_STATUS_TONER_LOW) return "تونر کم است";
  if (st & PRINTER_STATUS_NO_TONER) return "تونر تمام شده";
  if (st & PRINTER_STATUS_PAUSED) return "متوقف‌شده";
  if (st & PRINTER_STATUS_ERROR) return "خطا";
  if (st & PRINTER_STATUS_PRINTING) return "در حال چاپ";
  if (st & PRINTER_STATUS_BUSY) return "مشغول";
  return "آماده";
}

EncodableList ListPrinters() {
  EncodableList out;
  DWORD need = 0, count = 0;
  const DWORD flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
  EnumPrintersW(flags, nullptr, 2, nullptr, 0, &need, &count);
  if (need == 0) return out;
  std::vector<BYTE> buf(need);
  if (!EnumPrintersW(flags, nullptr, 2, buf.data(), need, &need, &count))
    throw HwError{"PRINTERS", "خواندن فهرست چاپگرها ممکن نشد."};
  wchar_t def[512] = {0}; DWORD defLen = 512;
  GetDefaultPrinterW(def, &defLen);
  auto* info = (PRINTER_INFO_2W*)buf.data();
  for (DWORD i = 0; i < count; i++) {
    EncodableMap m;
    std::wstring name = info[i].pPrinterName ? info[i].pPrinterName : L"";
    const wchar_t* port = info[i].pPortName;
    Put(m, "id", EncodableValue(Utf8(name)));
    Put(m, "name", EncodableValue(Utf8(name)));
    Put(m, "driver", EncodableValue(Utf8(info[i].pDriverName ? info[i].pDriverName : L"")));
    Put(m, "isDefault", EncodableValue(name == def));
    Put(m, "isNetwork", EncodableValue((info[i].Attributes & PRINTER_ATTRIBUTE_NETWORK) != 0));
    bool offline = (info[i].Attributes & PRINTER_ATTRIBUTE_WORK_OFFLINE) || (info[i].Status & PRINTER_STATUS_OFFLINE);
    Put(m, "isOffline", EncodableValue(offline));
    Put(m, "statusFa", EncodableValue(PrinterStatusFa(info[i].Status, info[i].Attributes)));
    Put(m, "duplex", EncodableValue(DeviceCapabilitiesW(name.c_str(), port, DC_DUPLEX, nullptr, nullptr) == 1));
    Put(m, "color", EncodableValue(DeviceCapabilitiesW(name.c_str(), port, DC_COLORDEVICE, nullptr, nullptr) == 1));
    out.push_back(EncodableValue(m));
  }
  return out;
}

}  // namespace

void RegisterHardwareChannel(flutter::BinaryMessenger* messenger) {
  static std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "persian_scanner/hardware", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        try {
          const std::string& method = call.method_name();
          if (method == "listScanners") {
            EncodableList devices, warnings;
            ListWia(devices, warnings);
            ListTwain(devices, warnings);
            EncodableMap m;
            Put(m, "devices", devices); Put(m, "warnings", warnings);
            result->Success(EncodableValue(m));
          } else if (method == "getCapabilities") {
            const auto* args = std::get_if<EncodableMap>(call.arguments());
            const auto* idv = args ? std::get_if<std::string>(&args->at(EncodableValue(std::string("id")))) : nullptr;
            if (!idv) throw HwError{"BAD_ARGS", "شناسه دستگاه نامعتبر است."};
            if (idv->rfind("wia:", 0) == 0) result->Success(EncodableValue(WiaCaps(Wide(idv->substr(4)))));
            else if (idv->rfind("twain:", 0) == 0) result->Success(EncodableValue(TwainCaps(idv->substr(6))));
            else throw HwError{"BAD_ARGS", "شناسه دستگاه نامعتبر است."};
          } else if (method == "listPrinters") {
            result->Success(EncodableValue(ListPrinters()));
          } else {
            result->NotImplemented();
          }
        } catch (const HwError& e) {
          result->Error(e.code, e.msg);
        } catch (...) {
          result->Error("UNKNOWN", "خطای ناشناخته در ارتباط با سخت‌افزار.");
        }
      });
}
