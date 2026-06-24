import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';
import 'datasets_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Map<String, dynamic>? _dashboardStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final stats = await ApiService().fetchDashboardStats();
    if (mounted) {
      setState(() {
        _dashboardStats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'DATAGO',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF7B00FF),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage, track, and analyze your datasets in one place.',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This platform helps you manage, organize, and analyze datasets efficiently. Upload data, track changes, and monitor dataset quality in one integrated system. Join us now on DATAGO.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DatasetsScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B00FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Explore'),
                  ),
                ],
              ),
            ),
            
            // About Section
            Container(
              padding: const EdgeInsets.all(24.0),
              color: const Color(0xFFF8F9FA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'About Us',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7B00FF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildInfoCard(
                    title: 'Our Goal',
                    description: 'This platform was created to simplify the process of managing datasets used in software modeling and data analysis.\n\nWith DATAGO, users can create dataset structures, upload data, and monitor dataset quality and changes efficiently.',
                  ),
                ],
              ),
            ),

            // Statistics Section
            Container(
              padding: const EdgeInsets.all(32.0),
              color: const Color(0xFF1F003C),
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildDonutChart(
                        'Total Dataset per Tahun', 
                        _dashboardStats?['datasets_per_year']
                      ),
                      const SizedBox(height: 48),
                      _buildDonutChart(
                        'Total Dataset Diunduh per Tahun', 
                        _dashboardStats?['downloads_per_year']
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String description}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF7B00FF).withOpacity(0.04),
        border: Border.all(color: const Color(0xFF7B00FF).withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B00FF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(String title, List<dynamic>? dataList) {
    if (dataList == null || dataList.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 20),
          const SizedBox(
            height: 200,
            child: Center(child: Text("Data tidak tersedia", style: TextStyle(color: Colors.white70))),
          ),
        ],
      );
    }

    final List<Color> colors = [
      const Color(0xFF00C853), // Green
      const Color(0xFFFFAB00), // Orange
      const Color(0xFF00B0FF), // Light Blue
      const Color(0xFFFF1744), // Red
      const Color(0xFFAA00FF), // Deep Purple
    ];

    List<PieChartSectionData> sections = [];
    int i = 0;
    for (var item in dataList) {
      final percentage = (item['percentage'] as num).toDouble();
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: percentage,
          title: '${item['year']}\n$percentage%',
          radius: 30, // ring thickness
          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 60,
              sections: sections,
            ),
          ),
        ),
      ],
    );
  }
}
