import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav_bar.dart';
import 'dataset_detail_screen.dart';
import 'landing_page.dart';
import '../services/api_service.dart';

class DatasetsScreen extends StatefulWidget {
  const DatasetsScreen({super.key});

  @override
  State<DatasetsScreen> createState() => _DatasetsScreenState();
}

class _DatasetsScreenState extends State<DatasetsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<dynamic> _allDatasets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDatasets();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _fetchDatasets() async {
    try {
      final data = await ApiService().fetchDatasets();
      setState(() {
        _allDatasets = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '-';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return '${date.day}-${date.month}-${date.year}';
    } catch (_) {
      return '-';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _getFilteredDatasets() {
    if (_searchQuery.isEmpty) return _allDatasets;
    return _allDatasets.where((dataset) {
      final title = dataset['title']?.toString().toLowerCase() ?? '';
      final owner = dataset['owner']?['first_name']?.toString().toLowerCase() ?? '';
      final description = dataset['description']?.toString().toLowerCase() ?? '';
      return title.contains(_searchQuery) ||
          owner.contains(_searchQuery) ||
          description.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
          'DATAGO',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF7B00FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline
            Text(
              'Available Datasets',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF7B00FF),
              ),
            ),
            const SizedBox(height: 20),

            // Filter Bar (Search)
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Cari dataset berdasarkan nama, deskripsi, atau owner...',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Cari'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B00FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Datasets Grid / List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF))),
              )
            else if (_getFilteredDatasets().isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Tidak ada dataset yang cocok.',
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                ),
              )
            else
              ..._getFilteredDatasets().map((dataset) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDatasetCard(
                    title: dataset['title'] ?? 'Unknown',
                    owner: dataset['owner']?['first_name'] ?? dataset['owner']?['username'] ?? 'Unknown',
                    filesCount: (dataset['files'] as List?)?.length ?? 0,
                    date: _formatDate(dataset['created_at']),
                    description: dataset['description'] ?? '',
                    license: dataset['license'] ?? '-',
                    isPublic: dataset['visibility'] == 'public',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DatasetDetailScreen(dataset: dataset),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildDatasetCard({
    required String title,
    required String owner,
    required int filesCount,
    required String date,
    required String description,
    required String license,
    required bool isPublic,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B00FF).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visibility Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublic ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPublic ? '✓ Public' : '🔒 Private',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPublic ? Colors.green.shade700 : const Color(0xFF856404),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F003C),
                  ),
                ),
                const SizedBox(height: 6),

                // Meta
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                    children: [
                      const TextSpan(text: 'Oleh '),
                      TextSpan(
                        text: owner,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      TextSpan(text: ' • $filesCount file • $date'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B00FF).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        license,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7B00FF),
                        ),
                      ),
                    ),
                    const Text(
                      'Lihat Detail →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F003C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
