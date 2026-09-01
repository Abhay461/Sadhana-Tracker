// Script to set admin role for a user
const { MongoClient } = require('mongodb');

const uri = 'mongodb+srv://abhaykumarsalempur8521_db_user:Abhay8521@cluster0.n2za0u5.mongodb.net/sadhana_tracker?retryWrites=true&w=majority&appName=Cluster0';
const email = 'abhaykumarsalempur8521@gmail.com';

async function setAdmin() {
  const client = new MongoClient(uri);
  try {
    await client.connect();
    console.log('Connected to MongoDB Atlas');
    
    const db = client.db('sadhana_tracker');
    const users = db.collection('users');
    
    // Find user first
    const user = await users.findOne({ email: email });
    if (!user) {
      console.log(`User with email ${email} NOT FOUND in database.`);
      console.log('\nAll users in database:');
      const allUsers = await users.find({}, { projection: { email: 1, name: 1, role: 1 } }).toArray();
      allUsers.forEach(u => console.log(`  - ${u.email} | ${u.name} | role: ${u.role}`));
      return;
    }
    
    console.log(`Found user: ${user.name} | Current role: ${user.role}`);
    
    // Update role to admin
    const result = await users.updateOne(
      { email: email },
      { $set: { role: 'admin' } }
    );
    
    console.log(`Updated ${result.modifiedCount} document(s)`);
    console.log(`✅ ${email} is now ADMIN!`);
    
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.close();
  }
}

setAdmin();
