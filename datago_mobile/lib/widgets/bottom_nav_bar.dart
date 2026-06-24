import 'package:flutter/material.dart';
import '../screens/landing_page.dart';
import '../screens/datasets_screen.dart';
import '../screens/dataset_requests_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/create_dataset_screen.dart';
import '../screens/profile_screen.dart';

import '../services/api_service.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;

  const CustomBottomNavBar({super.key, required this.currentIndex});

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final user = await ApiService().fetchCurrentUser();
      if (mounted && user != null) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (_) {}
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

  Widget _buildProfileAvatar(bool isActive) {
    String? profilePicUrl;
    if (_currentUser?['profile'] != null && _currentUser!['profile']['profile_picture'] != null) {
      profilePicUrl = _currentUser!['profile']['profile_picture'];
      if (!profilePicUrl!.startsWith('http')) {
        profilePicUrl = 'http://10.0.2.2:8000$profilePicUrl';
      }
    }
    
    final avatarColor = _getAvatarColor(_currentUser?['username'] ?? _currentUser?['email']);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF7B00FF) : Colors.transparent, 
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: avatarColor,
        backgroundImage: profilePicUrl != null ? NetworkImage(profilePicUrl) : null,
        child: profilePicUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabItem(
              context, 
              icon: Icons.home_outlined, 
              activeIcon: Icons.home, 
              label: 'Beranda', 
              index: 0, 
              targetPage: const LandingPage(),
            ),
            _buildTabItem(
              context, 
              icon: Icons.dataset_outlined, 
              activeIcon: Icons.dataset, 
              label: 'Dataset', 
              index: 1, 
              targetPage: const DatasetsScreen(),
            ),
            _buildCreateButton(context),
            _buildTabItem(
              context, 
              icon: Icons.assignment_outlined, 
              activeIcon: Icons.assignment, 
              label: 'Permintaan', 
              index: 2, 
              targetPage: const DatasetRequestsScreen(),
            ),
            _buildTabItem(
              context, 
              icon: Icons.person_outline, 
              activeIcon: Icons.person, 
              label: 'Profil', 
              index: 3, 
              targetPage: _currentUser != null ? const ProfileScreen() : const AuthScreen(),
              isPush: true,
              customIcon: _currentUser != null ? _buildProfileAvatar(false) : null,
              customActiveIcon: _currentUser != null ? _buildProfileAvatar(true) : null,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context, {
    required IconData icon, 
    required IconData activeIcon, 
    required String label, 
    required int index, 
    required Widget targetPage,
    bool isPush = false,
    Widget? customIcon,
    Widget? customActiveIcon,
  }) {
    final isSelected = widget.currentIndex == index;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          if (isPush) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => targetPage),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => targetPage),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B00FF).withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: isSelected 
            ? (customActiveIcon ?? Icon(activeIcon, color: const Color(0xFF7B00FF), size: 26))
            : (customIcon ?? Icon(icon, color: Colors.black54, size: 24)),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name == '/create_dataset') return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const CreateDatasetScreen(),
            settings: const RouteSettings(name: '/create_dataset'),
          ),
        );
      },
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF7B00FF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B00FF).withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }
}
