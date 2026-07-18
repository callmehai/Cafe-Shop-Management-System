# CSMS — Cafe Shop Management System · Project Context

> Tài liệu context để khởi tạo project code mới, trích xuất từ **CSMS-SRS v1.0** (Hanoi, 06/2026).
> Dùng làm "single source of truth" khi setup repo, viết spec cho coding agent, hoặc onboard dev mới.

---

## 1. Tổng quan sản phẩm

CSMS là phần mềm hỗ trợ vận hành hằng ngày của một quán cà phê: quản lý menu, tạo order, thanh toán & in hóa đơn, quản lý kho nguyên liệu, quản lý bàn, và báo cáo doanh thu. Thay thế quy trình giấy tờ thủ công bằng nền tảng số tập trung — tăng độ chính xác đơn hàng, phục vụ nhanh hơn, và cho chủ quán cái nhìn rõ ràng về doanh thu/tồn kho.

Hệ thống được dùng tại quầy bán hàng (point-of-sale) bởi cashier/barista, và ở back-office bởi manager/admin.

**Đối tượng release:** Release 1.0.

---

## 2. Tech stack

| Thành phần | Lựa chọn | Ghi chú |
|---|---|---|
| **Frontend** | **Flutter** (Android + iOS, tablet/phone) | **Cố định bởi SRS.** Tối ưu cho nhập order nhanh tại quầy, touch target lớn. |
| **Backend** | REST API over HTTPS | SRS chỉ quy định "REST/HTTPS", **không chốt ngôn ngữ/framework**. Xem đề xuất bên dưới. |
| **Database** | RDBMS (PostgreSQL / MySQL) | ERD quan hệ rõ ràng → phù hợp SQL. |
| **Auth** | JWT/session + RBAC | Password hash, role-based per ma trận §4. |
| **External** | Payment Gateway (REST/HTTPS), máy in nhiệt, barcode scanner (optional) | Xem §9. |

> **⚠️ Quyết định cần chốt — Backend stack.** SRS không chỉ định. Đề xuất (chọn 1):
> - **Spring Boot (Java)** — mạnh về REST + JPA + Spring Security (RBAC, audit), phổ biến cho capstone. *(khuyến nghị mặc định)*
> - **NestJS (Node/TypeScript)** — chung TypeScript ecosystem, nhanh khi prototype.
> - **ASP.NET Core (C#)** — nếu team quen .NET.
>
> Tài liệu này viết stack-agnostic ở phần domain; bạn báo mình stack chốt là mình điều chỉnh phần structure/scaffolding tương ứng.

---

## 3. Actors & Roles

| # | Actor | Mô tả |
|---|---|---|
| 1 | **Administrator** | Cấu hình hệ thống, quản lý tài khoản & role, thiết lập master data (product, category, table). |
| 2 | **Manager** | Giám sát vận hành, quản lý menu & giá, theo dõi kho, xem báo cáo doanh thu. |
| 3 | **Cashier** | Tạo/sửa order, thanh toán, áp dụng giảm giá, in hóa đơn tại quầy. |
| 4 | **Barista / Sales agent** | Nhận order ticket, pha chế, cập nhật trạng thái chuẩn bị món. |
| 5 | **Payment Gateway** *(external)* | Hệ thống ngoài xác thực & xử lý thanh toán thẻ / ví điện tử. |
| 6 | **Receipt Printer** *(external)* | Thiết bị in hóa đơn khách & kitchen ticket. |

### Ma trận phân quyền màn hình (Screen Authorization)

| Màn hình | Admin | Manager | Cashier | Barista |
|---|:---:|:---:|:---:|:---:|
| Login / Logout | ✓ | ✓ | ✓ | ✓ |
| Dashboard | ✓ | ✓ | ✓ | ✓ |
| Create Order | | | ✓ | |
| Order Details | | | ✓ | |
| View Order Queue | | ✓ | ✓ | ✓ |
| Update Item Prep Status | | | | ✓ |
| Payment | | | ✓ | |
| Menu Management (Product/Category) | | ✓ | | |
| Inventory (Purchase Order, Stock-In) | | ✓ | | |
| Reports | | ✓ | | |
| User Management (Add/Edit/Delete/Role) | ✓ | | | |
| Customer Management | | ✓ | | |

> CR-06: Chưa đăng nhập → redirect về Login. CR-07: chỉ truy cập chức năng theo role được cấp.

---

## 4. Modules & chức năng chính

1. **Authentication** — Login (username/password), Logout, auto-logout sau 30 phút không hoạt động (CR-12).
2. **Dashboard** — Home sau login; shortcut theo role + widget (doanh thu hôm nay, order đang mở, cảnh báo sắp hết hàng).
3. **Order Management** — Create Order, Update Order, Cancel Order, Assign Table (extend Create Order). Thêm món kèm option (size, sugar level, notes, quantity).
4. **Order Queue** — View Order Queue (open orders + trạng thái), Update Item Prep Status (in-progress / completed).
5. **Payment** — Chọn phương thức (Cash / Card / E-Wallet), áp giảm giá, earn/redeem loyalty points, gọi Payment Gateway nếu điện tử, in hóa đơn.
6. **Menu Management** — CRUD Product, CRUD Category.
7. **Inventory** — CRUD Ingredient, Purchase Order, Stock-In (Goods Receipt), cảnh báo low-stock.
8. **Customer & Loyalty** — CRUD Customer, tích/đổi điểm loyalty.
9. **Reporting** — Sales/revenue report theo khoảng ngày, export report.
10. **Table Management** — CRUD bàn (số bàn, sức chứa, trạng thái).

### Non-screen / background functions
- **Daily Sales Aggregation** — job cuối ngày tổng hợp sales vào bảng báo cáo.
- **Low-Stock Alert** — service nền thông báo manager khi ingredient < reorder threshold.
- **Stock Auto-Deduction** — khi thanh toán xong, tự trừ tồn kho ingredient theo món (BR-08).
- **Payment Gateway Integration** — gửi request thanh toán điện tử & ghi nhận authorization result.
- **Loyalty Accrual/Redemption** — trong luồng Payment, cộng điểm khi hoàn tất & áp điểm đổi.

---

## 5. Domain Model (Entities)

Quan hệ chính: `User` tạo `Order` → gồm nhiều `OrderItem` (ref `Product` ← `Category`). `Order` gắn `Table` (nullable, takeaway) và `Customer` (nullable). `Payment` thuộc `Order`, sinh `LoyaltyTransaction`. `PurchaseOrder` → nhiều `StockIn` ref `Ingredient`.

| Entity | Khóa & field chính | Ghi chú |
|---|---|---|
| **User** | UserID(PK), Username(unique), PasswordHash, Role, IsActive | Role ∈ {Administrator, Manager, Cashier, Barista} |
| **Category** | CategoryID(PK), Name | |
| **Product** | ProductID(PK), Name, CategoryID(FK), Price, Size?, IsAvailable, Description? | |
| **Order** | OrderID(PK), createBy(FK→User), TableID(FK, null=takeaway), CustomerID(FK?), Status, CreatedAt | Status ∈ {Open, Paid, Cancelled} |
| **OrderItem** | OrderItemID(PK), OrderID(FK), ProductID(FK), Quantity, Options?, LinePrice | Options = size/sugar/notes |
| **Payment** | PaymentID(PK), OrderID(FK), UserID(FK), CustomerID(FK?), Method, Amount, PointsRedeemed?, PaidAt | Method ∈ {Cash, Card, E-Wallet} |
| **Table** (TABLE_T) | TableID(PK), Number, Capacity, OccupancyStatus, Floor?, Shape | Status ∈ {Free, Occupied, Reserved} |
| **Ingredient** | IngredientID(PK), Name, QuantityOnHand, ReorderThreshold | |
| **Customer** | CustomerID(PK), FullName, Phone?, Email?, LoyaltyPoints, JoinedAt | |
| **LoyaltyTransaction** | LoyaltyTxnID(PK), CustomerID(FK), PaymentID(FK), Type, Points, CreatedAt | Type ∈ {Earn, Redeem} |
| **PurchaseOrder** | PurchaseOrderID(PK), UserID(FK), SupplierName, Status, TotalAmount, CreatedAt | |
| **StockIn** | StockInID(PK), PurchaseOrderID(FK), IngredientID(FK), Quantity, UnitCost, ReceivedAt | |

> CR-05: tự ghi `CreatedAt` / `UpdatedAt` cho mọi record giao dịch.

---

## 6. Business Rules (BR)

- **BR-01** Order phải có ≥1 product mới được lưu/thanh toán.
- **BR-02** Order total = Σ(price × quantity) − discount.
- **BR-03** Tất cả item trong 1 order thanh toán bằng **một** phương thức duy nhất.
- **BR-04** Product `unavailable` hoặc hết hàng → không cho order.
- **BR-05** Chỉ Manager/Admin được tạo/sửa/vô hiệu hóa product & giá.
- **BR-06** Discount ≤ 50% subtotal; vượt 50% phải Manager duyệt (nút "Request approval").
- **BR-07** Order đã `Paid` không sửa được; chỉnh sửa qua refund hoặc order mới.
- **BR-08** Trừ tồn kho ingredient tự động khi order được thanh toán.
- **BR-09** Truyền dữ liệu payment/cá nhân yêu cầu mã hóa ≥ 256-bit.
- **BR-10** Khóa tài khoản 15 phút sau 5 lần đăng nhập sai liên tiếp.
- **BR-11** Loyalty points chỉ tích khi payment hoàn tất; điểm redeem không vượt số dư. *(SRS đánh dấu "[EDIT — confirm]")*
- **BR-12** Stock-In quantity phải tham chiếu một Purchase Order line tồn tại. *(SRS đánh dấu "[EDIT — confirm]")*

---

## 7. Common Requirements (CR) — áp dụng toàn hệ thống

- CR-01 Field bắt buộc đánh dấu `*` và validate trước khi lưu.
- CR-02 Date/time dùng giờ hệ thống, format `DD/MM/YYYY HH:mm`.
- CR-03 Hiện message success/warning/error sau mỗi create/update/delete/login/payment.
- CR-04 Chặn trùng username.
- CR-08 Trim khoảng trắng đầu/cuối text field trước validate.
- CR-09 Xác nhận trước hành động không thể hoàn tác (xóa record, hủy order).
- CR-10 Tiền hiển thị bằng **VND** với dấu phân cách hàng nghìn.
- CR-11 Audit log cho login, logout, payment, hành động admin.
- CR-13 Hỗ trợ search/filter cho list (users, customers, products, orders).
- CR-14 Điều hướng nhất quán + cách quay lại màn trước.
- CR-15 Validate input phía client trước khi gửi backend.

---

## 8. Non-Functional Requirements

**Usability** — Cashier mới học tạo & hoàn tất order trong ≤30 phút; nhập order ≤5 món trong <60s; tác vụ thường xuyên (create order, payment) trong ≤2 tap từ Dashboard.

**Reliability** — Availability ≥ 99.5% giờ hoạt động; MTTR ≤ 30 phút; auto-recover dữ liệu order/payment đã commit sau restart; tính toán total chính xác 100%.

**Performance** — Chuyển màn/search ≤1s trung bình (≤3s peak); lưu order/xử lý payment ≤2s trung bình; chịu ≥20 user đồng thời & ≥60 order/giờ; lưu ≥2 năm lịch sử.

**Security** — Password hash; TLS ≥256-bit cho payment & dữ liệu cá nhân; RBAC theo §3; audit log login/payment/data-modification.

---

## 9. External Interfaces

- **Payment Gateway** — REST API over HTTPS, thanh toán thẻ & ví điện tử. Luồng: gửi `payment request` → nhận `authorization result` → ghi nhận, set order `Paid`, trừ kho, cộng điểm, in hóa đơn.
- **Receipt/Thermal Printer** — in hóa đơn khách & kitchen ticket.
- **Barcode Scanner** *(optional)* — tra cứu product.
- **Communication** — app ↔ backend qua HTTPS trên Wi-Fi/internet quán; gọi gateway cũng qua HTTPS.

---

## 10. Application Messages

| Code | Type | Context | Nội dung |
|---|---|---|---|
| MSG01 | inline | Không có kết quả | No search results. |
| MSG02 | red, dưới textbox | Field bắt buộc trống | The {field} field is required. |
| MSG03 | toast | Tạo order | Order created successfully. |
| MSG04 | toast | Thanh toán xong | Payment completed successfully. |
| MSG05 | toast | Lưu product | Product saved successfully. |
| MSG06 | confirm dialog | Xác nhận xóa | Are you sure you want to delete this item? |
| MSG07 | toast | Đã xóa | Item deleted successfully. |
| MSG08 | red, dưới textbox | Vượt max length | Exceed max length of {max_length}. |
| MSG09 | inline | Sai user/pass | Incorrect user name or password. Please check again. |

---

## 11. Gợi ý cấu trúc & lộ trình build

### Cấu trúc gợi ý (stack-agnostic)
```
/csms
  /mobile        # Flutter app (feature-first: auth, order, payment, menu, inventory, customer, report)
  /backend       # REST API: modules theo domain ở §4–§5
  /docs          # SRS, API contract (OpenAPI), ERD
```

### MVP → Full (Đã hoàn thành toàn bộ)
- **Phase 1 (core POS):** ✅ Hoàn thành (Auth, RBAC, Menu CRUD, Đặt/Hủy đơn, Thanh toán tiền mặt, In hóa đơn Mock).
- **Phase 2:** ✅ Hoàn thành (Báo chế biến Order Queue, Quản lý khách hàng, Loyalty tích điểm, Thanh toán VNPay).
- **Phase 3:** ✅ Hoàn thành (Quản lý kho Ingredient, Purchase Order, Stock-In Goods Receipt, Auto-deduction nguyên liệu, Low-stock alert).
- **Phase 4:** ✅ Hoàn thành (Báo cáo doanh thu & Export, Audit Log hệ thống cho Login/Logout/Payment/Admin actions, Quản lý bàn).

---

## 12. Câu hỏi mở / Câu trả lời thực tế (Đã chốt & đóng)

1. **Backend stack** chốt là gì?
   - *Trả lời:* Đã chốt sử dụng **NestJS (Node/TypeScript)** kết hợp **Prisma ORM** và **PostgreSQL** chạy qua Docker.
2. **Tỷ lệ quy đổi loyalty**
   - *Trả lời:* Đã chốt quy ước **1 điểm = 100₫** khi quy đổi giảm giá thanh toán; và tích lũy **cộng 1 điểm cho mỗi 10.000₫ thực trả** khi thanh toán thành công (BR-11).
3. **Payment Gateway cụ thể**
   - *Trả lời:* Chọn tích hợp **VNPay Gateway (Sandbox)** cho cổng thanh toán điện tử E-Wallet, trả kết quả qua IPN và Return URL. Các phương thức CARD/CASH được mock trực tiếp.
4. **Kiến trúc dữ liệu order khi offline**
   - *Trả lời:* Đã chốt vận hành Online-first qua kết nối Wi-Fi/Internet ổn định tại quán; trường hợp mất mạng sẽ báo lỗi DioException và yêu cầu kết nối lại để đảm bảo đồng bộ tồn kho thời gian thực.
5. **Quan hệ Product ↔ Ingredient** (recipe/BOM)
   - *Trả lời:* Đã thêm bảng trung gian `ProductIngredient` (định nghĩa công thức chế biến của mỗi món) để liên kết Product and Ingredient, từ đó hệ thống tự động trừ kho nguyên liệu khi thanh toán (BR-08).
6. **"Sales agent" vs "Barista"**
   - *Trả lời:* Thống nhất tên role trong code và phân quyền là **BARISTA** (pha chế món và chuẩn bị đơn hàng).

---

*Nguồn: CSMS-SRS v1.0 — Cafe Shop Management System, Project Code CSMS, Hanoi 06/2026.*
