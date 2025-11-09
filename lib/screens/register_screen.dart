import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  void _showDialog(String title, String message, DialogType type) {
    AwesomeDialog(
      context: context,
      dialogType: type,
      animType: AnimType.scale,
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  Future<void> _registerWithEmailPassword() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showDialog('Error', 'Please fill in all fields.', DialogType.error);
      return;
    }

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      _showDialog('Error', 'Passwords do not match.', DialogType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      _showDialog('Success', 'Registration successful!', DialogType.success);
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showDialog('Error', e.message ?? 'Registration failed', DialogType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      await _auth.signInWithCredential(credential);

      _showDialog('Success', 'Google Sign-Up successful!', DialogType.success);
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      _showDialog('Error', 'Google Sign-Up failed: $e', DialogType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.12),
            Image.asset('assets/images/zerowaste_logo.png',
                height: size.height * 0.18),
            const SizedBox(height: 20),
            Text(
              'Create an Account',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerWithEmailPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: const [
                Expanded(child: Divider(thickness: 1)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("or"),
                ),
                Expanded(child: Divider(thickness: 1)),
              ],
            ),
            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: _signUpWithGoogle,
              icon: Image.asset('assets/images/google.png', height: 20),
              label: const Text('Sign up with Google'),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? "),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
