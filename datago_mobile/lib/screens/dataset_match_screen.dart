import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'dataset_detail_screen.dart';

class DatasetMatchScreen extends StatefulWidget {
  final int requestId;

  const DatasetMatchScreen({super.key, required this.requestId});

  @override
  State<DatasetMatchScreen> createState() => _DatasetMatchScreenState();
}

class _DatasetMatchScreenState extends State<DatasetMatchScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _matchData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final data = await ApiService().findMatchingDatasets(widget.requestId);
    if (mounted) {
      if (data != null && data['request'] != null) {
        setState(() {
          _matchData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Gagal memuat data atau request sudah selesai.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fulfillRequest(int fileId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await ApiService().fulfillDatasetRequest(widget.requestId, fileId);
    
    if (mounted) {
      Navigator.of(context).pop(); // Tutup loading
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Berhasil mengirim ke IC')),
        );
        Navigator.of(context).pop(true); // Kembali ke layar sebelumnya
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Terjadi kesalahan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F003C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Dataset yang Cocok',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchMatches,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B00FF)),
                        child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final requestInfo = _matchData!['request'];
    final matches = _matchData!['matches'] as List;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kriteria Pencarian Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kriteria Pencarian:',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _buildCriteriaRow('Request', requestInfo['title'] ?? '-'),
                const SizedBox(height: 8),
                _buildCriteriaRow('Minimal Baris', '${requestInfo['min_rows']} baris'),
                const SizedBox(height: 8),
                _buildCriteriaRow('Kolom Wajib', requestInfo['required_columns'] ?? '-'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Daftar Matches
          Text(
            'Hasil Pencarian (${matches.length})',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          
          if (matches.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada dataset yang memenuhi kriteria tersebut.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coba buat dataset baru atau gunakan file lain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...matches.map((match) => _buildMatchItem(match)),
        ],
      ),
    );
  }

  Widget _buildCriteriaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
          ),
        ),
        const Text(': ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchItem(Map<String, dynamic> match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B00FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dataset, color: Color(0xFF7B00FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match['dataset_title'] ?? 'Unknown Dataset',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match['filename'] ?? 'Unknown File',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  match['version_tag'] ?? 'v1.0',
                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (match['file_url'] != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    String finalUrl = match['file_url'];
                    if (finalUrl.startsWith('/')) {
                      finalUrl = 'http://10.0.2.2:8000$finalUrl';
                    }
                    if (finalUrl.contains('localhost:8000') || finalUrl.contains('127.0.0.1:8000')) {
                      finalUrl = finalUrl.replaceAll('localhost:8000', '10.0.2.2:8000');
                      finalUrl = finalUrl.replaceAll('127.0.0.1:8000', '10.0.2.2:8000');
                    }
                    final uri = Uri.parse(finalUrl);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuka file ($finalUrl)')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Unduh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7B00FF),
                    side: const BorderSide(color: Color(0xFF7B00FF)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  _navigateToDatasetDetail(match['dataset_id']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7B00FF),
                  side: const BorderSide(color: Color(0xFF7B00FF)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                ),
                child: const Text('Lihat Dataset'),
              ),
              ElevatedButton.icon(
                onPressed: () => _fulfillRequest(match['id']),
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Kirim ke IC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B00FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToDatasetDetail(int datasetId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF))),
    );

    try {
      final datasets = await ApiService().fetchDatasets();
      final targetDataset = datasets.firstWhere(
        (ds) => ds['id'] == datasetId, 
        orElse: () => <String, dynamic>{}
      );

      if (context.mounted) {
        Navigator.pop(context); // close loading
        if (targetDataset.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DatasetDetailScreen(dataset: targetDataset),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dataset tidak ditemukan atau Anda tidak memiliki akses.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat detail dataset.')),
        );
      }
    }
  }
}
