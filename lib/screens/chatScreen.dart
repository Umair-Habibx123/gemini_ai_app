import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gemini_ai/DB/SQLiteHelper.dart';
import 'package:gemini_ai/main.dart';
import 'package:gemini_ai/widgets/AppBar.dart';
import 'package:gemini_ai/widgets/ImagePreview.dart';
import 'package:gemini_ai/widgets/InputArea.dart';
import 'package:gemini_ai/widgets/MessageList.dart';
import 'package:gemini_ai/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final int? chatId;
  final String? chatName;
  const ChatScreen({super.key, this.chatId, this.chatName});
  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AttachedFile> _attachedFiles = [];
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  int? _currentChatId;
  ChatSession? _chatSession;
  bool _isStreaming = false;
  String _streamingResponse = '';
  final List<Content> _chatHistory = [];
  bool _isFirstAttempt = true;

  late GenerativeModel _model;

  // Add this to your state variables
  int _currentModelIndex = 0; // tracks which fallback we're on at runtime
  int _selectedModelIndex = 0; // the model the user explicitly chose
  final Set<int> _triedModels = {}; // models already attempted this turn

  String get _activeModel => geminiModels[_currentModelIndex];

  // Replace initState model setup
  @override
  void initState() {
    super.initState();
    _currentModelIndex = 0;
    _selectedModelIndex = 0;
    _buildModel(_activeModel);
    _currentChatId = widget.chatId;
    if (_currentChatId != null) {
      _loadMessages(_currentChatId!);
    } else {
      _startFreshSession();
    }
  }

  void _buildModel(String modelName) {
    _model = GenerativeModel(
      model: modelName,
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        maxOutputTokens: 8192,
        temperature: 1.0,
      ),
      // System instruction (current Gemini API feature) — steers every reply
      // toward clean, well-structured Markdown so the in-app renderer shows a
      // polished, chat-bot style answer instead of a wall of text.
      systemInstruction: Content.system(
        'You are Gemini AI, a friendly and helpful assistant. '
        'Always format answers in clear GitHub-flavored Markdown: use short '
        'paragraphs, **bold** for key terms, bullet or numbered lists for steps, '
        '`inline code` for identifiers, fenced code blocks (with the language) '
        'for code, and tables when comparing things. Keep replies concise and '
        'easy to read for non-technical users.',
      ),
    );
    debugPrint('🤖 Active model: $modelName'); // ✅ console log
    if (mounted) setState(() => geminiModel = modelName);
  }

  // ─── Model switching (keeps full chat + context) ───────────────

  /// Switch to another available model WITHOUT losing the conversation.
  /// The chat session is rebuilt from [_chatHistory], so the new model picks
  /// up with the entire prior context intact.
  void _switchModel(int index) {
    if (index == _selectedModelIndex || _isLoading) return;
    _selectedModelIndex = index;
    _currentModelIndex = index;
    _buildModel(geminiModels[index]);
    _startFreshSession(); // re-seed the new model with existing history
    if (mounted) {
      _showSnackBar(
        'Switched to ${geminiModels[index]} · chat history kept',
        const Color(0xFF00B392),
      );
    }
  }

  void _showModelPicker() {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          margin: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: 12 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 18, color: c.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Choose AI Model',
                        style: GoogleFonts.dmSans(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your conversation stays — only the model changes.',
                      style: GoogleFonts.dmSans(
                        color: c.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                ...List.generate(geminiModels.length, (i) {
                  final isActive = i == _selectedModelIndex;
                  return ListTile(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _switchModel(i);
                    },
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: isActive ? c.brandGradient : null,
                        color: isActive ? null : c.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 18,
                        color: isActive ? Colors.white : c.primary,
                      ),
                    ),
                    title: Text(
                      geminiModels[i],
                      style: GoogleFonts.dmSans(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      i == 0 ? 'Default · first choice' : 'Fallback option',
                      style: GoogleFonts.dmSans(
                        color: c.textFaint,
                        fontSize: 11,
                      ),
                    ),
                    trailing:
                        isActive
                            ? Icon(
                              Icons.check_circle_rounded,
                              color: c.secondary,
                              size: 20,
                            )
                            : Icon(
                              Icons.circle_outlined,
                              color: c.textFaint,
                              size: 20,
                            ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Session ───────────────────────────────────────────────────

  void _startFreshSession() {
    _chatSession = _model.startChat(history: List.from(_chatHistory));
  }

  Future<void> _loadMessages(int chatId) async {
    final messages = await ChatDatabaseHelper.instance.getMessages(chatId);
    if (mounted)
      setState(() {
        _messages.clear();
        _chatHistory.clear();
      });
    for (final msg in messages) {
      final text = msg['text'] as String;
      final type = msg['type'] as String;
      // Only text + response go into Gemini history (files not stored as binary)
      if (type == 'text') _chatHistory.add(Content.text(text));
      if (type == 'response') _chatHistory.add(Content.model([TextPart(text)]));
      if (mounted) setState(() => _messages.add({'text': text, 'type': type}));
    }
    _startFreshSession();
  }

  // ─── File picking ──────────────────────────────────────────────

  /// Request storage/media permission for the given file type
  /// Handles both Android 13+ (granular) and older (READ_EXTERNAL_STORAGE)
  Future<bool> _requestStoragePermission(String type) async {
    if (!Platform.isAndroid) return true;

    final sdkInt = await _getAndroidSdkVersion();

    Permission permission;
    if (sdkInt >= 33) {
      // Android 13+ — granular media permissions
      if (type == 'video')
        permission = Permission.videos;
      else if (type == 'audio')
        permission = Permission.audio;
      else
        permission = Permission.manageExternalStorage; // pdf fallback
    } else {
      // Android 12 and below — legacy storage permission
      permission = Permission.storage;
    }

    var status = await permission.status;
    if (status.isGranted) return true;

    status = await permission.request();
    if (status.isGranted) return true;

    if (mounted) {
      if (status.isPermanentlyDenied) {
        _showSnackBar(
          'Permission denied permanently. Enable in app Settings.',
          Colors.red.shade700,
        );
        await openAppSettings();
      } else {
        _showSnackBar('Storage permission denied.', Colors.red.shade700);
      }
    }
    return false;
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 30; // safe fallback
    }
  }

  /// Copies a picked/recorded file into permanent app storage so it stays
  /// playable/openable later — even after the OS clears the temp cache or the
  /// chat is reopened in a future session. Returns the new persistent path
  /// (falls back to the original path if copying fails).
  Future<String> _persistFile(String srcPath, String type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${dir.path}/media');
      if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
      final ext = srcPath.contains('.') ? srcPath.split('.').last : type;
      final dest =
          '${mediaDir.path}/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(srcPath).copy(dest);
      return dest;
    } catch (e) {
      debugPrint('_persistFile error: $e');
      return srcPath;
    }
  }

  /// Called from InputArea via onPickFile(type)
  Future<void> _pickFile(String type) async {
    try {
      if (type == 'image') {
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (picked != null && mounted) {
          final stored = await _persistFile(picked.path, 'image');
          setState(
            () => _attachedFiles.add(
              AttachedFile(file: XFile(stored), type: 'image'),
            ),
          );
        }
        return;
      }

      // Only media types need a runtime permission. PDF and generic files go
      // through Android's Storage Access Framework picker, which grants access
      // to the chosen file without any permission prompt.
      if (type == 'video' || type == 'audio') {
        final granted = await _requestStoragePermission(type);
        if (!granted) return;
      }

      FileType fileType;
      List<String>? extensions;
      switch (type) {
        case 'video':
          fileType = FileType.video;
          break;
        case 'audio':
          fileType = FileType.audio;
          break;
        case 'pdf':
          fileType = FileType.custom;
          extensions = ['pdf'];
          break;
        case 'file':
          fileType = FileType.any; // any file type — documents, code, archives
          break;
        default:
          return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: extensions,
        allowCompression: false,
        withData: true,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;
      final pf = result.files.single;

      String filePath;
      if (pf.path != null) {
        filePath = pf.path!;
      } else if (pf.bytes != null) {
        final dir = await getTemporaryDirectory();
        final ext = pf.extension ?? type;
        final name =
            pf.name.isNotEmpty
                ? pf.name
                : 'file_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final tmp = File('${dir.path}/$name');
        await tmp.writeAsBytes(pf.bytes!);
        filePath = tmp.path;
      } else {
        _showSnackBar(
          'Could not read file. Try a different file.',
          Colors.red.shade700,
        );
        return;
      }

      final stored = await _persistFile(filePath, type);
      if (mounted)
        setState(
          () => _attachedFiles.add(
            AttachedFile(file: XFile(stored), type: type),
          ),
        );
    } catch (e, stack) {
      debugPrint('_pickFile error: $e\n$stack');
      _showSnackBar(
        'Could not pick file: ${e.toString()}',
        Colors.red.shade700,
      );
    }
  }

  /// Called when InputArea finishes a voice recording
  Future<void> _onAudioRecorded(String path) async {
    final stored = await _persistFile(path, 'audio');
    if (mounted)
      setState(
        () => _attachedFiles.add(
          AttachedFile(file: XFile(stored), type: 'audio'),
        ),
      );
  }

  /// Scrolls the (reversed) message list to the newest message. Offset 0 is the
  /// bottom because the ListView is reversed. Waits a frame so it runs after the
  /// keyboard has resized the viewport.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// Called when suggestion chip tapped — fill controller
  void _onSuggestionTap(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  // ─── MIME resolution ───────────────────────────────────────────

  /// Returns the correct MIME type string for the Gemini API
  String _mimeType(AttachedFile f) {
    final ext = f.path.split('.').last.toLowerCase();
    return switch (f.type) {
      'image' => switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      },
      'video' => switch (ext) {
        'mp4' => 'video/mp4',
        'mpeg' => 'video/mpeg',
        'mov' => 'video/mov',
        'avi' => 'video/avi',
        'flv' => 'video/x-flv',
        'webm' => 'video/webm',
        'wmv' => 'video/wmv',
        '3gp' => 'video/3gpp',
        _ => 'video/mp4',
      },
      'audio' => switch (ext) {
        'mp3' => 'audio/mp3',
        'wav' => 'audio/wav',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        'flac' => 'audio/flac',
        'm4a' => 'audio/m4a',
        _ => 'audio/mp3',
      },
      'pdf' => 'application/pdf',
      // Generic files — map common document/code/text extensions so Gemini can
      // actually read them; fall back to plain text, then octet-stream.
      'file' => switch (ext) {
        'pdf' => 'application/pdf',
        'txt' || 'log' || 'ini' || 'env' => 'text/plain',
        'md' => 'text/md',
        'csv' => 'text/csv',
        'json' => 'application/json',
        'xml' => 'text/xml',
        'html' || 'htm' => 'text/html',
        'css' => 'text/css',
        'js' => 'application/x-javascript',
        'py' => 'text/x-python',
        'rtf' => 'text/rtf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mp3' => 'audio/mp3',
        'wav' => 'audio/wav',
        'mp4' => 'video/mp4',
        _ => 'text/plain',
      },
      _ => 'application/octet-stream',
    };
  }

  // ─── Send message ──────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _attachedFiles.isEmpty) {
      _showAlert('Please enter a message or attach a file.');
      return;
    }

    // ✅ Start each new message from the user's chosen model; fallback then
    // tries any other model if that one is overloaded/unavailable.
    _currentModelIndex = _selectedModelIndex;
    _triedModels.clear();
    _buildModel(_activeModel);
     _isFirstAttempt = true;    

     setState(() {
    _isLoading = true;
    _isStreaming = true;
    _streamingResponse = '';
  });

    final filesCopy = List<AttachedFile>.from(_attachedFiles);
    final msgCopy = message;

    final parts = <Part>[];
    if (msgCopy.isNotEmpty) parts.add(TextPart(msgCopy));
    for (final f in filesCopy) {
      final bytes = await File(f.path).readAsBytes();
      parts.add(DataPart(_mimeType(f), bytes));
    }

    await _sendWithFallback(msgCopy, filesCopy, parts);
  }

  Future<void> _sendWithFallback(
  String msgCopy,
  List<AttachedFile> filesCopy,
  List<Part> parts,
) async {
  try {
    final chatId = _currentChatId ?? await _createNewChat();

    // ✅ Only persist + add UI messages on the very first attempt
    if (_isFirstAttempt) {
      _isFirstAttempt = false; // ✅ flip immediately so retries skip this

      if (msgCopy.isNotEmpty) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId,
          'text': msgCopy,
          'type': 'text',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      for (final f in filesCopy) {
        await ChatDatabaseHelper.instance.insertMessage({
          'chat_id': chatId,
          'text': f.path,
          'type': f.type,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        if (msgCopy.isNotEmpty) {
          _messages.add({'text': msgCopy, 'type': 'text'});
        }
        for (final f in filesCopy)
          _messages.add({'text': f.path, 'type': f.type});
        _messages.add({'text': '', 'type': 'response'}); // placeholder
      });

      _controller.clear();
      _attachedFiles.clear();
      _scrollToBottom();
    }

    final responseIndex = _messages.lastIndexWhere(
      (m) => m['type'] == 'response',
    );

    // Rebuild session with current model
    _triedModels.add(_currentModelIndex);
    _startFreshSession();
    debugPrint('📡 Sending with model: ${geminiModels[_currentModelIndex]}');

    final stream = _chatSession!.sendMessageStream(Content.multi(parts));

    await for (final chunk in stream) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty && mounted) {
        setState(() {
          _streamingResponse += text;
          _messages[responseIndex] = {
            'text': _streamingResponse,
            'type': 'response',
          };
        });
      }
    }

    if (_streamingResponse.isEmpty && mounted) {
      setState(() {
        _messages[responseIndex] = {
          'text': '_(No response — the model returned empty output.)_',
          'type': 'response',
        };
      });
    }

    await ChatDatabaseHelper.instance.insertMessage({
      'chat_id': chatId,
      'text': _streamingResponse,
      'type': 'response',
      'created_at': DateTime.now().toIso8601String(),
    });

    // ✅ Commit this turn to context only AFTER a successful response, so a
    // mid-stream fallback to another model never duplicates the user message.
    if (msgCopy.isNotEmpty) _chatHistory.add(Content.text(msgCopy));
    _chatHistory.add(Content.model([TextPart(_streamingResponse)]));

  } on GenerativeAIException catch (e) {
    // Find the next model we haven't tried yet (in priority order), regardless
    // of where the user's selected model sits in the list.
    final nextIndex = _nextUntriedModel();
    if (_shouldFallback(e) && nextIndex != null) {
      final failed = geminiModels[_currentModelIndex];
      _currentModelIndex = nextIndex;
      final nextModel = geminiModels[nextIndex];
      debugPrint('⚠️ Model $failed failed → trying $nextModel (${_triedModels.length}/${geminiModels.length})');
      _buildModel(nextModel);
      await _sendWithFallback(msgCopy, filesCopy, parts);
    } else {
      debugPrint('❌ All ${geminiModels.length} models exhausted. Last error: ${e.message}');
      _handleAiError(e);
    }
  } catch (e, stack) {
    debugPrint('_sendMessage error: $e\n$stack');
    _showSnackBar('Error: $e', Colors.red.shade700);
  } finally {
    if (mounted)
      setState(() {
        _isLoading = false;
        _isStreaming = false;
      });
  }
}

  /// Returns the next model index (in priority order) that hasn't been tried
  /// yet this turn, or null if every model has been attempted.
  int? _nextUntriedModel() {
    for (var i = 0; i < geminiModels.length; i++) {
      if (!_triedModels.contains(i)) return i;
    }
    return null;
  }

  /// Returns true if the error is worth retrying on a different model
  bool _shouldFallback(GenerativeAIException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('high demand') ||
        msg.contains('temporarily') ||
        msg.contains('overloaded') ||
        msg.contains('503') ||
        msg.contains('quota') ||
        msg.contains('rate') ||
        msg.contains('not found') ||
        msg.contains('404');
  }

  // ─── Chat management ───────────────────────────────────────────

  Future<int> _createNewChat() async {
    final chats = await ChatDatabaseHelper.instance.getChats();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final label = '${_generateRandomString(6)}-${chats.length + 1}';
    final newId = await ChatDatabaseHelper.instance.insertChat({
      'name': 'Chat $label',
      'created_at': now,
    });
    if (mounted)
      setState(() {
        _currentChatId = newId;
        _chatHistory.clear();
      });
    _startFreshSession();
    return newId;
  }

  void _createNewChatByDrawer() {
    setState(() {
      _currentChatId = null;
      _messages.clear();
      _chatHistory.clear();
      _attachedFiles.clear();
    });
    _startFreshSession();
  }

  String _generateRandomString(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ),
    );
  }

  // ─── Error handling ────────────────────────────────────────────

  void _handleAiError(GenerativeAIException e) {
    debugPrint('GenerativeAIException: ${e.message}');
    final msg = e.message.toLowerCase();
    String friendly;
    if (msg.contains('api_key') || msg.contains('permission')) {
      friendly = 'Invalid API key. Check your .env file.';
    } else if (msg.contains('quota') || msg.contains('rate')) {
      friendly = 'Rate limit hit. Wait a moment, or switch model in .env';
    } else if (msg.contains('high demand') || msg.contains('temporarily')) {
      // ✅ catch this first
      friendly =
          'Gemini is experiencing high demand. Please try again in a moment.';
    } else if (msg.contains('not found') || msg.contains('404')) {
      // ✅ removed 'model'
      friendly =
          'Model "${geminiModel ?? 'unknown'}" not accessible with your API key.';
    } else if (msg.contains('size') ||
        msg.contains('too large') ||
        msg.contains('limit')) {
      friendly = 'File too large for the API. Try a smaller file.';
    } else {
      friendly = 'Gemini error: ${e.message}'; // ✅ fallback shows real message
    }
    _showSnackBar(friendly, Colors.red.shade700);
  }

  // ─── Helpers ───────────────────────────────────────────────────

  void _showAlert(String message) {
    final c = context.colors;
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Notice',
              style: GoogleFonts.dmSans(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              message,
              style: GoogleFonts.dmSans(
                color: c.textSecondary,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.dmSans(color: c.primary),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      resizeToAvoidBottomInset: true,
      appBar: ChatAppBar(
        onExit: () => exit(1),
        chatName: widget.chatName,
        modelName: geminiModel, // ✅ pass it down
        onSwitchModel: geminiModels.length > 1 ? _showModelPicker : null,
      ),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: MessageList(
                  messages: _messages,
                  isStreaming: _isStreaming,
                  onSuggestionTap: _onSuggestionTap,
                  controller: _scrollController,
                ),
              ),
            ),
            if (_attachedFiles.isNotEmpty)
              ImagePreviewList(
                files: _attachedFiles,
                onRemove: (i) => setState(() => _attachedFiles.removeAt(i)),
              ),
            InputArea(
              controller: _controller,
              isLoading: _isLoading,
              onPickFile: _pickFile,
              onSendMessage: _sendMessage,
              onAudioRecorded: _onAudioRecorded,
              onInputFocused: _scrollToBottom,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Drawer ────────────────────────────────────────────────────

  Widget _buildDrawer() {
    final c = context.colors;
    return Drawer(
      backgroundColor: c.surfaceAlt,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: c.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: c.primary.withOpacity(0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gemini AI',
                  style: GoogleFonts.dmSans(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  geminiModel ?? 'unknown',
                  style: GoogleFonts.dmSans(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _createNewChatByDrawer();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: c.brandGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: c.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Chat',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: ChatDatabaseHelper.instance.getChats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: c.primary,
                      strokeWidth: 2,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: GoogleFonts.dmSans(
                        color: c.textFaint,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final chat = snapshot.data![index];
                    final isActive = _currentChatId == chat['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? c.primary.withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isActive
                                  ? c.primary.withOpacity(0.3)
                                  : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? c.primary.withOpacity(0.2)
                                    : c.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: isActive ? c.primary : c.textFaint,
                          ),
                        ),
                        title: Text(
                          chat['name'],
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                isActive ? c.textPrimary : c.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          chat['created_at'] ?? '',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: c.textFaint,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () => _confirmDeleteChat(chat),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: c.textFaint,
                          ),
                        ),
                        onTap:
                            () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatScreen(
                                      chatId: chat['id'],
                                      chatName: chat['name'],
                                    ),
                              ),
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(Map<String, dynamic> chat) {
    final c = context.colors;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Delete Chat',
              style: GoogleFonts.dmSans(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Text(
              'This will permanently delete this chat and all its messages.',
              style: GoogleFonts.dmSans(
                color: c.textSecondary,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(color: c.textFaint),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await ChatDatabaseHelper.instance.deleteChat(chat['id']);
                  if (mounted) Navigator.pop(context);
                  setState(() {
                    if (_currentChatId == chat['id']) {
                      _currentChatId = null;
                      _messages.clear();
                      _chatHistory.clear();
                      _attachedFiles.clear();
                      _startFreshSession();
                    }
                  });
                },
                child: Text(
                  'Delete',
                  style: GoogleFonts.dmSans(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
  }
}
