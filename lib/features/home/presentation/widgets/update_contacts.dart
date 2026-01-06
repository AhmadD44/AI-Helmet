import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContactsScreen extends StatefulWidget {
   // Pass the logged-in user's UID

  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();
  bool _isLoading = true;

  

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final user = FirebaseAuth.instance.currentUser; 
    final userId = user!.uid;

    final docRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      _contact1Controller.text = snapshot.data()?['contact1'] ?? '';
      _contact2Controller.text = snapshot.data()?['contact2'] ?? '';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveContacts() async {
    setState(() {
      _isLoading = true;
    });
    final user = FirebaseAuth.instance.currentUser; 
    final userId = user!.uid;


    final docRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
    await docRef.update({
      'contact1': _contact1Controller.text.trim(),
      'contact2': _contact2Controller.text.trim(),
    });

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contacts updated successfully!')),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    const borderColor = Color(0xFF00D1FF);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: borderColor),
      filled: true,
      fillColor: const Color(0xFF1B2236),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white70),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    controller: _contact1Controller,
                    decoration: _inputDecoration('Contact 1', Icons.phone),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contact2Controller,
                    decoration: _inputDecoration('Contact 2', Icons.phone),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveContacts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Center(child: Text('Save Contacts')),
                  ),
                ],
              ),
            ),
    );
  }
}