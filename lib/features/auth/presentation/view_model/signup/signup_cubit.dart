import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isd/features/auth/data/auth.dart';
import 'package:isd/features/auth/presentation/view_model/signup/signup_state.dart';

class SignupCubit extends Cubit<SignupState>{
  SignupCubit() : super(SignupInitial());

  Future<void> signUpUser(
    {
    required String email,
    required String password,
    required String username,
    required int contact1,
    required int contact2,
    required int phoneNb,
    required context,
    }
  ) async {
    try {
      final userCredential = await Auth().auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      
      CollectionReference users = FirebaseFirestore.instance.collection('users');
      users
    .doc(userCredential.user!.uid)
    .set({
      'username': username,
      'email': email,
      'password': password,
      'contact1': contact1,
      'contact2': contact2,
      'phoneNb': phoneNb
    });

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.',style: TextStyle(color: Colors.white),),
            duration: Duration(seconds: 3),
            backgroundColor: const Color(0xFF00D1FF),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      Auth().showErrorSnackBar(context, e.message);
    } catch (e) {
      Auth().showErrorSnackBar(context, 'An unexpected error occurred');
    }
  }
}