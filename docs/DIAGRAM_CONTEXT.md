# CSMS — Full Context cho Báo Cáo & Diagram Generation

> Tài liệu này tổng hợp toàn bộ context cần thiết để sinh các diagram báo cáo cho hệ thống **Cafe Shop Management System (CSMS)**.  
> Cập nhật: 2026-06-24. Stack đã chốt: NestJS + Prisma + PostgreSQL (backend), Flutter (mobile).

---

## 1. Tổng quan hệ thống

CSMS là phần mềm quản lý vận hành quán cà phê, thay thế quy trình giấy tờ thủ công. Hệ thống gồm:
- **Backend REST API** chạy tại port 3000 (NestJS + Prisma ORM + PostgreSQL).
- **Mobile App** Flutter (nhắm Android/iOS/Web), chạy trên tablet tại quầy.
- **Database** PostgreSQL chạy trong Docker container `csms-db` (port 5432).

Môi trường dev: monorepo tại `/Cafe-Shop-Management-System/` gồm thư mục `backend/` và `mobile/`.

---

## 2. Kiến trúc tổng thể (System Architecture)

```
┌─────────────────────────────────────────────────────┐
│                  CLIENT LAYER                       │
│  Flutter Mobile App (Android / iOS / Web)           │
│  - Feature-first architecture                       │
│  - Riverpod state management                        │
│  - GoRouter navigation + role-based guard           │
│  - JWT stored in-memory (401 → auto logout)         │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS / REST JSON
                     │ Base URL: localhost:3000 (web/iOS)
                     │           10.0.2.2:3000 (Android emulator)
┌────────────────────▼────────────────────────────────┐
│                 BACKEND LAYER                       │
│  NestJS (TypeScript) — REST API                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  Global Middleware: JwtAuthGuard + RolesGuard│   │
│  ├──────────┬──────────┬──────────┬─────────────┤   │
│  │   Auth   │  Menu    │  Orders  │  Payments   │   │
│  │  Tables  │ Inventory│ Customers│  Reports    │   │
│  └──────────┴──────────┴──────────┴─────────────┘   │
│  Prisma ORM → type-safe DB queries                  │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              DATABASE LAYER                         │
│  PostgreSQL 15 (Docker container: csms-db)          │
│  12 tables: User, Category, Product, Order,         │
│  OrderItem, Payment, Table, Ingredient, Customer,   │
│  LoyaltyTransaction, PurchaseOrder, StockIn,        │
│  ProductIngredient                                  │
└─────────────────────────────────────────────────────┘
              │
              ▼  (External — chưa implement thật)
     Payment Gateway (REST/HTTPS) | Receipt Printer
```

---

## 3. Actors & Roles (Use Case)

| Actor | Vai trò |
|---|---|
| **Administrator** | Quản lý tài khoản, cấu hình hệ thống, quản lý master data |
| **Manager** | Quản lý menu, giám sát kho, xem báo cáo, duyệt discount >50% |
| **Cashier** | Tạo/sửa order, thanh toán, áp giảm giá, in hóa đơn |
| **Barista** | Xem Order Queue, cập nhật trạng thái chuẩn bị món |
| **Payment Gateway** *(external)* | Xác thực & xử lý thanh toán thẻ/ví |
| **Receipt Printer** *(external)* | In hóa đơn & kitchen ticket |

### Ma trận phân quyền

| Chức năng | Admin | Manager | Cashier | Barista |
|---|:---:|:---:|:---:|:---:|
| Login / Logout | ✓ | ✓ | ✓ | ✓ |
| Dashboard (xem widget) | ✓ | ✓ | ✓ | ✓ |
| Tạo / Sửa / Hủy Order | | | ✓ | |
| Xem chi tiết Order | | | ✓ | |
| Xem Order Queue | | ✓ | ✓ | ✓ |
| Cập nhật trạng thái món | | | | ✓ |
| Thanh toán (Payment) | | | ✓ | |
| Quản lý Product / Category | | ✓ | | |
| Quản lý Table | ✓ | ✓ | | |
| Quản lý Inventory | | ✓ | | |
| Xem báo cáo doanh thu | | ✓ | | |
| Quản lý tài khoản (User) | ✓ | | | |
| Quản lý khách hàng (Customer) | | ✓ | | |

---

## 4. Domain Model / ERD

### Entities & Relations

```
User ──< Order (createdBy)
User ──< Payment
User ──< PurchaseOrder

Category ──< Product
Product ──< OrderItem
Product ──< ProductIngredient >── Ingredient

Order >── Table (nullable, null = takeaway)
Order >── Customer (nullable)
Order ──< OrderItem
Order ──1 Payment

Payment >── Customer (nullable)
Payment ──< LoyaltyTransaction

Customer ──< Order
Customer ──< Payment
Customer ──< LoyaltyTransaction

PurchaseOrder ──< StockIn >── Ingredient
```

### Schema chi tiết (Prisma)

| Entity | PK | Fields chính | Ghi chú |
|---|---|---|---|
| **User** | id (int) | username (unique), passwordHash, fullName, role, isActive | Role: ADMINISTRATOR/MANAGER/CASHIER/BARISTA |
| **Category** | id (int) | name | |
| **Product** | id (int) | name, categoryId(FK), price(Decimal), size?, isAvailable, description? | BR-04: unavailable không order được |
| **Order** | id (int) | createdById(FK→User), tableId(FK?, null=takeaway), customerId(FK?), status, createdAt | Status: OPEN/PAID/CANCELLED; orderNo=`ORD-${1000+id}` |
| **OrderItem** | id (int) | orderId(FK), productId(FK), quantity, options?, linePrice(Decimal) | options = size/sugar/notes (string) |
| **Payment** | id (int) | orderId(FK unique), userId(FK), customerId(FK?), method, amount(Decimal), pointsRedeemed?, paidAt | Method: CASH/CARD/E_WALLET |
| **Table** | id (int) | number, capacity, occupancyStatus, floor?, shape | Status: FREE/OCCUPIED/RESERVED |
| **Ingredient** | id (int) | name, quantityOnHand(Decimal), reorderThreshold(Decimal) | low-stock khi quantityOnHand < reorderThreshold |
| **Customer** | id (int) | fullName, phone?, email?, loyaltyPoints(int), joinedAt | |
| **LoyaltyTransaction** | id (int) | customerId(FK), paymentId(FK), type, points, createdAt | Type: EARN/REDEEM |
| **PurchaseOrder** | id (int) | userId(FK), supplierName, status, totalAmount(Decimal), createdAt | |
| **StockIn** | id (int) | purchaseOrderId(FK), ingredientId(FK), quantity(Decimal), unitCost(Decimal), receivedAt | |
| **ProductIngredient** | (productId, ingredientId) composite | quantity(Decimal) | BOM/recipe để BR-08 trừ kho tự động |

---

## 5. API Endpoints (Backend — đã implement)

**Base URL:** `http://localhost:3000`  
**Auth header:** `Authorization: Bearer <JWT>`

### Auth
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| POST | /auth/login | public | Đăng nhập, trả JWT + user info |
| GET | /auth/me | ALL | Lấy thông tin user hiện tại |

### Menu — Categories
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /categories | ALL | Danh sách category |
| POST | /categories | MANAGER, ADMIN | Tạo category mới |
| PATCH | /categories/:id | MANAGER, ADMIN | Cập nhật category (chặn nếu còn product) |
| DELETE | /categories/:id | MANAGER, ADMIN | Xóa category (chặn nếu còn product) |

### Menu — Products
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /products | ALL | Danh sách product (filter available) |
| POST | /products | MANAGER, ADMIN | Tạo product mới |
| PATCH | /products/:id | MANAGER, ADMIN | Cập nhật product / isAvailable |
| DELETE | /products/:id | MANAGER, ADMIN | Xóa product |

### Tables
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /tables | ALL | Danh sách bàn + occupancyStatus |
| POST | /tables | ADMIN, MANAGER | Tạo bàn |
| PATCH | /tables/:id | ADMIN, MANAGER | Cập nhật bàn |
| DELETE | /tables/:id | ADMIN, MANAGER | Xóa bàn (chặn nếu OCCUPIED/RESERVED) |

### Orders
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /orders/queue | ALL | OPEN orders (Order Queue) |
| GET | /orders/:id | ALL | Chi tiết order |
| POST | /orders | CASHIER | Tạo order (BR-01 ≥1 item, BR-04 available, gán bàn OCCUPIED) |
| PATCH | /orders/:id | CASHIER | Sửa items (BR-07 chỉ khi OPEN) |
| DELETE | /orders/:id | CASHIER | Hủy order (set CANCELLED, giải phóng bàn) |

### Payments
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| POST | /payments | CASHIER | Thanh toán atomic: BR-02 amount, BR-03 1 method, BR-06 discount>50% cần approvalManagerId, BR-08 trừ kho, loyalty earn/redeem, set PAID, giải phóng bàn |

### Customers
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /customers | ALL | Danh sách + search khách hàng |
| GET | /customers/:id | ALL | Chi tiết khách + loyalty points |
| POST | /customers | MANAGER, ADMIN | Tạo khách hàng |
| PATCH | /customers/:id | MANAGER, ADMIN | Cập nhật thông tin khách |

### Inventory
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /inventory/ingredients | MANAGER, ADMIN | Danh sách nguyên liệu |
| GET | /inventory/low-stock | MANAGER, ADMIN | Nguyên liệu dưới ngưỡng reorderThreshold |
| POST | /inventory/ingredients | MANAGER, ADMIN | Tạo nguyên liệu |
| PATCH | /inventory/ingredients/:id | MANAGER, ADMIN | Cập nhật nguyên liệu |
| GET | /inventory/purchase-orders | MANAGER, ADMIN | Danh sách đơn nhập hàng |
| POST | /inventory/stock-in | MANAGER, ADMIN | Nhập kho (tạo StockIn + tăng quantityOnHand) |

### Reports
| Method | Path | Roles | Mô tả |
|---|---|---|---|
| GET | /reports/dashboard | ALL | Widget: doanh thu hôm nay, OPEN orders, low-stock alerts |
| GET | /reports/sales | MANAGER, ADMIN | Báo cáo doanh thu theo khoảng ngày (query: from, to) |

---

## 6. Luồng nghiệp vụ chính (Sequence / Flow)

### 6.1 Luồng Đăng nhập (Auth Flow)
```
Mobile App          Backend (NestJS)        Database (PostgreSQL)
    │                     │                         │
    │── POST /auth/login ─►│                         │
    │   {username,password}│── SELECT User ─────────►│
    │                     │◄── User record ──────────│
    │                     │── bcrypt.verify          │
    │◄── {access_token,   │                         │
    │     user:{id,role}} │                         │
    │── lưu token/user    │                         │
    │   vào Riverpod state│                         │
```

### 6.2 Luồng Tạo Order (Cashier)
```
Cashier (Mobile)    Backend                 Database
    │                   │                       │
    │── GET /tables ────►│── SELECT Tables ─────►│
    │◄── table list ────│◄─────────────────────│
    │                   │                       │
    │── GET /products ──►│── SELECT Products ───►│
    │◄── product list ──│◄─────────────────────│
    │                   │                       │
    │── POST /orders ───►│ [validate]            │
    │  {tableId,items[]} │ BR-01: items.length≥1 │
    │                   │ BR-04: product.isAvail │
    │                   │── INSERT Order ───────►│
    │                   │── INSERT OrderItems ──►│
    │                   │── UPDATE Table        ─►│ (OCCUPIED)
    │◄── {orderId,      │◄─────────────────────│
    │     orderNo,      │                       │
    │     status:OPEN}  │                       │
```

### 6.3 Luồng Thanh toán (Payment Flow) — BR-02, 03, 06, 08, 11
```
Cashier (Mobile)    Backend                     Database
    │                   │                           │
    │── POST /payments ─►│ [atomic transaction]      │
    │  {orderId,        │ 1. verify order OPEN      │
    │   method,         │ 2. BR-02: amount=Σ-disc   │
    │   discount?,      │ 3. BR-06: disc>50%?       │
    │   customerId?,    │    → verify manager creds  │
    │   pointsRedeem?,  │ 4. BR-08: trừ kho         │
    │   approverId?}    │    (ProductIngredient)    │
    │                   │ 5. Loyalty earn/redeem     │
    │                   │    earn: 1pt per 10.000₫  │
    │                   │    redeem: 1pt = 100₫ disc│
    │                   │ 6. INSERT Payment         ─►│
    │                   │ 7. UPDATE Order→PAID      ─►│
    │                   │ 8. UPDATE Table→FREE      ─►│
    │                   │ 9. UPDATE Ingredient qty  ─►│
    │                   │ 10. INSERT LoyaltyTxn     ─►│
    │◄── {paymentId,    │◄─────────────────────────│
    │     amount,       │                           │
    │     loyaltyEarned}│                           │
```

### 6.4 Luồng Nhập kho (Inventory Flow)
```
Manager (Mobile)    Backend                 Database
    │                   │                       │
    │── POST /inventory/─►│                       │
    │   stock-in        │── INSERT StockIn ─────►│
    │  {purchaseOrderId,│── UPDATE Ingredient   ─►│ (quantityOnHand += qty)
    │   ingredientId,   │                       │
    │   quantity}       │── check low-stock     │
    │◄── {stockIn}      │◄─────────────────────│
```

---

## 7. Mobile App — Màn hình & Navigation

### Cấu trúc Feature-first
```
mobile/lib/
├── core/
│   ├── config/env.dart          # API base URL (auto-detect platform)
│   ├── network/api_client.dart  # Dio + JWT interceptor + 401 handler
│   ├── router/app_router.dart   # GoRouter + role-based guard
│   ├── theme/                   # AppTheme, AppColors
│   └── providers/               # Riverpod global providers
└── features/
    ├── auth/         # Login page, AuthNotifier (Riverpod AsyncNotifier)
    ├── shell/        # Bottom-nav shell (role-based tabs)
    ├── dashboard/    # Dashboard page (widgets: revenue, open orders, alerts)
    ├── order/        # Create/Edit/Detail/Queue pages
    ├── payment/      # Payment page + Manager approval dialog
    ├── menu/         # Product & Category management pages
    ├── tables/       # Table management page
    ├── inventory/    # Ingredient & PurchaseOrder pages
    ├── customer/     # Customer list, form, detail pages
    ├── report/       # Sales report page
    └── account/      # Account settings page
```

### Bottom Navigation theo Role

| Tab | Cashier | Manager | Barista | Admin |
|---|---|---|---|---|
| Dashboard | ✓ | ✓ | ✓ | ✓ |
| Orders | ✓ (create+queue) | ✓ (queue only) | ✓ (queue only) | |
| Payment | ✓ | | | |
| Menu | | ✓ | | ✓ |
| Inventory | | ✓ | | |
| Reports | | ✓ | | |
| Customers | | ✓ | | |
| Tables | | ✓ | | ✓ |
| Account | ✓ | ✓ | ✓ | ✓ |

### Màn hình theo Figma (30 màn, file key: `3vz6zE3zQAHYKcx1jcBh8T`)
| # Figma | Màn hình | Feature | Phase |
|---|---|---|---|
| 01 | Splash | auth | 0 |
| 02 | Login | auth | 0 |
| 03 | Dashboard | dashboard | 0 |
| 04–07 | Dashboard widgets (revenue/orders/alerts/reports) | dashboard/reports | 5 |
| 08 | Create Order | order | 2 |
| 08A | Order Details | order | 2 |
| 09 | Add Item to Order | order | 2 |
| 10 | Order Queue | order | 2 |
| 11 | Cancel Order confirm | order | 2 |
| 12 | Payment page | payment | 3 |
| 13 | Payment — loyalty | payment | 3 |
| 14 | Payment success | payment | 3 |
| 15 | Menu — Product list | menu | 1 |
| 16 | Menu — Add Product | menu | 1 |
| 17 | Menu — Category list | menu | 1 |
| 18 | Menu — Add Category | menu | 1 |
| 19 | Inventory — Ingredient list | inventory | 4 |
| 20 | Inventory — Add Ingredient | inventory | 4 |
| 21 | Inventory — Purchase Order | inventory | 4 |
| 22 | Customer list | customer | 5 |
| 23 | Customer detail | customer | 5 |
| 24 | Customer form | customer | 5 |
| 25–27 | Reports (sales chart, date filter, export) | reports | 5 |
| 28 | Table management | tables | 1 |
| 29 | Add Table | tables | 1 |
| 30 | Table status view | tables | 1 |

---

## 8. Business Rules tóm tắt

| Rule | Mô tả |
|---|---|
| BR-01 | Order phải có ≥1 item |
| BR-02 | Amount = Σ(linePrice) − discount |
| BR-03 | 1 order chỉ 1 phương thức thanh toán |
| BR-04 | Product `isAvailable=false` không được order |
| BR-05 | Chỉ Manager/Admin tạo/sửa/xóa product & giá |
| BR-06 | Discount >50% subtotal → cần Manager xác nhận credential (approvalManagerId) |
| BR-07 | Order PAID/CANCELLED → không sửa được |
| BR-08 | Payment thành công → tự trừ kho theo `ProductIngredient` recipe |
| BR-09 | TLS ≥256-bit cho data cá nhân & payment |
| BR-10 | Khóa account 15 phút sau 5 lần sai mật khẩu |
| BR-11 | Earn 1pt/10.000₫ thanh toán; Redeem 1pt=100₫ giảm giá |
| BR-12 | StockIn phải reference PurchaseOrder tồn tại |

---

## 9. Non-Functional Requirements

| NFR | Chỉ tiêu |
|---|---|
| **Availability** | ≥ 99.5% giờ hoạt động |
| **Performance** | Chuyển màn/search ≤1s avg (≤3s peak); lưu order/payment ≤2s |
| **Throughput** | ≥20 concurrent users; ≥60 orders/giờ |
| **Security** | Password bcrypt hash; JWT auth; RBAC; audit log |
| **Usability** | Nhập ≤5 món trong <60s; tác vụ thường dùng ≤2 tap từ Dashboard |
| **Retention** | Lưu lịch sử ≥2 năm |

---

## 10. Build Progress (tính đến 2026-06-24)

| Phase | Nội dung | Status |
|---|---|---|
| **Phase 0** | Nền tảng: JWT auth, router guard, role-based bottom-nav, login/dashboard/account | ✅ Done |
| **Phase 1** | Menu (Product/Category/Table) — BE CRUD + Mobile | ✅ Done |
| **Phase 2** | Orders — BE create/queue/detail/update/cancel + Mobile 08-11 | ✅ Done |
| **Phase 3** | Payment + Loyalty — atomic payment, BR-06 manager approval, loyalty earn/redeem + Mobile 12-14 | ✅ Done |
| **Phase 4** | Inventory (Ingredient, PurchaseOrder, StockIn, low-stock alert) | ⏳ Tiếp theo |
| **Phase 5** | Customer CRUD đầy đủ + Reports/Dashboard chi tiết | 🔜 Planned |

---

## 11. Dev Setup nhanh

```bash
# 1. Khởi động DB
docker compose up -d db      # container csms-db, port 5432

# 2. Backend
cd backend
npm install
npx prisma migrate deploy
npx prisma db seed           # seed demo accounts
npm run start:dev            # port 3000

# 3. Mobile (terminal riêng)
cd mobile
flutter run -d chrome        # web (localhost)
# hoặc flutter run           # device/emulator
```

**Demo accounts:**
| Username | Password | Role |
|---|---|---|
| admin | admin123 | ADMINISTRATOR |
| manager.an | 123456 | MANAGER |
| cashier.linh | 123456 | CASHIER |
| barista.huy | 123456 | BARISTA |

---

## 12. Danh sách Diagram cần vẽ cho báo cáo

Dựa trên context này, các diagram thường cần cho báo cáo CSMS:

1. **System Architecture Diagram** — 3 lớp: Mobile / REST API (NestJS modules) / PostgreSQL + external systems
2. **ERD (Entity-Relationship Diagram)** — 13 entities với quan hệ đầy đủ (xem §4)
3. **Use Case Diagram** — 5 actors × các use cases theo §3
4. **Sequence Diagram — Order Flow** — Cashier tạo order (xem §6.2)
5. **Sequence Diagram — Payment Flow** — Thanh toán atomic với loyalty (xem §6.3)
6. **Sequence Diagram — Auth Flow** — Login + JWT (xem §6.1)
7. **Component Diagram** — NestJS modules: Auth, Menu, Orders, Payments, Inventory, Customers, Reports, Tables + Prisma + DB
8. **Activity Diagram — Payment** — bao gồm nhánh BR-06 (discount >50% → manager approval)
9. **Mobile Screen Navigation Map** — màn hình theo role (xem §7)
10. **Class Diagram** — entities + enums từ Prisma schema (xem §4)

---

*Nguồn: CSMS-SRS v1.0, codebase tại `/Cafe-Shop-Management-System/`, cập nhật 2026-06-24.*
