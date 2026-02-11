# Echo - Real-Time Chat App

Echo is a modern real-time chat application built with Flutter.

It combines Firebase for authentication and messaging with Supabase Storage for media handling, demonstrating a hybrid backend architecture.

---

## 🚀 Features

- Firebase Authentication
- Real-time messaging with Cloud Firestore
- Image messaging via Supabase Storage
- Anonymous Supabase session handling
- Clean modern UI with SliverAppBar design
- Conversation metadata tracking
- Username-based chat initiation

---

## 🏗 Architecture

Frontend:
- Flutter (Dart)

Backend Services:
- Firebase Auth (user authentication)
- Firebase Firestore (real-time chat database)
- Supabase Storage (media storage)

Design Choice:
Text data is stored in Firestore for real-time sync.
Media is stored in Supabase Storage for scalable object handling.

This separation demonstrates multi-service backend integration.

---

## 📂 Project Structure

lib/
- screens/
- widgets/
- services/

---

## 🔐 Environment Setup

Create a `.env` file in root:

SUPABASE_URL=your_url
SUPABASE_ANON_KEY=your_key

---

## 📸 Screenshots

(Add screenshots here later)

---

## 🧠 Why This Project Matters

This project demonstrates:
- Real-time systems
- Cross-service integration
- State management in Flutter
- Backend rule handling
- Production-style folder structure

---

## 📌 Future Improvements

- Read receipts
- Online presence tracking
- Push notifications
- Message reactions
- End-to-end encryption

---

## 👨‍💻 Author

Built by Jasdeep Singh
