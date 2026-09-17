import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentSadhanaExcelGrid extends StatefulWidget {
  final List<dynamic> studentUpdates;
  final String studentName;

  const StudentSadhanaExcelGrid({
    super.key,
    required this.studentUpdates,
    required this.studentName,
  });

  @override
  State<StudentSadhanaExcelGrid> createState() => _StudentSadhanaExcelGridState();
}

class _StudentSadhanaExcelGridState extends State<StudentSadhanaExcelGrid> {
  String _dateSearchQuery = '';
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  // Standard activity columns definitions (Removed Other Logs and Daily Summary as requested)
  final List<Map<String, String>> _columns = const [
    {'key': 'date', 'title': '📅 Date'},
    {'key': 'wake_up', 'title': '⏰ Wake Up'},
    {'key': 'mangla_arti', 'title': '🌸 Mangala Arti'},
    {'key': 'chanting', 'title': '📿 Chanting'},
    {'key': 'reading', 'title': '📖 Book Reading'},
    {'key': 'class', 'title': '💻 Session / Class'},
    {'key': 'service', 'title': '🏛️ Temple / Service'},
    {'key': 'sleep', 'title': '🌙 Sleep Time'},
    {'key': 'screen_time', 'title': '📱 Screen Time'},
  ];

  /// Extract date string reliably from a log item
  String _getLogDate(Map<String, dynamic> u) {
    final raw = (u['dateString'] ?? u['date'] ?? u['created_at'] ?? u['createdAt'] ?? u['timestamp'] ?? u['date_string'] ?? u['updated_at'] ?? u['updatedAt'] ?? '').toString().trim();
    if (raw.isEmpty) return '';

    // If ISO timestamp like 2026-09-17T12:00:00.000Z
    if (raw.contains('T')) {
      final parts = raw.split('T');
      if (parts[0].isNotEmpty) return parts[0].trim();
    }

    // If datetime with space like 2026-09-17 12:00:00
    if (raw.contains(' ')) {
      final parts = raw.split(' ');
      if (parts[0].isNotEmpty && parts[0].contains('-')) return parts[0].trim();
    }

    return raw;
  }

  /// Parse DateTime cleanly
  DateTime? _tryParseDate(String str) {
    if (str.isEmpty) return null;
    try {
      return DateTime.parse(str);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yyyy').parse(str);
    } catch (_) {}
    try {
      return DateFormat('dd-MM-yyyy').parse(str);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd').parse(str);
    } catch (_) {}
    return null;
  }

  /// Format date string nicely for header and cells
  String _formatDateHeader(String str) {
    final dt = _tryParseDate(str);
    if (dt != null) {
      return DateFormat('dd MMM yyyy (EEE)').format(dt);
    }
    return str;
  }

  /// Normalize and extract unique dates from updates list
  List<String> _getSortedUniqueDates() {
    final Set<String> dateSet = {};
    for (var u in widget.studentUpdates) {
      if (u is Map<String, dynamic>) {
        final d = _getLogDate(u);
        if (d.isNotEmpty) {
          dateSet.add(d);
        }
      }
    }

    final dates = dateSet.toList();
    // Sort dates in descending order (newest date first)
    dates.sort((a, b) {
      DateTime? parseA = _tryParseDate(a);
      DateTime? parseB = _tryParseDate(b);
      if (parseA != null && parseB != null) {
        return parseB.compareTo(parseA);
      }
      return b.compareTo(a);
    });

    if (_dateSearchQuery.isEmpty) return dates;

    return dates.where((dateStr) {
      final formatted = _formatDateHeader(dateStr).toLowerCase();
      return dateStr.toLowerCase().contains(_dateSearchQuery.toLowerCase()) ||
          formatted.contains(_dateSearchQuery.toLowerCase());
    }).toList();
  }

  /// Parse raw activity object/value into clean text
  String? _parseActivityValue(dynamic obj, String columnKey) {
    if (obj == null) return null;

    if (obj is Map) {
      if (columnKey == 'reading') {
        final rTime = (obj['readingTime'] ?? obj['time'] ?? obj['duration'] ?? obj['readTime'] ?? obj['pages'] ?? '').toString().trim();
        final bName = (obj['bookName'] ?? obj['book'] ?? obj['name'] ?? '').toString().trim();
        if (rTime.isNotEmpty && rTime != '0' && rTime != '0 mins' && rTime != 'null') return rTime;
        if (bName.isNotEmpty && bName != 'null') return bName;
        if (obj['attended'] == true || obj['read'] == true) return 'Read';
        return null;
      }

      if (columnKey == 'class') {
        if (obj['attended'] == false) return null;
        final sName = (obj['sessionName'] ?? obj['topic'] ?? obj['title'] ?? obj['name'] ?? obj['className'] ?? '').toString().trim();
        final sTime = (obj['time'] ?? obj['duration'] ?? '').toString().trim();
        if (sName.isNotEmpty && sName != 'null') return sName;
        if (sTime.isNotEmpty && sTime != 'null') return sTime;
        if (obj['attended'] == true) return 'Attended';
        return null;
      }

      if (columnKey == 'service') {
        if (obj['attended'] == false) return null;
        final sName = (obj['serviceName'] ?? obj['name'] ?? obj['title'] ?? obj['service'] ?? '').toString().trim();
        final sTime = (obj['duration'] ?? obj['time'] ?? '').toString().trim();
        if (sName.isNotEmpty && sName != 'null') return sName;
        if (sTime.isNotEmpty && sTime != 'null') return sTime;
        if (obj['attended'] == true || obj['done'] == true) return 'Done';
        return null;
      }

      if (columnKey == 'mangla_arti') {
        if (obj['attended'] == false) return null;
        final aTime = (obj['time'] ?? obj['manglaTime'] ?? '').toString().trim();
        if (aTime.isNotEmpty && aTime != 'null') return aTime;
        if (obj['attended'] == true) return 'Attended';
        return null;
      }

      if (columnKey == 'chanting') {
        final rounds = (obj['rounds'] ?? obj['count'] ?? obj['japa'] ?? '').toString().trim();
        if (rounds.isNotEmpty && rounds != '0' && rounds != 'null') return '$rounds rounds';
        if (obj['completed'] == true) return 'Done';
        return null;
      }

      if (columnKey == 'wake_up') {
        final wTime = (obj['time'] ?? obj['wakeUpTime'] ?? obj['value'] ?? '').toString().trim();
        if (wTime.isNotEmpty && wTime != 'null') return wTime;
        return null;
      }

      if (columnKey == 'sleep') {
        final sTime = (obj['time'] ?? obj['sleepTime'] ?? obj['value'] ?? '').toString().trim();
        if (sTime.isNotEmpty && sTime != 'null') return sTime;
        return null;
      }

      // Fallback map inspection
      if (obj['time'] != null && obj['time'].toString().isNotEmpty && obj['time'] != 'null') return obj['time'].toString();
      if (obj['name'] != null && obj['name'].toString().isNotEmpty && obj['name'] != 'null') return obj['name'].toString();
      if (obj['title'] != null && obj['title'].toString().isNotEmpty && obj['title'] != 'null') return obj['title'].toString();
      if (obj['value'] != null && obj['value'].toString().isNotEmpty && obj['value'] != 'null') return obj['value'].toString();

      return null;
    }

    final str = obj.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'false' || str == '0') return null;
    if (str == 'true') return 'Done';

    if (columnKey == 'chanting' && !str.contains('round')) {
      return '$str rounds';
    }

    return str;
  }

  /// Extract display value for a specific column key from a log item
  String? _getDisplayValueFromLog(Map<String, dynamic> u, String columnKey) {
    final cat = (u['category'] ?? '').toString().toLowerCase();
    final act = (u['work_started'] ?? u['activity'] ?? u['title'] ?? u['name'] ?? '').toString().toLowerCase();
    final desc = (u['description'] ?? u['work_completed'] ?? u['notes'] ?? '').toString().toLowerCase();
    final directVal = (u['work_completed'] ?? u['value'] ?? u['rounds'] ?? u['duration'] ?? u['time'] ?? '').toString().trim();

    final dynamic rawActs = u['activities'];
    final Map<String, dynamic> acts = rawActs is Map ? Map<String, dynamic>.from(rawActs) : {};

    if (columnKey == 'screen_time') {
      if (cat == 'screen_time' || act.contains('screen') || desc.contains('screen')) {
        return directVal.isNotEmpty ? directVal : 'Synced';
      }
    } else if (columnKey == 'wake_up') {
      if (acts['wakeUpTime'] != null) return _parseActivityValue(acts['wakeUpTime'], columnKey);
      if (acts['wakeUp'] != null) return _parseActivityValue(acts['wakeUp'], columnKey);
      if (cat == 'wake_up' || act.contains('wake') || act.contains('morning') || act.contains('utha')) {
        return directVal.isNotEmpty ? directVal : 'Logged';
      }
    } else if (columnKey == 'mangla_arti') {
      if (acts['manglaArti'] != null) return _parseActivityValue(acts['manglaArti'], columnKey);
      if (acts['mangalaArti'] != null) return _parseActivityValue(acts['mangalaArti'], columnKey);
      if (cat == 'mangla_arti' || act.contains('mangla') || act.contains('arti') || act.contains('aarti')) {
        return directVal.isNotEmpty ? directVal : 'Attended';
      }
    } else if (columnKey == 'chanting') {
      if (acts['chanting'] != null) return _parseActivityValue(acts['chanting'], columnKey);
      if (acts['japa'] != null) return _parseActivityValue(acts['japa'], columnKey);
      if (acts['rounds'] != null) return _parseActivityValue(acts['rounds'], columnKey);
      if (cat == 'chanting' || act.contains('chant') || act.contains('japa') || act.contains('round')) {
        return _parseActivityValue(directVal.isNotEmpty ? directVal : 'Done', columnKey);
      }
    } else if (columnKey == 'reading') {
      if (acts['reading'] != null) return _parseActivityValue(acts['reading'], columnKey);
      if (acts['bookReading'] != null) return _parseActivityValue(acts['bookReading'], columnKey);
      if (cat == 'reading' || act.contains('read') || act.contains('book') || act.contains('path')) {
        return directVal.isNotEmpty ? directVal : 'Logged';
      }
    } else if (columnKey == 'class') {
      if (acts['class'] != null) return _parseActivityValue(acts['class'], columnKey);
      if (acts['onlineSession'] != null) return _parseActivityValue(acts['onlineSession'], columnKey);
      if (acts['session'] != null) return _parseActivityValue(acts['session'], columnKey);
      if (cat == 'class' || cat == 'online_session' || act.contains('session') || act.contains('class') || act.contains('sb') || act.contains('bg') || act.contains('bhagavatam') || act.contains('gita') || act.contains('lecture')) {
        return directVal.isNotEmpty ? directVal : 'Attended';
      }
    } else if (columnKey == 'service') {
      if (acts['service'] != null) return _parseActivityValue(acts['service'], columnKey);
      if (acts['templeVisit'] != null) return _parseActivityValue(acts['templeVisit'], columnKey);
      if (cat == 'service' || act.contains('service') || act.contains('temple') || act.contains('seva')) {
        return directVal.isNotEmpty ? directVal : 'Logged';
      }
    } else if (columnKey == 'sleep') {
      if (acts['sleepTime'] != null) return _parseActivityValue(acts['sleepTime'], columnKey);
      if (acts['sleep'] != null) return _parseActivityValue(acts['sleep'], columnKey);
      if (cat == 'sleep' || act.contains('sleep') || act.contains('night') || act.contains('sona')) {
        return directVal.isNotEmpty ? directVal : 'Logged';
      }
    }

    return null;
  }

  /// Match log item and extract (Update, DisplayValue) pair for a cell
  MapEntry<Map<String, dynamic>, String>? _getUpdateAndValueForCell(String date, String columnKey) {
    final dayLogs = widget.studentUpdates.where((u) {
      if (u is! Map<String, dynamic>) return false;
      return _getLogDate(u) == date;
    }).toList();

    if (dayLogs.isEmpty) return null;

    for (var item in dayLogs) {
      final u = item as Map<String, dynamic>;
      final val = _getDisplayValueFromLog(u, columnKey);
      if (val != null && val.trim().isNotEmpty && val != 'null') {
        return MapEntry(u, val.trim());
      }
    }
    return null;
  }

  Widget _buildCellContent(String date, String columnKey) {
    if (columnKey == 'date') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          _formatDateHeader(date),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
            color: Color(0xFF0F172A),
          ),
        ),
      );
    }

    final cellData = _getUpdateAndValueForCell(date, columnKey);
    if (cellData == null) {
      return Container(
        alignment: Alignment.center,
        child: const Text(
          '-',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    final update = cellData.key;
    final String displayVal = cellData.value;

    final bool isDone = update['is_completed'] == true || update['status'] == 'completed' || displayVal.isNotEmpty;
    final bool isScreenTime = update['category'] == 'screen_time';

    Color bgColor = isScreenTime
        ? const Color(0xFFFCE7F3)
        : (isDone ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB));
    Color textColor = isScreenTime
        ? const Color(0xFF9D174D)
        : (isDone ? const Color(0xFF065F46) : const Color(0xFF92400E));
    Color borderColor = isScreenTime
        ? const Color(0xFFFBCFE8)
        : (isDone ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A));

    return InkWell(
      onTap: () => _showCellDetailsDialog(update, date),
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Text(
          displayVal,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  void _showCellDetailsDialog(Map<String, dynamic> update, String date) {
    final title = update['work_started'] ?? update['activity'] ?? update['title'] ?? update['name'] ?? update['category'] ?? 'Sadhana Entry';
    final value = update['work_completed'] ?? update['value'] ?? 'Logged';
    final description = update['description'] ?? update['notes'] ?? 'No additional details provided.';
    final photoUrl = update['photo_url'] ?? update['photoUrl'] ?? update['image_url'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: Color(0xFF107C41)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${_formatDateHeader(date)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recorded Value: $value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    Text('Details / Notes:\n$description', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              ),
              if (photoUrl != null && photoUrl.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(photoUrl.toString(), height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getSortedUniqueDates();
    final totalLoggedEntries = widget.studentUpdates.length;

    return Column(
      children: [
        // Top Excel Summary Bar & Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF107C41), // Excel green color
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grid_on_rounded, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sadhana History Matrix (${widget.studentName})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '${dates.length} Dates Logged • $totalLoggedEntries Entries Found',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              // Search input for date
              SizedBox(
                width: 130,
                height: 32,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _dateSearchQuery = val.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search date...',
                    hintStyle: const TextStyle(fontSize: 10.5),
                    prefixIcon: const Icon(Icons.search, size: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFCBD5E1)),

        // Main Excel Spreadsheet Table Body
        Expanded(
          child: dates.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.table_rows_outlined, size: 48, color: Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          'No Sadhana history dates found for ${widget.studentName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'When the student logs daily sadhana, their records will automatically populate date-wise here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                )
              : Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 1050, // Total fixed width for clean 9-column excel grid
                      child: Column(
                        children: [
                          // Table Header Row
                          Container(
                            color: const Color(0xFF107C41), // Header excel theme
                            child: Row(
                              children: _columns.map((col) {
                                final double colWidth = col['key'] == 'date' ? 140.0 : 113.0;
                                return Container(
                                  width: colWidth,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Color(0xFF185C37), width: 1),
                                    ),
                                  ),
                                  child: Text(
                                    col['title']!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Table Rows (Date Wise)
                          Expanded(
                            child: Scrollbar(
                              controller: _verticalController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _verticalController,
                                itemCount: dates.length,
                                itemBuilder: (context, rowIndex) {
                                  final dateStr = dates[rowIndex];
                                  final bool isEven = rowIndex % 2 == 0;

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isEven ? Colors.white : const Color(0xFFF8FAFC),
                                      border: const Border(
                                        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      children: _columns.map((col) {
                                        final double colWidth = col['key'] == 'date' ? 140.0 : 113.0;
                                        return Container(
                                          width: colWidth,
                                          height: 48,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                                            ),
                                          ),
                                          child: _buildCellContent(dateStr, col['key']!),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
