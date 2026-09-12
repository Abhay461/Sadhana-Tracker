import 'dart:io';

void main() {
  try {
    final sourcePath = r'C:\Users\LENOVO\.gemini\antigravity-ide\brain\a1f70f4f-b3fa-4396-93cf-9341234f786e\media__1788678205664.png';
    final targetPath = r'd:\work update app\mobile_app\assets\folk_logo.png';
    File(sourcePath).copySync(targetPath);
    stdout.writeln('Successfully copied folk logo to assets/folk_logo.png');
  } catch (e) {
    stderr.writeln('Error copying logo: $e');
  }
}
