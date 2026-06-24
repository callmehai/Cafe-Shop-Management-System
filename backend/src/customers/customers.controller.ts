import { Controller } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Roles(Role.MANAGER, Role.ADMINISTRATOR)
@Controller('customers')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}
  // TODO routes CRUD
}
