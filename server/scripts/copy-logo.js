const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'mobile_app', 'assets', 'folk_logo.png');
const dest = path.join(__dirname, '..', 'admin_portal', 'folk_logo.png');

if (fs.existsSync(src)) {
  fs.copyFileSync(src, dest);
  console.log('Successfully copied folk_logo.png to admin_portal');
} else {
  console.error('Source logo file not found:', src);
}
