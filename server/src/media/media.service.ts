import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);

  constructor(private readonly configService: ConfigService) {}

  generateUploadSignature(folder = 'sadhana_app') {
    const cloudName = this.configService.get<string>('cloudinary.cloudName');
    const apiKey = this.configService.get<string>('cloudinary.apiKey');
    const apiSecret = this.configService.get<string>('cloudinary.apiSecret');

    if (!apiKey || !apiSecret) {
      // In development fallback, return cloudName with unsigned preset notice
      return {
        cloudName,
        apiKey: apiKey || 'CLIENT_CONFIGURED',
        signature: null,
        timestamp: Math.floor(Date.now() / 1000),
        folder,
        uploadUrl: `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
      };
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const paramsToSign = `folder=${folder}&timestamp=${timestamp}${apiSecret}`;
    
    const signature = crypto.createHash('sha1').update(paramsToSign).digest('hex');

    return {
      cloudName,
      apiKey,
      signature,
      timestamp,
      folder,
      uploadUrl: `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
    };
  }
}
