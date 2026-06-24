import { Controller } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@Roles(Role.CASHIER)
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}
  // TODO POST /payments  (process payment)
}
