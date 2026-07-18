import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post } from '@nestjs/common';
import { TablesService } from './tables.service';
import { CreateTableDto } from './dto/create-table.dto';
import { UpdateTableDto } from './dto/update-table.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { AuditAction } from '../audit-log/audit.decorator';

@Controller('tables')
export class TablesController {
  constructor(private readonly tables: TablesService) {}

  // Đọc: mọi role đã đăng nhập (cashier chọn bàn khi tạo order).
  @Get()
  list() {
    return this.tables.list();
  }

  // Ghi: chỉ Manager/Admin quản lý sơ đồ bàn.
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post()
  @AuditAction('CREATE_TABLE')
  create(@Body() dto: CreateTableDto) {
    return this.tables.create(dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR, Role.CASHIER)
  @Patch(':id')
  @AuditAction('UPDATE_TABLE')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateTableDto) {
    return this.tables.update(id, dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Delete(':id')
  @AuditAction('DELETE_TABLE')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.tables.remove(id);
  }
}
