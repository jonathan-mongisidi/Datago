import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class DatasetDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dataset;

  const DatasetDetailScreen({super.key, required this.dataset});

  @override
  State<DatasetDetailScreen> createState() => _DatasetDetailScreenState();
}

class _DatasetDetailScreenState extends State<DatasetDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _csvStats;
  bool _isLoadingStats = true;
  String? _currentUsername;
  bool _isUploadingFile = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStats();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    final user = await ApiService().fetchCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUsername = user['username'];
      });
    }
  }

  Future<void> _deleteDataset() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dataset'),
        content: const Text('Apakah Anda yakin ingin menghapus dataset ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService().deleteDataset(widget.dataset['id']);
      if (res['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dataset berhasil dihapus')));
          Navigator.pop(context, true); // Return true to trigger refresh
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
        }
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() => _isUploadingFile = true);
        final filePath = result.files.single.path!;
        final uploadResult = await ApiService().uploadDatasetFile(widget.dataset['id'], filePath, 'v1.0');
        
        if (!mounted) return;
        setState(() => _isUploadingFile = false);
        
        if (uploadResult['success']) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil diunggah!')));
          Navigator.pop(context, true); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uploadResult['message'])));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingFile = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteFile(int fileId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus File'),
        content: const Text('Apakah Anda yakin ingin menghapus file ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService().deleteDatasetFile(fileId);
      if (res['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File berhasil dihapus!')));
        Navigator.pop(context, true); 
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
      }
    }
  }

  Future<void> _downloadFile(int fileId, String fileUrl) async {
    await ApiService().incrementDownloadCount(fileId);
    
    String finalUrl = fileUrl;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh file: $e')),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    final datasetId = widget.dataset['id'];
    if (datasetId != null) {
      try {
        final stats = await ApiService().fetchDatasetStats(datasetId);
        if (mounted) {
          setState(() {
            _csvStats = stats ?? {'error': 'API returned null (kemungkinan 404 Not Found)'};
            _isLoadingStats = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _csvStats = {'error': 'Exception: $e'};
            _isLoadingStats = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _csvStats = {'error': 'datasetId is null'};
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPublic = widget.dataset['visibility'] == 'public';
    final int filesCount = (widget.dataset['files'] as List?)?.length ?? 0;
    final String ownerName = widget.dataset['owner']?['first_name'] ?? widget.dataset['owner']?['username'] ?? 'Unknown';
    
    String formattedDate = '-';
    if (widget.dataset['created_at'] != null) {
      try {
        final date = DateTime.parse(widget.dataset['created_at']).toLocal();
        formattedDate = '${date.day}-${date.month}-${date.year}';
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F003C), // Dark purple from web hero
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Kembali ke Datasets',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentUsername != null && _currentUsername == widget.dataset['owner']?['username'])
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Hapus Dataset',
              onPressed: _deleteDataset,
            ),
        ],
      ),
      body: Column(
        children: [
          // Hero Header
          Container(
            width: double.infinity,
            color: const Color(0xFF1F003C),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.dataset['title'] ?? 'Unknown Title',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildVisBadge(isPublic),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.dataset['description'] ?? 'No description provided.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetaChip(Icons.person, ownerName),
                    _buildMetaChip(Icons.description, widget.dataset['license'] ?? 'No License'),
                    _buildMetaChip(Icons.folder, '$filesCount file'),
                    _buildMetaChip(Icons.calendar_today, formattedDate),
                  ],
                ),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            color: Colors.white,
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF7B00FF),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF7B00FF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Ringkasan'),
                Tab(text: 'Statistik'),
                Tab(text: 'Activity Log'),
                Tab(text: 'Proyek'),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(isPublic, ownerName, formattedDate, filesCount),
                _buildStatistikTab(),
                _buildChangelogTab(ownerName, formattedDate),
                _buildProyekTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisBadge(bool isPublic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPublic ? const Color(0xFF27C27A).withOpacity(0.2) : const Color(0xFFFFC107).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPublic ? '✓ Public' : '🔒 Private',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isPublic ? const Color(0xFF27C27A) : const Color(0xFFFFC107),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _cleanFile(int fileId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Dataset?'),
        content: const Text('Tindakan ini akan menghapus baris kosong (NA) dan baris duplikat dari file CSV, lalu membuat versi Dataset baru. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B00FF)),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Bersihkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() {
      _isUploadingFile = true;
    });

    final result = await ApiService().cleanDatasetFile(fileId);

    if (mounted) {
      setState(() {
        _isUploadingFile = false;
      });
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'File berhasil dibersihkan!')),
        );
        // Kembali agar bisa melihat dataset baru
        Navigator.pop(context, true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal membersihkan file')),
        );
      }
    }
  }

  // --- OVERVIEW TAB ---
  Widget _buildOverviewTab(bool isPublic, String ownerName, String formattedDate, int filesCount) {
    final bool isOwner = _currentUsername != null && _currentUsername == widget.dataset['owner']?['username'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Informasi Dataset Card
          _buildCard(
            title: 'Informasi Dataset',
            child: Column(
               children: [
                _buildInfoRow('Pemilik', ownerName),
                _buildInfoRow('Visibilitas', isPublic ? 'Publik' : 'Pribadi'),
                _buildInfoRow('Lisensi', widget.dataset['license'] ?? '-'),
                _buildInfoRow('Dibuat', formattedDate),
                _buildInfoRow('Jumlah File', '$filesCount'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // File yang Diunggah Card
          _buildCard(
            title: 'File yang Diunggah',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingFile ? null : _pickAndUploadFile,
                      icon: _isUploadingFile ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.upload_file),
                      label: Text(_isUploadingFile ? 'Mengunggah...' : 'Upload File Tambahan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B00FF),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                filesCount > 0
                    ? Column(
                        children: (widget.dataset['files'] as List).map<Widget>((f) {
                          return _buildFileItem(
                            f['id'],
                            f['filename'] ?? 'Unknown', 
                            '${f['file_size_mb'] ?? 0} MB', 
                            f['version_tag'] ?? 'v1.0',
                            f['file'],
                            isOwner,
                          );
                        }).toList(),
                      )
                    : const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('Belum ada file yang diunggah.', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(int? fileId, String filename, String size, String version, String? fileUrl, bool isOwner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B00FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, color: Color(0xFF7B00FF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      size,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B00FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  version,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7B00FF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.print, color: Color(0xFF7B00FF), size: 20),
                  onPressed: () async {
                    if (fileUrl != null) {
                      String finalUrl = fileUrl;
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
                            SnackBar(content: Text('Gagal membuka file: Bisa jadi karena file URL tidak valid ($finalUrl)')),
                          );
                        }
                      }
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('URL File tidak ditemukan')),
                       );
                    }
                  },
                  tooltip: 'Print File',
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.black54, size: 20),
                  onPressed: () {
                     if (fileId != null && fileUrl != null) {
                        _downloadFile(fileId, fileUrl);
                     } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File tidak valid')));
                     }
                  },
                  splashRadius: 20,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                if (isOwner) ...[
                  if (filename.toLowerCase().endsWith('.csv'))
                    IconButton(
                      icon: const Icon(Icons.cleaning_services, color: Color(0xFF7B00FF), size: 20),
                      onPressed: () {
                        if (fileId != null) {
                           _cleanFile(fileId);
                        }
                      },
                      tooltip: 'Clean Data (Hapus duplikat & NA)',
                      splashRadius: 20,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () {
                      if (fileId != null) {
                         _deleteFile(fileId);
                      }
                    },
                    splashRadius: 20,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STATISTIK TAB ---
  Widget _buildStatistikTab() {
    final downloads = widget.dataset['download_count'] ?? 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildCard(
            title: 'Total Unduhan Dataset',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.download_done, color: Color(0xFF7B00FF), size: 40),
                    const SizedBox(width: 16),
                    Text(
                      '$downloads',
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7B00FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('unduhan', style: TextStyle(fontSize: 18, color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingStats)
            const Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF)))
          else if (_csvStats == null || _csvStats!['error'] != null || _csvStats!['empty'] == true)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _csvStats?['error'] ?? 'Statistik CSV tidak tersedia.', 
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            _buildCard(
              title: 'Analisis Per Kolom',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Geser tabel ke kanan untuk detail', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  dataTextStyle: const TextStyle(color: Colors.black87),
                  columns: const [
                    DataColumn(label: Text('Kolom')),
                    DataColumn(label: Text('Tipe')),
                    DataColumn(label: Text('Missing')),
                    DataColumn(label: Text('Unique')),
                    DataColumn(label: Text('Min')),
                    DataColumn(label: Text('Max')),
                    DataColumn(label: Text('Mean')),
                    DataColumn(label: Text('Std')),
                  ],
                  rows: (_csvStats!['columns'] as List).map<DataRow>((col) {
                    return _buildDataRow(
                      col['name'].toString(),
                      col['type'].toString(),
                      '${col['missing']} (${col['missing_pct']}%)',
                      col['unique'].toString(),
                      col['min']?.toString() ?? '-',
                      col['max']?.toString() ?? '-',
                      col['mean']?.toString() ?? '-',
                      col['std']?.toString() ?? '-',
                    );
                  }).toList(),
                ),
              ),
              ],
            ),
          ),
          const SizedBox(height: 20),
            _buildCard(
              title: 'Preview Data (5 baris pertama)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Geser tabel ke kanan untuk melihat semua kolom', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                  dataTextStyle: const TextStyle(color: Colors.black87),
                  columns: (_csvStats!['sample_headers'] as List).map<DataColumn>((h) {
                    return DataColumn(label: Text(h.toString()));
                  }).toList(),
                  rows: (_csvStats!['sample_rows'] as List).map<DataRow>((row) {
                    return DataRow(
                      cells: (row as List).map<DataCell>((cell) {
                        return DataCell(Text(cell.toString()));
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
              ],
            ),
          ),
          ]
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7B00FF)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(String col, String type, String missing, String unique, String min, String max, String mean, String std) {
    return DataRow(
      cells: [
        DataCell(Container(
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
          child: Text(col, style: const TextStyle(fontFamily: 'monospace', fontSize: 13), softWrap: true, maxLines: 2, overflow: TextOverflow.ellipsis),
        )),
        DataCell(Text(type, style: TextStyle(color: type == 'Numerik' ? const Color(0xFF7B00FF) : Colors.blue))),
        DataCell(Text(missing)),
        DataCell(Text(unique)),
        DataCell(Text(min)),
        DataCell(Text(max)),
        DataCell(Text(mean)),
        DataCell(Text(std)),
      ],
    );
  }

  // --- CHANGELOG TAB ---
  Widget _buildChangelogTab(String ownerName, String formattedDate) {
    final changelogs = widget.dataset['changelogs'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildCard(
        title: 'Activity Log',
        child: changelogs.isEmpty 
          ? const Center(child: Text('Belum ada activity log.'))
          : Column(
              children: changelogs.map<Widget>((cl) {
                 return _buildTimelineItem(
                   cl['action'] ?? 'Update', 
                   cl['description'] ?? '', 
                   cl['created_at'] != null ? DateTime.parse(cl['created_at']).toLocal().toString().split('.')[0] : '-'
                 );
              }).toList(),
            ),
      ),
    );
  }

  Widget _buildTimelineItem(String title, String desc, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4, right: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF7B00FF),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PROYEK TAB ---
  Widget _buildProyekTab() {
    final projects = widget.dataset['projects'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildCard(
        title: 'Proyek yang Menggunakan Dataset Ini',
        child: projects.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'Belum ada proyek yang menggunakan dataset ini.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : Column(
              children: projects.map<Widget>((p) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF7B00FF),
                    child: Icon(Icons.work, color: Colors.white, size: 20),
                  ),
                  title: Text(p['name'] ?? 'Unknown Project', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Oleh: ${p['owner']}'),
                );
              }).toList(),
            ),
      ),
    );
  }

  // --- REUSABLE CARD ---
  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
