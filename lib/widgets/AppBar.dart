import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExit;

  const ChatAppBar({super.key, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 4, // Adds a shadow effect
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A6FA5), Color(0xFF7180AC)], // Modern gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'Gemini AI App',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        PopupMenuButton(
          onSelected: (value) {
            if (value == 'exit') onExit();
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'exit',
              child: Row(
                children: const [
                  Icon(Icons.exit_to_app, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Exit App', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert, color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
