import 'package:flutter/material.dart';
import '../pages/profile_page.dart';

class SidebarDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;

  const SidebarDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Material(
              color: Colors.black,
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
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        userName,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              icon: Icons.calendar_month,
              title: 'Monthly Plan',
            ),
            _menuTile(
              context,
              icon: Icons.subscriptions,
              title: 'Subscription',
            ),
            _menuTile(
              context,
              icon: Icons.repeat,
              title: 'Recurring Expenses',
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
            ),
          ],
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
          color: Colors.black54,
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
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: destructive ? Colors.red : Colors.black87,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
      },
    );
  }
}