// مرحله ۳: اسکن واقعی با WIA 2.0 (IWiaTransfer) روی رشته جداگانه تا رابط قفل نشود.
// فقط WIA؛ اسکن TWAIN هنوز پیاده‌سازی نشده است. این کد کامپایل‌نشده نوشته شده است.
#include "scan_channel.h"

#include <windows.h>
#include <objbase.h>
#include <shlwapi.h>
#include <shobjidl.h>
#include <wia.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cmath>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")
#pragma comment(lib, "wiaguid.lib")

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

// ───── ابزارها ─────
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
void Put(EncodableMap& m, const char* k, EncodableValue v) { m[EncodableValue(std::string(k))] = std::move(v); }

template <class T>
bool Get(const EncodableMap& m, const char* k, T& out) {
  auto it = m.find(EncodableValue(std::string(k)));
  if (it == m.end()) return false;
  if (auto* v = std::get_if<T>(&it->second)) { out = *v; return true; }
  return false;
}

// ───── ارسال به رشته رابط (پنجره پیام مخفی روی همان رشته‌ای که ثبت‌کننده است) ─────
const UINT kWmUi = WM_APP + 17;
HWND g_ui = nullptr;
std::mutex g_mu;
std::queue<std::function<void()>> g_q;
std::unique_ptr<flutter::MethodChannel<EncodableValue>> g_channel;
std::atomic<bool> g_busy{false}, g_cancel{false};
std::atomic<int> g_job{0};

LRESULT CALLBACK UiProc(HWND h, UINT m, WPARAM w, LPARAM l) {
  if (m == kWmUi) {
    for (;;) {
      std::function<void()> f;
      { std::lock_guard<std::mutex> lk(g_mu); if (g_q.empty()) break; f = std::move(g_q.front()); g_q.pop(); }
      f();
    }
    return 0;
  }
  return DefWindowProcW(h, m, w, l);
}
void InitUi() {
  if (g_ui) return;
  WNDCLASSW wc{};
  wc.lpfnWndProc = UiProc;
  wc.hInstance = GetModuleHandleW(nullptr);
  wc.lpszClassName = L"PersianScannerUiBridge";
  RegisterClassW(&wc);
  g_ui = CreateWindowExW(0, wc.lpszClassName, L"", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
}
void PostUi(std::function<void()> f) {
  { std::lock_guard<std::mutex> lk(g_mu); g_q.push(std::move(f)); }
  PostMessageW(g_ui, kWmUi, 0, 0);
}
void Emit(EncodableMap m, int job) {
  Put(m, "jobId", EncodableValue(job));
  PostUi([m]() {
    if (g_channel) g_channel->InvokeMethod("scanEvent", std::make_unique<EncodableValue>(m));
  });
}
void EmitType(const char* type, int job) {
  EncodableMap m; Put(m, "type", EncodableValue(std::string(type))); Emit(m, job);
}
void EmitError(const std::string& msg, int job) {
  EncodableMap m; Put(m, "type", EncodableValue(std::string("error"))); Put(m, "message", EncodableValue(msg)); Emit(m, job);
}

std::string HrFa(HRESULT hr) {
  if (hr == WIA_ERROR_PAPER_JAM) return "کاغذ داخل اسکنر گیر کرده است. کاغذ را خارج کنید و دوباره تلاش کنید.";
  if (hr == WIA_ERROR_PAPER_EMPTY) return "کاغذی در تغذیه‌کننده (ADF) نیست.";
  if (hr == WIA_ERROR_PAPER_PROBLEM) return "مشکل در کاغذ اسکنر. وضعیت کاغذ را بررسی کنید.";
  if (hr == WIA_ERROR_OFFLINE) return "اسکنر آفلاین است. روشن بودن و کابل را بررسی کنید.";
  if (hr == WIA_ERROR_BUSY) return "اسکنر مشغول است؛ کمی صبر کنید و دوباره تلاش کنید.";
  if (hr == WIA_ERROR_WARMING_UP) return "اسکنر در حال گرم شدن است؛ کمی صبر کنید.";
  if (hr == WIA_ERROR_USER_INTERVENTION) return "دستگاه نیاز به دخالت شما دارد (مثلاً درب باز یا خطای دستگاه).";
  if (hr == WIA_ERROR_COVER_OPEN) return "درب اسکنر باز است.";
  if (hr == WIA_ERROR_DEVICE_COMMUNICATION) return "ارتباط با اسکنر قطع شد. کابل را بررسی کنید.";
  return "اسکن ناموفق بود. اتصال و درایور دستگاه را بررسی کنید.";
}

// ───── ویژگی‌های WIA ─────
HRESULT WriteLong(IWiaPropertyStorage* ps, PROPID id, LONG v) {
  PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
  PROPVARIANT pv; PropVariantInit(&pv); pv.vt = VT_I4; pv.lVal = v;
  return ps->WriteMultiple(1, &s, &pv, WIA_IPA_FIRST);
}
HRESULT WriteGuid(IWiaPropertyStorage* ps, PROPID id, const GUID& g) {
  PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
  PROPVARIANT pv; PropVariantInit(&pv); pv.vt = VT_CLSID; pv.puuid = const_cast<GUID*>(&g);
  return ps->WriteMultiple(1, &s, &pv, WIA_IPA_FIRST);
}
// درصد (‎-۱۰۰..۱۰۰) را به بازه واقعی دستگاه تبدیل می‌کند؛ اگر بازه نبود LONG_MIN.
LONG ScaleToRange(IWiaPropertyStorage* ps, PROPID id, int pct) {
  PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
  ULONG flags = 0; PROPVARIANT v; PropVariantInit(&v);
  LONG out = LONG_MIN;
  if (ps->GetPropertyAttributes(1, &s, &flags, &v) == S_OK && (flags & WIA_PROP_RANGE) && (v.vt & VT_VECTOR) && v.cal.pElems) {
    LONG mn = v.cal.pElems[WIA_RANGE_MIN], nom = v.cal.pElems[WIA_RANGE_NOM], mx = v.cal.pElems[WIA_RANGE_MAX];
    out = pct >= 0 ? nom + (LONG)std::lround((mx - nom) * pct / 100.0) : nom + (LONG)std::lround((nom - mn) * pct / 100.0);
  }
  PropVariantClear(&v);
  return out;
}

// ───── درخواست و بافت اسکن ─────
struct ScanReq {
  int job = 0;
  std::string deviceId, source, color;
  int dpi = 300, brightness = 0, contrast = 0, pages = 0;
  bool hasArea = false;
  double ax = 0, ay = 0, aw = 0, ah = 0;
  std::wstring outDir;
};

struct ScanCtx {
  int job = 0, pageNo = 0, pages = 0;
  std::wstring dir, lastPath;
  std::vector<std::string> warnings;
};

class TransferCb : public IWiaTransferCallback {
 public:
  explicit TransferCb(ScanCtx* c) : ctx_(c) {}
  STDMETHODIMP QueryInterface(REFIID iid, void** ppv) override {
    if (iid == IID_IUnknown || iid == __uuidof(IWiaTransferCallback)) {
      *ppv = static_cast<IWiaTransferCallback*>(this); AddRef(); return S_OK;
    }
    *ppv = nullptr; return E_NOINTERFACE;
  }
  STDMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&ref_); }
  STDMETHODIMP_(ULONG) Release() override { ULONG r = InterlockedDecrement(&ref_); if (!r) delete this; return r; }

  STDMETHODIMP TransferCallback(LONG, WiaTransferParams* p) override {
    if (p) {
      if (p->lMessage == WIA_TRANSFER_MSG_STATUS) {
        EncodableMap m; Put(m, "type", EncodableValue(std::string("progress")));
        Put(m, "percent", EncodableValue((int)p->lPercentComplete)); Emit(m, ctx_->job);
      } else if (p->lMessage == WIA_TRANSFER_MSG_END_OF_STREAM && !ctx_->lastPath.empty()) {
        ctx_->pages++;
        EncodableMap m; Put(m, "type", EncodableValue(std::string("page")));
        Put(m, "path", EncodableValue(Utf8(ctx_->lastPath))); Emit(m, ctx_->job);
      }
    }
    return g_cancel.load() ? S_FALSE : S_OK;
  }
  STDMETHODIMP GetNextStream(LONG, BSTR, BSTR, IStream** pp) override {
    if (g_cancel.load()) return S_FALSE;
    ctx_->pageNo++;
    wchar_t name[64];
    swprintf_s(name, L"\\page_%d_%d.bmp", ctx_->job, ctx_->pageNo);
    ctx_->lastPath = ctx_->dir + name;
    return SHCreateStreamOnFileEx(ctx_->lastPath.c_str(), STGM_CREATE | STGM_WRITE | STGM_SHARE_DENY_WRITE,
                                  FILE_ATTRIBUTE_NORMAL, TRUE, nullptr, pp);
  }

 private:
  ULONG ref_ = 1;
  ScanCtx* ctx_;
};

bool PickItem(IWiaItem2* root, bool adf, Rel<IWiaItem2>& item) {
  const GUID* cat = adf ? &WIA_CATEGORY_FEEDER : &WIA_CATEGORY_FLATBED;
  for (int pass = 0; pass < 2; pass++) {
    Rel<IEnumWiaItem2> kids;
    if (FAILED(root->EnumChildItems(pass == 0 ? cat : nullptr, &kids))) continue;
    ULONG got = 0;
    if (kids->Next(1, &item, &got) == S_OK && got == 1) return true;
  }
  root->AddRef(); item.p = root;  // درایورهایی که آیتم فرزند ندارند
  return true;
}

void ScanImpl(const ScanReq& r) {
  ScanCtx ctx; ctx.job = r.job; ctx.dir = r.outDir;

  Rel<IWiaDevMgr2> mgr;
  if (FAILED(CoCreateInstance(__uuidof(WiaDevMgr2), nullptr, CLSCTX_LOCAL_SERVER, __uuidof(IWiaDevMgr2), (void**)&mgr))) {
    EmitError("سرویس WIA ویندوز در دسترس نیست.", r.job); return;
  }
  BSTR b = SysAllocString(Wide(r.deviceId).c_str());
  Rel<IWiaItem2> root;
  HRESULT hr = mgr->CreateDevice(0, b, &root);
  SysFreeString(b);
  if (FAILED(hr)) { EmitError("اتصال به اسکنر برقرار نشد. روشن بودن و اتصال دستگاه را بررسی کنید.", r.job); return; }

  const bool adf = r.source != "flatbed";
  Rel<IWiaPropertyStorage> rps;
  root->QueryInterface(__uuidof(IWiaPropertyStorage), (void**)&rps);
  if (rps) {
    WriteLong(rps.p, WIA_DPS_DOCUMENT_HANDLING_SELECT, adf ? (0x01 | (r.source == "adfDuplex" ? 0x04 : 0)) : 0x02);
    WriteLong(rps.p, WIA_DPS_PAGES, adf ? r.pages : 1);
  }

  Rel<IWiaItem2> item;
  PickItem(root.p, adf, item);
  Rel<IWiaPropertyStorage> ips;
  if (FAILED(item->QueryInterface(__uuidof(IWiaPropertyStorage), (void**)&ips))) {
    EmitError("خواندن تنظیمات اسکنر ممکن نشد.", r.job); return;
  }

  auto setL = [&](PROPID id, LONG v, const char* warn) {
    if (FAILED(WriteLong(ips.p, id, v)) && warn) ctx.warnings.push_back(warn);
  };
  // درایورهای WIA قدیمی رنگ را از «قصد اسکن» (Intent) می‌گیرند؛ اول آن را می‌نویسیم
  // (نوشتنش ممکن است رزولوشن و عمق را بازنشانی کند، پس قبل از بقیه تنظیمات می‌آید).
  WriteLong(ips.p, WIA_IPS_CUR_INTENT, r.color == "color" ? 1 : (r.color == "gray" ? 2 : 4));
  setL(WIA_IPS_XRES, r.dpi, "رزولوشن انتخابی توسط دستگاه پذیرفته نشد و مقدار پیش‌فرض دستگاه استفاده شد.");
  setL(WIA_IPS_YRES, r.dpi, nullptr);
  // مقادیر واقعی WIA: THRESHOLD=0، DITHER=1، GRAYSCALE=2، COLOR=3 (از ماکروها استفاده می‌شود)
  const LONG dt = r.color == "color" ? WIA_DATA_COLOR : (r.color == "gray" ? WIA_DATA_GRAYSCALE : WIA_DATA_THRESHOLD);
  setL(WIA_IPA_DATATYPE, dt, "حالت رنگ انتخابی توسط دستگاه پذیرفته نشد.");
  setL(WIA_IPA_DEPTH, dt == WIA_DATA_COLOR ? 24 : (dt == WIA_DATA_GRAYSCALE ? 8 : 1), nullptr);
  if (r.brightness != 0) {
    LONG v = ScaleToRange(ips.p, WIA_IPS_BRIGHTNESS, r.brightness);
    if (v == LONG_MIN) ctx.warnings.push_back("تنظیم روشنایی توسط دستگاه پشتیبانی نمی‌شود."); else setL(WIA_IPS_BRIGHTNESS, v, nullptr);
  }
  if (r.contrast != 0) {
    LONG v = ScaleToRange(ips.p, WIA_IPS_CONTRAST, r.contrast);
    if (v == LONG_MIN) ctx.warnings.push_back("تنظیم کنتراست توسط دستگاه پشتیبانی نمی‌شود."); else setL(WIA_IPS_CONTRAST, v, nullptr);
  }
  // ناحیه اسکن همیشه صریح تنظیم می‌شود (درایور ممکن است ناحیه قبلی/کوچک را نگه دارد)
  {
    auto rdL = [](IWiaPropertyStorage* ps, PROPID id, LONG* out) {
      if (!ps) return false;
      PROPSPEC sp; sp.ulKind = PRSPEC_PROPID; sp.propid = id;
      PROPVARIANT v; PropVariantInit(&v);
      bool ok = ps->ReadMultiple(1, &sp, &v) == S_OK && (v.vt == VT_I4 || v.vt == VT_UI4);
      if (ok) *out = v.lVal;
      PropVariantClear(&v);
      return ok;
    };
    // اندازه فیزیکی سطح اسکن (هزارم اینچ): ADF → اندازه ورق، وگرنه شیشه
    LONG bw = 0, bh = 0;
    bool haveBed = false;
    if (adf) haveBed = rdL(rps.p, WIA_DPS_HORIZONTAL_SHEET_FEED_SIZE, &bw) && rdL(rps.p, WIA_DPS_VERTICAL_SHEET_FEED_SIZE, &bh) && bw > 0 && bh > 0;
    if (!haveBed) haveBed = rdL(rps.p, WIA_DPS_HORIZONTAL_BED_SIZE, &bw) && rdL(rps.p, WIA_DPS_VERTICAL_BED_SIZE, &bh) && bw > 0 && bh > 0;
    const double bedWmm = haveBed ? bw * 0.0254 : 0, bedHmm = haveBed ? bh * 0.0254 : 0;
    auto px = [&](double mm) { return (LONG)std::lround(mm / 25.4 * r.dpi); };

    double ax = 0, ay = 0, aw = 0, ah = 0;
    bool ok = false;
    if (r.hasArea) {
      ax = r.ax; ay = r.ay; aw = r.aw; ah = r.ah; ok = true;
      if (haveBed) {
        if (ax + aw > bedWmm) aw = bedWmm - ax;
        if (ay + ah > bedHmm) ah = bedHmm - ay;
      }
    } else if (haveBed) {
      aw = bedWmm; ah = bedHmm; ok = true;
    }
    if (ok && aw > 1 && ah > 1) {
      WriteLong(ips.p, WIA_IPS_XPOS, 0);
      WriteLong(ips.p, WIA_IPS_YPOS, 0);
      setL(WIA_IPS_XEXTENT, px(aw), "محدوده اسکن توسط دستگاه پذیرفته نشد؛ ممکن است فقط بخشی از صفحه اسکن شود.");
      setL(WIA_IPS_YEXTENT, px(ah), nullptr);
      if (ax > 0) WriteLong(ips.p, WIA_IPS_XPOS, px(ax));
      if (ay > 0) WriteLong(ips.p, WIA_IPS_YPOS, px(ay));
    } else if (!r.hasArea) {
      // اندازه سطح معلوم نیست: بیشینه مجاز درایور
      LONG mw = 0, mh = 0;
      if (rdL(ips.p, WIA_IPS_MAX_HORIZONTAL_SIZE, &mw) && rdL(ips.p, WIA_IPS_MAX_VERTICAL_SIZE, &mh) && mw > 0 && mh > 0) {
        WriteLong(ips.p, WIA_IPS_XPOS, 0);
        WriteLong(ips.p, WIA_IPS_YPOS, 0);
        setL(WIA_IPS_XEXTENT, mw, nullptr);
        setL(WIA_IPS_YEXTENT, mh, nullptr);
      }
    }
  }
  // بازخوانی مقادیر واقعی اعمال‌شده توسط درایور (عیب‌یابی رنگ و رزولوشن)
  {
    auto readL = [&](PROPID id, LONG* out) {
      PROPSPEC s; s.ulKind = PRSPEC_PROPID; s.propid = id;
      PROPVARIANT v; PropVariantInit(&v);
      bool ok = ips->ReadMultiple(1, &s, &v) == S_OK && (v.vt == VT_I4 || v.vt == VT_UI4);
      if (ok) *out = v.lVal;
      PropVariantClear(&v);
      return ok;
    };
    LONG got = -1;
    if (readL(WIA_IPA_DATATYPE, &got) && got != dt)
      ctx.warnings.push_back("دستگاه حالت رنگ درخواستی را اعمال نکرد (کد حالت فعلی دستگاه: " + std::to_string(got) + ").");
    if (readL(WIA_IPS_XRES, &got) && got != r.dpi)
      ctx.warnings.push_back("دستگاه رزولوشن " + std::to_string(got) + " را اعمال کرد، نه " + std::to_string(r.dpi) + ".");
  }
  WriteGuid(ips.p, WIA_IPA_FORMAT, WiaImgFmt_BMP);

  Rel<IWiaTransfer> tr;
  if (FAILED(item->QueryInterface(__uuidof(IWiaTransfer), (void**)&tr))) {
    EmitError("این دستگاه از انتقال تصویر WIA 2.0 پشتیبانی نمی‌کند.", r.job); return;
  }
  auto* cb = new TransferCb(&ctx);
  hr = tr->Download(0, cb);
  cb->Release();

  if (hr == S_FALSE || g_cancel.load()) { EmitType("cancelled", r.job); return; }
  if (FAILED(hr) && !(hr == WIA_ERROR_PAPER_EMPTY && ctx.pages > 0)) {
    EmitError(HrFa(hr), r.job); return;
  }
  EncodableMap m; EncodableList w;
  for (auto& s : ctx.warnings) w.push_back(EncodableValue(s));
  Put(m, "type", EncodableValue(std::string("done"))); Put(m, "warnings", w);
  Emit(m, r.job);
}

// دیالوگ انتخاب پوشه (روی رشته رابط)
std::string PickFolder() {
  Rel<IFileOpenDialog> dlg;
  if (FAILED(CoCreateInstance(__uuidof(FileOpenDialog), nullptr, CLSCTX_INPROC_SERVER,
                              __uuidof(IFileOpenDialog), (void**)&dlg))) return {};
  DWORD opts = 0;
  dlg->GetOptions(&opts);
  dlg->SetOptions(opts | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM);
  dlg->SetTitle(L"انتخاب پوشه ذخیره‌سازی");
  if (dlg->Show(GetActiveWindow()) != S_OK) return {};
  Rel<IShellItem> item;
  if (FAILED(dlg->GetResult(&item))) return {};
  PWSTR path = nullptr;
  if (FAILED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) || !path) return {};
  std::string out = Utf8(path);
  CoTaskMemFree(path);
  return out;
}

void RunJob(ScanReq r) {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  ScanImpl(r);  // همه اشیای COM قبل از خروج از ScanImpl آزاد می‌شوند
  CoUninitialize();
  g_busy = false;
}

}  // namespace

void RegisterScanChannel(flutter::BinaryMessenger* messenger) {
  InitUi();
  g_channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "persian_scanner/scan", &flutter::StandardMethodCodec::GetInstance());
  g_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "startScan") {
          const auto* a = std::get_if<EncodableMap>(call.arguments());
          ScanReq r;
          std::string id, out;
          if (!a || !Get(*a, "deviceId", id) || !Get(*a, "outDir", out) || id.rfind("wia:", 0) != 0) {
            result->Error("BAD_ARGS", "فقط اسکنرهای WIA برای اسکن پشتیبانی می‌شوند."); return;
          }
          bool expected = false;
          if (!g_busy.compare_exchange_strong(expected, true)) {
            result->Error("BUSY", "اسکن دیگری در حال انجام است."); return;
          }
          r.deviceId = id.substr(4);
          r.outDir = Wide(out);
          Get(*a, "source", r.source); Get(*a, "color", r.color);
          int32_t v = 0;
          if (Get(*a, "dpi", v)) r.dpi = v;
          if (Get(*a, "brightness", v)) r.brightness = v;
          if (Get(*a, "contrast", v)) r.contrast = v;
          if (Get(*a, "pages", v)) r.pages = v;
          if (Get(*a, "ax", r.ax) && Get(*a, "ay", r.ay) && Get(*a, "aw", r.aw) && Get(*a, "ah", r.ah)) r.hasArea = true;
          r.job = ++g_job;
          g_cancel = false;
          std::thread(RunJob, r).detach();
          result->Success(EncodableValue(r.job));
        } else if (call.method_name() == "pickFolder") {
          std::string p = PickFolder();
          if (p.empty()) result->Success(); else result->Success(EncodableValue(p));
        } else if (call.method_name() == "cancelScan") {
          g_cancel = true;
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}
