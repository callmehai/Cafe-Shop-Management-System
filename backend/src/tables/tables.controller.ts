import { Controller } from '@nestjs/common';
import { TablesService } from './tables.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Roles(Role.MANAGER, Role.ADMINISTRATOR)
@Controller('tables')
export class TablesController {
  constructor(private readonly tables: TablesService) {}
}
