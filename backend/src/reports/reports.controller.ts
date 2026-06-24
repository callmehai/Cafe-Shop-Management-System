import { Controller } from '@nestjs/common';
import { ReportsService } from './reports.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Roles(Role.MANAGER, Role.ADMINISTRATOR)
@Controller('reports')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}
  // TODO GET /reports/sales?from=&to= ; GET /reports/sales/export
}
