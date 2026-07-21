# Changelog

Các thay đổi đáng chú ý của CSMS.
Định dạng theo [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/).

## [Unreleased]

### Added

- **Quản lý công thức nguyên liệu cho món (BR-08).** Manager/Admin xem, thêm, sửa, xóa lượng
  nguyên liệu mà mỗi món tiêu tốn ngay trong màn Edit Product — trước đây `ProductIngredient` chỉ
  tồn tại ở DB và phải sửa tay, không có đường nào thao tác từ app.
  - Backend: `recipe` được trả kèm trong `GET /products` và `GET /products/:id` (endpoint mới);
    `POST`/`PATCH /products` nhận mảng `recipe`.
  - Mobile: mục "Ingredients per item" trong `product_form_page.dart`.
- **Chọn khách hàng khi tạo order.** Màn hình chọn khách mới: tìm theo tên/số điện thoại, hiển thị
  điểm loyalty, tạo nhanh khách mới rồi gán luôn, và bỏ gán khách khỏi order.
- Tài liệu: `docs/API.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`, `CLAUDE.md` và cấu hình `.claude/`.

### Fixed

- **Đơn hàng thiếu nguyên liệu giờ bị chặn ngay khi tạo, thay vì tới lúc thanh toán.**
  Trước đây cashier nhập xong cả đơn, khách chờ, đến bước trả tiền mới báo hết nguyên liệu.
  `POST`/`PATCH /orders` nay kiểm tra tồn kho theo công thức và trả `400` kèm tên nguyên liệu thiếu.

  Tồn khả dụng được tính **trừ hao phần các order `OPEN` khác đang giữ**. Đây là điểm dễ bỏ sót:
  kho chỉ bị trừ thật lúc thanh toán, nên nếu chỉ so với `quantityOnHand`, hai đơn vẫn cùng qua
  được bước tạo rồi đơn thứ hai lại fail đúng ở màn thanh toán như cũ.
  Kiểm tra ở bước thanh toán vẫn giữ nguyên làm lớp phòng thủ cuối.

- **Nút "Add customer" trong màn Create Order không hoạt động** — trước chỉ hiện thông báo
  "coming in a later phase". `createOrder` đã có sẵn tham số `customerId` nhưng không nơi nào truyền
  vào, nên order tạo từ app luôn không gắn khách và **không tích được điểm loyalty**.

### Changed

- `PATCH /products/:id` hiểu `recipe` như sau: **không gửi** = giữ nguyên công thức cũ;
  gửi mảng (kể cả rỗng) = thay thế toàn bộ. Chọn cách này để client cũ chưa biết field không vô tình
  xóa mất công thức.
- `menu.service.ts` dùng transaction khi cập nhật sản phẩm kèm công thức.

### Tests

- Thêm 3 test cho guard tồn kho BR-08: chặn khi thiếu, có tính phần order `OPEN` khác đang giữ,
  và cho qua khi đủ. Backend 17/17 pass, mobile 7/7 pass.

---

## [1.0.0] — 2026-07-19

Release đầu tiên, bám theo CSMS-SRS v1.0.

### Added

- **Data model** — 12 entity theo SRS + `ProductIngredient` (công thức, BR-08) + `AuditLog` (CR-11).
- **Auth & bảo mật** — Đăng nhập JWT, phân quyền RBAC theo `@Roles()`, khóa tài khoản sau 5 lần sai
  (BR-10), rate limit chống brute-force.
- **Audit log (CR-11)** — Ghi nhận đăng nhập, đăng xuất, thanh toán và các thao tác CRUD của
  Admin/Manager.
- **POS & quản lý bàn** — Tạo order dine-in/takeaway, cập nhật trạng thái pha chế theo từng món
  (UC12), quản lý sơ đồ và trạng thái bàn.
- **Thanh toán & loyalty (BR-11)** — Tiền mặt, thẻ và ví điện tử (VNPay sandbox).
  Quy ước điểm: 1 điểm = 100₫ khi đổi, tích 1 điểm mỗi 10.000₫ thực trả.
- **Kho (BR-08)** — Tự động trừ nguyên liệu theo công thức khi thanh toán, nhập hàng (goods receipt)
  và cảnh báo sắp hết hàng.
- **Khách hàng & báo cáo** — CRUD khách hàng, báo cáo doanh thu theo khoảng ngày, xuất CSV.
- **Tài liệu thiết kế** — class diagram, sequence diagram, package diagram, kiến trúc 4+1.

### Fixed

- `cashTendered` trở thành bắt buộc với thanh toán `CASH`, chặn trường hợp ghi nhận đã trả tiền
  trong khi khách đưa thiếu.

[Unreleased]: https://github.com/callmehai/Cafe-Shop-Management-System/compare/main...HEAD
