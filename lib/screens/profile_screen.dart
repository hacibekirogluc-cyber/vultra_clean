import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  File? _image;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Verileri ve Fotoğraf Yolunu Yükle
  void _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = user?.displayName ?? prefs.getString('user_name') ?? "";
      _emailController.text = user?.email ?? prefs.getString('user_email') ?? "";
      _imagePath = prefs.getString('profile_image_path');
      if (_imagePath != null) {
        _image = File(_imagePath!);
      }
    });
  }

  // --- FOTOĞRAF SEÇ VE KAYDET ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500);
    
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _image = File(pickedFile.path);
        _imagePath = pickedFile.path;
      });
      // Fotoğraf yolunu kalıcı olarak kaydet
      await prefs.setString('profile_image_path', pickedFile.path);
    }
  }

  // --- PROFİL GÜNCELLEME ---
  Future<void> _updateProfile() async {
    try {
      await user?.updateDisplayName(_nameController.text);
      if (_emailController.text != user?.email) {
        await user?.updateEmail(_emailController.text);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text);
      await prefs.setString('user_email', _emailController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil güncellendi! ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: ${e.toString()}")));
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link açılamadı.")));
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hesabı Sil"),
        content: const Text("Tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          TextButton(
            onPressed: () async {
              try {
                await user?.delete();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeniden giriş yapmalısınız.")));
              }
            },
            child: const Text("Verilerimi Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF4361EE);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(primaryBlue),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("HESAP BİLGİLERİ"),
                  _buildInputCard(),
                  
                  const SizedBox(height: 25),
                  _buildSaveButton(primaryBlue),
                  
                  const SizedBox(height: 40),
                  _buildSectionTitle("YASAL & DOKÜMANTASYON"),
                  _buildModernItem("Gizlilik Politikası", CupertinoIcons.doc_text, Colors.blue, () {
                    _launchURL("https://doc-hosting.flycricket.io/vultra-privacy-policy/3de41148-a0ba-45f7-adb7-ba6fd75a82eb/privacy");
                  }),
                  _buildModernItem("Kullanım Koşulları", CupertinoIcons.shield, Colors.blueGrey, () {
                    _launchURL("https://doc-hosting.flycricket.io/vultra-terms-of-use/7a585d76-0157-4511-a0f5-7f66795ecaf4/terms");
                  }),

                  const SizedBox(height: 30),
                  const Divider(),
                  
                  ListTile(
                    onTap: _showDeleteAccountDialog,
                    leading: const Icon(CupertinoIcons.person_badge_minus, color: Colors.redAccent),
                    title: const Text("Hesabımı Sil", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                  ),

                  Center(
                    child: TextButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false)),
                      icon: const Icon(Icons.logout, color: Colors.grey),
                      label: const Text("Oturumu Kapat", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Color color) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: color,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft),
          ),
          child: Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  backgroundImage: _image != null ? FileImage(_image!) : null,
                  child: _image == null ? const Icon(CupertinoIcons.person_fill, size: 50, color: Colors.white) : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.camera_alt, size: 20, color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "İsim", prefixIcon: Icon(CupertinoIcons.person), border: InputBorder.none),
          ),
          const Divider(),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: "E-posta", prefixIcon: Icon(CupertinoIcons.mail), border: InputBorder.none),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _updateProfile,
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text("KAYDET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildModernItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}