// ignore_for_file: depend_on_referenced_packages, avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_app/utils/constants.dart';

void main() {
  test('Supabase Profile Insert Test', () async {
    // Initialize Supabase
    final supabase = SupabaseClient(
      Constants.supabaseUrl, 
      Constants.supabaseAnonKey
    );

    try {
      final updates = await supabase.from('updates').select('*').limit(1);
      if (updates.isNotEmpty) {
        print('UPDATES COLUMNS: ${updates.first.keys}');
        print('SAMPLE UPDATE: ${updates.first}');
      } else {
        print('Updates table is empty.');
      }
    } catch (e) {
      print('Error querying updates: $e');
    }
  });
}


