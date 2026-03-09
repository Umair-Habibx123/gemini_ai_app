import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

typedef OnPickFile = void Function(String type);
typedef OnAudioRecorded = void Function(String path);

class InputArea extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final OnPickFile onPickFile;
  final VoidCallback onSendMessage;
  final OnAudioRecorded onAudioRecorded;

  const InputArea({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onPickFile,
    required this.onSendMessage,
    required this.onAudioRecorded,
  });

  @override
  State<InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<InputArea> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _recPulse;

  // Recording
  AudioRecorder? _recorder;
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  bool _recorderBusy = false; // prevent double-tap

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _recPulse = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this)
      ..repeat(reverse: true);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _pulseController.dispose();
    _recPulse.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  // ── Permission helper ────────────────────────────────────────

  Future<bool> _requestMicPermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;
    status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied && mounted) {
      // Show dialog to open settings
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Microphone Permission',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
          content: Text('Microphone access is required for voice recording. Please enable it in app settings.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
            TextButton(onPressed: () { Navigator.pop(context); openAppSettings(); },
                child: const Text('Open Settings', style: TextStyle(color: Color(0xFF6C63FF)))),
          ],
        ),
      );
    }
    return false;
  }

  // ── Recording logic ──────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_recorderBusy) return;
    _recorderBusy = true;

    try {
      final granted = await _requestMicPermission();
      if (!granted) { _recorderBusy = false; return; }

      // Lazy init AFTER permission granted (avoids MissingPluginException on first call)
      _recorder ??= AudioRecorder();

      // Double check plugin is available
      final isAvailable = await _recorder!.isEncoderSupported(AudioEncoder.aacLc);
      if (!isAvailable && mounted) {
        _showSnackBar('Audio recording not supported on this device.');
        _recorderBusy = false;
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
        path: path,
      );

      if (mounted) setState(() { _isRecording = true; _recordDuration = Duration.zero; });
      _tickTimer();
    } catch (e) {
      debugPrint('_startRecording error: $e');
      if (mounted) _showSnackBar('Could not start recording: $e');
    } finally {
      _recorderBusy = false;
    }
  }

  void _tickTimer() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopAndSend() async {
    if (_recorder == null) return;
    try {
      final path = await _recorder!.stop();
      if (mounted) setState(() { _isRecording = false; _recordDuration = Duration.zero; });
      if (path != null) {
        final file = File(path);
        if (await file.exists() && await file.length() > 0) {
          widget.onAudioRecorded(path);
        } else {
          if (mounted) _showSnackBar('Recording was empty. Try again.');
        }
      }
    } catch (e) {
      debugPrint('_stopAndSend error: $e');
      if (mounted) setState(() { _isRecording = false; _recordDuration = Duration.zero; });
    }
  }

  Future<void> _cancelRecording() async {
    if (_recorder == null) return;
    try {
      final path = await _recorder!.stop();
      // Delete the temp file
      if (path != null) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
    if (mounted) setState(() { _isRecording = false; _recordDuration = Duration.zero; });
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  String get _recordingLabel {
    final m = _recordDuration.inMinutes.toString().padLeft(2, '0');
    final s = (_recordDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Attach menu ──────────────────────────────────────────────

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Attach File', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8))),
            _AttachOption(icon: Icons.image_outlined,          label: 'Image', subtitle: 'JPG, PNG, WebP',     color: const Color(0xFF6C63FF), onTap: () { Navigator.pop(context); widget.onPickFile('image'); }),
            _AttachOption(icon: Icons.videocam_outlined,       label: 'Video', subtitle: 'MP4, MOV, AVI',      color: const Color(0xFF00D4AA), onTap: () { Navigator.pop(context); widget.onPickFile('video'); }),
            _AttachOption(icon: Icons.audiotrack_outlined,     label: 'Audio', subtitle: 'MP3, WAV, M4A, AAC', color: const Color(0xFFFF6B9D), onTap: () { Navigator.pop(context); widget.onPickFile('audio'); }),
            _AttachOption(icon: Icons.picture_as_pdf_outlined, label: 'PDF',   subtitle: 'PDF documents',      color: const Color(0xFFFFB347), onTap: () { Navigator.pop(context); widget.onPickFile('pdf'); }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _isRecording ? const Color(0xFF1A0F18) : const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRecording
              ? const Color(0xFFFF6B9D).withOpacity(0.5)
              : _isFocused
                  ? const Color(0xFF6C63FF).withOpacity(0.6)
                  : Colors.white.withOpacity(0.07),
          width: 1.5,
        ),
        boxShadow: [BoxShadow(
          color: _isRecording
              ? const Color(0xFFFF6B9D).withOpacity(0.12)
              : _isFocused
                  ? const Color(0xFF6C63FF).withOpacity(0.15)
                  : Colors.black.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 4),
        )],
      ),
      child: _isRecording ? _buildRecordingUI() : _buildNormalUI(context),
    );
  }

  // ── Recording UI ─────────────────────────────────────────────

  Widget _buildRecordingUI() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _recPulse,
            builder: (_, __) => Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B9D).withOpacity(0.5 + _recPulse.value * 0.5),
                boxShadow: [BoxShadow(color: const Color(0xFFFF6B9D).withOpacity(0.4 * _recPulse.value), blurRadius: 8)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('Recording  $_recordingLabel',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.4), size: 18),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFFFF6B9D).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Normal UI ────────────────────────────────────────────────

  Widget _buildNormalUI(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: TextField(
            controller: widget.controller,
            maxLines: null,
            focusNode: _focusNode,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.9), height: 1.5),
            decoration: InputDecoration(
              hintText: 'Ask anything...',
              hintStyle: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.25)),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              _ToolbarButton(icon: Icons.attach_file_rounded,
                  onTap: widget.isLoading ? null : () => _showAttachMenu(context), tooltip: 'Attach'),
              const SizedBox(width: 4),
              _ToolbarButton(icon: Icons.mic_none_rounded,
                  onTap: widget.isLoading ? null : _startRecording,
                  tooltip: 'Record voice', activeColor: const Color(0xFFFF6B9D)),
              const Spacer(),
              GestureDetector(
                onTap: widget.isLoading ? null : widget.onSendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: widget.isLoading ? null : const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00D4AA)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    color: widget.isLoading ? Colors.white.withOpacity(0.06) : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: widget.isLoading ? [] : [
                      BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: widget.isLoading
                      ? Center(child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (_, __) => Opacity(opacity: _pulseAnimation.value,
                            child: const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2)))))
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon; final String label; final String subtitle; final Color color; final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    leading: Container(width: 42, height: 42,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
    trailing: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2), size: 18),
  );
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap; final String tooltip; final Color? activeColor;
  const _ToolbarButton({required this.icon, required this.onTap, required this.tooltip, this.activeColor});
  @override Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(onTap: onTap, child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20,
        color: onTap == null ? Colors.white.withOpacity(0.15) : (activeColor ?? Colors.white.withOpacity(0.45))),
    )),
  );
}