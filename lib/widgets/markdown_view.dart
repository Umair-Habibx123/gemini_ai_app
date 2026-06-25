import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

/// Renders AI responses as a designed Markdown preview (bold, headings, lists,
/// tables, code blocks, links …) instead of showing raw `**text**` syntax.
class MarkdownView extends StatelessWidget {
  final String data;
  const MarkdownView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GptMarkdown(
      data,
      style: GoogleFonts.dmSans(
        color: c.textPrimary.withOpacity(0.9),
        fontSize: 15,
        height: 1.6,
      ),
      onLinkTap: (url, title) {
        final uri = Uri.tryParse(url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      // Render fenced code blocks as a styled, copyable card.
      codeBuilder: (context, name, code, closed) {
        return _CodeBlock(language: name, code: code);
      },
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String language;
  final String code;
  const _CodeBlock({required this.language, required this.code});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B14) : const Color(0xFF1E1E2E);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: GoogleFonts.robotoMono(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: c.primary.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: GoogleFonts.dmSans(
                            color: c.primary.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              code.trimRight(),
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFE0E0F0),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
