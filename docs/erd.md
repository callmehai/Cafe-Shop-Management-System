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
    User ||--o{ Order : "creates"
    User ||--o{ Payment : "processes"
    User ||--o{ PurchaseOrder : "raises"

    Category ||--o{ Product : "classifies"

    Product ||--o{ OrderItem : "ordered as"
    Product ||--o{ ProductIngredient : "has recipe"
    Ingredient ||--o{ ProductIngredient : "used in"
    Ingredient ||--o{ StockIn : "received as"

    Order ||--o{ OrderItem : "contains"
    Order ||--|| Payment : "paid by"
    Table }o--|| Order : "served at"
    Customer }o--|| Order : "placed by"

    Customer ||--o{ Payment : "pays"
    Customer ||--o{ LoyaltyTransaction : "earns/redeems"
    Payment ||--o{ LoyaltyTransaction : "generates"

    PurchaseOrder ||--o{ StockIn : "contains"

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
    User ||--o{ Order : "creates"
    Table }o--|| Order : "served at"
    Customer }o--|| Order : "placed by"
    Order ||--o{ OrderItem : "contains"
    Product ||--o{ OrderItem : "ordered as"
    Order ||--|| Payment : "paid by"
    Payment ||--o{ LoyaltyTransaction : "generates"
    Customer ||--o{ LoyaltyTransaction : "earns/redeems"
```

### Kho — công thức và nhập hàng

```mermaid
erDiagram
    Product ||--o{ ProductIngredient : "has recipe"
    Ingredient ||--o{ ProductIngredient : "used in"
    PurchaseOrder ||--o{ StockIn : "contains"
    Ingredient ||--o{ StockIn : "received as"
    User ||--o{ PurchaseOrder : "raises"
```

---

## Ghi chú

- `ProductIngredient` có khóa chính **cặp** `[productId, ingredientId]` — một nguyên liệu chỉ xuất
  hiện 1 lần trong công thức của mỗi món (BR-08).
- `Payment.orderId` là FK kèm `@unique` → quan hệ 1-1 với `Order` (BR-03: mỗi order một phương
  thức thanh toán) — trong sơ đồ ghi là `FK,UK`.
- `Order.tableId` null = takeaway; `Order.customerId` null = khách vãng lai.
- `AuditLog.userId` / `username` chỉ là snapshot, **không khai báo FK** tới `User` — cố ý, để log
  còn nguyên khi tài khoản bị xóa (CR-11).
- Tiền và số lượng dùng `Decimal(12,2)`; API trả JSON dạng string, client phải parse.
