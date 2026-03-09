import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class MessageList extends StatelessWidget {
  final List<Map<String, String>> messages;
  final bool isStreaming;
  final void Function(String)? onSuggestionTap; // ✅ new

  const MessageList({
    super.key,
    required this.messages,
    this.isStreaming = false,
    this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return _buildEmptyState();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[messages.length - 1 - index];
        final isLast = index == 0;
        switch (msg['type']) {
          case 'text':     return _buildUserMessage(context, msg['text']!);
          case 'image':    return _buildImageMessage(context, msg['text']!);
          case 'video':    return _buildFileMessage(context, msg['text']!, 'video');
          case 'audio':    return _buildFileMessage(context, msg['text']!, 'audio');
          case 'pdf':      return _buildFileMessage(context, msg['text']!, 'pdf');
          case 'response': return _buildAiMessage(context, msg['text']!, isStreaming: isStreaming && isLast);
          default:         return const SizedBox.shrink();
        }
      },
    );
  }

  // ─── Empty state ──────────────────────────────────────────────

Widget _buildEmptyState() {
  return Center(
    child: SingleChildScrollView(                          // ✅ prevents overflow
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,                    // ✅ shrink to content
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 24, spreadRadius: 4)],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 24),
          Text('Gemini AI', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('How can I help you today?', style: GoogleFonts.dmSans(fontSize: 15, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 6),
          Text('Text · Image · Video · Audio · PDF', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.18), letterSpacing: 0.5)),
          const SizedBox(height: 40),
          _buildSuggestionChips(),
        ],
      ),
    ),
  );
}

  Widget _buildSuggestionChips() {
    final suggestions = [
      ('✍️', 'Help me write'),
      ('🧠', 'Explain a concept'),
      ('💻', 'Debug my code'),
      ('🎨', 'Creative ideas'),
    ];
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: suggestions.map((s) {
        final label = '${s.$1} ${s.$2}';
        return GestureDetector(                          // ✅ tappable
          onTap: () => onSuggestionTap?.call(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white.withOpacity(0.55))),
          ),
        );
      }).toList(),
    );
  }

  // ─── User text bubble ─────────────────────────────────────────

  Widget _buildUserMessage(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context, text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF8B84FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
                  boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Text(text, style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15, height: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image message ────────────────────────────────────────────

  Widget _buildImageMessage(BuildContext context, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 48),
      child: GestureDetector(
        onTap: () => _showImageViewer(context, path),
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65, maxHeight: 240),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(path), fit: BoxFit.cover)),
            ),
            Positioned(right: 8, bottom: 8,
              child: Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14))),
          ],
        ),
      ),
    );
  }

  // ─── Non-image file message ───────────────────────────────────

  Widget _buildFileMessage(BuildContext context, String path, String type) {
    final (color, icon, label) = switch (type) {
      'video' => (const Color(0xFF00D4AA), Icons.videocam_outlined,       'Video'),
      'audio' => (const Color(0xFFFF6B9D), Icons.audiotrack_outlined,     'Audio'),
      'pdf'   => (const Color(0xFFFFB347), Icons.picture_as_pdf_outlined, 'PDF'),
      _       => (Colors.white38,          Icons.attach_file,              'File'),
    };
    final fileName = path.split('/').last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.dmSans(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            Text(fileName, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.7), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  // ─── AI response card ─────────────────────────────────────────

  Widget _buildAiMessage(BuildContext context, String response, {bool isStreaming = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF13131F),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (response.isEmpty && isStreaming)
                  _buildTypingIndicator()
                else
                  SelectableText(response, style: GoogleFonts.dmSans(color: Colors.white.withOpacity(0.85), fontSize: 15, height: 1.65)),
                if (isStreaming && response.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)))),
                ],
                if (!isStreaming && response.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    _ActionButton(icon: Icons.copy_outlined,  label: 'Copy',  onTap: () => _copyToClipboard(context, response)),
                    const SizedBox(width: 8),
                    _ActionButton(icon: Icons.share_outlined, label: 'Share', onTap: () => Share.share(response)),
                  ]),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (i) => _AnimatedDot(delay: Duration(milliseconds: i * 200))));

  void _showImageViewer(BuildContext context, String imagePath) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Color(0xFF0A0A12), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          Expanded(child: PhotoView(imageProvider: FileImage(File(imagePath)),
            backgroundDecoration: const BoxDecoration(color: Color(0xFF0A0A12)),
            minScale: PhotoViewComputedScale.contained * 0.5,
            maxScale: PhotoViewComputedScale.covered * 2.0)),
        ]),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Color(0xFF00D4AA), size: 16),
        const SizedBox(width: 8),
        Text('Copied', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13)),
      ]),
      backgroundColor: const Color(0xFF1A1A28),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }
}

class _AnimatedDot extends StatefulWidget {
  final Duration delay;
  const _AnimatedDot({required this.delay});
  @override State<_AnimatedDot> createState() => _AnimatedDotState();
}
class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _a = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () { if (mounted) _c.repeat(reverse: true); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, _a.value),
      child: Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)]), borderRadius: BorderRadius.circular(50))),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.white.withOpacity(0.4)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.4))),
    ]),
  ));
}