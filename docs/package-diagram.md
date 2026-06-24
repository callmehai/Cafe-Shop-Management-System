# CSMS — Package Diagram

> Biểu đồ package thể hiện cấu trúc tổ chức module cấp cao và mối quan hệ phụ thuộc giữa các thành phần.  
> **Backend:** NestJS 10 + Prisma 5 + PostgreSQL · **Mobile:** Flutter + Riverpod

---

## 1. Tổng quan hệ thống

```mermaid
graph LR
    subgraph Mobile["📱 Mobile (Flutter + Riverpod)"]
        direction TB
        MobFeat["Feature Modules\nauth · order · payment · menu\ncustomer · inventory · tables\nreport · users · dashboard"]
        MobCore["Core\nApiClient · AppRouter\nRiverpod Providers · Utils"]
        MobFeat --> MobCore
    end

    subgraph Backend["🔷 Backend (NestJS + Prisma)"]
        direction TB
        NestFeat["Feature Modules\nAuth · Users · Menu · Orders\nPayments · Inventory · Tables\nCustomers · Reports"]
        PrismaORM["Prisma ORM"]
        CrossCut["Cross-cutting\nJwtAuthGuard · RolesGuard\n@Public · @Roles · @CurrentUser"]
        NestFeat --> PrismaORM
        CrossCut -. "applied globally" .-> NestFeat
    end

    DB[(PostgreSQL)]

    Mobile -->|"REST + Bearer JWT"| Backend
    PrismaORM -->|SQL| DB
```

---

## 2. Backend — NestJS Module Dependency Graph

Ký hiệu: `──►` import trực tiếp · `- -►` phụ thuộc PrismaModule (shared)

```mermaid
graph TD
    App["AppModule\n(root)"]

    App --> Auth["AuthModule"]
    App --> Users["UsersModule"]
    App --> Menu["MenuModule"]
    App --> Orders["OrdersModule"]
    App --> Payments["PaymentsModule"]
    App --> Inventory["InventoryModule"]
    App --> Tables["TablesModule"]
    App --> Customers["CustomersModule"]
    App --> Reports["ReportsModule"]
    App --> Prisma["PrismaModule"]

    Auth -->|"user lookup\n& bcrypt verify"| Users
    Orders -->|"lấy price\nkhi tạo items"| Menu
    Payments -->|"đổi status\nORDER → PAID"| Orders
    Payments -->|"loyalty\ncalc (BR-11)"| Customers
    Payments -->|"trừ stock\ntheo recipe (BR-08)"| Inventory

    Users  -.-> Prisma
    Auth   -.-> Prisma
    Menu   -.-> Prisma
    Orders -.-> Prisma
    Payments -.-> Prisma
    Inventory -.-> Prisma
    Tables  -.-> Prisma
    Customers -.-> Prisma
    Reports -.-> Prisma
```

---

## 3. Backend — Cấu trúc nội bộ mỗi Module

Tất cả module tuân theo pattern 3 lớp:

```mermaid
graph LR
    subgraph "FeatureModule (ví dụ: OrdersModule)"
        direction LR
        D["DTOs\nCreateXDto · UpdateXDto\n(class-validator)"]
        C["XController\nHTTP endpoints\n@UseGuards · @Roles"]
        S["XService\nBusiness logic\nBR enforcement"]
        P["PrismaService\nDB queries"]
        D --> C --> S --> P
    end
```

---

## 4. Backend — Cross-cutting Concerns

```mermaid
graph TD
    subgraph Guards["Guards (APP_GUARD)"]
        JWT["JwtAuthGuard\n— xác thực Bearer token\n— inject payload → request.user"]
        Roles["RolesGuard\n— đọc @Roles metadata\n— so sánh với request.user.role"]
        JWT --> Roles
    end

    subgraph Decorators["Custom Decorators"]
        Public["@Public()\n— bypass JwtAuthGuard"]
        RolesDec["@Roles(Role.MANAGER, ...)\n— yêu cầu role cụ thể"]
        CUser["@CurrentUser()\n— inject user từ JWT payload"]
    end
```

---

## 5. Mobile — Feature & Dependency Graph

```mermaid
graph TD
    subgraph Core["⚙️ Core"]
        Api["ApiClient\n(Dio + JWT interceptor\n+ 401 auto-refresh)"]
        Router["AppRouter\n(go_router)"]
        Providers["Riverpod Providers\n(apiClientProvider\nsecureStorageProvider\nauthRepositoryProvider ...)"]
        Utils["Utils\n(formatVnd · parseAmount\ndate helpers)"]
    end

    subgraph Features["📦 Features"]
        auth["auth\nlogin_page"]
        order["order\norder_page · create_order\norder_queue · order_details"]
        payment["payment\npayment_page · success"]
        customer["customer\nlist · details · form"]
        menu["menu\nmenu_page · product_form\nmenu_management"]
        inventory["inventory\ninventory_page · stock_in"]
        tables["tables\ntables_management · form"]
        report["report\nreport_page · reports_page"]
        users["users\nusers_management"]
        dashboard["dashboard\ndashboard_page"]
    end

    Features -->|"HTTP calls"| Api
    Features -->|"DI wiring"| Providers
    Router --> Features

    order -->|"product picker"| menu
    order -->|"table picker"| tables
    payment -->|"order context"| order
    payment -->|"customer lookup"| customer
    dashboard -->|"reads DashboardStats"| report
```

---

## 6. Mobile — Cấu trúc nội bộ mỗi Feature

Tất cả feature tuân theo pattern 3 lớp:

```mermaid
graph LR
    subgraph "Feature (ví dụ: order)"
        direction LR
        Model["domain/\nDomain Models\n(immutable data classes)"]
        Repo["data/\nXRepository\n(ApiClient calls → parse JSON)"]
        Prov["presentation/\nRiverpod Notifier\n(AsyncNotifier / state)"]
        UI["presentation/\nPages & Widgets\n(ConsumerWidget)"]
        Model --> Repo --> Prov --> UI
    end
```

---

## 7. Bảng phụ thuộc quan trọng

| Phụ thuộc | Business Rule | Ghi chú |
|-----------|--------------|---------|
| `PaymentsModule` → `InventoryModule` | BR-08 | Tự động trừ kho theo recipe (`ProductIngredient`) khi order được thanh toán |
| `PaymentsModule` → `CustomersModule` | BR-11 | Earn 1 point / 10.000₫; redeem bù vào amount |
| `PaymentsModule` → `OrdersModule` | BR-07 | Chỉ đổi status `OPEN → PAID`; reject nếu đã PAID/CANCELLED |
| `AuthModule` → `UsersModule` | — | `findByUsername` + bcrypt compare khi login |
| `OrdersModule` → `MenuModule` | BR-04 | Lấy `price` + kiểm tra `isAvailable` khi thêm item |
| `payment` → `order` (mobile) | — | Hiển thị chi tiết đơn hàng trước khi xác nhận thanh toán |
| `order` → `menu` (mobile) | — | Product picker dùng danh sách menu khi tạo đơn |
| `order` → `tables` (mobile) | — | Table picker khi chọn bàn cho đơn dine-in |
