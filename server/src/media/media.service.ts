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

  async deleteCloudinaryImage(url: string) {
    if (!url || typeof url !== 'string' || !url.includes('cloudinary.com')) return;
    try {
      const cloudName = this.configService.get<string>('cloudinary.cloudName') || 'dxm9zgkv2';
      const apiKey = this.configService.get<string>('cloudinary.apiKey');
      const apiSecret = this.configService.get<string>('cloudinary.apiSecret');

      const parts = url.split('/upload/');
      if (parts.length < 2) return;
      let publicIdWithVersion = parts[1].replace(/^v\d+\//, '');
      const publicId = publicIdWithVersion.substring(0, publicIdWithVersion.lastIndexOf('.'));
      if (!publicId) return;

      if (apiKey && apiSecret) {
        const timestamp = Math.floor(Date.now() / 1000);
        const signatureStr = `public_id=${publicId}&timestamp=${timestamp}${apiSecret}`;
        const signature = crypto.createHash('sha1').update(signatureStr).digest('hex');

        const formData = new URLSearchParams();
        formData.append('public_id', publicId);
        formData.append('api_key', apiKey);
        formData.append('timestamp', timestamp.toString());
        formData.append('signature', signature);

        await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`, {
          method: 'POST',
          body: formData,
        });
        this.logger.log(`Successfully deleted Cloudinary image: ${publicId}`);
      }
    } catch (err) {
      this.logger.error(`Failed to delete Cloudinary image: ${err}`);
    }
  }
}
