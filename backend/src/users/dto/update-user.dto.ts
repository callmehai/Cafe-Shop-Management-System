import { PartialType } from '@nestjs/mapped-types';
import { CreateUserDto } from './create-user.dto';

// Cho phép cập nhật từng phần (UC03 Edit User). Password optional khi edit.
export class UpdateUserDto extends PartialType(CreateUserDto) {}
