import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../pages/lending/lendings_list_page.dart';
import '../pages/loan/loans_list_page.dart';
import '../pages/profile_page.dart';
import '../pages/recurring/recurring_list_page.dart';
import '../pages/sms/sms_parser_page.dart';

class _Dark {
  _Dark._();
  static const Color bg = Color(0xFF0B0F14);
  static const Color card = Color(0xFF141B24);
  static const Color accent = Color(0xFF2DD4A7);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color error = Color(0xFFF87171);
}

class SidebarDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final AuthService _authService = AuthService();

  SidebarDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _Dark.bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Material(
              color: _Dark.card,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _Dark.accent,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _Dark.bg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        userName,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: _Dark.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: _Dark.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _smsParserHighlight(context),
            ),
            _sectionHeader('Finance'),
            _menuTile(
              context,
              icon: Icons.account_balance_wallet,
              title: 'My Accounts',
            ),
            const SizedBox(height: 12),
            _sectionHeader('Planning'),
            _menuTile(
              context,
              icon: Icons.subscriptions,
              title: 'Subscription',
            ),
            _menuTile(
              context,
              icon: Icons.repeat,
              title: 'Recurring Expenses',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringListPage()),
              ),
            ),
            _menuTile(
              context,
              icon: Icons.north_east_rounded,
              title: 'Lendings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LendingsListPage()),
              ),
            ),
            _menuTile(
              context,
              icon: Icons.account_balance_outlined,
              title: 'Loans',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoansListPage()),
              ),
            ),
            const SizedBox(height: 12),
            _sectionHeader('Accounts'),
            _menuTile(
              context,
              icon: Icons.settings,
              title: 'Settings',
            ),
            _menuTile(
              context,
              icon: Icons.contact_mail,
              title: 'Contact Us',
            ),
            _menuTile(
              context,
              icon: Icons.logout,
              title: 'Logout',
              destructive: true,
              onTap: () async {
                await _authService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _smsParserHighlight(BuildContext context) {
    return Material(
      color: _Dark.accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmsParserPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Dark.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: _Dark.bg,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Parser',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _Dark.accent,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Paste a bank SMS to add a transaction',
                      style: TextStyle(fontSize: 11, color: _Dark.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _Dark.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _Dark.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    bool destructive = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: destructive ? _Dark.error : _Dark.textPrimary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? _Dark.error : _Dark.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }
}
