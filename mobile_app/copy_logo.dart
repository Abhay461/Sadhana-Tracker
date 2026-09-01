import 'dart:io';
void main() {
  try {
    File('C:\\Users\\LENOVO\\.gemini\\antigravity-ide\\brain\\bfec33b3-1019-4f00-bbc5-a1be059f9f52\\media__1779885401188.jpg')
      .copySync('d:\\work update app\\mobile_app\\assets\\logo.jpg');
    stdout.writeln('Success');
  } catch (e) {
    stderr.writeln('Error: $e');
  }
}
