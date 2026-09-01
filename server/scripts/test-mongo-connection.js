const mongoose = require('mongoose');

const uri = "mongodb+srv://abhaykumarsalempur8521_db_user:Abhay8521@cluster0.n2za0u5.mongodb.net/sadhana_tracker?retryWrites=true&w=majority&appName=Cluster0";

async function testConnection() {
  console.log('Testing MongoDB Atlas connection...');
  try {
    await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
    console.log('✅ MongoDB Atlas connection SUCCESSFUL!');
    console.log(`Connected to database: ${mongoose.connection.name}`);
    await mongoose.disconnect();
  } catch (error) {
    console.error('❌ MongoDB Atlas connection FAILED:', error.message);
  }
}

testConnection();
