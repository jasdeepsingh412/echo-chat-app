import 'package:echo_app/screens/chat_screen.dart';
import 'package:flutter/material.dart';

//reusable chat row widget
class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool isUnread;

  const ChatTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text(name,

        style: TextStyle(fontWeight: isUnread? FontWeight.bold: FontWeight.normal)),

        subtitle: Text(message,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
        ),),

        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
              )
          ],
        ),
    );
  }
}
