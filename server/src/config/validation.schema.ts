import { config } from 'dotenv';
config();

export function validateEnvironment() {
  const port = process.env.PORT || '3000';
  const mongodbUri = process.env.MONGODB_URI;

  if (process.env.NODE_ENV === 'production' && !mongodbUri) {
    throw new Error('FATAL CONFIG ERROR: MONGODB_URI environment variable is required in production.');
  }

  return {
    PORT: parseInt(port, 10),
    NODE_ENV: process.env.NODE_ENV || 'development',
    MONGODB_URI: mongodbUri || 'mongodb://localhost:27017/sadhana_tracker',
  };
}
