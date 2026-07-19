# CSMS — REST API Reference

Base URL: `http://localhost:3000/api` (global prefix `api`, đổi cổng bằng biến môi trường `PORT`).

Tài liệu này mô tả API **thực tế trong code** (`backend/src/**/*.controller.ts`).
Business rule (BR-xx) tra chi tiết ở `CSMS_PROJECT_CONTEXT.md`.

---

## Quy ước chung

**Auth** — Mọi endpoint yêu cầu JWT trừ khi đánh dấu `Public`:

```
Authorization: Bearer <accessToken>
```

**Validation** — `ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true })`.
Gửi field không khai báo trong DTO sẽ bị **reject 400**, không phải bỏ qua im lặng.

**Kiểu số** — Tiền và số lượng lưu `Decimal(12,2)`, trả về JSON dạng **string** (vd `"45000.00"`).
Client phải parse (mobile dùng `parseAmount()`).

**Mã lỗi**

| Code | Nghĩa |
|---|---|
| 400 | Sai validation, hết nguyên liệu, tiền mặt không đủ |
| 401 | Thiếu/hết hạn token |
| 403 | Role không có quyền (CR-07), hoặc manager duyệt không hợp lệ |
| 404 | Không tìm thấy resource |
| 409 | Xung đột trạng thái (sửa order đã thanh toán, xóa category còn sản phẩm, cần manager duyệt) |

Body lỗi theo chuẩn Nest: `{ "statusCode": 400, "message": "...", "error": "Bad Request" }`.
`message` có thể là mảng string khi lỗi validation nhiều field.

**Ký hiệu role** dưới đây: A = Administrator, M = Manager, C = Cashier, B = Barista.
"Mọi role" = bất kỳ user nào đã đăng nhập.

---

## Auth — `/auth`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| POST | `/auth/login` | **Public** | Đăng nhập, rate limit 10 req/phút |
| GET | `/auth/me` | Mọi role | Khôi phục phiên từ token đã lưu (CR-06) |
| POST | `/auth/logout` | Mọi role | Ghi audit log, trả `{ success: true }` |

**POST `/auth/login`**

```json
{ "username": "manager.an", "password": "123456" }
```

Trả về `accessToken` + thông tin user. Sai 5 lần liên tiếp → khóa tài khoản (BR-10).

---

## Products — `/products`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/products?search=` | Mọi role | Danh sách món, kèm `category` + `recipe` |
| GET | `/products/:id` | Mọi role | Chi tiết 1 món kèm công thức |
| POST | `/products` | M, A | Thêm món (BR-05) |
| PATCH | `/products/:id` | M, A | Sửa món |
| DELETE | `/products/:id` | M, A | Xóa món |
| POST | `/products/upload` | M, A | Upload ảnh, `multipart/form-data` field `file` |

Đọc mở cho mọi role vì cashier cần xem menu để tạo order.

**POST/PATCH body**

```json
{
  "name": "Cappuccino",
  "categoryId": 1,
  "price": 45000,
  "size": "S/M/L",
  "description": "…",
  "isAvailable": true,
  "imageUrl": "/uploads/1720000000-123.jpg",
  "recipe": [
    { "ingredientId": 9, "quantity": 18 },
    { "ingredientId": 4, "quantity": 120 }
  ]
}
```

`name` tối đa 30 ký tự (MSG02), `price` ≥ 0 tối đa 2 chữ số thập phân (MSG08).

**Ngữ nghĩa `recipe`** (BR-08) — lượng nguyên liệu cho **1 đơn vị** món:

- Không gửi field → **giữ nguyên** công thức cũ.
- Gửi mảng (kể cả `[]`) → **thay thế toàn bộ** công thức.

Mỗi `ingredientId` chỉ được xuất hiện 1 lần (khóa chính là cặp `[productId, ingredientId]`),
trùng → `409`. Ingredient không tồn tại → `404`.

**Response** kèm `recipe[].ingredient` để client hiển thị tên:

```json
{
  "id": 12, "name": "Cappuccino", "price": "45000.00",
  "category": { "id": 1, "name": "Coffee" },
  "recipe": [
    { "productId": 12, "ingredientId": 9, "quantity": "18.00",
      "ingredient": { "id": 9, "name": "Coffee Beans", "quantityOnHand": "500.00" } }
  ]
}
```

**DELETE** → `409` nếu món đã từng nằm trong order (giữ lịch sử; ẩn bằng `isAvailable: false` thay vì xóa).

---

## Categories — `/categories`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/categories` | Mọi role | Kèm `_count.products` |
| POST | `/categories` | M, A | Body `{ "name": "Coffee" }` |
| PATCH | `/categories/:id` | M, A | |
| DELETE | `/categories/:id` | M, A | `409` nếu còn sản phẩm (MSG06) |

---

## Orders — `/orders`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/orders/queue` | Mọi role | Các order `OPEN`, cũ nhất trước (UC11) |
| GET | `/orders/:id` | Mọi role | Chi tiết order |
| POST | `/orders` | C, M, A | Tạo order (UC06) |
| PATCH | `/orders/:id` | C, M, A | Sửa order / đổi bàn (UC07, UC09) |
| DELETE | `/orders/:id` | C, M, A | Hủy order (UC08) |
| PATCH | `/orders/:id/items/:itemId/prep` | B, C, M, A | Trạng thái pha chế 1 món (UC12) |
| PATCH | `/orders/:id/prep-done` | B, C, M, A | Đánh dấu cả order pha xong |

**POST `/orders`**

```json
{
  "tableId": 5,
  "customerId": 3,
  "items": [
    { "productId": 101, "quantity": 2, "options": "M · Sugar 50%" }
  ]
}
```

`tableId` bỏ trống = takeaway. `customerId` tùy chọn — gán khách để tích điểm.
`items` cần ít nhất 1 phần tử (BR-01), `quantity` ≥ 1.

Validate khi tạo:
- Món phải `isAvailable` → 400 (BR-04).
- **Đủ nguyên liệu trong kho → 400 nếu thiếu (BR-08).** Tồn khả dụng đã **trừ hao phần các order
  `OPEN` khác đang giữ**, vì kho chỉ bị trừ thật lúc thanh toán. Nhờ vậy đơn thiếu nguyên liệu bị
  chặn ngay khi tạo, không để đến bước thanh toán mới báo.
- `linePrice` **luôn tính lại từ giá DB**, không dùng giá client gửi.

Gán `tableId` → bàn chuyển `OCCUPIED`. Hủy/thanh toán → bàn về `FREE`.

**PATCH `/orders/:id`** — chỉ khi order `OPEN`, ngược lại `409` (BR-07).
Gửi `items` = thay toàn bộ danh sách món (và kiểm lại tồn kho, bỏ qua phần chính order này giữ).

**PATCH `.../prep`** — body `{ "status": "PENDING" | "MAKING" | "DONE" }`.

**Response** thêm 3 field tính sẵn (không lưu DB): `orderNo` (`ORD-1001`), `subtotal`, `itemCount`.

---

## Payments — `/payments`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| POST | `/payments` | C, M, A | Thanh toán order (UC10) |
| POST | `/payments/:id/vnpay-url` | C, M, A | Sinh link thanh toán VNPay |
| GET | `/payments/vnpay-return` | **Public** | Redirect người dùng về sau khi trả tiền |
| GET | `/payments/vnpay-ipn` | **Public** | VNPay gọi server-to-server để chốt đơn |

**POST `/payments`**

```json
{
  "orderId": 1,
  "method": "CASH",
  "customerId": 3,
  "pointsRedeemed": 10,
  "discount": 5000,
  "cashTendered": 100000,
  "approvalManagerId": 2
}
```

| Field | Bắt buộc | Ghi chú |
|---|---|---|
| `orderId` | ✓ | Order phải đang `OPEN` và có ≥ 1 món |
| `method` | ✓ | `CASH` / `CARD` / `E_WALLET` — 1 phương thức duy nhất (BR-03) |
| `customerId` | | Cần khi `pointsRedeemed > 0` |
| `pointsRedeemed` | | 1 điểm = 100₫; không vượt số dư khách |
| `discount` | | Giảm giá thủ công (số tiền), cộng dồn với giảm giá loyalty |
| `cashTendered` | ✓ khi `CASH` | Thiếu hoặc nhỏ hơn số phải trả → 400 |
| `approvalManagerId` | ✓ khi giảm > 50% | Thiếu → 409; không phải M/A đang hoạt động → 403 (BR-06) |

Xử lý trong 1 transaction: tạo `Payment` → order sang `PAID` → bàn về `FREE` →
trừ kho theo công thức (BR-08) → ghi loyalty REDEEM rồi EARN (1 điểm mỗi 10.000₫ thực trả, BR-11).

**Response**

```json
{
  "payment": { "id": 7, "orderId": 1, "method": "CASH", "amount": "39000.00" },
  "orderNo": "ORD-1001", "subtotal": 45000, "discount": 6000, "amount": 39000,
  "change": 61000, "pointsRedeemed": 10, "pointsEarned": 3, "newBalance": 15,
  "lowStock": ["Coffee Beans"]
}
```

`lowStock` = nguyên liệu vừa chạm/dưới ngưỡng đặt lại sau khi trừ — client nên cảnh báo.

---

## Inventory — `/inventory`

Toàn bộ nhóm này chỉ **M, A**.

| Method | Path | Mô tả |
|---|---|---|
| GET | `/inventory/ingredients` | Danh sách nguyên liệu, kèm cờ `lowStock` |
| GET | `/inventory/low-stock` | Chỉ nguyên liệu dưới ngưỡng |
| POST | `/inventory/ingredients` | Thêm nguyên liệu |
| PATCH | `/inventory/ingredients/:id` | Sửa |
| DELETE | `/inventory/ingredients/:id` | Xóa |
| GET | `/inventory/purchase-orders` | Lịch sử nhập hàng |
| POST | `/inventory/stock-in` | Goods receipt — cộng kho (BR-12) |

**POST `/inventory/ingredients`**

```json
{ "name": "Coffee Beans", "quantityOnHand": 500, "reorderThreshold": 100 }
```

**POST `/inventory/stock-in`** — tạo Purchase Order + cộng kho trong 1 bước:

```json
{
  "supplierName": "Trung Nguyen",
  "items": [{ "ingredientId": 9, "quantity": 1000, "unitCost": 250 }]
}
```

---

## Customers — `/customers`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/customers?search=` | Mọi role | Tìm theo tên/SĐT — cashier cần gán khách vào order |
| GET | `/customers/:id` | Mọi role | Kèm `activity` (lịch sử điểm) |
| POST | `/customers` | M, A | |
| PATCH | `/customers/:id` | M, A | |
| DELETE | `/customers/:id` | M, A | |

```json
{ "fullName": "Nguyen Van A", "phone": "0901234567", "email": "a@example.com" }
```

`phone`/`email` tùy chọn; `email` phải đúng định dạng.

---

## Tables — `/tables`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/tables` | Mọi role | Sơ đồ bàn + trạng thái |
| POST | `/tables` | M, A | |
| PATCH | `/tables/:id` | M, A, **C** | Cashier được đổi `occupancyStatus` |
| DELETE | `/tables/:id` | M, A | |

`occupancyStatus`: `FREE` / `OCCUPIED` / `RESERVED` — thường do luồng order tự cập nhật.

---

## Reports — `/reports`

| Method | Path | Role | Mô tả |
|---|---|---|---|
| GET | `/reports/dashboard` | Mọi role | Số liệu trang chủ |
| GET | `/reports/sales?from=&to=` | M, A | Báo cáo doanh thu (UC20) |
| GET | `/reports/sales/export?from=&to=` | M, A | Xuất CSV (UC21) |

`from`/`to` dạng ISO date; mặc định 7 ngày gần nhất.

```json
{
  "from": "2026-07-13T00:00:00.000Z", "to": "2026-07-19T…",
  "totalRevenue": 12500000, "orderCount": 143, "avgTicket": 87413,
  "topProducts": [{ "name": "Cappuccino", "qty": 88, "revenue": 3960000 }]
}
```

`topProducts` giới hạn 5 món doanh thu cao nhất.

---

## Users — `/users`

Toàn bộ nhóm này chỉ **Administrator**.

| Method | Path | Mô tả |
|---|---|---|
| GET | `/users` | Danh sách tài khoản |
| POST | `/users` | Tạo tài khoản, `username` không trùng (CR-04) |
| PATCH | `/users/:id` | Sửa thông tin/role/khóa mở tài khoản |
| DELETE | `/users/:id` | Xóa tài khoản |

---

## Static files

Ảnh sản phẩm phục vụ tại `/uploads/<filename>` (**không** có prefix `/api`).
`imageUrl` trong response là đường dẫn tương đối; mobile ghép base URL trong `Product.fullImageUrl`.
