import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:returan_apps/utils/printer_service.dart';
import 'package:returan_apps/model/retur_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ListReturPage extends StatefulWidget {
  const ListReturPage({super.key});

  @override
  State<ListReturPage> createState() => _ListReturPageState();
}

class _ListReturPageState extends State<ListReturPage> {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _selectedKategori = 'All';
  bool _isLoading = false;
  bool _isFirstLoad = true;

  // ✅ Cache untuk menghindari decode berulang
  final Map<String, Uint8List?> _fotoCache = {};
  final Map<String, Uint8List?> _ttdCache = {};

  // ✅ Date Filter Variables - DEFAULT HARI INI
  DateTime? _selectedDate;

  int _okCount = 0;
  int _serviceCount = 0;
  int _wasteCount = 0;

  @override
  void initState() {
    super.initState();
    // Set default tanggal ke hari ini
    _selectedDate = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ OPTIMASI: Format tanggal untuk filter server-side
      String tanggalParam = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      final response = await http.get(
        Uri.parse("http://sci.rotio.id:9050/returx/api/retur/list.php?tanggal=$tanggalParam"),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        List data = result['data'];
        
        // Clear cache setiap load data baru
        _fotoCache.clear();
        _ttdCache.clear();
        
        int ok = 0, service = 0, waste = 0;

        for (var item in data) {
          // Hitung kategori tanpa proses berat
          switch (item['kategori']) {
            case 'OK':
              ok++;
              break;
            case 'Service':
              service++;
              break;
            case 'Waste':
              waste++;
              break;
          }
        }

        setState(() {
          _allData = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _okCount = ok;
          _serviceCount = service;
          _wasteCount = waste;
          _isLoading = false;
          _isFirstLoad = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isFirstLoad = false;
        });
        if (mounted) {
          _showErrorSnackBar("Gagal memuat data: ${result['message']}");
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFirstLoad = false;
      });
      if (mounted) {
        _showErrorSnackBar("Error koneksi: $e");
      }
    }
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    // ✅ OPTIMASI: Coba format yang paling umum dulu
    try {
      // Format yyyy-MM-dd (format umum dari database)
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
    } catch (e) {
      // Coba format lain
    }
    
    // Fallback ke DateFormat hanya jika diperlukan
    try {
      // Coba format dd/MM/yyyy
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          // Handle tahun 2 digit
          final fullYear = year < 100 ? 2000 + year : year;
          return DateTime(fullYear, month, day);
        }
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _allData;

    // Filter by kategori
    if (_selectedKategori != 'All') {
      filtered = filtered.where((e) => e['kategori'] == _selectedKategori).toList();
    }

    // Filter by specific date
    if (_selectedDate != null) {
      final normalizedSelected = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      
      filtered = filtered.where((item) {
        String tanggalStr = item['tanggal'] ?? '';
        if (tanggalStr.isEmpty) return false;

        final itemDate = _parseDate(tanggalStr);
        if (itemDate == null) return false;

        bool matches = itemDate.year == normalizedSelected.year &&
                       itemDate.month == normalizedSelected.month &&
                       itemDate.day == normalizedSelected.day;
        
        return matches;
      }).toList();
    }

    setState(() {
      _filteredData = filtered;
    });
  }

  void _filterKategori(String kategori) {
    _selectedKategori = kategori;
    _applyFilters();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = DateTime.now(); // Reset ke hari ini
    });
    _loadData();
  }

  // ================= EDIT DATA =================
  Future<void> _editData(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReturPage(data: item),
      ),
    );

    if (result == true) {
      _loadData();
      _showSuccessSnackBar("Data berhasil diupdate!");
    }
  }

  // ================= DELETE DATA =================
  Future<void> _deleteData(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus data retur dari ${item['nama_toko']}?'),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse("http://sci.rotio.id:9050/returx/api/retur/delete.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': item['id']}),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _loadData();
        _showSuccessSnackBar("Data berhasil dihapus");
      } else {
        _showErrorSnackBar("Gagal menghapus: ${result['message']}");
      }
    } catch (e) {
      _showErrorSnackBar("Error: $e");
    }
  }

  // ================= PRINT SINGLE ITEM =================
  Future<void> _printSingleItem(Map<String, dynamic> item) async {
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
                Text('Mengirim ke printer...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      bool connected = await PrinterService.ensureConnected();
      
      if (mounted) Navigator.pop(context);
      
      if (!connected) {
        _showWarningSnackBar("Printer belum terhubung");
        return;
      }

      Uint8List? ttdImage;
      if (item['ttd_base64'] != null && item['ttd_base64'] != "") {
        ttdImage = base64Decode(item['ttd_base64']);
      }

      final returBarang = ReturBarang(
        tanggal: item['tanggal'] ?? '',
        namaToko: item['nama_toko'] ?? '',
        namaIT: item['nama_it'] ?? '',
        namaBarang: item['nama_barang'] ?? '',
        snBarang: item['sn_barang'] ?? '',
        nomorDokumen: item['nomor_dokumen'] ?? '',
        kategori: item['kategori'] ?? '',
        keterangan: item['keterangan'] ?? '',
        ttdBase64: item['ttd_base64'],
      );

      await PrinterService.printRetur(returBarang, ttdImage: ttdImage);
      
      _showSuccessSnackBar("Berhasil print data!");
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Gagal print: $e");
    }
  }

  // ================= PRINT ALL FILTERED DATA =================
  Future<void> _printAllData() async {
    if (_filteredData.isEmpty) {
      _showWarningSnackBar("Tidak ada data untuk di print");
      return;
    }

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Konfirmasi Print'),
        content: Text('Print ${_filteredData.length} data?\n\nIni akan mencetak semua data satu per satu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Print Semua'),
          ),
        ],
      ),
    );

    if (shouldPrint != true) return;

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
                Text('Mengirim ke printer...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      bool connected = await PrinterService.ensureConnected();
      
      if (!connected) {
        if (mounted) Navigator.pop(context);
        _showWarningSnackBar("Printer belum terhubung");
        return;
      }

      for (int i = 0; i < _filteredData.length; i++) {
        final item = _filteredData[i];
        
        Uint8List? ttdImage;
        if (item['ttd_base64'] != null && item['ttd_base64'] != "") {
          ttdImage = base64Decode(item['ttd_base64']);
        }

        final returBarang = ReturBarang(
          tanggal: item['tanggal'] ?? '',
          namaToko: item['nama_toko'] ?? '',
          namaIT: item['nama_it'] ?? '',
          namaBarang: item['nama_barang'] ?? '',
          snBarang: item['sn_barang'] ?? '',
          nomorDokumen: item['nomor_dokumen'] ?? '',
          kategori: item['kategori'] ?? '',
          keterangan: item['keterangan'] ?? '',
          ttdBase64: item['ttd_base64'],
        );

        await PrinterService.printRetur(returBarang, ttdImage: ttdImage);
        
        if (i < _filteredData.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) Navigator.pop(context);
      _showSuccessSnackBar("Berhasil print ${_filteredData.length} data!");
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Gagal print: $e");
    }
  }

  // ================= FOTO BARANG UTILS dengan CACHE =================
  Uint8List? _getCachedFotoBarang(String id, String? fotoBase64) {
    if (fotoBase64 == null || fotoBase64.isEmpty) {
      return null;
    }
    
    // Cek cache dulu
    if (_fotoCache.containsKey(id)) {
      return _fotoCache[id];
    }
    
    // Decode dan cache
    try {
      final decoded = base64Decode(fotoBase64);
      _fotoCache[id] = decoded;
      return decoded;
    } catch (e) {
      print('Error decoding foto barang: $e');
      _fotoCache[id] = null;
      return null;
    }
  }

  Uint8List? _getCachedTTD(String id, String? ttdBase64) {
    if (ttdBase64 == null || ttdBase64.isEmpty) {
      return null;
    }
    
    // Cek cache dulu
    if (_ttdCache.containsKey(id)) {
      return _ttdCache[id];
    }
    
    // Decode dan cache
    try {
      final decoded = base64Decode(ttdBase64);
      _ttdCache[id] = decoded;
      return decoded;
    } catch (e) {
      print('Error decoding TTD: $e');
      _ttdCache[id] = null;
      return null;
    }
  }

  // MODIFIED: Hanya tampilkan icon, bukan gambar
  Widget _buildItemImage() {
    return Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  // ================= ZOOM IMAGE DIALOG =================
  void _showZoomImageDialog(Uint8List imageBytes, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header dengan tombol close
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Gambar dengan interactive viewer
            Expanded(
              child: InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Footer dengan instruksi
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: const Text(
                'Pinch untuk zoom • Drag untuk geser • Tap untuk close',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= PDF GENERATE =================
  Future<void> _generatePdfReport() async {
    if (_filteredData.isEmpty) {
      _showWarningSnackBar("Tidak ada data untuk dibuat PDF");
      return;
    }

    final pdf = pw.Document();

    final List<pw.TableRow> rows = _filteredData.map((item) {
      pw.Widget ttdWidget;
      if (item['ttd_base64'] != null && item['ttd_base64'] != "") {
        final Uint8List bytes = base64Decode(item['ttd_base64']);
        ttdWidget = pw.Image(pw.MemoryImage(bytes), width: 50, height: 50);
      } else {
        ttdWidget = pw.Text("-");
      }

      // ✅ FOTO BARANG WIDGET
      pw.Widget fotoWidget;
      final fotoBarang = _getCachedFotoBarang(item['id'].toString(), item['foto_barang']);
      if (fotoBarang != null) {
        fotoWidget = pw.Image(pw.MemoryImage(fotoBarang), width: 50, height: 50);
      } else {
        fotoWidget = pw.Text("-");
      }

      return pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['tanggal'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nama_toko'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nama_barang'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['sn_barang'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nomor_dokumen'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['nama_it'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['kategori'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['keterangan'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: fotoWidget),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: ttdWidget),
      ]);
    }).toList();

    String dateFilterText = '';
    if (_selectedDate != null) {
      dateFilterText = 'Filter Tanggal: ${DateFormat('dd MMMM yyyy').format(_selectedDate!)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Laporan Retur Barang',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Bullet(text: 'OK: $_okCount'),
          pw.Bullet(text: 'Service: $_serviceCount'),
          pw.Bullet(text: 'Waste: $_wasteCount'),
          pw.Bullet(text: 'Total: ${_allData.length}'),
          pw.SizedBox(height: 12),
          pw.Text('Filter Kategori: $_selectedKategori', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
          if (dateFilterText.isNotEmpty)
            pw.Text(dateFilterText, style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
          pw.Text('Data Ditampilkan: ${_filteredData.length}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Toko', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Barang', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('SN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('No Dokumen', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('IT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Kategori', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Keterangan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Foto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              ...rows,
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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

  // ================= BUILD dengan SHIMMER LOADING =================
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.list_alt_rounded,
                color: Color(0xFF667eea),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isMobile
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Daftar Retur",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          "Laporan data retur",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      "Daftar Retur Barang",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ),
          ],
        ),
        actions: [
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green, size: 22),
            tooltip: "Refresh Data",
            onPressed: _loadData,
          ),
          // Print Button
          IconButton(
            icon: const Icon(Icons.print, color: Colors.orange, size: 22),
            tooltip: "Print Semua",
            onPressed: _filteredData.isEmpty ? null : _printAllData,
          ),
          // PDF Button
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
            tooltip: "Laporan PDF",
            onPressed: _filteredData.isEmpty ? null : _generatePdfReport,
          ),
        ],
      ),
      body: _isLoading && _isFirstLoad
          ? _buildShimmerLoading(isMobile)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Icons.info_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Data retur akan ditampilkan berdasarkan filter kategori dan tanggal yang dipilih",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Summary Card
                  const Text(
                    "Summary Retur",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isMobile 
                          ? Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSummaryItem("OK", _okCount, Colors.green),
                                    _buildSummaryItem("Service", _serviceCount, Colors.orange),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSummaryItem("Waste", _wasteCount, Colors.red),
                                    _buildSummaryItem("Total", _allData.length, Colors.blue),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem("OK", _okCount, Colors.green),
                                _buildSummaryItem("Service", _serviceCount, Colors.orange),
                                _buildSummaryItem("Waste", _wasteCount, Colors.red),
                                _buildSummaryItem("Total", _allData.length, Colors.blue),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Filter Section
                  const Text(
                    "Filter Data",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kategori Filter
                          Row(
                            children: [
                              const Icon(Icons.filter_list, size: 20, color: Color(0xFF667eea)),
                              const SizedBox(width: 8),
                              Text(
                                "Kategori:",
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _selectedKategori,
                                    underline: const SizedBox(),
                                    isExpanded: true,
                                    style: TextStyle(fontSize: isMobile ? 12 : 14, color: Colors.black87),
                                    items: const [
                                      DropdownMenuItem(value: 'All', child: Text('Semua Kategori')),
                                      DropdownMenuItem(value: 'OK', child: Text('OK')),
                                      DropdownMenuItem(value: 'Service', child: Text('Service')),
                                      DropdownMenuItem(value: 'Waste', child: Text('Waste')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) _filterKategori(v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          
                          // Date Filter (DEFAULT HARI INI)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 20, color: Color(0xFF667eea)),
                              const SizedBox(width: 8),
                              Text(
                                "Tanggal:",
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(_selectedDate!),
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: _clearDateFilter,
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _selectDate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667eea),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 12 : 16, 
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Icon(
                                  Icons.calendar_month, 
                                  size: isMobile ? 18 : 20
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Default: Data hari ini. Klik X untuk reset ke hari ini",
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Data Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Daftar Data",
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF667eea),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          "${_filteredData.length} data",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // List Data
                  if (_isLoading && !_isFirstLoad)
                    _buildListShimmer(isMobile)
                  else if (_filteredData.isEmpty)
                    Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _selectedDate != null
                                ? "Tidak ada data pada tanggal\n${DateFormat('dd MMM yyyy').format(_selectedDate!)}"
                                : "Belum ada data retur",
                            style: TextStyle(
                              color: Colors.grey.shade600, 
                              fontSize: isMobile ? 14 : 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_selectedDate != null) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _clearDateFilter,
                              icon: const Icon(Icons.clear, size: 18),
                              label: Text("Reset Filter", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 20 : 24, 
                                  vertical: isMobile ? 10 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredData.length,
                      itemBuilder: (context, index) {
                        final item = _filteredData[index];

                        // ✅ OPTIMASI: Gunakan cache
                        Uint8List? ttdImage;
                        if (item['ttd_base64'] != null && item['ttd_base64'] != "") {
                          ttdImage = _getCachedTTD(item['id'].toString(), item['ttd_base64']);
                        }

                        Uint8List? fotoBarangImage;
                        if (item['foto_barang'] != null && item['foto_barang'] != "") {
                          fotoBarangImage = _getCachedFotoBarang(item['id'].toString(), item['foto_barang']);
                        }

                        Color kategoriColor;
                        switch (item['kategori']) {
                          case 'OK':
                            kategoriColor = Colors.green;
                            break;
                          case 'Service':
                            kategoriColor = Colors.orange;
                            break;
                          case 'Waste':
                            kategoriColor = Colors.red;
                            break;
                          default:
                            kategoriColor = Colors.grey;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _showDetailDialog(item, ttdImage, fotoBarangImage, isMobile);
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
                              child: Row(
                                children: [
                                  // Hanya icon, bukan gambar
                                  Container(
                                    width: isMobile ? 50 : 60,
                                    height: isMobile ? 50 : 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _buildItemImage(),
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  
                                  // Main Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['nama_toko'] ?? '-',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isMobile ? 14 : 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: kategoriColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: kategoriColor.withOpacity(0.5)),
                                              ),
                                              child: Text(
                                                item['kategori'] ?? '-',
                                                style: TextStyle(
                                                  color: kategoriColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isMobile ? 10 : 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['nama_barang'] ?? '-',
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(Icons.person_outline, size: isMobile ? 12 : 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              "IT: ${item['nama_it'] ?? '-'}",
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12, 
                                                color: Colors.grey.shade600
                                              ),
                                            ),
                                            SizedBox(width: isMobile ? 6 : 12),
                                            Icon(Icons.calendar_today, size: isMobile ? 12 : 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['tanggal'] ?? '-',
                                              style: TextStyle(
                                                fontSize: isMobile ? 10 : 12, 
                                                color: Colors.grey.shade600
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Action Buttons
                                  Column(
                                    children: [
                                      // Edit Button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.edit, size: isMobile ? 18 : 20),
                                          color: Colors.orange,
                                          tooltip: "Edit",
                                          onPressed: () => _editData(item),
                                          padding: EdgeInsets.all(isMobile ? 4 : 8),
                                        ),
                                      ),
                                      SizedBox(height: isMobile ? 2 : 4),
                                      // Print Button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.print, size: isMobile ? 18 : 20),
                                          color: Colors.blueAccent,
                                          tooltip: "Print",
                                          onPressed: () => _printSingleItem(item),
                                          padding: EdgeInsets.all(isMobile ? 4 : 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String title, int count, Color color) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: isMobile ? 10 : 12
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16, 
            vertical: isMobile ? 6 : 8
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 16 : 18,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showDetailDialog(Map<String, dynamic> item, Uint8List? ttdImage, Uint8List? fotoBarangImage, bool isMobile) {
    Color kategoriColor;
    switch (item['kategori']) {
      case 'OK':
        kategoriColor = Colors.green;
        break;
      case 'Service':
        kategoriColor = Colors.orange;
        break;
      case 'Waste':
        kategoriColor = Colors.red;
        break;
      default:
        kategoriColor = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Detail Retur",
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        iconSize: isMobile ? 20 : 24,
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  _buildDetailRow("Tanggal", item['tanggal'] ?? '-', isMobile),
                  _buildDetailRow("Nama Toko", item['nama_toko'] ?? '-', isMobile),
                  _buildDetailRow("Nama Barang", item['nama_barang'] ?? '-', isMobile),
                  _buildDetailRow("SN Barang", item['sn_barang'] ?? '-', isMobile),
                  _buildDetailRow("Nomor Dokumen", item['nomor_dokumen'] ?? '-', isMobile),
                  _buildDetailRow("Nama IT", item['nama_it'] ?? '-', isMobile),
                  
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text("Kategori: ", style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: kategoriColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kategoriColor),
                        ),
                        child: Text(
                          item['kategori'] ?? '-',
                          style: TextStyle(
                            color: kategoriColor,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  _buildDetailRow("Keterangan", item['keterangan'] ?? '-', isMobile),
                  
                  // ✅ FOTO BARANG SECTION
                  if (fotoBarangImage != null) ...[
                    const SizedBox(height: 16),
                    Text("Foto Barang:", style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    )),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showZoomImageDialog(fotoBarangImage, "Foto Barang - ${item['nama_barang']}");
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Image.memory(
                                fotoBarangImage,
                                height: isMobile ? 120 : 150,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap untuk memperbesar',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: isMobile ? 10 : 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // ✅ TANDA TANGAN SECTION
                  const SizedBox(height: 16),
                  Text("Tanda Tangan:", style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  )),
                  const SizedBox(height: 8),
                  
                  if (ttdImage != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showZoomImageDialog(ttdImage, "Tanda Tangan - ${item['nama_it']}");
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Image.memory(
                                ttdImage, 
                                height: isMobile ? 80 : 120,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap untuk memperbesar',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: isMobile ? 10 : 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        height: isMobile ? 80 : 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "Tidak ada tanda tangan", 
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: isMobile ? 12 : 14,
                            )
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  if (isMobile) 
                    Column(
                      children: [
                        // Edit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _editData(item);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text("Edit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Print Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _printSingleItem(item);
                            },
                            icon: const Icon(Icons.print),
                            label: const Text("Print"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Delete Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteData(item);
                            },
                            icon: const Icon(Icons.delete),
                            label: const Text("Hapus Data"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        // Edit Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _editData(item);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text("Edit"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Print Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _printSingleItem(item);
                            },
                            icon: const Icon(Icons.print),
                            label: const Text("Print"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!isMobile) ...[
                    const SizedBox(height: 8),
                    // Delete Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteData(item);
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text("Hapus Data"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isMobile) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 100 : 120,
          child: Text(
            "$label:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: isMobile ? 12 : 14),
          ),
        ),
      ],
    ),
  );
}

  // ================= SHIMMER LOADING EFFECT =================
  Widget _buildShimmerLoading(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Shimmer
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[200],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Summary Shimmer
          Container(
            height: 20,
            width: 150,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 12),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) => 
                  Column(
                    children: [
                      Container(
                        height: 15,
                        width: 40,
                        color: Colors.grey[200],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Filter Shimmer
          Container(
            height: 20,
            width: 100,
            color: Colors.grey[200],
          ),
          const SizedBox(height: 12),
          
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.grey[200], radius: 10),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 15, width: 80, color: Colors.grey[200]),
                            const SizedBox(height: 4),
                            Container(height: 40, width: double.infinity, color: Colors.grey[200]),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.grey[200], radius: 10),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 15, width: 60, color: Colors.grey[200]),
                            const SizedBox(height: 4),
                            Container(height: 40, width: double.infinity, color: Colors.grey[200]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // List Shimmer
          _buildListShimmer(isMobile),
        ],
      ),
    );
  }

  Widget _buildListShimmer(bool isMobile) {
    return Column(
      children: List.generate(5, (index) => 
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
            child: Row(
              children: [
                Container(
                  width: isMobile ? 50 : 60,
                  height: isMobile ? 50 : 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 15, width: double.infinity, color: Colors.grey[200]),
                      const SizedBox(height: 6),
                      Container(height: 12, width: 150, color: Colors.grey[200]),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 200, color: Colors.grey[200]),
                    ],
                  ),
                ),
                
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
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

// ================= EDIT PAGE tanpa TTD =================
class EditReturPage extends StatefulWidget {
  final Map<String, dynamic> data;
  
  const EditReturPage({super.key, required this.data});

  @override
  State<EditReturPage> createState() => _EditReturPageState();
}

class _EditReturPageState extends State<EditReturPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _tanggalController;
  late TextEditingController _namaTokoController;
  late TextEditingController _namaITController;
  late TextEditingController _namaBarangController;
  late TextEditingController _snBarangController;
  late TextEditingController _nomorDokumenController;
  late TextEditingController _keteranganController;
  
  String _selectedKategori = 'OK';
  bool _isLoading = false;
  
  // ✅ FOTO BARANG VARIABLES
  File? _newFotoBarang;
  Uint8List? _existingFotoBarang;
  bool _fotoChanged = false;

  @override
  void initState() {
    super.initState();
    _tanggalController = TextEditingController(text: widget.data['tanggal'] ?? '');
    _namaTokoController = TextEditingController(text: widget.data['nama_toko'] ?? '');
    _namaITController = TextEditingController(text: widget.data['nama_it'] ?? '');
    _namaBarangController = TextEditingController(text: widget.data['nama_barang'] ?? '');
    _snBarangController = TextEditingController(text: widget.data['sn_barang'] ?? '');
    _nomorDokumenController = TextEditingController(text: widget.data['nomor_dokumen'] ?? '');
    _keteranganController = TextEditingController(text: widget.data['keterangan'] ?? '');
    _selectedKategori = widget.data['kategori'] ?? 'OK';
    
    // ✅ Load existing foto barang
    if (widget.data['foto_barang'] != null && widget.data['foto_barang'] != "") {
      try {
        _existingFotoBarang = base64Decode(widget.data['foto_barang']);
      } catch (e) {
        print('Error decoding foto: $e');
      }
    }
  }

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaTokoController.dispose();
    _namaITController.dispose();
    _namaBarangController.dispose();
    _snBarangController.dispose();
    _nomorDokumenController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  // ✅ FOTO FUNCTIONS
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
          _newFotoBarang = File(photo.path);
          _fotoChanged = true;
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
          _newFotoBarang = File(photo.path);
          _fotoChanged = true;
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
                color: Colors.grey[300],
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
                  color: Colors.blue[50],
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
                  color: Colors.purple[50],
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
      _newFotoBarang = null;
      _existingFotoBarang = null;
      _fotoChanged = true;
    });
    _showSuccessSnackBar("Foto dihapus");
  }

  void _batalUbahFoto() {
    setState(() {
      _newFotoBarang = null;
      _fotoChanged = false;
    });
    _showSuccessSnackBar("Batal ubah foto");
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _updateData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ Handle foto barang
      String? fotoBase64;
      if (_fotoChanged) {
        if (_newFotoBarang != null) {
          // Ada foto baru
          final bytes = await _newFotoBarang!.readAsBytes();
          fotoBase64 = base64Encode(bytes);
        } else {
          // Foto dihapus - kirim empty string
          fotoBase64 = "";
        }
      } else {
        // Foto tidak berubah - jangan kirim (null)
        fotoBase64 = null;
      }

      // Build request body
      final Map<String, dynamic> requestBody = {
        'id': widget.data['id'],
        'tanggal': _tanggalController.text,
        'nama_toko': _namaTokoController.text,
        'nama_it': _namaITController.text,
        'nama_barang': _namaBarangController.text,
        'sn_barang': _snBarangController.text,
        'nomor_dokumen': _nomorDokumenController.text,
        'kategori': _selectedKategori,
        'keterangan': _keteranganController.text,
      };

      // Hanya kirim foto_barang jika berubah
      if (fotoBase64 != null) {
        requestBody['foto_barang'] = fotoBase64;
      }

      final response = await http.post(
        Uri.parse("http://sci.rotio.id:9050/returx/api/retur/update.php"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final result = jsonDecode(response.body);
      
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showErrorSnackBar(result['message'] ?? 'Gagal update data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar("Error: $e");
    }
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
        backgroundColor: Colors.green[400],
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
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          "Edit Data Retur",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Edit informasi data retur barang",
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: isMobile ? 12 : 14
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Form Fields
              _buildTextField("Tanggal", _tanggalController, 
                icon: Icons.calendar_today,
                readOnly: true,
                onTap: _selectDate,
                isMobile: isMobile,
              ),
              _buildTextField("Nama Toko", _namaTokoController, icon: Icons.store, isMobile: isMobile),
              _buildTextField("Nama IT", _namaITController, icon: Icons.person, isMobile: isMobile),
              _buildTextField("Nama Barang", _namaBarangController, icon: Icons.inventory, isMobile: isMobile),
              _buildTextField("SN Barang", _snBarangController, icon: Icons.qr_code, required: false, isMobile: isMobile),
              _buildTextField("Nomor Dokumen", _nomorDokumenController, icon: Icons.description, required: false, isMobile: isMobile),
              
              // Kategori Dropdown
              Text(
                "Kategori",
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: isMobile ? 12 : 14
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: DropdownButton<String>(
                  value: _selectedKategori,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'OK', child: Text('OK')),
                    DropdownMenuItem(value: 'Service', child: Text('Service')),
                    DropdownMenuItem(value: 'Waste', child: Text('Waste')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedKategori = v;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              _buildTextField("Keterangan", _keteranganController, 
                icon: Icons.notes,
                maxLines: 3,
                required: false,
                isMobile: isMobile,
              ),
              
              // ✅ FOTO BARANG SECTION
              const SizedBox(height: 20),
              Text(
                "Foto Barang",
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  fontSize: isMobile ? 12 : 14
                ),
              ),
              const SizedBox(height: 8),
              
              if (_existingFotoBarang != null && !_fotoChanged)
                Column(
                  children: [
                    Container(
                      height: isMobile ? 200 : 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _existingFotoBarang!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pilihSumberFoto,
                            icon: const Icon(Icons.edit),
                            label: Text("Ubah Foto", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _hapusFoto,
                            icon: const Icon(Icons.delete),
                            label: Text("Hapus", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else if (_newFotoBarang != null)
                Column(
                  children: [
                    Container(
                      height: isMobile ? 200 : 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _newFotoBarang!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_existingFotoBarang != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _batalUbahFoto,
                              icon: const Icon(Icons.cancel),
                              label: Text("Batal", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                            ),
                          ),
                        if (_existingFotoBarang != null) const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pilihSumberFoto,
                            icon: const Icon(Icons.edit),
                            label: Text("Ganti", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _hapusFoto,
                            icon: const Icon(Icons.delete),
                            label: Text("Hapus", style: TextStyle(fontSize: isMobile ? 12 : 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                InkWell(
                  onTap: _pilihSumberFoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: isMobile ? 150 : 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50]!,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tambah Foto Barang",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tap untuk memilih foto",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              const SizedBox(height: 30),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Simpan Perubahan",
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    int maxLines = 1,
    bool required = true,
    bool readOnly = false,
    VoidCallback? onTap,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: isMobile ? 12 : 14
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF667eea)) : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
          ),
          validator: required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label tidak boleh kosong';
                  }
                  return null;
                }
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}