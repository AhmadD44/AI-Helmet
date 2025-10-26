import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isd/features/auth/data/auth.dart';
import 'package:isd/features/auth/presentation/view_model/login/login_state.dart';

class LoginCubit extends Cubit<LoginState>{
  LoginCubit() : super(LoginInitial());

  Future<void> loginUser({required String email, required String password, required context}) async{
    emit(LoginLoading());
    try {
      final userCredential = await Auth().auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await Auth().auth.signOut(); // Optional: Sign them out immediately
        Auth().showErrorSnackBar(context, "Please verify your email before signing in.");
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signed in successfully!',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: const Color(0xFF00D1FF),
        ),
      );
      emit(LoginSuccess());
    } on FirebaseAuthException catch (e) {
      Auth().showErrorSnackBar(context, e.message ?? 'Auth error');
      emit(LoginFailure());
    } catch (e) {
      Auth().showErrorSnackBar(context, 'An unexpected error occurred');
      emit(LoginFailure());
    }
  }
}