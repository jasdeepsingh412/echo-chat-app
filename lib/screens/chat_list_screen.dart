import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    _ensureEchoAIConversation();
  }

  // --- RESTORED ORIGINAL LOGIC ---

  Future<void> _showDeleteDialog({required String chatId}) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Delete chat?",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18)),
        content: Text("This will delete all messages in this chat.",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("CANCEL", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("DELETE", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteConversation(chatId);
    }
  }

  Future<void> _deleteConversation(String chatId) async {
    final firestore = FirebaseFirestore.instance;
    final conversationRef = firestore.collection('conversations').doc(chatId);
    final messagesSnapshot = await conversationRef.collection('messages').get();
    final batch = firestore.batch();
    for (var doc in messagesSnapshot.docs) { batch.delete(doc.reference); }
    batch.delete(conversationRef);
    await batch.commit();
  }

  Future<void> _ensureEchoAIConversation() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [currentUid, 'echo_ai'];
    ids.sort();
    final chatId = ids.join('_');
    final conversationRef = FirebaseFirestore.instance.collection('conversations').doc(chatId);
    final doc = await conversationRef.get();

    if (!doc.exists) {
      await conversationRef.set({
        'participants': [currentUid, 'echo_ai'],
        'lastMessage': 'Start chatting with Echo AI 🤖',
        'lastTimestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // --- UI REDESIGN ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text("Messages",
            style: GoogleFonts.poppins(
                color: const Color(0xFF1D1D28),
                fontWeight: FontWeight.w700,
                fontSize: 28
            )),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.withOpacity(0.1))),
            child: IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF1D1D28), size: 22),
              onPressed: () {},
            ),
          ),
          _buildMoreMenu(context),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: currentUid)
            .orderBy('lastTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildErrorState();
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());

          final conversations = snapshot.data!.docs;
          if (conversations.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversationDoc = conversations[index];
              final conversation = conversationDoc.data() as Map<String, dynamic>;
              final participants = List<String>.from(conversation['participants'])..remove(currentUid);
              final otherUserUid = participants.first;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherUserUid).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final otherUsername = userData['username'] ?? 'User';

                  return _buildConversationTile(
                    context: context,
                    chatId: conversationDoc.id,
                    username: otherUsername,
                    lastMsg: conversation['lastMessage'] ?? '',
                    time: _formatTimestamp(conversation['lastTimestamp'] as Timestamp?),
                    otherUid: otherUserUid,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartChatDialog(context),
        backgroundColor: const Color(0xFF5A57FF),
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: Text("New Chat", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Widget _buildConversationTile({
    required BuildContext context,
    required String chatId,
    required String username,
    required String lastMsg,
    required String time,
    required String otherUid
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserUid: otherUid, otherUserName: username))),
        onLongPress: () => _showDeleteDialog(chatId: chatId),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8E8FF),
              child: Text(username[0].toUpperCase(), style: const TextStyle(color: Color(0xFF5A57FF), fontWeight: FontWeight.bold, fontSize: 20)),
            ),
            if (otherUid == 'echo_ai')
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: Colors.amber, size: 14),
                ),
              )
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(username, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
            Text(time, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    if (now.difference(date).inDays == 1) return "Yesterday";
    return "${date.day}/${date.month}";
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text("No messages yet", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(child: Text("Portal error. Please check your connection."));
  }

  Widget _buildMoreMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Color(0xFF1D1D28)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) async {
        if (value == 'logout') {
          // RESTORED ORIGINAL LOGOUT FUNCTIONALITY
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Log out?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                "You'll need to sign in again to use this app.",
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    "CANCEL",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    "LOG OUT",
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

          if (shouldLogout == true) {
            await FirebaseAuth.instance.signOut();
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'new_group', child: Text('New group')),
        const PopupMenuItem(value: 'new_broadcast', child: Text('New broadcast')),
        const PopupMenuItem(value: 'starred', child: Text('Starred messages')),
        const PopupMenuItem(value: 'settings', child: Text('Settings')),
        const PopupMenuItem(value: 'logout', child: Text('Log out')),
      ],
    );
  }

  void _showStartChatDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Start a Chat", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserUid: 'echo_ai', otherUserName: 'Echo AI')));
              },
              leading: const CircleAvatar(backgroundColor: Color(0xFF5A57FF), child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
              title: Text("Talk to Echo AI", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
              subtitle: const Text("Your personal AI assistant"),
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Enter username",
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
              onPressed: () async {
                final input = controller.text.trim().toLowerCase();
                if (input.isEmpty) return;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .where('usernameLowercase', isEqualTo: input)
                    .get();

                if (!context.mounted) return;
                Navigator.pop(context); // Pop loading
                Navigator.pop(context); // Pop search dialog

                if (query.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User not found")),
                  );
                  return;
                }

                final userDoc = query.docs.first;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      otherUserUid: userDoc.id,
                      otherUserName: userDoc['username'],
                    ),
                  ),
                );
              },
              child: const Text("SEARCH", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A57FF)))
          ),
        ],
      ),
    );
  }
}