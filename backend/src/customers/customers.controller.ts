import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { CreateCustomerDto, UpdateCustomerDto } from './dto/customer.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { AuditAction } from '../audit-log/audit.decorator';

@Controller('customers')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  // Đọc: mọi role đã đăng nhập (cashier gắn loyalty khi thanh toán).
  @Get()
  list(@Query('search') search?: string) {
    return this.customers.list(search);
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.customers.findOne(id);
  }

  // Ghi: Manager/Admin.
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post()
  @AuditAction('CREATE_CUSTOMER')
  create(@Body() dto: CreateCustomerDto) {
    return this.customers.create(dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Patch(':id')
  @AuditAction('UPDATE_CUSTOMER')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateCustomerDto) {
    return this.customers.update(id, dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Delete(':id')
  @AuditAction('DELETE_CUSTOMER')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.customers.remove(id);
  }
}
