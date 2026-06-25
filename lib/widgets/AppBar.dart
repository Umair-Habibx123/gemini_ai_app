import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onExit;
  final String? chatName;
  final String? modelName;
  final VoidCallback? onSwitchModel;

  const ChatAppBar({
    super.key,
    required this.onExit,
    this.chatName,
    this.modelName,
    this.onSwitchModel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final themeProvider = context.watch<ThemeProvider>();

    return AppBar(
      elevation: 0,
      backgroundColor: c.surfaceAlt,
      iconTheme: IconThemeData(color: c.textSecondary),
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                c.primary,
                c.secondary,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: c.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: c.primary.withOpacity(0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gemini AI',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                if (chatName != null && chatName!.isNotEmpty)
                  Text(
                    chatName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: c.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          modelName != null && modelName!.isNotEmpty
                              ? modelName!
                              : 'Ready',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: c.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Switch between available AI models (keeps the conversation).
        if (onSwitchModel != null)
          IconButton(
            tooltip: 'Switch model',
            onPressed: onSwitchModel,
            icon: Icon(Icons.swap_horiz_rounded, color: c.primary, size: 22),
          ),
        // Light / dark theme toggle — one tap, easy for everyone.
        IconButton(
          tooltip: themeProvider.isDark ? 'Light mode' : 'Dark mode',
          onPressed: () => themeProvider.toggle(),
          icon: Icon(
            themeProvider.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            color: c.secondary,
            size: 20,
          ),
        ),
        PopupMenuButton(
          onSelected: (value) {
            if (value == 'exit') onExit();
          },
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: c.border),
          ),
          itemBuilder:
              (BuildContext context) => [
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
                        child: const Icon(
                          Icons.exit_to_app,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Exit App',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          icon: Icon(Icons.more_vert, color: c.textFaint),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}
