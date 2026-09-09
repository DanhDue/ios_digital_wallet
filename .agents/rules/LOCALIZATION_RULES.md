# AI Agent Rules — Localization & Translations (DOs & DON'Ts)

Tài liệu quy tắc bắt buộc dành cho AI Agents khi làm việc với hệ thống Localization trong dự án **iOS Super App Template**.

---

## 1. Nguyên tắc cốt lõi (Core Principles)

1. **Phân quyền Module (Decentralized Catalogs)**:
   - Các chuỗi bản dịch thuộc về module nào phải nằm trong `Localizable.xcstrings` của module đó:
     - Feature: `Features/<Feature>/Sources/<Feature>/Resources/Localizable.xcstrings`
     - Shell: `Packages/Shell/Sources/Shell/Resources/Localizable.xcstrings`
   - ❌ **TUYỆT ĐỐI KHÔNG** thêm chuỗi trực tiếp vào `App/Resources/Localizable.xcstrings` hoặc `Packages/Platform/Resources/Localizable.xcstrings`. Hai file này là đích tự động sinh (auto-generated destinations).

2. **Quy ước đặt Key (Key Naming Convention)**:
   - Tất cả các phần trong key **bắt buộc** phải là **`camelCase`** (`^[a-z][a-zA-Z0-9]*$`).
   - ❌ **CẤM** dùng `snake_case` (ví dụ: `settings.user_profile`), `kebab-case` (`settings.user-profile`), hoặc `PascalCase` (`Settings.Account.Title`).
   - Tối thiểu 2 phân đoạn: `<feature>.<key>`. ❌ **CẤM** dùng key cộc lốc không có prefix như `"title"`, `"logout"`.

3. **Phân tầng Key (Hierarchical Scoping)**:
   - **Cấp Feature (2 cấp)**: `<feature>.<key>` (ví dụ: `settings.title`, `settings.logout`, `scanner.title`). Dùng cho title root màn hình, nút bấm và thông báo chung của feature.
   - **Cấp Subfeature (3 cấp)**: `<feature>.<subfeature>.<key>` (ví dụ: `settings.account.profile`, `settings.preferences.darkMode`). Dùng cho màn hình con (`Presentation/<Subfeature>/`), section card, hoặc bottom sheet.
   - Tiền tố `<feature>` phải trùng khớp với tên module sở hữu (trong `Features/Settings` phải bắt đầu bằng `settings.`).

4. **Tránh xung đột cấu trúc (No Structural Collision)**:
   - Một key không được là tiền tố của key khác (Leaf vs. Branch collision).
   - ❌ **SAI**: Khai báo key `"settings.account"` (chuỗi leaf) đồng thời có `"settings.account.profile"` (branch).
   - ✅ **ĐÚNG**: Đổi thành `"settings.account.title"` và `"settings.account.profile"`.

5. **Sử dụng trong SwiftUI View**:
   - Khai báo `@Environment(\.t) private var t: Translations`.
   - Sử dụng dot-notation có type-safety: `t.<feature>.<key>` hoặc `t.<feature>.<subfeature>.<key>`.
   - ❌ **HẠN CHẾ** dùng chuỗi literal cứng `Text("...")` hoặc `t("literal.key")` nếu đã có typed accessors.

6. **Chính sách ngôn ngữ tĩnh vs. OTA**:
   - Binary mặc định chỉ đóng gói **`en` (English)** và **`vi` (Tiếng Việt)**.
   - ❌ **KHÔNG** thêm `ja`, `ko` hoặc các ngôn ngữ khác vào file `.xcstrings` cục bộ. Chúng được nạp 100% động qua OTA.

7. **Bắt buộc Re-sync sau khi sửa**:
   - Luôn chạy `python3 scripts/merge_localizations.py` (hoặc build Xcode) sau khi thêm, sửa hoặc xóa bất kỳ key nào trong file `.xcstrings` để:
     - Chạy qua bộ kiểm tra hợp lệ `validate_catalogs`.
     - Đồng bộ master catalogs.
     - Tái tạo `Translations.generated.swift`.
     - Xuất các file JSON cho Backend (`App/Resources/backend_translations/`).

---

## 2. Checklist kiểm tra nhanh trước khi hoàn thành task

- [ ] File `.xcstrings` có chứa `"version": "1.0"` ở root?
- [ ] Tất cả các key mới đều là `camelCase` (`^[a-z][a-zA-Z0-9]*$`)?
- [ ] Tiền tố của key có khớp với tên feature hiện tại?
- [ ] Không có xung đột giữa key lá và key nhánh (`<name>` vs `<name>.<child>`)?
- [ ] Đã chạy `python3 scripts/merge_localizations.py` và output báo `🛡️ All module catalogs passed DOs & DON'Ts validation rules`?
- [ ] Đã chạy `swift test --package-path ArchTests` và `mise exec -- swiftlint` đảm bảo không lỗi?
