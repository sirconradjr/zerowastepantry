import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Login Failed',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  void _showSuccess(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Success',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      _showSuccess("Welcome back!");
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Login failed. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<User?> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled login

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _showSuccess("Signed in successfully with Google!");
      await Future.delayed(const Duration(seconds: 1));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );

      return userCredential.user;
    } catch (e) {
      _showError("Google Sign-In failed: $e");
      return null;
    }
  }

  void _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showError("Please enter your email to reset your password.");
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      AwesomeDialog(
        context: context,
        dialogType: DialogType.info,
        animType: AnimType.scale,
        title: 'Email Sent',
        desc: 'Check your inbox to reset your password.',
        btnOkOnPress: () {},
      ).show();
    } catch (e) {
      _showError("Error sending password reset email: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/zerowaste_logo.png',
                    height: size.height * 0.25),
                const SizedBox(height: 10),
                Text(
                  "Welcome Back!",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFFA500),
                  ),
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetPassword,
                    child: const Text("Forgot Password?",
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA500),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),

                // Google Sign-In Button
                OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: Image.asset('assets/images/google.png', height: 20),
                  label: const Text('Sign In with Google'),
                ),
                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Color(0xFFFFA500),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
