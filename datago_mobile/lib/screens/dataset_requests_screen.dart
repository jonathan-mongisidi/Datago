import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'landing_page.dart';
import 'dataset_match_screen.dart';

class DatasetRequestsScreen extends StatefulWidget {
  const DatasetRequestsScreen({super.key});

  @override
  State<DatasetRequestsScreen> createState() => _DatasetRequestsScreenState();
}

class _DatasetRequestsScreenState extends State<DatasetRequestsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final data = await ApiService().fetchDatasetRequests();
    setState(() {
      _requests = data;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(int reqId, String newStatus) async {
    final res = await ApiService().updateDatasetRequestStatus(reqId, newStatus);
    if (res['success']) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status berhasil diubah!')));
      _fetchRequests(); // refresh
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = _requests.where((r) => r['status'] == 'PENDING' || r['status'] == 'IN_PROGRESS').toList();
    final completedRequests = _requests.where((r) => r['status'] == 'COMPLETED' || r['status'] == 'REJECTED').toList();

    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LandingPage()),
          );
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              'Permintaan Dataset',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF7B00FF),
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Request Baru / Aktif'),
                Tab(text: 'Selesai / Ditolak'),
              ],
            ),
          ),
          bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF)))
              : TabBarView(
                  children: [
                    _buildRequestsList(pendingRequests),
                    _buildRequestsList(completedRequests),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<dynamic> requests) {
    if (requests.isEmpty) {
      return const Center(
        child: Text('Tidak ada request dataset.', style: TextStyle(color: Colors.black54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _buildRequestCard(req);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    Color statusColor;
    switch (req['status']) {
      case 'PENDING':
        statusColor = Colors.orange;
        break;
      case 'IN_PROGRESS':
        statusColor = Colors.blue;
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    req['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    req['status'] ?? 'UNKNOWN',
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              req['description'] ?? '',
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.email, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text(req['ic_contact_email'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const Spacer(),
                const Icon(Icons.priority_high, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text(req['urgency'] ?? 'NORMAL', style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
            if (req['min_rows'] != null || (req['required_columns'] != null && req['required_columns'].toString().isNotEmpty)) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFF7B00FF), width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kriteria Pencarian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    if (req['min_rows'] != null)
                      Text('- Minimal Baris: ${req['min_rows']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (req['required_columns'] != null && req['required_columns'].toString().isNotEmpty)
                      Text('- Kolom Wajib: ${req['required_columns']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DatasetMatchScreen(requestId: req['id']),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Cari Dataset Sesuai Kriteria', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B00FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Ubah Status: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                DropdownButton<String>(
                  value: req['status'],
                  items: const [
                    DropdownMenuItem(value: 'PENDING', child: Text('Menunggu')),
                    DropdownMenuItem(value: 'IN_PROGRESS', child: Text('Sedang Berjalan')),
                    DropdownMenuItem(value: 'COMPLETED', child: Text('Selesai')),
                    DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
                  ],
                  onChanged: (val) {
                    if (val != null && val != req['status']) {
                      _updateStatus(req['id'], val);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
