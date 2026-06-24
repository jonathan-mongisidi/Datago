import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';
import 'landing_page.dart';

class CreateDatasetScreen extends StatefulWidget {
  const CreateDatasetScreen({super.key});

  @override
  State<CreateDatasetScreen> createState() => _CreateDatasetScreenState();
}

class _CreateDatasetScreenState extends State<CreateDatasetScreen> {
  int _currentStep = 0;
  String _visibility = 'Public (Anyone can view)';
  
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _licenseController = TextEditingController(text: 'CC-BY-4.0');
  final _versionController = TextEditingController(text: 'v1.0.0');
  
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: -1),
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepper(),
              const SizedBox(height: 32),
              
              if (_currentStep == 0) ...[
                Text(
                  'Create New Dataset',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7B00FF),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Initialize an empty tracking dataset container. You can add files and versions later.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _buildLabel('Dataset Title'),
                _buildTextField(controller: _titleController, hintText: 'e.g. Traffic Sensors Hourly Logs 2026'),
                const SizedBox(height: 20),
                
                _buildLabel('Deskripsi'),
                _buildTextField(
                  controller: _descController,
                  hintText: 'Describe the contents of this dataset, data collection methods, format, etc...',
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                
                _buildLabel('Visibilitas'),
                _buildDropdown(borderRadius: 12),
                const SizedBox(height: 20),

                _buildLabel('Lisensi'),
                _buildTextField(controller: _licenseController, hintText: 'e.g. MIT, CC-BY-4.0', borderRadius: 12),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LandingPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep = 1;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B00FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text('Next: Upload Dataset →', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Upload Dataset File',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7B00FF),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload raw files (CSV, JSON, ZIP, etc.) for this dataset. File bersifat opsional — bisa diunggah nanti.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                
                _buildDropzone(),
                const SizedBox(height: 24),

                _buildLabel('Version Tag'),
                _buildTextField(controller: _versionController, hintText: 'e.g. v1.0.0'),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentStep = 0;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: const Text('← Back', style: TextStyle(color: Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitDataset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B00FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Upload & Publish', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepItem(
            stepNumber: '1', 
            label: 'Input Description', 
            isActive: _currentStep == 0, 
            isDone: _currentStep > 0
          ),
          Container(
            height: 2,
            width: 40,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: _currentStep > 0 ? const Color(0xFF27C27A) : Colors.grey.shade300,
          ),
          _buildStepItem(
            stepNumber: '2', 
            label: 'Unggah Dataset', 
            isActive: _currentStep == 1, 
            isDone: false
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String stepNumber, required String label, required bool isActive, required bool isDone}) {
    Color circleColor = Colors.grey.shade300;
    if (isDone) circleColor = const Color(0xFF27C27A);
    else if (isActive) circleColor = const Color(0xFF7B00FF);

    return Opacity(
      opacity: isActive || isDone ? 1.0 : 0.4,
      child: Row(
        children: [
          Container(
            width: isActive ? 36 : 30,
            height: isActive ? 36 : 30,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              boxShadow: isActive ? [BoxShadow(color: const Color(0xFF7B00FF).withOpacity(0.15), spreadRadius: 4)] : null,
            ),
            child: Center(
              child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(stepNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF444444),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, int maxLines = 1, double? borderRadius}) {
    final double radius = borderRadius ?? (maxLines > 1 ? 12 : 50);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFF7B00FF), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildDropdown({double borderRadius = 50}) {
    return DropdownButtonFormField<String>(
      value: _visibility,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: Color(0xFF7B00FF), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      items: const [
        DropdownMenuItem(value: 'Public (Anyone can view)', child: Text('Public (Anyone can view)')),
        DropdownMenuItem(value: 'Private (Only you can access)', child: Text('Private (Only you can access)')),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _visibility = val);
      },
      style: const TextStyle(fontSize: 14, color: Colors.black87),
    );
  }

  Widget _buildDropzone() {
    return GestureDetector(
      onTap: () async {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          setState(() {
            _selectedFile = result.files.first;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF7B00FF).withOpacity(0.04),
          border: Border.all(
            color: const Color(0xFF7B00FF).withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFile != null ? Icons.file_present : Icons.cloud_upload_outlined, 
              size: 48, 
              color: const Color(0xFF7B00FF).withOpacity(0.8)
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFile != null ? _selectedFile!.name : 'Tap here to browse from your device',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFile != null ? '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB' : 'Max size: 5 GB per file',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDataset() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dataset Title is required!')));
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService().createDataset(
      title,
      _descController.text.trim(),
      _visibility,
      _licenseController.text.trim(),
    );

    if (result['success']) {
      final datasetId = result['dataset']['id'];
      
      // Upload file if selected
      if (_selectedFile != null && _selectedFile!.path != null) {
        final uploadResult = await ApiService().uploadDatasetFile(
          datasetId,
          _selectedFile!.path!,
          _versionController.text.trim(),
        );
        if (!uploadResult['success'] && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(uploadResult['message'])));
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dataset successfully created!')));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LandingPage()));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }
}
