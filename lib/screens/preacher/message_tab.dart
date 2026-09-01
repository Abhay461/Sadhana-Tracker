import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageTab extends StatefulWidget {
  final List<dynamic> folkBoys;
  final bool isLoadingBoys;

  const MessageTab({
    super.key,
    required this.folkBoys,
    required this.isLoadingBoys,
  });

  @override
  State<MessageTab> createState() => _MessageTabState();
}

class _MessageTabState extends State<MessageTab> {
  final _messageSearchController = TextEditingController();
  
  String _messageRoleFilter = 'All'; // 'All', 'folk_boy', 'residency'
  String _messageSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _messageSearchController.addListener(() {
      setState(() {
        _messageSearchQuery = _messageSearchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _messageSearchController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    String finalPhone = cleanPhone;
    if (cleanPhone.length == 10) {
      finalPhone = '91$cleanPhone';
    }
    
    final url = 'https://wa.me/$finalPhone';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch WhatsApp in tab: $e');
    }
  }

  Widget _buildMessageChoiceChip(String value, String label) {
    final isSelected = _messageRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F766E),
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _messageRoleFilter = value;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalFolkBoysCount = widget.folkBoys.where((boy) => boy['role'] == 'folk_boy').length;
    final totalResidencyCount = widget.folkBoys.where((boy) => boy['role'] == 'residency').length;
    final totalCircleCount = widget.folkBoys.length;

    final filteredCircle = widget.folkBoys.where((boy) {
      if (_messageRoleFilter != 'All' && boy['role'] != _messageRoleFilter) {
        return false;
      }
      
      if (_messageSearchQuery.isNotEmpty) {
        final query = _messageSearchQuery.toLowerCase();
        final name = (boy['name'] ?? '').toString().toLowerCase();
        final rawWhatsapp = (boy['whatsapp_number'] ?? '').toString();
        final whatsapp = rawWhatsapp.split(' | ').first.trim().toLowerCase();
        return name.contains(query) || whatsapp.contains(query);
      }
      
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Direct Circle Messaging', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _messageSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or number...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _messageSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _messageSearchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Filter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMessageChoiceChip('All', 'All ($totalCircleCount)'),
                            const SizedBox(width: 8),
                            _buildMessageChoiceChip('folk_boy', 'Folk Boy ($totalFolkBoysCount)'),
                            const SizedBox(width: 8),
                            _buildMessageChoiceChip('residency', 'Residency ($totalResidencyCount)'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          Expanded(
            child: widget.isLoadingBoys
                ? const Center(child: CircularProgressIndicator())
                : filteredCircle.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _messageSearchQuery.isNotEmpty ? Icons.search_off : Icons.chat_bubble_outline,
                              size: 56,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _messageSearchQuery.isNotEmpty ? 'No circle members found' : 'No circle members registered',
                              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredCircle.length,
                        itemBuilder: (context, index) {
                          final boy = filteredCircle[index];
                          final name = boy['name'] ?? (boy['role'] == 'residency' ? 'Resident' : 'Folk Boy');
                          final photoUrl = boy['photo_url'];
                          final role = boy['role'] ?? 'folk_boy';
                          final rawWhatsapp = boy['whatsapp_number'] ?? '';
                          final whatsapp = rawWhatsapp.toString().split(' | ').first.trim();
                          final hasWhatsapp = whatsapp.isNotEmpty;

                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey[100]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                    backgroundColor: role == 'residency' ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                                    child: photoUrl == null
                                        ? Text(
                                            name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: role == 'residency' ? const Color(0xFF9333EA) : const Color(0xFF0284C7),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: role == 'residency' ? const Color(0xFFF3E8FF) : const Color(0xFFE0F2FE),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                role == 'residency' ? 'RESIDENCY' : 'FOLK BOY',
                                                style: TextStyle(
                                                  color: role == 'residency' ? const Color(0xFF7E22CE) : const Color(0xFF0369A1),
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              hasWhatsapp ? whatsapp : 'No WhatsApp number',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: hasWhatsapp ? Colors.grey[600] : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: hasWhatsapp
                                        ? () => _launchWhatsApp(whatsapp)
                                        : () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('This circle member does not have a WhatsApp number logged.')),
                                            );
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: hasWhatsapp ? const Color(0xFFDCF8C6) : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.chat_outlined,
                                        color: hasWhatsapp ? const Color(0xFF075E54) : Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
