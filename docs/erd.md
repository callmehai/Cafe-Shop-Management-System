# CSMS — Entity Relationship Diagram

Sinh từ `backend/prisma/schema.prisma`. Khi schema đổi, cập nhật lại file này.

Ký hiệu quan hệ Mermaid:

| Ký hiệu | Nghĩa |
|---|---|
| `||--o{` | 1 — 0..n |
| `||--||` | 1 — 1 |
| `}o--||` | 0..n — 1 (FK nullable) |

---

## Sơ đồ tổng thể

```mermaid
erDiagram
    User ||--o{ Order : "tạo"
    User ||--o{ Payment : "xử lý"
    User ||--o{ PurchaseOrder : "lập"

    Category ||--o{ Product : "phân loại"

    Product ||--o{ OrderItem : "được đặt"
    Product ||--o{ ProductIngredient : "có công thức"
    Ingredient ||--o{ ProductIngredient : "được dùng"
    Ingredient ||--o{ StockIn : "được nhập"

    Order ||--o{ OrderItem : "gồm"
    Order ||--|| Payment : "thanh toán"
    Table }o--|| Order : "phục vụ"
    Customer }o--|| Order : "đặt"

    Customer ||--o{ Payment : "trả"
    Customer ||--o{ LoyaltyTransaction : "tích/đổi"
    Payment ||--o{ LoyaltyTransaction : "phát sinh"

    PurchaseOrder ||--o{ StockIn : "gồm"

    User {
        int id PK
        string username UK
        string passwordHash
        string fullName
        Role role
        boolean isActive
        int failedAttempts
        datetime lockedUntil
        datetime createdAt
        datetime updatedAt
    }

    Category {
        int id PK
        string name
    }

    Product {
        int id PK
        int categoryId FK
        string name
        decimal price
        string size
        boolean isAvailable
        string description
        string imageUrl
    }

    Ingredient {
        int id PK
        string name
        decimal quantityOnHand
        decimal reorderThreshold
    }

    ProductIngredient {
        int productId PK
        int ingredientId PK
        decimal quantity
    }

    Order {
        int id PK
        int createdById FK
        int tableId FK
        int customerId FK
        OrderStatus status
        datetime createdAt
        datetime updatedAt
    }

    OrderItem {
        int id PK
        int orderId FK
        int productId FK
        int quantity
        string options
        decimal linePrice
        PrepStatus prepStatus
    }

    Payment {
        int id PK
        int orderId FK,UK
        int userId FK
        int customerId FK
        PaymentMethod method
        decimal amount
        int pointsRedeemed
        datetime paidAt
    }

    Customer {
        int id PK
        string fullName
        string phone
        string email
        int loyaltyPoints
        datetime joinedAt
    }

    LoyaltyTransaction {
        int id PK
        int customerId FK
        int paymentId FK
        LoyaltyType type
        int points
        datetime createdAt
    }

    Table {
        int id PK
        int number
        int capacity
        OccupancyStatus occupancyStatus
        string floor
        string shape
    }

    PurchaseOrder {
        int id PK
        int userId FK
        string supplierName
        string status
        decimal totalAmount
        datetime createdAt
    }

    StockIn {
        int id PK
        int purchaseOrderId FK
        int ingredientId FK
        decimal quantity
        decimal unitCost
        datetime receivedAt
    }

    AuditLog {
        int id PK
        int userId
        string username
        string action
        string details
        string ipAddress
        datetime createdAt
    }
```

---

## Cụm nghiệp vụ

### Bán hàng — order tới thanh toán

```mermaid
erDiagram
    User ||--o{ Order : "tạo"
    Table }o--|| Order : "phục vụ"
    Customer }o--|| Order : "đặt"
    Order ||--o{ OrderItem : "gồm"
    Product ||--o{ OrderItem : "được đặt"
    Order ||--|| Payment : "thanh toán"
    Payment ||--o{ LoyaltyTransaction : "phát sinh"
    Customer ||--o{ LoyaltyTransaction : "tích/đổi"
```

### Kho — công thức và nhập hàng

```mermaid
erDiagram
    Product ||--o{ ProductIngredient : "có công thức"
    Ingredient ||--o{ ProductIngredient : "được dùng"
    PurchaseOrder ||--o{ StockIn : "gồm"
    Ingredient ||--o{ StockIn : "được nhập"
    User ||--o{ PurchaseOrder : "lập"
```

---

## Ghi chú

- `ProductIngredient` có khóa chính **cặp** `[productId, ingredientId]` — một nguyên liệu chỉ xuất
  hiện 1 lần trong công thức của mỗi món (BR-08).
- `Payment.orderId` là FK kèm `@unique` → quan hệ 1-1 với `Order` (BR-03: mỗi order một phương
  thức thanh toán). Mermaid không có ký hiệu FK+UK nên ghi là `FK_UK`.
- `Order.tableId` null = takeaway; `Order.customerId` null = khách vãng lai.
- `AuditLog.userId` / `username` chỉ là snapshot, **không khai báo FK** tới `User` — cố ý, để log
  còn nguyên khi tài khoản bị xóa (CR-11).
- Tiền và số lượng dùng `Decimal(12,2)`; API trả JSON dạng string, client phải parse.
