import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResidencyPdfHelper {
  static Future<void> generateAndSharePdf(Map<String, dynamic> data) async {
    try {
      final doc = pw.Document();

      // Extracted nested items safely
      final personal = data['personal'] as Map<String, dynamic>? ?? {};
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final emergency = data['emergency'] as Map<String, dynamic>? ?? {};
      final academic = data['academic'] as List<dynamic>? ?? [];
      final training = data['training'] as List<dynamic>? ?? [];
      final employment = data['employment'] as List<dynamic>? ?? [];
      final hobbies = data['hobbies_and_activities'] as Map<String, dynamic>? ?? {};
      final spiritual = data['spiritual_assessment'] as Map<String, dynamic>? ?? {};
      final lifestyle = data['lifestyle_assessment'] as Map<String, dynamic>? ?? {};
      final medical = data['medical_history'] as Map<String, dynamic>? ?? {};
      final debts = data['debts'] as Map<String, dynamic>? ?? {};
      final criminal = data['criminal'] as Map<String, dynamic>? ?? {};
      final selfDecl = data['self_declaration'] as Map<String, dynamic>? ?? {};

      // Build styling constants
      final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.teal800,
      );
      final subtitleStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.teal600,
      );
      final sectionHeaderStyle = pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final labelStyle = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey800,
      );
      final valStyle = pw.TextStyle(
        fontSize: 9,
        color: PdfColors.grey700,
      );

      // Section wrapper
      pw.Widget buildSectionHeader(String title) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          decoration: const pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(title, style: sectionHeaderStyle),
        );
      }

      // 2-column row helper
      pw.Widget buildKeyValueRow(String key, String val, [String? key2, String? val2]) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$key: ', style: labelStyle),
                    pw.Expanded(child: pw.Text(val.isEmpty ? 'N/A' : val, style: valStyle)),
                  ],
                ),
              ),
              if (key2 != null) ...[
                pw.SizedBox(width: 12),
                pw.Expanded(
                  flex: 1,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$key2: ', style: labelStyle),
                      pw.Expanded(child: pw.Text(val2?.isEmpty ?? true ? 'N/A' : val2!, style: valStyle)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              'Yoga For Happiness Residential Program Enrolment',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
          build: (context) => [
            // Cover Title Block
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('YOGA FOR HAPPINESS RESIDENTIAL PROGRAM', style: titleStyle, textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 6),
                  pw.Text('COMPREHENSIVE RESIDENCY ENROLMENT FORM', style: subtitleStyle, textAlign: pw.TextAlign.center),
                  pw.Container(
                    margin: const pw.EdgeInsets.symmetric(vertical: 12),
                    height: 2,
                    color: PdfColors.teal700,
                  ),
                ],
              ),
            ),

            // Referrer & Joining Block
            buildKeyValueRow('Date of Joining', data['date_of_joining']?.toString() ?? ''),
            buildKeyValueRow('Referrer', data['referrer']?.toString() ?? '', 'Folk Residency Name', data['folk_residency_name']?.toString() ?? ''),

            // 1. Personal Details
            buildSectionHeader('1. Personal Details'),
            buildKeyValueRow('Full Name', personal['full_name']?.toString() ?? '', 'Mobile No', personal['mobile_no']?.toString() ?? ''),
            buildKeyValueRow('E-mail ID', personal['email']?.toString() ?? '', 'Date of Birth', personal['dob']?.toString() ?? ''),
            buildKeyValueRow('Education', personal['education']?.toString() ?? '', 'Marital Status', personal['marital_status']?.toString() ?? ''),
            buildKeyValueRow('Blood Group', personal['blood_group']?.toString() ?? '', 'College/Org', personal['org_or_college']?.toString() ?? ''),
            buildKeyValueRow('Course/Role', personal['role_or_course']?.toString() ?? ''),

            // 2. Address Details
            buildSectionHeader('2. Address Details'),
            pw.Text('Present Address:', style: labelStyle),
            pw.Text('${address['present_address'] ?? ''} - PIN: ${address['present_pin'] ?? ''}', style: valStyle),
            pw.SizedBox(height: 6),
            pw.Text('Permanent Address:', style: labelStyle),
            pw.Text('${address['permanent_address'] ?? ''} - PIN: ${address['permanent_pin'] ?? ''}', style: valStyle),

            // 3. Emergency Details
            buildSectionHeader('3. Emergency Contact Details'),
            buildKeyValueRow('Contact Person', emergency['name']?.toString() ?? '', 'Relationship', emergency['relation']?.toString() ?? ''),
            buildKeyValueRow('Mobile Phone', emergency['phone']?.toString() ?? '', 'Email ID', emergency['email']?.toString() ?? ''),
            pw.Text('Emergency Address:', style: labelStyle),
            pw.Text('${emergency['address'] ?? ''} - PIN: ${emergency['pin'] ?? ''}', style: valStyle),

            // 4. Academic Details
            if (academic.isNotEmpty) ...[
              buildSectionHeader('4. Academic Details'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Examination', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('School/College', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Board/Univ', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Year', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('CGPA/%', style: labelStyle)),
                    ],
                  ),
                  ...academic.map((ac) {
                    final item = ac as Map<String, dynamic>? ?? {};
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['examination']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['school_or_college']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['board_or_university']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['year_of_passing']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['percentage_or_cgpa']?.toString() ?? '', style: valStyle)),
                      ],
                    );
                  }),
                ],
              ),
            ],

            // 5. Training / Employment Details
            if (training.isNotEmpty) ...[
              buildSectionHeader('5. Courses & Training Details'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Course/Training', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Institution', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Duration', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Year', style: labelStyle)),
                    ],
                  ),
                  ...training.map((tr) {
                    final item = tr as Map<String, dynamic>? ?? {};
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['course_or_training']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['institution']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['duration']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['year']?.toString() ?? '', style: valStyle)),
                      ],
                    );
                  }),
                ],
              ),
            ],

            if (employment.isNotEmpty) ...[
              buildSectionHeader('6. Employment Record'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Organization', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Designation', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('From', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('To', style: labelStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Nature of Work', style: labelStyle)),
                    ],
                  ),
                  ...employment.map((em) {
                    final item = em as Map<String, dynamic>? ?? {};
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['organization']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['designation']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['duration_from']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['duration_to']?.toString() ?? '', style: valStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nature_of_work']?.toString() ?? '', style: valStyle)),
                      ],
                    );
                  }),
                ],
              ),
            ],

            // 7. Hobbies
            buildSectionHeader('7. Extra-Curricular Activities'),
            buildKeyValueRow('Hobbies', hobbies['hobbies']?.toString() ?? '', 'Memberships', hobbies['professional_memberships']?.toString() ?? ''),
            buildKeyValueRow('Publications', hobbies['publications']?.toString() ?? '', 'Honors/Awards', hobbies['honors_and_scholarships']?.toString() ?? ''),

            // 8. Spiritual Assessment
            buildSectionHeader('8. Spiritual Assessment'),
            buildKeyValueRow('Folk ID', spiritual['folk_id']?.toString() ?? '', 'Folk Guide', spiritual['folk_guide']?.toString() ?? ''),
            buildKeyValueRow('Recommended Rounds', spiritual['recommended_rounds']?.toString() ?? '', 'Chanting Rounds', spiritual['chanting_rounds']?.toString() ?? ''),
            buildKeyValueRow(
              'Chanting Period',
              '${spiritual['chanting_duration_years'] ?? '0'} yrs, ${spiritual['chanting_duration_months'] ?? '0'} months',
              'One Mala Duration',
              spiritual['chanting_one_mala_time']?.toString() ?? '',
            ),
            buildKeyValueRow('Four Principles Checked?', spiritual['know_four_principles']?.toString() == 'true' ? 'YES' : 'NO'),
            buildKeyValueRow('Heard Srila Prabhupada?', spiritual['heard_prabhupada']?.toString() ?? 'N/A', 'Reads Prabhupada Books?', spiritual['read_prabhupada_books']?.toString() ?? 'N/A'),
            if (spiritual['prabhupada_books_details']?.toString().isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('Books Details: ${spiritual['prabhupada_books_details']}', style: valStyle),
              ),

            buildKeyValueRow('Rendered Services?', spiritual['rendered_services']?.toString() ?? 'N/A'),
            if (spiritual['rendered_services_details']?.toString().isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text('Services Details: ${spiritual['rendered_services_details']}', style: valStyle),
              ),

            buildKeyValueRow('VCM Visited Source', (spiritual['vcm_source'] as List<dynamic>? ?? []).join(', ')),
            buildKeyValueRow('Visit Details', spiritual['first_visit_vcm']?.toString() ?? '', 'Visit Since Childhood?', spiritual['visit_since_childhood']?.toString() ?? 'N/A'),

            // 9. Lifestyle Assessment
            buildSectionHeader('9. Lifestyle Assessment'),
            pw.Text('Aim in Life:', style: labelStyle),
            pw.Text(lifestyle['aim_in_life']?.toString() ?? 'N/A', style: valStyle),
            pw.SizedBox(height: 4),
            pw.Text('Motivation to join Residency:', style: labelStyle),
            pw.Text(lifestyle['motivation_residency']?.toString() ?? 'N/A', style: valStyle),
            pw.SizedBox(height: 4),
            buildKeyValueRow('Parents Approved?', lifestyle['parents_approved']?.toString() ?? 'N/A', 'Will participate morning schedule?', lifestyle['will_participate_morning_schedule']?.toString() ?? 'N/A'),
            buildKeyValueRow('Wake up Time', lifestyle['wakeup_time']?.toString() ?? 'N/A', 'Office/College timings', lifestyle['office_college_timings']?.toString() ?? 'N/A'),
            buildKeyValueRow('Watch Movies Frequency', lifestyle['watch_movies_frequency']?.toString() ?? 'N/A', 'Luggage Details', lifestyle['luggage_details']?.toString() ?? 'N/A'),

            // 10. Medical History
            buildSectionHeader('10. Medical History'),
            ...medical.entries.map((entry) {
              final val = entry.value as Map<String, dynamic>? ?? {};
              if (val['has_condition'] == true) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Text('- ${entry.key.toUpperCase()}: Yes (${val['details']})', style: valStyle),
                );
              }
              return pw.SizedBox();
            }),

            // 11. Decl & Debts
            buildSectionHeader('11. Declarations & Clearances'),
            buildKeyValueRow('Any Debts/Loans?', debts['has_debts']?.toString() == 'true' ? 'YES' : 'NO'),
            if (debts['details']?.toString().isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('Debts details: ${debts['details']}', style: valStyle),
              ),

            buildKeyValueRow('Any Criminal Cases/Charges?', criminal['has_charges']?.toString() == 'true' ? 'YES' : 'NO'),
            if (criminal['details']?.toString().isNotEmpty == true)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('Criminal details: ${criminal['details']}', style: valStyle),
              ),

            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Self Declaration & Undertaking', style: labelStyle),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'I hereby declare that all the statements made in this application are true, complete and correct to the best of my knowledge and belief. I understand that in the event of any information being found false or incorrect at any stage, my residency eligibility is liable to be terminated immediately.',
                    style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                  ),
                  pw.SizedBox(height: 8),
                  buildKeyValueRow('Place', selfDecl['declaration_place']?.toString() ?? 'N/A', 'Date', selfDecl['declaration_date']?.toString() ?? 'N/A'),
                ],
              ),
            ),
          ],
        ),
      );

      // Sharing/Printing options
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Residency_Admission_Form_${personal['full_name']?.toString().replaceAll(' ', '_') ?? 'Disciple'}.pdf',
      );
    } catch (e) {
      debugPrint('Error generating residency form PDF: $e');
      rethrow;
    }
  }
}
