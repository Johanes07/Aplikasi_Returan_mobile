import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:returan_apps/screens/list_retur.dart';
import 'package:returan_apps/screens/profil_ttd.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:returan_apps/db/retur_db.dart';
import 'package:returan_apps/model/retur_model.dart';
import 'package:returan_apps/utils/printer_service.dart';
import 'login_page.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FormReturPage extends StatefulWidget {
  const FormReturPage({super.key});

  @override
  State<FormReturPage> createState() => _FormReturPageState();
}

class _FormReturPageState extends State<FormReturPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaToko = TextEditingController();
  final _namaIT = TextEditingController();
  final _namaBarang = TextEditingController();
  final _keterangan = TextEditingController();
  final _snBarang = TextEditingController();
  final _nomorDokumen = TextEditingController();

  String _kategori = 'OK';
  String _tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Uint8List? _ttdImage;
  File? _fotoBarang;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadNamaIT();
    _loadTTD();
  }

  @override
  void dispose() {
    _namaToko.dispose();
    _namaIT.dispose();
    _namaBarang.dispose();
    _keterangan.dispose();
    _snBarang.dispose();
    _nomorDokumen.dispose();
    super.dispose();
  }

  Future<void> _loadNamaIT() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _namaIT.text = prefs.getString('nama_it') ?? '';
    });
  }

  Future<void> _loadTTD() async {
    final prefs = await SharedPreferences.getInstance();
    final ttdBase64 = prefs.getString('ttd_image');
    if (ttdBase64 != null) {
      setState(() {
        _ttdImage = base64Decode(ttdBase64);
      });
    }
  }

  Future<void> _ambilFotoDariKamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _fotoBarang = File(photo.path);
        });
        _showSuccessSnackBar("Foto berhasil diambil");
      }
    } catch (e) {
      _showErrorSnackBar("Gagal mengambil foto: $e");
    }
  }

  Future<void> _ambilFotoDariGaleri() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _fotoBarang = File(photo.path);
        });
        _showSuccessSnackBar("Foto berhasil dipilih");
      }
    } catch (e) {
      _showErrorSnackBar("Gagal memilih foto: $e");
    }
  }

  Future<void> _pilihSumberFoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Pilih Sumber Foto",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text("Kamera"),
              subtitle: const Text("Ambil foto baru"),
              onTap: () {
                Navigator.pop(context);
                _ambilFotoDariKamera();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: const Text("Galeri"),
              subtitle: const Text("Pilih dari galeri"),
              onTap: () {
                Navigator.pop(context);
                _ambilFotoDariGaleri();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _hapusFoto() {
    setState(() {
      _fotoBarang = null;
    });
    _showSuccessSnackBar("Foto dihapus");
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nama_it');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _simpanData() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menyimpan data...'),
                ],
              ),
            ),
          ),
        ),
      );

      String? fotoBase64;
      if (_fotoBarang != null) {
        final bytes = await _fotoBarang!.readAsBytes();
        fotoBase64 = base64Encode(bytes);
      }

      final data = {
        "tanggal": _tanggal,
        "nama_toko": _namaToko.text,
        "nama_it": _namaIT.text,
        "nama_barang": _namaBarang.text,
        "sn_barang": _snBarang.text,
        "nomor_dokumen": _nomorDokumen.text,
        "kategori": _kategori,
        "keterangan": _keterangan.text,
        "ttd_base64": _ttdImage != null ? base64Encode(_ttdImage!) : "",
        "foto_barang": fotoBase64 ?? "",
      };

      try {
        final response = await http.post(
          Uri.parse("http://192.168.0.110/returx/api/retur/insert.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(data),
        );

        final result = jsonDecode(response.body);
        
        if (mounted) Navigator.pop(context);

        if (result["success"] == true) {
          _showSuccessSnackBar("Data berhasil disimpan ke server!");

          bool connected = await PrinterService.ensureConnected();
          if (connected) {
            await PrinterService.printRetur(
              ReturBarang(
                tanggal: _tanggal,
                namaToko: _namaToko.text,
                namaIT: _namaIT.text,
                namaBarang: _namaBarang.text,
                snBarang: _snBarang.text,
                nomorDokumen: _nomorDokumen.text,
                kategori: _kategori,
                keterangan: _keterangan.text,
                ttdBase64: _ttdImage != null ? base64Encode(_ttdImage!) : null,
              ),
              ttdImage: _ttdImage,
            );
          }

          _namaToko.clear();
          _namaBarang.clear();
          _keterangan.clear();
          _snBarang.clear();
          _nomorDokumen.clear();
          setState(() {
            _kategori = 'OK';
            _fotoBarang = null;
          });
        } else {
          _showErrorSnackBar("Gagal: ${result["message"]}");
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showErrorSnackBar("Error koneksi: $e");
      }
    }
  }

  Future<void> _testPrint() async {
    bool connected = await PrinterService.ensureConnected();
    if (!connected) {
      _showWarningSnackBar("Printer belum terhubung");
      return;
    }

    await PrinterService.printTest(ttdImage: _ttdImage);
    _showSuccessSnackBar("Test print berhasil dikirim ke printer");
  }

  void _goToProfilTTD() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileTTDPage()),
    );
    _loadTTD();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildFormCard(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: Color(0xFF667eea),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Form Retur",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                "Sistem Retur Barang IT",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.list_alt_rounded,
              color: Colors.blue,
              size: 22,
            ),
          ),
          tooltip: "Laporan",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListReturPage()),
            );
          },
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'logout') _logout();
            if (value == 'ttd') _goToProfilTTD();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'ttd',
              child: Row(
                children: [
                  Icon(Icons.draw_outlined, size: 20, color: Color(0xFF667eea)),
                  SizedBox(width: 12),
                  Text('Atur TTD'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF667eea), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF667eea),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        _namaIT.text.isNotEmpty
                            ? _namaIT.text[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (_ttdImage != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final formattedDate = '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tanggal Retur",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Informasi Retur",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _namaToko,
                label: "Nama Toko",
                icon: Icons.store_outlined,
                hint: "Masukkan nama toko",
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _namaIT,
                label: "Nama IT Checker",
                icon: Icons.person_outline,
                hint: "Auto dari login",
                readOnly: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _namaBarang,
                label: "Nama Barang",
                icon: Icons.inventory_2_outlined,
                hint: "Masukkan nama barang",
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _snBarang,
                label: "SN Barang",
                icon: Icons.qr_code_2,
                hint: "Masukkan serial number barang",
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nomorDokumen,
                label: "Nomor Dokumen",
                icon: Icons.description_outlined,
                hint: "Contoh: MVO1231...",
              ),
              const SizedBox(height: 16),
              _buildDropdown(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _keterangan,
                label: "Keterangan",
                icon: Icons.notes_outlined,
                hint: "Masukkan keterangan",
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              _buildFotoSection(),
              const SizedBox(height: 30),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Foto Barang",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        if (_fotoBarang == null)
          InkWell(
            onTap: _pilihSumberFoto,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Tambah Foto Barang",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap untuk memilih foto",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _fotoBarang!,
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                        onPressed: _pilihSumberFoto,
                        tooltip: "Ganti foto",
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                        onPressed: _hapusFoto,
                        tooltip: "Hapus foto",
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool readOnly = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF667eea), size: 22),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (v) => v!.isEmpty ? "$label wajib diisi" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Kategori",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _kategori,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF667eea), size: 22),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          items: const [
            DropdownMenuItem(
              value: 'OK',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Text('OK'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Service',
              child: Row(
                children: [
                  Icon(Icons.build_circle, color: Colors.orange, size: 20),
                  SizedBox(width: 10),
                  Text('Service'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Waste',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 20),
                  SizedBox(width: 10),
                  Text('Waste'),
                ],
              ),
            ),
          ],
          onChanged: (v) => setState(() => _kategori = v!),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save_rounded, size: 22),
            label: const Text(
              "Simpan & Cetak",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _simpanData,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange, width: 2),
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.print_rounded, size: 22),
            label: const Text(
              "Test Print",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _testPrint,
          ),
        ),
      ],
    );
  }
}