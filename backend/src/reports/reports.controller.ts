import { Controller, Get, Header, Query } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  // Dashboard mở cho mọi role đã đăng nhập (home theo role).
  @Get('dashboard')
  dashboard() {
    return this.reports.dashboard();
  }

  // UC21 Export Report (CSV) — khai báo trước 'sales' cho rõ ràng.
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Get('sales/export')
  @Header('Content-Type', 'text/csv; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="sales-report.csv"')
  export(@Query('from') from?: string, @Query('to') to?: string) {
    return this.reports.salesCsv(from, to);
  }

  // Sales report chỉ Manager/Admin (UC20).
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Get('sales')
  sales(@Query('from') from?: string, @Query('to') to?: string) {
    return this.reports.sales(from, to);
  }
}
