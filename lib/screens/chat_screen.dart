import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserUid;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserUid,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String chatId;

  bool _isEchoTyping = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final supabase = Supabase.instance.client;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    chatId = _generateChatId(currentUid, widget.otherUserUid);

    // Sign in to Supabase anonymously
    _signInToSupabase();
  }

  Future<void> _signInToSupabase() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        print('🔐 No Supabase session. Signing in anonymously...');
        await supabase.auth.signInAnonymously();
        print('✅ Signed in to Supabase anonymously');
      } else {
        print('✅ Already signed in to Supabase: ${session.user.id}');
      }
    } catch (e) {
      print('❌ Failed to sign in to Supabase: $e');
    }
  }

  String _generateChatId(String uid1, String uid2) {
    final ids = [uid1, uid2];
    ids.sort();
    return ids.join('_');
  }

  // =========================
  // SEND TEXT MESSAGE
  // =========================
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    final conversationRef =
    FirebaseFirestore.instance.collection('conversations').doc(chatId);

    // 1️⃣ Save USER message
    await conversationRef.collection('messages').add({
      'type': 'text',
      'text': text,
      'senderId': currentUid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Update conversation metadata (for chat list preview)
    await conversationRef.set({
      'participants': [currentUid, widget.otherUserUid],
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3️⃣ Clear input field
    _messageController.clear();

    // 4️⃣ If this is Echo AI chat → trigger AI reply
    if (widget.otherUserUid == "echo_ai") {
      // Show "AI is typing..." indicator
      await conversationRef.collection('messages').add({
        'type': 'typing',
        'senderId': 'echo_ai',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _generateEchoAIReply(text);

      // Remove typing indicator after response
    }
  }

  Future<void> _generateEchoAIReply(String userMessage) async {
    final conversationRef =
    FirebaseFirestore.instance.collection('conversations').doc(chatId);

    final apiKey = dotenv.env['GROQ_API_KEY'];

    final history = await _getChatHistory();

    final messages = [
      {
        "role": "system",
        "content":
        "You are Echo AI, a friendly assistant. Remember details shared during conversation."
      },
      ...history,
      {"role": "user", "content": userMessage}
    ];

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": messages,
          "temperature": 0.7
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final aiReply = body["choices"][0]["message"]["content"] ?? "Hmm...";

        await conversationRef.collection('messages').add({
          'type': 'text',
          'text': aiReply,
          'senderId': 'echo_ai',
          'timestamp': FieldValue.serverTimestamp(),
        });

        await conversationRef.set({
          'lastMessage': aiReply,
          'lastTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await _sendFallbackReply(conversationRef);
      }
    } catch (e) {
      await _sendFallbackReply(conversationRef);
    }
  }

  Future<List<Map<String, String>>> _getChatHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(10)
        .get();

    final List<Map<String, String>> history = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['type'] != 'text') continue;

      history.add({
        "role": data['senderId'] == FirebaseAuth.instance.currentUser!.uid
            ? "user"
            : "assistant",
        "content": data['text'] ?? "",
      });
    }

    return history;
  }

  Future<void> _sendFallbackReply(DocumentReference conversationRef) async {
    await conversationRef.collection('messages').add({
      'type': 'text',
      'text': "I'm thinking... try again in a moment 🤖",
      'senderId': 'echo_ai',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =========================
  // SEND IMAGE MESSAGE (SUPABASE)
  // =========================
  Future<void> _sendImage() async {
    if (_isUploading) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    final file = File(pickedFile.path);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final fileExt = pickedFile.path.split('.').last;
    final filePath = 'chat_images/$chatId/$fileName.$fileExt';

    try {
      print('🔄 Starting upload to Supabase...');

      // Check if user is authenticated in Supabase, if not sign in
      final session = supabase.auth.currentSession;
      if (session == null) {
        print('🔐 Not authenticated. Signing in...');
        await supabase.auth.signInAnonymously();
        print('✅ Signed in successfully');
      }

      // Upload to Supabase Storage
      await supabase.storage.from('chat-media').upload(
        filePath,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      print('✅ Upload successful!');

      // Get public URL
      final downloadUrl =
      supabase.storage.from('chat-media').getPublicUrl(filePath);

      print('📷 Image URL: $downloadUrl');

      // Save message to Firebase
      final conversationRef =
      FirebaseFirestore.instance.collection('conversations').doc(chatId);

      await conversationRef.collection('messages').add({
        'type': 'image',
        'mediaUrl': downloadUrl,
        'senderId': currentUid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await conversationRef.set({
        'participants': [currentUid, widget.otherUserUid],
        'lastMessage': '📷 Image',
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Message saved to Firebase');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Image sent successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on StorageException catch (e) {
      print('❌ Supabase Storage Error:');
      print('Message: ${e.message}');
      print('Status Code: ${e.statusCode}');

      String errorMessage = 'Error uploading image';

      if (e.statusCode == '403' || e.statusCode == '401') {
        errorMessage =
        'Storage permission denied. Check bucket policies in Supabase.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        leading: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        title: InkWell(
          onTap: () {
            // Navigate to profile or info screen
          },
          child: Row(
            children: [
              Hero(
                tag: 'avatar_${widget.otherUserUid}',
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text(
                    widget.otherUserName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'tap here for contact info',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              // Handle menu selection
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('View contact')),
              const PopupMenuItem(value: 'media', child: Text('Media, links, and docs')),
              const PopupMenuItem(value: 'search', child: Text('Search')),
              const PopupMenuItem(value: 'mute', child: Text('Mute notifications')),
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // =========================
          // MESSAGE LIST
          // =========================
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade700,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start chatting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;

                    final timestamp = data['timestamp'] as Timestamp?;
                    String timeString = '';

                    if (timestamp != null) {
                      final date = timestamp.toDate();
                      timeString =
                      "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                    }

                    // TYPING INDICATOR
                    if (data['type'] == 'typing') {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 1,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 40,
                                    height: 18,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: List.generate(
                                        3,
                                            (index) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 400),
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade500,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // IMAGE MESSAGE
                    if (data['type'] == 'image') {
                      return Align(
                        alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 8,
                          ),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    data['mediaUrl'],
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 280,
                                        height: 280,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                .expectedTotalBytes !=
                                                null
                                                ? loadingProgress
                                                .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                                : null,
                                            valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 280,
                                        height: 280,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image_outlined,
                                              size: 48,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Failed to load',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (timeString.isNotEmpty)
                                  Positioned(
                                    bottom: 6,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            timeString,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.done_all,
                                              size: 14,
                                              color: Colors.blue,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // TEXT MESSAGE
                    return MessageBubble(
                      message: data['text'] ?? '',
                      isMe: isMe,
                      time: timeString,
                    );
                  },
                );
              },
            ),
          ),

          // =========================
          // INPUT BAR
          // =========================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.grey.shade100,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                // Show emoji picker
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onSubmitted: (_) => _sendMessage(),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: null,
                              decoration: const InputDecoration(
                                hintText: "Message",
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 10,
                                ),
                              ),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: _isUploading ? null : _sendImage,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _isUploading
                                    ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                      Colors.blue.shade700,
                                    ),
                                  ),
                                )
                                    : Icon(
                                  Icons.attach_file,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.grey.shade600,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(28),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _sendMessage,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}