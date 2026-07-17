import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, UseInterceptors, UploadedFile, BadRequestException } from '@nestjs/common';
import { MenuService } from './menu.service';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';
import { FileInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';

@Controller('products')
export class ProductsController {
  constructor(private readonly menu: MenuService) {}

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: diskStorage({
        destination: './uploads',
        filename: (req, file, callback) => {
          const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
          callback(null, `${uniqueSuffix}${extname(file.originalname)}`);
        },
      }),
      fileFilter: (req, file, callback) => {
        if (!file.mimetype.match(/\/(jpg|jpeg|png|gif)$/)) {
          return callback(new Error('Only image files are allowed!'), false);
        }
        callback(null, true);
      },
    }),
  )
  uploadFile(@UploadedFile() file: any) {
    if (!file) {
      throw new BadRequestException('No file uploaded or file is not an image.');
    }
    return {
      url: `/uploads/${file.filename}`,
    };
  }

  // Đọc: mọi role đã đăng nhập (cashier tạo order cần xem). Không gắn @Roles.
  @Get()
  list(@Query('search') search?: string) {
    return this.menu.listProducts(search);
  }

  // Ghi: chỉ Manager/Admin (BR-05).
  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Post()
  create(@Body() dto: CreateProductDto) {
    return this.menu.createProduct(dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateProductDto) {
    return this.menu.updateProduct(id, dto);
  }

  @Roles(Role.MANAGER, Role.ADMINISTRATOR)
  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.menu.deleteProduct(id);
  }
}
