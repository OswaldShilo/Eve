import 'package:flutter/material.dart';

enum EveNavTab { home, chat, log }

class EveBottomNav extends StatelessWidget {
  const EveBottomNav({
    super.key,
    required this.currentTab,
    required this.onHomeTap,
    required this.onChatTap,
    required this.onLogTap,
  });

  final EveNavTab currentTab;
  final VoidCallback onHomeTap;
  final VoidCallback onChatTap;
  final VoidCallback onLogTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentTab.index,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Log'),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            onHomeTap();
            break;
          case 1:
            onChatTap();
            break;
          case 2:
            onLogTap();
            break;
        }
      },
    );
  }
}
