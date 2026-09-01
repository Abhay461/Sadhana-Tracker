const fs = require('fs');
try {
  fs.copyFileSync(
    "C:\\Users\\LENOVO\\.gemini\\antigravity-ide\\brain\\bfec33b3-1019-4f00-bbc5-a1be059f9f52\\media__1779885401188.jpg",
    "d:\\work update app\\mobile_app\\assets\\logo.jpg"
  );
  console.log("Success");
} catch (e) {
  console.error("Error", e);
}
