import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
// Mở route cho khách chưa đăng nhập (vd: Login).
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
