import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  // TODO UC10 Process Payment (giao dịch atomic - dùng prisma.$transaction):
  //   1. Validate order OPEN & có item (BR-01).
  //   2. Discount <= 50% subtotal, nếu vượt cần Manager duyệt (BR-06).
  //   3. amount = subtotal - discount (BR-02). Một phương thức duy nhất (BR-03).
  //   4. Nếu Card/E-Wallet: gọi Payment Gateway (REST/HTTPS) -> authorization result.
  //   5. Tạo Payment, set order PAID (BR-07 -> sau đó không sửa order).
  //   6. BR-08: trừ Ingredient.quantityOnHand theo ProductIngredient * quantity.
  //   7. Loyalty (BR-11): EARN khi hoàn tất; REDEEM <= customer.loyaltyPoints. Cần chốt tỷ lệ quy đổi.
  //   8. Low-stock alert nếu chạm reorderThreshold; in receipt (MSG04).
}
