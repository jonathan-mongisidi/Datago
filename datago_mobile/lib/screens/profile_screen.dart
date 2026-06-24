import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'auth_screen.dart';
import 'landing_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isUploading = false;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final user = await _apiService.fetchCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isUploading = true);

    final result = await _apiService.uploadProfilePicture(image.path);
    if (result['success']) {
      await _fetchUser(); // Refresh user data to get new image URL
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengunggah foto')),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  Future<void> _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }
  Color _getAvatarColor(String? identifier) {
    if (identifier == null || identifier.isEmpty) return const Color(0xFFF4436A);
    final colors = [
      const Color(0xFFF4436A), // Pink
      const Color(0xFF7B00FF), // Purple
      const Color(0xFF00B0FF), // Light Blue
      const Color(0xFF00E676), // Green
      const Color(0xFFFF9100), // Orange
      const Color(0xFFD50000), // Red
    ];
    int hash = 0;
    for (int i = 0; i < identifier.length; i++) {
      hash = identifier.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  Widget _buildAvatar() {
    String? profilePicUrl;
    if (_currentUser?['profile'] != null && _currentUser!['profile']['profile_picture'] != null) {
      profilePicUrl = _currentUser!['profile']['profile_picture'];
      if (!profilePicUrl!.startsWith('http')) {
        profilePicUrl = 'http://10.0.2.2:8000$profilePicUrl';
      }
    }
    
    final avatarColor = _getAvatarColor(_currentUser?['username'] ?? _currentUser?['email']);

    return CircleAvatar(
      radius: 60,
      backgroundColor: avatarColor,
      backgroundImage: profilePicUrl != null
          ? NetworkImage(profilePicUrl)
          : null,
      child: profilePicUrl == null
          ? const Icon(Icons.person, size: 60, color: Colors.white)
          : null,
    );
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
        title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF7B00FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B00FF)))
          : _currentUser == null
              ? const Center(child: Text('Gagal memuat profil'))
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        _buildAvatar(),
                        const SizedBox(height: 24),
                        Text(
                          _currentUser!['first_name']?.isNotEmpty == true
                              ? "${_currentUser!['first_name']} ${_currentUser!['last_name'] ?? ''}".trim()
                              : _currentUser!['username'] ?? 'User',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F003C)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser!['email'] ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.image_outlined, color: Color(0xFF1F003C)),
                                title: const Text('Unggah dari Perangkat', style: TextStyle(fontWeight: FontWeight.w500)),
                                trailing: _isUploading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.chevron_right),
                                onTap: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
                              ListTile(
                                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF1F003C)),
                                title: const Text('Ambil Foto', style: TextStyle(fontWeight: FontWeight.w500)),
                                trailing: _isUploading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.chevron_right),
                                onTap: _isUploading ? null : () => _pickAndUploadImage(ImageSource.camera),
                              ),

                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.logout, color: Colors.red),
                            title: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
                            onTap: _logout,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
