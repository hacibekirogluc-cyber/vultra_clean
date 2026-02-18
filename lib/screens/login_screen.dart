import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../main.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  final Color primaryBlue = const Color(0xFF4361EE);
  final Color bgDark = const Color(0xFF0A0A0A);

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // Google hesabı seçtir
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // kullanıcı iptal etti

      // Token al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase ile giriş
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!context.mounted) return;

      // Ana sayfaya geç
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootShell()),
        (_) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google giriş hatası: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(radius: 200, backgroundColor: primaryBlue.withOpacity(0.05)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // LOGO
                  Hero(
                    tag: 'logo',
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(color: primaryBlue.withOpacity(0.2), blurRadius: 40, spreadRadius: 5)
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/logos/app_icon.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Vultra Finance",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Finansal verilerini tüm cihazlarında\ngüvende tut.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // APPLE GİRİŞ (şimdilik placeholder)
                  _authButton(
                    context,
                    label: "Apple ile Devam Et",
                    icon: FontAwesomeIcons.apple,
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => debugPrint("Apple login (sonra bağlayacağız)"),
                  ),
                  const SizedBox(height: 16),

                  // GOOGLE GİRİŞ (ARTIK ÇALIŞIR)
                  _authButton(
                    context,
                    label: "Google ile Devam Et",
                    icon: FontAwesomeIcons.google,
                    color: const Color(0xFF1F1F1F),
                    textColor: Colors.white,
                    isBordered: true,
                    onTap: () => _signInWithGoogle(context),
                  ),
                  const SizedBox(height: 16),

                  // MAIL İLE GİRİŞ
                  _authButton(
                    context,
                    label: "Mail ile Devam Et",
                    icon: FontAwesomeIcons.envelope,
                    color: const Color(0xFF1F1F1F),
                    textColor: Colors.white,
                    isBordered: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // TELEFON İLE GİRİŞ
                  _authButton(
                    context,
                    label: "Telefon ile Giriş Yap",
                    icon: FontAwesomeIcons.phone,
                    color: primaryBlue,
                    textColor: Colors.white,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
                      );
                    },
                  ),

                  const Spacer(),

                  // ALT METİN
                  Text(
                    "Giriş yaparak kullanım koşullarını kabul etmiş olursunuz.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 11),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    bool isBordered = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: FaIcon(icon, size: 20, color: textColor),
        label: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          backgroundColor: color,
          side: isBordered ? const BorderSide(color: Colors.white10) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

// -------------------- MAIL AUTH SCREEN --------------------
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _isLogin = true; // true: giriş, false: kayıt
  bool _loading = false;

  final Color primaryBlue = const Color(0xFF4361EE);
  final Color bgDark = const Color(0xFF0A0A0A);

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email ve şifre boş olamaz.")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pass);
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootShell()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Hata: ${e.code}";
      if (e.code == "user-not-found") msg = "Bu email ile kullanıcı yok.";
      if (e.code == "wrong-password") msg = "Şifre yanlış.";
      if (e.code == "email-already-in-use") msg = "Bu email zaten kayıtlı.";
      if (e.code == "weak-password") msg = "Şifre çok zayıf (en az 6 karakter).";
      if (e.code == "invalid-email") msg = "Email formatı hatalı.";

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifre sıfırlamak için email gir.")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifre sıfırlama maili gönderildi.")),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mail gönderilemedi. Email doğru mu?")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLogin ? "Mail ile\nGiriş Yap" : "Mail ile\nKayıt Ol",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Email ve şifrenle devam et.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 30),

            _field(controller: _email, hint: "Email", isPass: false),
            const SizedBox(height: 16),
            _field(controller: _pass, hint: "Şifre", isPass: true),

            const SizedBox(height: 10),
            if (_isLogin)
              TextButton(
                onPressed: _resetPassword,
                child: const Text("Şifremi unuttum", style: TextStyle(color: Colors.white70)),
              ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _loading ? null : _submit,
                child: Text(
                  _loading ? "Lütfen bekle..." : (_isLogin ? "GİRİŞ YAP" : "KAYIT OL"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),

            Center(
              child: TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? "Hesabın yok mu? Kayıt ol" : "Zaten hesabın var mı? Giriş yap",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required bool isPass}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        keyboardType: isPass ? TextInputType.visiblePassword : TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

// -------------------- TELEFON DOĞRULAMA EKRANI --------------------
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final Color primaryBlue = const Color(0xFF4361EE);
  final Color bgDark = const Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Telefon Numaranı\nDoğrula",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Sana 6 haneli bir doğrulama kodu göndereceğiz.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Text("🇹🇷 +90",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "5XX XXX XX XX",
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => _showOTPSheet(),
                child: const Text(
                  "KOD GÖNDER",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showOTPSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 30,
          right: 30,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 30),
            Text("Doğrulama Kodu",
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("${_phoneController.text} numarasına gelen kodu girin.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _otpBox()),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RootShell()));
                },
                child: Text("DOĞRULA VE GİRİŞ YAP",
                    style: TextStyle(color: bgDark, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _otpBox() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: const TextField(
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(counterText: "", border: InputBorder.none),
      ),
    );
  }
}
