import { Controller } from '@nestjs/common';
import { OrdersService } from './orders.service';

// §4: Create/Update/Cancel -> CASHIER; Order Queue -> Barista/Cashier/Manager; Prep status -> Barista.
@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}
  // TODO: routes theo use case 06-12.
}
