import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class OrdersService {
  constructor(private prisma: PrismaService) {}

  // TODO UC06 Create Order: BR-01 (>=1 item), BR-04 (product available), gán table/takeaway.
  //   linePrice = product.price * quantity; tính total = sum(linePrice) - discount (BR-02).
  // TODO UC07 Update Order: chỉ khi status=OPEN (BR-07).
  // TODO UC08 Cancel Order: status=OPEN -> CANCELLED, cần confirm (CR-09).
  // TODO UC09 Assign Table.
  // TODO UC11 View Order Queue: list OPEN orders + prep status.
  // TODO UC12 Update Item Prep Status (Barista).
}
