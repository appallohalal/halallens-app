import 'package:flutter/material.dart';
import 'login_screen.dart';
export 'login_screen.dart';
export 'register_screen.dart';

/// Legacy bridge pointing to the separate LoginScreen
class AuthScreen extends StatelessWidget {
  final bool isMandatory;
  final VoidCallback? onSuccess;

  const AuthScreen({
    super.key,
    this.isMandatory = false,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      isMandatory: isMandatory,
      onSuccess: onSuccess,
    );
  }
}
