import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
} from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { User, UserDocument } from '../../database/schemas/users.schema';

@Injectable()
export class OwnershipGuard implements CanActivate {
  constructor(@InjectModel(User.name) private readonly userModel: Model<UserDocument>) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const currentUser = request.mongoUser;

    if (!currentUser) {
      throw new ForbiddenException('User context missing for ownership validation.');
    }

    // Admins bypass ownership restrictions
    if (currentUser.role === 'admin') {
      return true;
    }

    // Extract target userId from query parameters or body or route params
    const targetUserId = request.params.userId || request.params.id || request.body.userId;

    if (!targetUserId) {
      return true; // No explicit target specified, default controller authorization handles it
    }

    const targetUserIdStr = targetUserId.toString();
    const currentUserIdStr = currentUser._id.toString();

    // 1. Students can only access their own data
    if (currentUser.role === 'folk_boy' || currentUser.role === 'residency') {
      if (targetUserIdStr !== currentUserIdStr) {
        throw new ForbiddenException('Access denied: You can only view or modify your own records.');
      }
      return true;
    }

    // 2. Preachers can access their assigned students or themselves
    if (currentUser.role === 'preacher') {
      if (targetUserIdStr === currentUserIdStr) {
        return true;
      }

      const targetStudent = await this.userModel.findById(targetUserIdStr);
      if (!targetStudent) {
        throw new ForbiddenException('Target user record not found.');
      }

      const assignedPreacherIdStr = targetStudent.preacherId?.toString();
      if (assignedPreacherIdStr !== currentUserIdStr) {
        throw new ForbiddenException('Access denied: This student is not assigned to your group.');
      }
      return true;
    }

    return true;
  }
}
