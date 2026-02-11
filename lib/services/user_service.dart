import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {

  //creates user doc in firestore
  //if it does not already exist

  Future<void> createUserIfNotExist() async {

    //get current logged in user
    final user = FirebaseAuth.instance.currentUser;


    //if somehow no user is logged in, stop

    if (user == null) return;

    //ref to this users doc
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    //check if doc already exists

    if (!docSnapshot.exists) {

      // Create new document
      await userDoc.set({
        'username': '', // initially empty
        'usernameLowercase': '',
        'createdAt': Timestamp.now(),
      });
    }
  }
}