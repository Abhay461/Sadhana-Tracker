import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import * as fs from 'fs';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private firebaseApp: admin.app.App;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    if (admin.apps.length > 0) {
      this.firebaseApp = admin.apps[0]!;
      return;
    }

    try {
      const base64Creds = this.configService.get<string>('firebase.credentialsBase64');
      const credsPath = this.configService.get<string>('firebase.credentialsPath');

      let serviceAccount: admin.ServiceAccount | null = null;

      if (base64Creds && base64Creds.trim().length > 0) {
        const decoded = Buffer.from(base64Creds.trim(), 'base64').toString('utf8');
        serviceAccount = JSON.parse(decoded);
        this.logger.log('Firebase Admin SDK initialized using Base64 credentials.');
      } else if (credsPath && fs.existsSync(credsPath)) {
        const fileContent = fs.readFileSync(credsPath, 'utf8');
        serviceAccount = JSON.parse(fileContent);
        this.logger.log(`Firebase Admin SDK initialized using file: ${credsPath}`);
      }

      if (serviceAccount) {
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      } else {
        // Fallback for development/testing if application default credentials exist
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.applicationDefault(),
        });
        this.logger.log('Firebase Admin SDK initialized using Application Default Credentials.');
      }
    } catch (error) {
      this.logger.error('Failed to initialize Firebase Admin SDK:', error);
      // In dev mode, initialize with dummy credentials to allow server startup if needed
      if (this.configService.get<string>('nodeEnv') === 'development') {
        this.logger.warn('DEVELOPMENT WARNING: Operating Firebase Admin SDK in fallback state.');
      }
    }
  }

  getAuth(): admin.auth.Auth {
    return admin.auth(this.firebaseApp);
  }

  getMessaging(): admin.messaging.Messaging {
    return admin.messaging(this.firebaseApp);
  }

  async verifyIdToken(token: string): Promise<admin.auth.DecodedIdToken> {
    return this.getAuth().verifyIdToken(token);
  }
}
