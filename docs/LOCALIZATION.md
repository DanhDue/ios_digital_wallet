# Multi-Module Localization & Translations Guide

Tài liệu hướng dẫn kiến trúc, quy ước đặt tên, cách tạo mới, quản lý và cơ chế tự động hóa hệ thống đa ngôn ngữ (Localization) trong dự án **iOS Super App Template**.

---

## 1. Tổng quan & Triết lý thiết kế

Hệ thống Localization của dự án được thiết kế theo các nguyên tắc cốt lõi:

1. **Decentralized (Phân quyền theo module)**: Mỗi Feature (`Features/*`) và Package UI (`Packages/Shell`) tự quản lý catalog chuỗi riêng trong thư mục `Resources/Localizable.xcstrings` của module đó. Không tập trung toàn bộ chuỗi vào một file khổng lồ tại App host.
2. **Type-Safe Slang-Style Code Generation**: Script tự động quét tất cả catalog cục bộ để sinh ra typed accessors dạng dot-notation `t.<feature>.<subfeature>.<key>` (lấy cảm hứng từ thư viện [Slang](https://pub.dev/packages/slang)), giúp IDE auto-complete và bắt lỗi compile-time khi sai key.
3. **Cây phân cấp 3 tầng (Hierarchical 3-tier Scoping)**:
   $$\text{Feature} \longrightarrow \text{Subfeature} \longrightarrow \text{Key / Property}$$
   Cấu trúc này map **1:1** với cây JSON từ Backend OTA Remote API.
4. **Hỗ trợ OTA 3 cấp độ Fallback (Zero Hardcoded OTA Languages)**:
   - **Ưu tiên 1 (OTA Server Override)**: Bản dịch tải động từ Remote Server lưu trong cache.
   - **Ưu tiên 2 (Local String Catalog)**: Bản dịch tĩnh đóng gói sẵn trong App binary (`.xcstrings`).
   - **Ưu tiên 3 (Compile-time Fallback String)**: Chuỗi mặc định định nghĩa ngay tại vị trí gọi code.
   - **Chính sách ngôn ngữ tĩnh**: App binary chỉ đóng gói mặc định **English (`en`)** và **Tiếng Việt (`vi`)**. Các ngôn ngữ mở rộng (như `ja`, `ko`) được nạp 100% động qua OTA, giúp tối ưu dung lượng app cài đặt.

---

## 2. Cấu trúc thư mục & Tệp tin

```text
├── Features/
│   ├── Settings/Sources/Settings/Resources/
│   │   └── Localizable.xcstrings                # Chuỗi riêng của Settings Feature (21+ keys)
│   ├── Scanner/Sources/Scanner/Resources/
│   │   └── Localizable.xcstrings                # Chuỗi riêng của Scanner Feature
│   └── <Feature>/Sources/<Feature>/Resources/
│       └── Localizable.xcstrings                # Chuỗi của Feature mới tạo
├── Packages/
│   ├── Shell/Sources/Shell/Resources/
│   │   └── Localizable.xcstrings                # Chuỗi của Shell/Tabs (home.title, shell.tab.*)
│   └── Platform/
│       ├── Resources/
│       │   └── Localizable.xcstrings            # (Tự động sinh) Catalog tổng hợp fallback cho Platform
│       └── Sources/Platform/Localization/
│           └── Translations.generated.swift     # (Tự động sinh) Typed Swift accessors: t.<module>.<key>
├── App/Resources/
│   ├── Localizable.xcstrings                    # (Tự động sinh) Master catalog hợp nhất cho App Host
│   └── backend_translations/                    # (Tự động sinh) Nested JSON phục vụ Backend sync
│       ├── en.json / en_US.json
│       └── vi.json / vi_VN.json
└── scripts/
    └── merge_localizations.py                   # Engine hợp nhất, code gen và JSON sync
```

---

---

## 3. Quy tắc đặt Key chi tiết: Feature-level vs. Subfeature-level

Mọi localization key trong dự án đều tuân theo nguyên tắc **Namespaced Dot-Notation** và viết bằng định dạng **`camelCase`**. Tùy thuộc vào phạm vi sử dụng của chuỗi, bạn lựa chọn cấu trúc 2 cấp (Feature-level) hoặc 3 cấp (Subfeature-level).

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. Feature-level:     <feature>.<key>                       │
│ 2. Subfeature-level:  <feature>.<subfeature>.<key>          │
└─────────────────────────────────────────────────────────────┘
```

---

### A. Chuỗi cấp Feature (Feature-level: `<feature>.<key>`)

#### Khi nào sử dụng?
- **Tiêu đề chính** của toàn bộ màn hình Feature (Root screen).
- **Hành động toàn cục** của Feature (ví dụ: Đăng xuất, Lưu, Hủy).
- **Trạng thái chung** của Feature (Loading, Empty state, Error message chung).

#### Ví dụ đặt key trong `Features/<Feature>/Sources/<Feature>/Resources/Localizable.xcstrings`:
```json
{
  "sourceLanguage": "en",
  "strings": {
    "settings.title": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Settings" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Cài đặt" } }
      }
    },
    "settings.logout": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Logout" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Đăng xuất" } }
      }
    },
    "settings.saving": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Saving…" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Đang lưu…" } }
      }
    }
  },
  "version": "1.0"
}
```

#### Gọi trong SwiftUI View:
```swift
Text(t.settings.title)     // "Settings" hoặc "Cài đặt"
Text(t.settings.logout)    // "Logout" hoặc "Đăng xuất"
Text(t.settings.saving)    // "Saving…" hoặc "Đang lưu…"
```

#### Cấu trúc JSON tương ứng từ Backend OTA:
```json
{
  "settings": {
    "title": "Settings",
    "logout": "Logout",
    "saving": "Saving…"
  }
}
```

---

### B. Chuỗi cấp Subfeature (Subfeature-level: `<feature>.<subfeature>.<key>`)

#### Khi nào sử dụng?
- **Màn hình con / Sub-screen**: Được tạo qua lệnh `mason make ios_mvi_subfeature` (ví dụ: màn hình `Account`, `Security`, `Profile`).
- **Section Card / Component riêng**: Các khối nội dung độc lập bên trong màn hình cha (ví dụ: nhóm cài đặt `account`, nhóm `preferences`, nhóm `developer`, nhóm `appInfo`).
- **Dialogs / Bottom Sheets**: Hộp thoại xác nhận hoặc bảng chọn riêng (ví dụ: `scanner.comingSoon`, `settings.languagePicker`).

> [!NOTE]
> **Vị trí tệp**: Chuỗi của Subfeature **vẫn nằm trong cùng file `Localizable.xcstrings` của Feature cha**, nhưng được gom nhóm bằng tiền tố `<feature>.<subfeature>`.

#### Ví dụ đặt key trong `Features/<Feature>/Sources/<Feature>/Resources/Localizable.xcstrings`:
```json
{
  "sourceLanguage": "en",
  "strings": {
    "settings.account.title": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Account" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Tài khoản" } }
      }
    },
    "settings.account.profile": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Edit Profile" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Thông tin cá nhân" } }
      }
    },
    "settings.account.changePassword": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Change Password" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Đổi mật khẩu" } }
      }
    },
    "settings.preferences.darkMode": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Dark Mode" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Chế độ tối" } }
      }
    },
    "scanner.comingSoon.message": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "This tab is a stub in the template" } },
        "vi": { "stringUnit": { "state": "translated", "value": "Tab này là bản mẫu" } }
      }
    }
  },
  "version": "1.0"
}
```

#### Gọi trong SwiftUI View:
CodeGen tự động tạo các struct lồng nhau (`SettingsTranslations` $\rightarrow$ `SettingsAccountTranslations`):
```swift
// Trong AccountView (Sub-screen) hoặc SettingsView:
Text(t.settings.account.title)           // "Account" / "Tài khoản"
Text(t.settings.account.profile)         // "Edit Profile" / "Thông tin cá nhân"
Text(t.settings.account.changePassword)  // "Change Password" / "Đổi mật khẩu"
Toggle(t.settings.preferences.darkMode, isOn: $isDark)
Text(t.scanner.comingSoon.message)
```

#### Cấu trúc JSON tương ứng từ Backend OTA:
```json
{
  "settings": {
    "account": {
      "title": "Account",
      "profile": "Edit Profile",
      "changePassword": "Change Password"
    },
    "preferences": {
      "darkMode": "Dark Mode"
    }
  },
  "scanner": {
    "comingSoon": {
      "message": "This tab is a stub in the template"
    }
  }
}
```

---

### C. Bảng so sánh tổng hợp

| Tiêu chí | Chuỗi cấp Feature | Chuỗi cấp Subfeature |
| :--- | :--- | :--- |
| **Cú pháp** | `<feature>.<key>` | `<feature>.<subfeature>.<key>` |
| **Số phân đoạn** | 2 cấp | 3 cấp (hoặc nhiều hơn nếu có sub-component) |
| **Phạm vi dùng** | Toàn feature (Title, Action bar, Error chung) | Màn hình con, Section, Dialog riêng |
| **File khai báo** | `Features/<Feature>/.../Localizable.xcstrings` | `Features/<Feature>/.../Localizable.xcstrings` |
| **Swift Accessor** | `t.<feature>.<key>` | `t.<feature>.<subfeature>.<key>` |
| **Tự động hóa Mason** | `mason make ios_mvi_feature` | `mason make ios_mvi_subfeature` |
| **Cơ chế khi xóa** | `ios_remove_feature` (xóa cả catalog) | `ios_remove_subfeature` (xóa các key `*.<subfeature>.*`) |

---

### D. Các quy tắc "NÊN" và "KHÔNG NÊN" (DOs & DON'Ts)

- ✅ **DO**: Luôn dùng **`camelCase`** cho tất cả các phần: `settings.account.changePassword`.
- ✅ **DO**: Đặt tên key mang tính ngữ nghĩa theo mục đích hiển thị: `.title`, `.message`, `.description`, `.placeholder`, `.buttonConfirm`, `.buttonCancel`.
- ❌ **DON'T**: **Không dùng `snake_case` hoặc `kebab-case`** trong key (ví dụ: `settings.user_profile` sẽ sinh Swift accessor không đúng chuẩn).
- ❌ **DON'T**: **Không đặt key trùng với tên subfeature**:
  - *Ví dụ sai*: Đặt key `"settings.account"` (chuỗi) đồng thời lại có `"settings.account.profile"`. Điều này sẽ gây xung đột cấu trúc (một node vừa là String vừa là Dictionary).
  - *Ví dụ đúng*: Đặt `"settings.account.title"` và `"settings.account.profile"`.
- ❌ **DON'T**: **Không bỏ tiền tố feature**: Không đặt key cộc lốc như `"title"` hay `"logout"` ở root, vì sẽ gây xung đột tên giữa các feature khi merge vào master catalog.

---

## 4. Hướng dẫn sử dụng trong SwiftUI View

### Cách 1: Sử dụng Environment Property Wrapper (Khuyên dùng)

Trong bất kỳ SwiftUI View nào (đã `import Platform`), khai báo `@Environment(\.t)`:

```swift
import Platform
import SwiftUI

struct SettingsView: View {
    @Environment(\.t) private var t: Translations

    var body: some View {
        List {
            Section(t.settings.account.title) {
                Text(t.settings.account.profile)
                Text(t.settings.account.changePassword)
            }
            Section(t.settings.preferences.title) {
                Text(t.settings.preferences.darkMode)
            }
        }
        .navigationTitle(t.settings.title)
    }
}
```

### Cách 2: Truy cập toàn cục qua `t` hoặc `Translations.current`

Phù hợp cho các helper, formatters, hoặc tầng phi SwiftUI:

```swift
import Platform

let title = t.settings.title
let tabName = Translations.current.shell.tab.home
```

### Cách 3: Interpolation với Dynamic Arguments / Fallback

Khi cần chèn biến động vào chuỗi (String format) hoặc fallback tuỳ biến:

```swift
Text(t("settings.account.greeting", default: "Xin chào, \(username)!"))
```

---

## 5. Quy trình Quản lý Translations tự động qua Mason Bricks

Template đã tích hợp tự động hóa 100% vào các Mason Bricks trong thư mục `bricks/`.

### A. Thêm Feature mới (`ios_mvi_feature`)

Khi bạn chạy lệnh tạo feature mới:
```bash
mason make ios_mvi_feature --name Payments
```
1. Brick tự động sinh file `Features/Payments/Sources/Payments/Resources/Localizable.xcstrings` với starter key `"payments.title"`.
2. Hook `post_gen.dart` tự động wire Tuist manifests và `AppComposition.swift` (tự động import và đăng ký `PaymentsRouteProvider`).
3. Hook tự động chạy `scripts/merge_localizations.py`, `tuist generate`, feature unit tests, và `ArchTests`.
4. Swift accessor `t.payments.title` được sinh ra ngay lập tức và sẵn sàng dùng trong `PaymentsView.swift`.

### B. Thêm Subfeature mới (`ios_mvi_subfeature`)

Khi tạo sub-screen mới cho feature đã có:
```bash
mason make ios_mvi_subfeature --feature Settings --name Security
```
1. Hook `post_gen.dart` tự động mở file `Features/Settings/.../Localizable.xcstrings` và thêm key khởi tạo:
   ```json
   "settings.security.title": {
     "extractionState": "manual",
     "localizations": {
       "en": { "stringUnit": { "state": "translated", "value": "Security" } },
       "vi": { "stringUnit": { "state": "translated", "value": "Security" } }
     }
   }
   ```
2. Hook tự động chạy `scripts/merge_localizations.py`.
3. File `SecurityView.swift` sinh ra được trỏ trực tiếp vào dot-notation:
   ```swift
   .navigationTitle(t.settings.security.title)
   ```

### C. Xóa Subfeature (`ios_remove_subfeature`)

Khi loại bỏ một sub-screen:
```bash
mason make ios_remove_subfeature --feature Settings --name Security
```
1. Hook tự động xóa thư mục `Presentation/Security/` và file test.
2. Hook tự động quét file `Localizable.xcstrings` của `Settings` và **xóa toàn bộ các key bắt đầu bằng `settings.security.*`**.
3. Hook kích hoạt `scripts/merge_localizations.py`: struct `SettingsSecurityTranslations` và các node JSON tự động bị loại bỏ hoàn toàn.

### D. Xóa Feature (`ios_remove_feature`)

Khi xóa toàn bộ feature:
```bash
mason make ios_remove_feature --name Payments
```
1. Toàn bộ thư mục `Features/Payments` (bao gồm catalog của nó) bị xóa.
2. Tuist manifests được tháo gỡ tự động.
3. Hook tự động chạy lại `merge_localizations.py`, làm sạch toàn bộ accessors `t.payments` khỏi codebase.

---

## 6. Hướng dẫn Thêm/Sửa Translations thủ công

Nếu bạn muốn thêm các chuỗi mới cho màn hình có sẵn mà không tạo subfeature mới:

### Bước 1: Mở catalog của Feature tương ứng
Mở file `Features/<FeatureName>/Sources/<FeatureName>/Resources/Localizable.xcstrings`.

### Bước 2: Thêm key mới tuân thủ quy tắc dot-notation
```json
{
  "sourceLanguage": "en",
  "strings": {
    "settings.account.deleteAccount": {
      "extractionState": "manual",
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Delete Account"
          }
        },
        "vi": {
          "stringUnit": {
            "state": "translated",
            "value": "Xóa tài khoản"
          }
        }
      }
    }
  },
  "version": "1.0"
}
```

> [!IMPORTANT]
> Luôn giữ thuộc tính `"version": "1.0"` ở root của file `.xcstrings`. Nếu thiếu key này, trình biên dịch `xcstringstool` của Apple sẽ báo lỗi `Missing required key 'version'`.

### Bước 3: Đồng bộ và sinh code
Bạn có thể chọn 1 trong 2 cách:
- **Cách 1**: Chạy lệnh script từ Terminal:
  ```bash
  python3 scripts/merge_localizations.py
  ```
- **Cách 2**: Nhấn **`Cmd + B`** (Build) trong Xcode. Target host `iOSDigitalWallet` đã có Build Phase tự động chạy script này trước mỗi lần biên dịch.

### Bước 4: Sử dụng trong code
Trong SwiftUI View:
```swift
Button(t.settings.account.deleteAccount) {
    viewModel.dispatch(.deleteAccountTapped)
}
```

---

## 7. Cơ chế OTA & Xuất bản cho Backend

### Bi-directional Sync với Backend OTA
Mỗi lần script `merge_localizations.py` chạy, hệ thống sẽ tự động xuất các file JSON tại:
`App/Resources/backend_translations/`:
- `en.json` & `en_US.json`
- `vi.json` & `vi_VN.json`

Cấu trúc JSON này hoàn toàn tương thích với schema của Remote Backend API:
```json
{
  "language_code": "en_US",
  "language_name": "English (US)",
  "version": "1.0.0",
  "is_default": true,
  "is_active": true,
  "translations": {
    "settings": {
      "account": {
        "profile": "Edit Profile",
        "title": "Account"
      }
    }
  }
}
```

### Cơ chế nạp động phía iOS
1. Khi app khởi động hoặc người dùng vào màn hình Cài đặt ngôn ngữ, UseCase `GetDynamicLocalizationUseCase` gọi API remote để kiểm tra phiên bản mới (`since_version`).
2. Nếu có bản dịch OTA mới (kể cả ngôn ngữ không có sẵn trong app binary như `ja`, `ko`), payload được lưu vào `UserDefaultsCacheStore`.
3. `AppLocalizationManager` nạp các override này vào bộ nhớ.
4. `AppEventBus` phát sự kiện thay đổi ngôn ngữ, giao diện người dùng lập tức cập nhật theo bản dịch mới mà không cần khởi động lại ứng dụng.

---

## 8. Xử lý sự cố thường gặp (Troubleshooting)

| Vấn đề | Nguyên nhân | Cách khắc phục |
| :--- | :--- | :--- |
| **`Missing required key 'version'`** | File `.xcstrings` thiếu `"version": "1.0"`. | Đảm bảo root JSON của file `.xcstrings` luôn có `"version": "1.0"`. |
| **Key đã xóa vẫn xuất hiện trong code `t.*`** | Script merge đọc nhầm catalog đích làm nguồn. | Đã được khắc phục trong `scripts/merge_localizations.py` (loại trừ `dest_paths`). Chạy lại `python3 scripts/merge_localizations.py`. |
| **Build phase báo `python3 not found`** | PATH môi trường build Xcode thiếu python3. | Kiểm tra Xcode Build Settings hoặc cài đặt python3 qua Homebrew (`/opt/homebrew/bin/python3`). |
| **Key trong `View` báo đỏ không compile** | Chưa chạy code gen sau khi sửa file `.xcstrings`. | Nhấn `Cmd + B` trong Xcode hoặc chạy `python3 scripts/merge_localizations.py`. |

---

## 9. Cơ chế kiểm soát tự động & AI Agent Governance

Để đảm bảo các quy tắc **DOs & DON'Ts** được thực thi nghiêm ngặt và ngăn ngừa lỗi từ cả con người lẫn AI Agents, dự án áp dụng hệ thống bảo vệ đa tầng (**Multi-tiered Enforcement Gates**):

```text
┌─────────────────────────────────────────────────────────────┐
│ 1. AI AGENT RULES GATE                                      │
│    - AGENTS.md (Rule 8)                                     │
│    - .agents/rules/LOCALIZATION_RULES.md                    │
├─────────────────────────────────────────────────────────────┤
│ 2. VALIDATION ENGINE GATE                                   │
│    - scripts/merge_localizations.py: validate_catalogs()    │
│    - Kiểm tra: camelCase, namespace prefix, leaf vs branch  │
├─────────────────────────────────────────────────────────────┤
│ 3. IDE & CI COMPILER GATE                                   │
│    - Xcode Pre-build Phase (Run Script Phase)               │
│    - Mason Hooks (post_gen.dart)                            │
│    - GitHub Actions CI (ci.yml)                             │
└─────────────────────────────────────────────────────────────┘
```

1. **Gate 1 — AI Agent Rules (`AGENTS.md` & `.agents/rules/LOCALIZATION_RULES.md`)**:
   Mọi AI Agent (Antigravity, Claude, Copilot, Cursor) khi tương tác với codebase đều tự động nạp các quy tắc bắt buộc:
   - Chỉ sửa file catalog cục bộ của feature/package.
   - Luôn đặt key `camelCase` với đúng prefix module.
   - Tuyệt đối không tạo xung đột giữa key lá và key nhánh.
2. **Gate 2 — Automated Validation Engine (`scripts/merge_localizations.py`)**:
   Hàm `validate_catalogs()` tự động quét tất cả catalog và chặn đứng quá trình build nếu phát hiện:
   - Key không phải `camelCase` (ví dụ: `settings.user_profile` $\rightarrow$ chặn đứng).
   - Key cộc lốc thiếu prefix (ví dụ: `"title"` $\rightarrow$ chặn đứng).
   - Key sai prefix module (ví dụ: `"scanner.test"` nằm trong `Features/Settings` $\rightarrow$ chặn đứng).
   - Xung đột cấu trúc (ví dụ: có cả `"settings.account"` và `"settings.account.title"` $\rightarrow$ chặn đứng).
3. **Gate 3 — IDE & CI Compiler Gate**:
   - Khi có vi phạm, script thoát với mã lỗi `sys.exit(1)`, hiển thị thông báo lỗi màu đỏ trực tiếp trong Xcode Issue Navigator.
   - GitHub Actions CI sẽ tự động đánh fail PR nếu có bất kỳ vi phạm nào lọt qua.

