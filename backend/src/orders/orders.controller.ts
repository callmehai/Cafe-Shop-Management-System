import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { OrdersService } from './orders.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { UpdateOrderDto } from './dto/update-order.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { CurrentUser, AuthUser } from '../common/decorators/current-user.decorator';

// §4: Create/Update/Cancel -> Cashier (+ Manager/Admin). Queue -> mọi role đã đăng nhập.
const WRITE_ROLES = [Role.CASHIER, Role.MANAGER, Role.ADMINISTRATOR] as const;

@Controller('orders')
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  // Khai báo TRƯỚC ':id' để '/orders/queue' không bị bắt như id.
  @Get('queue')
  queue() {
    return this.orders.queue();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.orders.findOne(id);
  }

  @Roles(...WRITE_ROLES)
  @Post()
  create(@Body() dto: CreateOrderDto, @CurrentUser() user: AuthUser) {
    return this.orders.create(dto, user.userId);
  }

  @Roles(...WRITE_ROLES)
  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateOrderDto) {
    return this.orders.update(id, dto);
  }

  @Roles(...WRITE_ROLES)
  @Delete(':id')
  cancel(@Param('id', ParseIntPipe) id: number) {
    return this.orders.cancel(id);
  }
}
