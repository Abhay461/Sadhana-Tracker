const { MongoClient } = require('mongodb');

const uri = 'mongodb+srv://abhaykumarsalempur8521_db_user:Abhay8521@cluster0.n2za0u5.mongodb.net/sadhana_tracker?retryWrites=true&w=majority&appName=Cluster0';
const email = 'abhaykumarsalempur8521@gmail.com';
const firebaseUid = 'evAA9a1Oq8QMBiGPExkm8766hqw2';

async function linkFirebaseUid() {
  const client = new MongoClient(uri);
  try {
    await client.connect();
    console.log('Connected to MongoDB Atlas');
    
    const db = client.db('sadhana_tracker');
    const users = db.collection('users');
    
    // Find user by email
    const user = await users.findOne({ email: email });
    if (!user) {
      console.log(`User with email ${email} NOT FOUND in database.`);
      console.log('\nSearching all users...');
      const allUsers = await users.find({}, { projection: { name: 1, email: 1, firebaseUid: 1, role: 1, status: 1 } }).limit(10).toArray();
      console.log('First 10 users:', JSON.stringify(allUsers, null, 2));
      return;
    }
    
    console.log('Found user:', JSON.stringify({ _id: user._id, name: user.name, email: user.email, role: user.role, status: user.status, firebaseUid: user.firebaseUid }, null, 2));
    
    // Update firebaseUid
    const result = await users.updateOne(
      { _id: user._id },
      { $set: { firebaseUid: firebaseUid, status: 'ACTIVE' } }
    );
    
    console.log(`\nUpdate result: ${result.modifiedCount} document(s) modified`);
    console.log(`User ${email} linked to Firebase UID: ${firebaseUid} and status set to ACTIVE`);
    
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await client.close();
    console.log('Connection closed.');
  }
}

linkFirebaseUid();
