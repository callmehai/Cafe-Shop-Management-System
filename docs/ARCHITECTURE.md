# CSMS — Tổng quan kiến trúc

Tài liệu tóm tắt để onboard dev mới. Chi tiết hơn xem `system-design.md`, `class-diagrams.md`,
`sequence-diagrams.md`. Nghiệp vụ gốc: `../CSMS_PROJECT_CONTEXT.md`.

---

## 1. Bức tranh tổng thể

```
┌──────────────────────┐         HTTPS / REST + JWT        ┌──────────────────────┐
│   Flutter (mobile)   │ ────────────────────────────────► │  NestJS  /api        │
│   Android / iOS      │ ◄──────────────────────────────── │  Controller→Service  │
└──────────────────────┘            JSON                   └──────────┬───────────┘
                                                                      │ Prisma
                                                           ┌──────────▼───────────┐
                                                           │    PostgreSQL        │
                                                           └──────────────────────┘
                                                                      │
                                                           VNPay sandbox (e-wallet)
```

| Tầng | Công nghệ | Thư mục |
|---|---|---|
| Client | Flutter + Riverpod + Dio | `mobile/lib/` |
| API | NestJS (TypeScript) | `backend/src/` |
| ORM | Prisma | `backend/prisma/` |
| DB | PostgreSQL | `docker-compose.yml` |

---

## 2. Backend

### Phân tầng

Mỗi domain là một NestJS module, luồng đi một chiều:

```
Controller ──► Service ──► PrismaService ──► PostgreSQL
    │             │
 @Roles()      business rule (BR-xx)
 DTO validate  transaction
```

- **Controller** — chỉ định tuyến, phân quyền `@Roles()`, gắn `@AuditAction()`. Không chứa nghiệp vụ.
- **Service** — toàn bộ business rule, sở hữu transaction.
- **DTO** (`dto/`) — validate bằng `class-validator`, trim input (CR-08).

### Cross-cutting

| Thành phần | Vai trò |
|---|---|
| `common/guards/jwt-auth.guard.ts` | Bảo vệ mặc định mọi route; mở bằng `@Public()` |
| `common/guards/roles.guard.ts` | RBAC theo `@Roles()` (CR-07) |
| `audit-log/audit.interceptor.ts` | Tự ghi log thao tác gắn `@AuditAction()` (CR-11) |
| `ValidationPipe` (global) | `whitelist` + `forbidNonWhitelisted` — field lạ bị **reject 400** |

Hệ quả cần nhớ: **thêm field mới vào request thì phải khai báo trong DTO**, nếu không API trả 400.

### Module

| Module | Nghiệp vụ chính |
|---|---|
| `auth` | Đăng nhập JWT, khóa tài khoản sau 5 lần sai (BR-10) |
| `users` | CRUD tài khoản (chỉ Admin), chống trùng username (CR-04) |
| `menu` | CRUD product/category, upload ảnh, **công thức nguyên liệu** (BR-05, BR-08) |
| `orders` | Tạo/sửa/hủy order, gán bàn, trạng thái pha chế (UC06–12) |
| `payments` | Cash/card/VNPay, giảm giá, trừ kho, loyalty (BR-02/03/06/08/11) |
| `inventory` | CRUD nguyên liệu, nhập hàng, cảnh báo sắp hết |
| `customers` | CRUD khách hàng + lịch sử điểm |
| `tables` | Sơ đồ bàn và trạng thái chiếm dụng |
| `reports` | Doanh thu theo khoảng ngày, xuất CSV (UC20–21) |
| `audit-log` | Ghi nhận hành vi hệ thống |

---

## 3. Mobile

Cấu trúc **feature-first**, mỗi feature 3 lớp:

```
features/<name>/
├── domain/         model + fromJson (không phụ thuộc Flutter)
├── data/           repository gọi API + Riverpod provider
└── presentation/   page & widget
```

Dùng chung trong `core/`: `network/api_client.dart` (Dio + gắn JWT + `apiErrorMessage`),
`router/`, `theme/`, `utils/format.dart` (`formatVnd`, `parseAmount`).

**State** — Riverpod. Dữ liệu server qua `FutureProvider.autoDispose`
(`productsProvider`, `orderQueueProvider`, `customersProvider`, `ingredientsProvider`…).
Sau khi mutate phải `ref.invalidate(<provider>)` để refetch, nếu không UI hiển thị dữ liệu cũ.

**Giao tiếp giữa các màn** — `Navigator.push<T>` trả kết quả về màn trước.
Khi cần phân biệt "người dùng bấm back" với "người dùng chủ động xóa lựa chọn", bọc kết quả
trong một type riêng thay vì dùng `null` cho cả hai (xem `CustomerPickerResult`).

---

## 4. Mô hình dữ liệu

Quan hệ chính (chi tiết ở `backend/prisma/schema.prisma`):

```
User ──< Order >── Customer          Order ──< OrderItem >── Product
                     │                                          │
                     └──< LoyaltyTransaction                     └──< ProductIngredient >── Ingredient
Order ──1:1── Payment                                                                            │
Table ──< Order                                              PurchaseOrder ──< StockIn ──────────┘
```

- `Order` 1–1 `Payment` — mỗi order chỉ một phương thức thanh toán (BR-03).
- `ProductIngredient` = công thức, khóa chính là cặp `[productId, ingredientId]`
  → 1 nguyên liệu chỉ xuất hiện 1 lần trong công thức mỗi món.
- Tiền/số lượng dùng `Decimal(12,2)`, trả về JSON dạng **string** — client phải parse.

---

## 5. Hai luồng cốt lõi

### Tạo order (UC06)

```
Chọn bàn/khách → thêm món vào giỏ (local) → Review
   └─► POST /orders
         ├── món phải isAvailable                         → 400 (BR-04)
         ├── đủ nguyên liệu theo công thức                 → 400 (BR-08)
         ├── linePrice tính lại từ giá DB (không tin client)
         └── gán bàn → OCCUPIED
```

Giỏ hàng giữ **cục bộ trên máy** cho tới khi bấm Review — chưa gọi API lúc thêm từng món.

### Thanh toán (UC10)

```
POST /payments  ── một transaction ──┐
   ├── kiểm tra order OPEN, có ≥1 món
   ├── loyalty redeem (1 điểm = 100₫)
   ├── giảm > 50% → cần approvalManagerId          (BR-06)
   ├── CASH → cashTendered ≥ số phải trả, tính thối (BR-02)
   ├── order → PAID, bàn → FREE
   ├── trừ kho theo công thức, thu thập lowStock    (BR-08)
   └── loyalty earn (1 điểm / 10.000₫ thực trả)     (BR-11)
```

---

## 6. Quyết định thiết kế cần biết

**Tồn kho chỉ bị trừ thật lúc thanh toán, không giữ chỗ ở DB khi tạo order.**
Đây là ràng buộc quan trọng nhất khi đụng vào nghiệp vụ order. Vì order `OPEN` không giữ stock,
guard BR-08 lúc tạo/sửa đơn phải **tự tính phần các order `OPEN` khác đang giữ**
(`OrdersService.ensureStockAvailable`). Nếu chỉ so với `quantityOnHand`, hai đơn cùng ăn một
nguyên liệu sẽ đều qua được bước tạo, rồi đơn thứ hai lại fail đúng ở màn thanh toán.

*Đánh đổi:* cách này thêm một truy vấn các order `OPEN` mỗi lần tạo đơn, và vẫn có khe hở race
condition rất hẹp giữa lúc kiểm tra và lúc ghi. Chấp nhận được ở quy mô một quán cà phê, và
kiểm tra ở bước thanh toán vẫn là lớp chốt cuối. Nếu sau này cần chặt chẽ hơn thì nên
giữ chỗ tồn kho tường minh (reservation) thay vì siết khóa transaction.

**Không xóa cứng dữ liệu đã dùng.** Product đã vào order, category còn sản phẩm → trả `409`,
ẩn bằng `isAvailable: false`. Giữ lịch sử order và báo cáo doanh thu chính xác.

**Giá luôn tính lại phía server.** `OrdersService.buildItems` bỏ qua giá client gửi lên.

**`recipe` khi update product**: bỏ trống = giữ nguyên, gửi mảng (kể cả rỗng) = thay toàn bộ.
Chọn vậy để client cũ chưa biết field không vô tình xóa mất công thức.

---

## 7. Chỗ cần cẩn thận

| Điểm | Ghi chú |
|---|---|
| Sau khi đổi `schema.prisma` | Phải `npx prisma generate`, nếu không Prisma Client vẫn dùng type cũ |
| Unit test dùng **mock Prisma** | Không bắt được lỗi query sai/migration thiếu — cần chạy thật để chắc |
| Thêm field vào request | Phải khai báo trong DTO, nếu không `forbidNonWhitelisted` trả 400 |
| Route có param | Khai báo route tĩnh **trước** route `:id` (xem `/orders/queue`) |
| Decimal từ API | Là string, không phải number — parse bằng `parseAmount()` |
| VNPay | Chỉ sandbox; IPN là nguồn chốt đơn đáng tin, không phải return URL |
