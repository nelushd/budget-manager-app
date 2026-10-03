import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF1B2430);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFF2E3A4A);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();

  String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  String _initial(User? user) {
    final name = _displayName(user);
    return name.substring(0, 1).toUpperCase();
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: _Dark.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: _Dark.bg,
        foregroundColor: _Dark.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: _Dark.accent,
                child: Text(
                  _initial(user),
                  style: const TextStyle(
                    color: _Dark.bg,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _infoCard(
              icon: Icons.person,
              label: 'Name',
              value: _displayName(user),
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.email,
              label: 'Email',
              value: user?.email ?? 'No email available',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _logout,
                style: FilledButton.styleFrom(
                  backgroundColor: _Dark.accent,
                  foregroundColor: _Dark.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _Dark.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Dark.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: _Dark.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _Dark.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _Dark.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
