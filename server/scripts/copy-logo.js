const fs = require('fs');
const path = require('path');

const possibleSrcs = [
  path.join(__dirname, '..', '..', 'assets', 'folk_logo.png'),
  path.join(__dirname, '..', '..', 'mobile_app', 'assets', 'folk_logo.png'),
  path.join(__dirname, '..', 'assets', 'folk_logo.png'),
];

const dest = path.join(__dirname, '..', 'admin_portal', 'folk_logo.png');

let copied = false;
for (const src of possibleSrcs) {
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, dest);
    console.log(`Successfully copied ${src} to admin_portal`);
    copied = true;
    break;
  }
}

if (!copied) {
  console.error('Source logo file not found in any expected location');
}

