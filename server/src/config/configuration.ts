export default () => ({
  port: parseInt(process.env.PORT, 10) || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  apiPrefix: process.env.API_PREFIX || 'api/v1',
  mongodb: {
    uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/sadhana_tracker',
  },
  firebase: {
    credentialsBase64: process.env.FIREBASE_CREDENTIALS_BASE64 || '',
    credentialsPath: process.env.FIREBASE_CREDENTIALS_PATH || '',
  },
  cors: {
    origins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['*'],
  },
  throttler: {
    ttl: parseInt(process.env.THROTTLE_TTL, 10) || 60000,
    limit: parseInt(process.env.THROTTLE_LIMIT, 10) || 60,
  },
  cloudinary: {
    cloudName: process.env.CLOUDINARY_CLOUD_NAME || 'dxm9zgkv2',
    apiKey: process.env.CLOUDINARY_API_KEY || '',
    apiSecret: process.env.CLOUDINARY_API_SECRET || '',
  },
  resend: {
    apiKey: process.env.RESEND_API_KEY || '',
    fromEmail: process.env.RESEND_FROM_EMAIL || process.env.EMAIL_FROM || process.env.SENDER_EMAIL || '',
  },
});
