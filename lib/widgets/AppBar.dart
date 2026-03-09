import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExit;
  final String? chatName;

  const ChatAppBar({super.key, required this.onExit, this.chatName});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF0D0D14),
      iconTheme: const IconThemeData(color: Color(0xFFB8B8CC)),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF6C63FF),
                Color(0xFF00D4AA),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          // Animated logo mark
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gemini AI',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              if (chatName != null && chatName!.isNotEmpty)
                Text(
                  chatName!,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00D4AA),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF00D4AA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      actions: [
        PopupMenuButton(
          onSelected: (value) {
            if (value == 'exit') onExit();
          },
          color: const Color(0xFF1A1A28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'exit',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.exit_to_app,
                        color: Colors.redAccent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Exit App',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert, color: Color(0xFF8888AA)),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}