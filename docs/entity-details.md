# Entities Description & Entity Details

Generated from `backend/prisma/schema.prisma`. Update this file whenever the schema changes.

**Type mapping** — Prisma/PostgreSQL types are written in generic form for documentation:
`Int` → Integer, `String` → String, `Boolean` → Boolean, `DateTime` → DateTime,
`Decimal @db.Decimal(12,2)` → Decimal(12,2).

**Mandatory** — "Yes" means `NOT NULL` in the database. Columns with a default value are still
mandatory; the default only applies when the client omits the field.

---

## Entities Description

| #   | Entity             | Description                                                                                          |
| --- | ------------------ | ---------------------------------------------------------------------------------------------------- |
| 1   | User               | A system user (admin, manager, cashier, barista) with login credentials and a role.                  |
| 2   | Category           | A grouping of products (Coffee, Tea, Pastry…).                                                       |
| 3   | Product            | A menu item with name, category, price and availability.                                             |
| 4   | Order              | A customer order with status, table, customer, creator and timestamp.                                |
| 5   | OrderItem          | A single line of an order: product, quantity, options, line price and preparation status.            |
| 6   | Payment            | The payment settling an order (one per order), with method, amount and the cashier who processed it. |
| 7   | Table              | A physical table in the shop, with capacity, location and occupancy status.                          |
| 8   | Customer           | A loyalty customer with contact details and an accumulated point balance.                            |
| 9   | LoyaltyTransaction | A single earn or redeem movement of loyalty points, tied to a payment.                               |
| 10  | Ingredient         | A stock item consumed by product recipes, with quantity on hand and reorder threshold.               |
| 11  | ProductIngredient  | The recipe line linking a product to an ingredient and the amount consumed per unit.                 |
| 12  | PurchaseOrder      | A purchase of ingredients from a supplier, with status and total amount.                             |
| 13  | StockIn            | A goods-receipt line adding an ingredient quantity to stock under a purchase order.                  |
| 14  | AuditLog           | A record of a security- or business-significant action performed in the system.                      |

---

## Entity Details

### 1. User

| #   | Attribute      | PK  | FK  | Type     | Mandatory | Description                                                |
| --- | -------------- | :-: | :-: | -------- | :-------: | ---------------------------------------------------------- |
| 1   | UserID         |  x  |     | Integer  |    Yes    | Unique identifier.                                         |
| 2   | Username       |     |     | String   |    Yes    | Login name; unique.                                        |
| 3   | PasswordHash   |     |     | String   |    Yes    | Hashed password; never stored in plain text.               |
| 4   | FullName       |     |     | String   |    Yes    | Display name of the staff member.                          |
| 5   | Role           |     |     | String   |    Yes    | Administrator / Manager / Cashier / Barista.               |
| 6   | IsActive       |     |     | Boolean  |    Yes    | Whether the account is active. Default: true.              |
| 7   | FailedAttempts |     |     | Integer  |    Yes    | Consecutive failed logins; account locks at 5. Default: 0. |
| 8   | LockedUntil    |     |     | DateTime |    No     | Time until which login is blocked; null when not locked.   |
| 9   | CreatedAt      |     |     | DateTime |    Yes    | Record creation time.                                      |
| 10  | UpdatedAt      |     |     | DateTime |    Yes    | Last modification time.                                    |

### 2. Category

| #   | Attribute  | PK  | FK  | Type    | Mandatory | Description                           |
| --- | ---------- | :-: | :-: | ------- | :-------: | ------------------------------------- |
| 1   | CategoryID |  x  |     | Integer |    Yes    | Unique identifier.                    |
| 2   | Name       |     |     | String  |    Yes    | Category name (Coffee, Tea, Pastry…). |

### 3. Product

| #   | Attribute   | PK  | FK  | Type          | Mandatory | Description                                        |
| --- | ----------- | :-: | :-: | ------------- | :-------: | -------------------------------------------------- |
| 1   | ProductID   |  x  |     | Integer       |    Yes    | Unique identifier.                                 |
| 2   | CategoryID  |     |  x  | Integer       |    Yes    | Category the product belongs to.                   |
| 3   | Name        |     |     | String        |    Yes    | Product name; max 30 characters.                   |
| 4   | Price       |     |     | Decimal(12,2) |    Yes    | Unit selling price.                                |
| 5   | Size        |     |     | String        |    No     | Available sizes, e.g. "S/M/L".                     |
| 6   | IsAvailable |     |     | Boolean       |    Yes    | Whether the product can be ordered. Default: true. |
| 7   | Description |     |     | String        |    No     | Short description shown in the menu.               |
| 8   | ImageUrl    |     |     | String        |    No     | Relative path to the product image.                |

### 4. Order

| #   | Attribute   | PK  | FK  | Type     | Mandatory | Description                                  |
| --- | ----------- | :-: | :-: | -------- | :-------: | -------------------------------------------- |
| 1   | OrderID     |  x  |     | Integer  |    Yes    | Unique identifier.                           |
| 2   | CreatedByID |     |  x  | Integer  |    Yes    | Staff member who created the order.          |
| 3   | TableID     |     |  x  | Integer  |    No     | Assigned table; null means takeaway.         |
| 4   | CustomerID  |     |  x  | Integer  |    No     | Linked loyalty customer; null for a walk-in. |
| 5   | Status      |     |     | String   |    Yes    | OPEN / PAID / CANCELLED. Default: OPEN.      |
| 6   | CreatedAt   |     |     | DateTime |    Yes    | Time the order was placed.                   |
| 7   | UpdatedAt   |     |     | DateTime |    Yes    | Last modification time.                      |

### 5. OrderItem

| #   | Attribute   | PK  | FK  | Type          | Mandatory | Description                                          |
| --- | ----------- | :-: | :-: | ------------- | :-------: | ---------------------------------------------------- |
| 1   | OrderItemID |  x  |     | Integer       |    Yes    | Unique identifier.                                   |
| 2   | OrderID     |     |  x  | Integer       |    Yes    | Parent order; deleted together with the order.       |
| 3   | ProductID   |     |  x  | Integer       |    Yes    | Product ordered.                                     |
| 4   | Quantity    |     |     | Integer       |    Yes    | Number of units; at least 1.                         |
| 5   | Options     |     |     | String        |    No     | Size, sugar level or notes, e.g. "M · Sugar 50%".    |
| 6   | LinePrice   |     |     | Decimal(12,2) |    Yes    | Quantity × unit price, recomputed from the database. |
| 7   | PrepStatus  |     |     | String        |    Yes    | PENDING / MAKING / DONE. Default: PENDING.           |

### 6. Payment

| #   | Attribute      | PK  | FK  | Type          | Mandatory | Description                                                       |
| --- | -------------- | :-: | :-: | ------------- | :-------: | ----------------------------------------------------------------- |
| 1   | PaymentID      |  x  |     | Integer       |    Yes    | Unique identifier.                                                |
| 2   | OrderID        |     |  x  | Integer       |    Yes    | Order being settled; unique, so an order has at most one payment. |
| 3   | UserID         |     |  x  | Integer       |    Yes    | Cashier who processed the payment.                                |
| 4   | CustomerID     |     |  x  | Integer       |    No     | Customer credited with the payment; null for a walk-in.           |
| 5   | Method         |     |     | String        |    Yes    | CASH / CARD / E_WALLET; one method per order.                     |
| 6   | Amount         |     |     | Decimal(12,2) |    Yes    | Amount actually paid, after all discounts.                        |
| 7   | PointsRedeemed |     |     | Integer       |    No     | Loyalty points spent on this payment. Default: 0.                 |
| 8   | PaidAt         |     |     | DateTime      |    Yes    | Time the payment completed.                                       |

### 7. Table

| #   | Attribute       | PK  | FK  | Type    | Mandatory | Description                                |
| --- | --------------- | :-: | :-: | ------- | :-------: | ------------------------------------------ |
| 1   | TableID         |  x  |     | Integer |    Yes    | Unique identifier.                         |
| 2   | Number          |     |     | Integer |    Yes    | Table number shown to staff.               |
| 3   | Capacity        |     |     | Integer |    Yes    | Number of seats.                           |
| 4   | OccupancyStatus |     |     | String  |    Yes    | FREE / OCCUPIED / RESERVED. Default: FREE. |
| 5   | Floor           |     |     | String  |    No     | Floor or zone the table is on.             |
| 6   | Shape           |     |     | String  |    No     | Table shape, used to draw the floor plan.  |

### 8. Customer

| #   | Attribute     | PK  | FK  | Type     | Mandatory | Description                                     |
| --- | ------------- | :-: | :-: | -------- | :-------: | ----------------------------------------------- |
| 1   | CustomerID    |  x  |     | Integer  |    Yes    | Unique identifier.                              |
| 2   | FullName      |     |     | String   |    Yes    | Customer name.                                  |
| 3   | Phone         |     |     | String   |    No     | Contact phone number.                           |
| 4   | Email         |     |     | String   |    No     | Contact email address.                          |
| 5   | LoyaltyPoints |     |     | Integer  |    Yes    | Current point balance. Default: 0.              |
| 6   | JoinedAt      |     |     | DateTime |    Yes    | Date the customer joined the loyalty programme. |

### 9. LoyaltyTransaction

| #   | Attribute    | PK  | FK  | Type     | Mandatory | Description                          |
| --- | ------------ | :-: | :-: | -------- | :-------: | ------------------------------------ |
| 1   | LoyaltyTxnID |  x  |     | Integer  |    Yes    | Unique identifier.                   |
| 2   | CustomerID   |     |  x  | Integer  |    Yes    | Customer whose balance changed.      |
| 3   | PaymentID    |     |  x  | Integer  |    Yes    | Payment that triggered the movement. |
| 4   | Type         |     |     | String   |    Yes    | EARN / REDEEM.                       |
| 5   | Points       |     |     | Integer  |    Yes    | Number of points earned or redeemed. |
| 6   | CreatedAt    |     |     | DateTime |    Yes    | Time the movement was recorded.      |

### 10. Ingredient

| #   | Attribute        | PK  | FK  | Type          | Mandatory | Description                                          |
| --- | ---------------- | :-: | :-: | ------------- | :-------: | ---------------------------------------------------- |
| 1   | IngredientID     |  x  |     | Integer       |    Yes    | Unique identifier.                                   |
| 2   | Name             |     |     | String        |    Yes    | Ingredient name.                                     |
| 3   | QuantityOnHand   |     |     | Decimal(12,2) |    Yes    | Current quantity in stock.                           |
| 4   | ReorderThreshold |     |     | Decimal(12,2) |    Yes    | Level at or below which a low-stock alert is raised. |

### 11. ProductIngredient

| #   | Attribute    | PK  | FK  | Type          | Mandatory | Description                                                |
| --- | ------------ | :-: | :-: | ------------- | :-------: | ---------------------------------------------------------- |
| 1   | ProductID    |  x  |  x  | Integer       |    Yes    | Product the recipe belongs to; part of the composite key.  |
| 2   | IngredientID |  x  |  x  | Integer       |    Yes    | Ingredient consumed; part of the composite key.            |
| 3   | Quantity     |     |     | Decimal(12,2) |    Yes    | Amount of the ingredient consumed per unit of the product. |

> This entity has a **composite primary key** `(ProductID, IngredientID)` and no surrogate ID, so an
> ingredient can appear at most once in a given product's recipe.

### 12. PurchaseOrder

| #   | Attribute       | PK  | FK  | Type          | Mandatory | Description                                 |
| --- | --------------- | :-: | :-: | ------------- | :-------: | ------------------------------------------- |
| 1   | PurchaseOrderID |  x  |     | Integer       |    Yes    | Unique identifier.                          |
| 2   | UserID          |     |  x  | Integer       |    Yes    | Staff member who raised the purchase order. |
| 3   | SupplierName    |     |     | String        |    Yes    | Supplier the goods were ordered from.       |
| 4   | Status          |     |     | String        |    Yes    | Processing status of the purchase order.    |
| 5   | TotalAmount     |     |     | Decimal(12,2) |    Yes    | Total value of the purchase order.          |
| 6   | CreatedAt       |     |     | DateTime      |    Yes    | Time the purchase order was raised.         |

### 13. StockIn

| #   | Attribute       | PK  | FK  | Type          | Mandatory | Description                                         |
| --- | --------------- | :-: | :-: | ------------- | :-------: | --------------------------------------------------- |
| 1   | StockInID       |  x  |     | Integer       |    Yes    | Unique identifier.                                  |
| 2   | PurchaseOrderID |     |  x  | Integer       |    Yes    | Purchase order this receipt line belongs to.        |
| 3   | IngredientID    |     |  x  | Integer       |    Yes    | Ingredient received into stock.                     |
| 4   | Quantity        |     |     | Decimal(12,2) |    Yes    | Quantity received; added to the ingredient's stock. |
| 5   | UnitCost        |     |     | Decimal(12,2) |    Yes    | Purchase cost per unit.                             |
| 6   | ReceivedAt      |     |     | DateTime      |    Yes    | Time the goods were received.                       |

### 14. AuditLog

| #   | Attribute  | PK  | FK  | Type     | Mandatory | Description                                       |
| --- | ---------- | :-: | :-: | -------- | :-------: | ------------------------------------------------- |
| 1   | AuditLogID |  x  |     | Integer  |    Yes    | Unique identifier.                                |
| 2   | UserID     |     |     | Integer  |    No     | Acting user; a snapshot value, not a foreign key. |
| 3   | Username   |     |     | String   |    No     | Username at the time of the action.               |
| 4   | Action     |     |     | String   |    Yes    | Action performed, e.g. LOGIN, PROCESS_PAYMENT.    |
| 5   | Details    |     |     | String   |    Yes    | Additional context, stored as JSON.               |
| 6   | IpAddress  |     |     | String   |    No     | Client IP address the request came from.          |
| 7   | CreatedAt  |     |     | DateTime |    Yes    | Time the action was recorded.                     |

> `UserID` and `Username` are deliberately **not** foreign keys: the log must survive deletion of the
> user account it refers to.

---

## Notes for the document author

- **Enum columns** (Role, Status, PrepStatus, Method, OccupancyStatus, Type) are stored as
  PostgreSQL enum types. They are written as `String` above because that is how they are usually
  presented in an SRS; the allowed values are listed in each Description cell.
- **Money and quantities** use `Decimal(12,2)` to avoid floating-point rounding errors.
- Two entities are **not** part of the original SRS ERD and were added during implementation:
  `ProductIngredient` (required for automatic stock deduction) and `AuditLog` (required for audit
  logging). Both are present from the initial database migration.
