import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  // UC10 Login. MSG09 nếu sai. TODO BR-10: khóa 15' sau 5 lần sai liên tiếp.
  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { username: dto.username } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Incorrect user name or password. Please check again.');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Incorrect user name or password. Please check again.');
    }
    const token = await this.jwt.signAsync({
      sub: user.id,
      username: user.username,
      role: user.role,
    });
    return {
      accessToken: token,
      user: { id: user.id, username: user.username, fullName: user.fullName, role: user.role },
    };
  }
}
