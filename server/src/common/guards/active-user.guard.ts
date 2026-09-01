import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/users.schema';

@Injectable()
export class ActiveUserGuard implements CanActivate {
  constructor(@InjectModel(User.name) private readonly userModel: Model<UserDocument>) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const firebaseUser = request.firebaseUser;

    if (!firebaseUser || !firebaseUser.uid) {
      throw new UnauthorizedException('Authentication required before checking active status.');
    }

    const mongoUser = await this.userModel.findOne({ firebaseUid: firebaseUser.uid });

    if (!mongoUser) {
      // User is authenticated via Firebase but profile not synced in MongoDB yet
      request.mongoUser = null;
      return true; // Allow /auth/sync endpoint to process registration
    }

    if (mongoUser.isBlocked || mongoUser.status === 'BLOCKED') {
      throw new ForbiddenException({
        statusCode: 403,
        errorCode: 'ACCOUNT_BLOCKED',
        message: 'Your account has been blocked by an administrator.',
      });
    }

    if (mongoUser.status === 'DEACTIVATED') {
      throw new ForbiddenException({
        statusCode: 403,
        errorCode: 'ACCOUNT_DEACTIVATED',
        message: 'Your account has been deactivated.',
      });
    }

    request.mongoUser = mongoUser;
    return true;
  }
}
