import 'package:flutter/material.dart';

class BirthdayTab extends StatelessWidget {
  final List<dynamic> folkBoys;

  const BirthdayTab({
    super.key,
    required this.folkBoys,
  });

  void _sendBirthdayBlessing(BuildContext context, Map<String, dynamic> boy) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.pink[600],
        content: Text(
          '🎂 Wish & Blessings successfully dispatched to ${boy['name']}!',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return folkBoys.isEmpty
        ? const Center(child: Text('No circle members found.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: folkBoys.length,
            itemBuilder: (context, index) {
              final boy = folkBoys[index];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: boy['photo_url'] != null ? NetworkImage(boy['photo_url']) : null,
                        child: boy['photo_url'] == null ? Text(boy['name'][0].toUpperCase()) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(boy['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text((boy['role'] ?? 'Member').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDB2777),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cake, size: 14),
                        label: const Text('BLESS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        onPressed: () => _sendBirthdayBlessing(context, boy),
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }
}
