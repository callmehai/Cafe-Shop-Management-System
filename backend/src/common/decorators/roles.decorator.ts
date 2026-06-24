import { SetMetadata } from '@nestjs/common';
import { Role } from '../enums/role.enum';

export const ROLES_KEY = 'roles';
// CR-07: chỉ role được liệt kê mới truy cập (theo ma trận §4 context).
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
