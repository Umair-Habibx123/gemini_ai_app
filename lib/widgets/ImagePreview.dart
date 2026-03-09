import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// A single attached file (image, video, audio, or PDF)
class AttachedFile {
  final XFile file;
  final String type; // 'image' | 'video' | 'audio' | 'pdf'

  const AttachedFile({required this.file, required this.type});

  String get path => file.path;
  String get name => file.name;
}

class ImagePreviewList extends StatelessWidget {
  final List<AttachedFile> files;
  final void Function(int) onRemove;

  const ImagePreviewList({
    super.key,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final f = files[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _FileThumbnail(file: f),
                Positioned(
                  top: -6, right: -6,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D14),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 12),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FileThumbnail extends StatelessWidget {
  final AttachedFile file;
  const _FileThumbnail({required this.file});

  Color get _accentColor {
    switch (file.type) {
      case 'image': return const Color(0xFF6C63FF);
      case 'video': return const Color(0xFF00D4AA);
      case 'audio': return const Color(0xFFFF6B9D);
      case 'pdf':   return const Color(0xFFFFB347);
      default:      return Colors.white38;
    }
  }

  IconData get _icon {
    switch (file.type) {
      case 'image': return Icons.image_outlined;
      case 'video': return Icons.videocam_outlined;
      case 'audio': return Icons.audiotrack_outlined;
      case 'pdf':   return Icons.picture_as_pdf_outlined;
      default:      return Icons.attach_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentColor.withOpacity(0.4)),
      ),
      child: file.type == 'image'
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(File(file.path), fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon, color: _accentColor, size: 24),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    file.name.length > 10 ? '${file.name.substring(0, 9)}…' : file.name,
                    style: GoogleFonts.dmSans(color: _accentColor, fontSize: 9, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
    );
  }
}