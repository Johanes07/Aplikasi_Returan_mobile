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

  // ✅ Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  final int _itemsPerPage = 50;
  bool _hasMoreData = true;

  // ✅ Cache untuk detail items (baru load ketika dibutuhkan)
  final Map<int, Map<String, dynamic>> _detailCache = {};

  DateTime? _selectedDate;

  int _okCount = 0;
  int _serviceCount = 0;
  int _wasteCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadData();
  }

  // ✅ OPTIMASI UTAMA: Load data TANPA gambar
  Future<void> _loadData({bool append = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      String tanggalParam = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // ✅ PENTING: Kirim filter ke server
      final url = "http://sci.rotio.id:9050/returx/api/retur/list.php"
          "?tanggal=$tanggalParam"
          "&kategori=$_selectedKategori"
          "&page=$_currentPage"
          "&limit=$_itemsPerPage";
      
      final response = await http.get(Uri.parse(url));

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        List data = result['data'];
        
        // ✅ Update pagination info
        if (result['pagination'] != null) {
          _totalPages = result['pagination']['total_pages'] ?? 1;
          _totalItems = result['pagination']['total_items'] ?? 0;
          _hasMoreData = _currentPage < _totalPages;
        }
        
        // ✅ Hitung summary (server bisa kirim ini juga untuk lebih optimal)
        int ok = 0, service = 0, waste = 0;
        for (var item in data) {
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
          if (append) {
            _allData.addAll(List<Map<String, dynamic>>.from(data));
          } else {
            _allData = List<Map<String, dynamic>>.from(data);
            _detailCache.clear(); // Clear cache ketika reload
          }
          _filteredData = _allData;
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

  // ✅ Load next page (infinite scroll)
  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoading) return;
    
    _currentPage++;
    await _loadData(append: true);
  }

  // ✅ Load detail dengan gambar (on-demand)
  Future<Map<String, dynamic>?> _loadDetailData(int id) async {
    // Check cache first
    if (_detailCache.containsKey(id)) {
      return _detailCache[id];
    }

    try {
      final response = await http.get(
        Uri.parse("http://sci.rotio.id:9050/returx/api/retur/detail.php?id=$id"),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _detailCache[id] = result['data'];
        return result['data'];
      }
    } catch (e) {
      print('Error loading detail: $e');
    }
    return null;
  }

  void _applyFilters() {
    // Reset pagination
    _currentPage = 1;
    _hasMoreData = true;
    _loadData();
  }

  void _filterKategori(String kategori) {
    setState(() {
      _selectedKategori = kategori;
    });
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
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _applyFilters();
  }

  // ================= EDIT DATA =================
  Future<void> _editData(Map<String, dynamic> item) async {
    // ✅ Load detail dulu jika belum ada
    Map<String, dynamic>? detailData = await _loadDetailData(int.parse(item['id'].toString()));
    
    if (detailData == null) {
      _showErrorSnackBar("Gagal memuat detail data");
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditReturPage(data: detailData),
      ),
    );

    if (result == true) {
      // Clear cache untuk item ini
      _detailCache.remove(item['id']);
      _applyFilters();
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
        _detailCache.remove(item['id']);
        _applyFilters();
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
                Text('Memuat data untuk print...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // ✅ Load detail data dulu (dengan gambar)
      Map<String, dynamic>? detailData = await _loadDetailData(int.parse(item['id'].toString()));
      
      if (mounted) Navigator.pop(context);
      
      if (detailData == null) {
        _showErrorSnackBar("Gagal memuat data");
        return;
      }

      bool connected = await PrinterService.ensureConnected();
      
      if (!connected) {
        _showWarningSnackBar("Printer belum terhubung");
        return;
      }

      Uint8List? ttdImage;
      if (detailData['ttd_base64'] != null && detailData['ttd_base64'] != "") {
        ttdImage = base64Decode(detailData['ttd_base64']);
      }

      final returBarang = ReturBarang(
        tanggal: detailData['tanggal'] ?? '',
        namaToko: detailData['nama_toko'] ?? '',
        namaIT: detailData['nama_it'] ?? '',
        namaBarang: detailData['nama_barang'] ?? '',
        snBarang: detailData['sn_barang'] ?? '',
        nomorDokumen: detailData['nomor_dokumen'] ?? '',
        kategori: detailData['kategori'] ?? '',
        keterangan: detailData['keterangan'] ?? '',
        ttdBase64: detailData['ttd_base64'],
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
        
        // ✅ Load detail untuk setiap item
        Map<String, dynamic>? detailData = await _loadDetailData(int.parse(item['id'].toString()));
        if (detailData == null) continue;
        
        Uint8List? ttdImage;
        if (detailData['ttd_base64'] != null && detailData['ttd_base64'] != "") {
          ttdImage = base64Decode(detailData['ttd_base64']);
        }

        final returBarang = ReturBarang(
          tanggal: detailData['tanggal'] ?? '',
          namaToko: detailData['nama_toko'] ?? '',
          namaIT: detailData['nama_it'] ?? '',
          namaBarang: detailData['nama_barang'] ?? '',
          snBarang: detailData['sn_barang'] ?? '',
          nomorDokumen: detailData['nomor_dokumen'] ?? '',
          kategori: detailData['kategori'] ?? '',
          keterangan: detailData['keterangan'] ?? '',
          ttdBase64: detailData['ttd_base64'],
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

  // ✅ Indicator untuk has_foto dan has_ttd
  Widget _buildItemImage(Map<String, dynamic> item) {
    bool hasFoto = item['has_foto'] == 1;
    
    return Container(
      decoration: BoxDecoration(
        color: hasFoto ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.inventory_2_outlined,
              size: 32,
              color: hasFoto ? Colors.blue : Colors.grey.shade400,
            ),
          ),
          if (hasFoto)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
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
                'Pinch untuk zoom • Drag untuk geser',
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
                Text('Membuat PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    final pdf = pw.Document();

    final List<pw.TableRow> rows = [];
    
    // ✅ Load detail untuk setiap item (untuk PDF)
    for (var item in _filteredData) {
      Map<String, dynamic>? detailData = await _loadDetailData(int.parse(item['id'].toString()));
      if (detailData == null) continue;

      pw.Widget ttdWidget;
      if (detailData['ttd_base64'] != null && detailData['ttd_base64'] != "") {
        final Uint8List bytes = base64Decode(detailData['ttd_base64']);
        ttdWidget = pw.Image(pw.MemoryImage(bytes), width: 50, height: 50);
      } else {
        ttdWidget = pw.Text("-");
      }

      pw.Widget fotoWidget;
      if (detailData['foto_barang'] != null && detailData['foto_barang'] != "") {
        final Uint8List bytes = base64Decode(detailData['foto_barang']);
        fotoWidget = pw.Image(pw.MemoryImage(bytes), width: 50, height: 50);
      } else {
        fotoWidget = pw.Text("-");
      }

      rows.add(pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['tanggal'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['nama_toko'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['nama_barang'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['sn_barang'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['nomor_dokumen'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['nama_it'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['kategori'] ?? '-', style: const pw.TextStyle(fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(detailData['keterangan'] ?? '-', style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: fotoWidget),
        pw.Padding(padding: const pw.EdgeInsets.all(4), child: ttdWidget),
      ]));
    }

    if (mounted) Navigator.pop(context);

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
          pw.Bullet(text: 'Total: $_totalItems'),
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

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(isMobile),
      body: _isLoading && _isFirstLoad
          ? _buildShimmerLoading(isMobile)
          : NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // ✅ Infinite scroll
                if (!_isLoading &&
                    _hasMoreData &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  _loadMoreData();
                }
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderInfo(isMobile),
                    const SizedBox(height: 20),
                    _buildSummaryCard(isMobile),
                    const SizedBox(height: 20),
                    _buildFilterCard(isMobile),
                    const SizedBox(height: 20),
                    _buildDataCountHeader(isMobile),
                    const SizedBox(height: 12),
                    _buildDataList(isMobile),
                    
                    // ✅ Load more indicator
                    if (_isLoading && !_isFirstLoad)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    
                    // ✅ End of data indicator
                    if (!_hasMoreData && _filteredData.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            "Semua data sudah dimuat",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
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

PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
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
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.green, size: 22),
          tooltip: "Refresh Data",
          onPressed: () {
            _currentPage = 1;
            _hasMoreData = true;
            _loadData();
          },
        ),
        IconButton(
          icon: const Icon(Icons.print, color: Colors.orange, size: 22),
          tooltip: "Print Semua",
          onPressed: _filteredData.isEmpty ? null : _printAllData,
        ),
        IconButton(
          icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
          tooltip: "Laporan PDF",
          onPressed: _filteredData.isEmpty ? null : _generatePdfReport,
        ),
      ],
    );
  }

  Widget _buildHeaderInfo(bool isMobile) {
    return Container(
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
    );
  }

  Widget _buildSummaryCard(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                          _buildSummaryItem("OK", _okCount, Colors.green, isMobile),
                          _buildSummaryItem("Service", _serviceCount, Colors.orange, isMobile),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem("Waste", _wasteCount, Colors.red, isMobile),
                          _buildSummaryItem("Total", _totalItems, Colors.blue, isMobile),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem("OK", _okCount, Colors.green, isMobile),
                      _buildSummaryItem("Service", _serviceCount, Colors.orange, isMobile),
                      _buildSummaryItem("Waste", _wasteCount, Colors.red, isMobile),
                      _buildSummaryItem("Total", _totalItems, Colors.blue, isMobile),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String title, int count, Color color, bool isMobile) {
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

  Widget _buildFilterCard(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _buildDataCountHeader(bool isMobile) {
    return Row(
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
            "${_filteredData.length} / $_totalItems data",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: isMobile ? 10 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataList(bool isMobile) {
    if (_filteredData.isEmpty) {
      return Container(
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
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredData.length,
      itemBuilder: (context, index) {
        final item = _filteredData[index];

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
            onTap: () async {
              // ✅ Load detail on demand
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

             Map<String, dynamic>? detailData = await _loadDetailData(int.parse(item['id'].toString()));
              
              if (mounted) Navigator.pop(context);
              
              if (detailData != null) {
                Uint8List? ttdImage;
                if (detailData['ttd_base64'] != null && detailData['ttd_base64'] != "") {
                  ttdImage = base64Decode(detailData['ttd_base64']);
                }

                Uint8List? fotoBarangImage;
                if (detailData['foto_barang'] != null && detailData['foto_barang'] != "") {
                  fotoBarangImage = base64Decode(detailData['foto_barang']);
                }

                _showDetailDialog(detailData, ttdImage, fotoBarangImage, isMobile);
              }
            },
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8.0 : 12.0),
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 50 : 60,
                    height: isMobile ? 50 : 60,
                    child: _buildItemImage(item),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  
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
                  
                  Column(
                    children: [
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
    );
  }

  Widget _buildShimmerLoading(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 20),
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
          ...List.generate(5, (index) => 
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ DETAIL DIALOG dengan lazy loading
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
                  
                  // ✅ Action Buttons
                  if (isMobile) 
                    Column(
                      children: [
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
                    Column(
                      children: [
                        Row(
                          children: [
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
                        const SizedBox(height: 8),
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
                    ),
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

  
  
  
 

  
}

// ================= EDIT PAGE (ELEGAN VERSION) =================
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
    _initializeControllers();
    _loadExistingFoto();
  }

  void _initializeControllers() {
    _tanggalController = TextEditingController(text: widget.data['tanggal'] ?? '');
    _namaTokoController = TextEditingController(text: widget.data['nama_toko'] ?? '');
    _namaITController = TextEditingController(text: widget.data['nama_it'] ?? '');
    _namaBarangController = TextEditingController(text: widget.data['nama_barang'] ?? '');
    _snBarangController = TextEditingController(text: widget.data['sn_barang'] ?? '');
    _nomorDokumenController = TextEditingController(text: widget.data['nomor_dokumen'] ?? '');
    _keteranganController = TextEditingController(text: widget.data['keterangan'] ?? '');
    _selectedKategori = widget.data['kategori'] ?? 'OK';
  }

  void _loadExistingFoto() {
    if (widget.data['foto_barang'] != null && widget.data['foto_barang'] != "") {
      try {
        _existingFotoBarang = base64Decode(widget.data['foto_barang']);
      } catch (e) {
        print('❌ Error decoding foto: $e');
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

  // ================= FOTO BARANG FUNCTIONS =================
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
        _showSuccessSnackBar("📸 Foto berhasil diambil");
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
        _showSuccessSnackBar("🖼️ Foto berhasil dipilih");
      }
    } catch (e) {
      _showErrorSnackBar("Gagal memilih foto: $e");
    }
  }

  Future<void> _pilihSumberFoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  "Pilih Sumber Foto",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              
              const Divider(height: 1),
              
              // Camera Option
              _buildPhotoOption(
                icon: Icons.camera_alt_rounded,
                title: "Kamera",
                subtitle: "Ambil foto baru",
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _ambilFotoDariKamera();
                },
              ),
              
              // Gallery Option
              _buildPhotoOption(
                icon: Icons.photo_library_rounded,
                title: "Galeri",
                subtitle: "Pilih dari galeri",
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _ambilFotoDariGaleri();
                },
              ),
              
              // Cancel Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      "Batal",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
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

  Widget _buildPhotoOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _hapusFoto() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text("Konfirmasi Hapus"),
          ],
        ),
        content: const Text("Apakah Anda yakin ingin menghapus foto barang ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _newFotoBarang = null;
                _existingFotoBarang = null;
                _fotoChanged = true;
              });
              _showSuccessSnackBar("🗑️ Foto berhasil dihapus");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  void _batalUbahFoto() {
    setState(() {
      _newFotoBarang = null;
      _fotoChanged = false;
    });
    _showSuccessSnackBar("🔄 Batal ubah foto");
  }

  // ================= DATE PICKER =================
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667eea),
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
        _tanggalController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ================= UPDATE DATA =================
  Future<void> _updateData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Handle foto barang
      String? fotoBase64;
      if (_fotoChanged) {
        if (_newFotoBarang != null) {
          final bytes = await _newFotoBarang!.readAsBytes();
          fotoBase64 = base64Encode(bytes);
        } else {
          fotoBase64 = "";
        }
      } else {
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

  // ================= SNACKBAR HELPERS =================
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
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ================= BUILD METHOD =================
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF667eea),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Edit Data Retur",
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  widget.data['nama_toko'] ?? 'Toko',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.close, size: 24),
              onPressed: () => Navigator.pop(context),
              tooltip: "Tutup",
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Info Card
                    Container(
                      width: double.infinity,
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
                            color: const Color(0xFF667eea).withOpacity(0.2),
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
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Edit Data Retur",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Perbarui informasi retur barang dengan data terbaru",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: isMobile ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Form Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Informasi Data",
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF667eea),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Isi semua informasi yang diperlukan",
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Form Fields
                    _buildTextField(
                      context: context,
                      label: "Tanggal",
                      controller: _tanggalController,
                      icon: Icons.calendar_today_rounded,
                      readOnly: true,
                      onTap: _selectDate,
                      isMobile: isMobile,
                      isRequired: true,
                    ),
                    
                    _buildTextField(
                      context: context,
                      label: "Nama Toko",
                      controller: _namaTokoController,
                      icon: Icons.storefront_rounded,
                      isMobile: isMobile,
                      isRequired: true,
                    ),
                    
                    _buildTextField(
                      context: context,
                      label: "Nama IT",
                      controller: _namaITController,
                      icon: Icons.person_outline_rounded,
                      isMobile: isMobile,
                      isRequired: true,
                    ),
                    
                    _buildTextField(
                      context: context,
                      label: "Nama Barang",
                      controller: _namaBarangController,
                      icon: Icons.inventory_2_rounded,
                      isMobile: isMobile,
                      isRequired: true,
                    ),
                    
                    _buildTextField(
                      context: context,
                      label: "SN Barang",
                      controller: _snBarangController,
                      icon: Icons.qr_code_scanner_rounded,
                      isMobile: isMobile,
                      isRequired: false,
                    ),
                    
                    _buildTextField(
                      context: context,
                      label: "Nomor Dokumen",
                      controller: _nomorDokumenController,
                      icon: Icons.description_rounded,
                      isMobile: isMobile,
                      isRequired: false,
                    ),
                    
                    // Kategori Dropdown
                    const SizedBox(height: 8),
                    Text(
                      "Kategori *",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 15,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[100]!,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedKategori,
                            isExpanded: true,
                            icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
                            style: TextStyle(
                              fontSize: isMobile ? 15 : 16,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            items: [
                              _buildDropdownItem('OK', Colors.green),
                              _buildDropdownItem('Service', Colors.orange),
                              _buildDropdownItem('Waste', Colors.red),
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
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      context: context,
                      label: "Keterangan",
                      controller: _keteranganController,
                      icon: Icons.note_alt_rounded,
                      maxLines: 3,
                      isMobile: isMobile,
                      isRequired: false,
                    ),
                    
                    // Foto Barang Section
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Foto Barang",
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF667eea),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        "Unggah foto barang yang diretur (Opsional)",
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Foto Display
                    _buildFotoDisplaySection(isMobile),
                    
                    // Action Buttons
                    const SizedBox(height: 32),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              "Batal",
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updateData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Simpan",
                                        style: TextStyle(
                                          fontSize: isMobile ? 15 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF667eea)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Menyimpan perubahan...",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoDisplaySection(bool isMobile) {
    if (_existingFotoBarang != null && !_fotoChanged) {
      return Column(
        children: [
          Container(
            height: isMobile ? 220 : 280,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _existingFotoBarang!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pilihSumberFoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text("Ubah Foto"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF667eea)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hapusFoto,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text("Hapus Foto"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_newFotoBarang != null) {
      return Column(
        children: [
          Container(
            height: isMobile ? 220 : 280,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _newFotoBarang!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_existingFotoBarang != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _batalUbahFoto,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text("Kembali"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              if (_existingFotoBarang != null) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pilihSumberFoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: const Text("Ganti Foto"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF667eea),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF667eea)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hapusFoto,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text("Hapus"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.red[200]!),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return InkWell(
        onTap: _pilihSumberFoto,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: isMobile ? 180 : 220,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[300]!,
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[50]!,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 40,
                  color: const Color(0xFF667eea).withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Tambahkan Foto Barang",
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Tap untuk mengambil atau memilih foto",
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Max. 2MB • Format: JPG, PNG",
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ================= HELPER WIDGETS =================
  Widget _buildTextField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    IconData? icon,
    int maxLines = 1,
    bool isRequired = true,
    bool readOnly = false,
    VoidCallback? onTap,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 14 : 15,
              color: Colors.grey[800],
            ),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            color: Colors.grey[800],
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    color: const Color(0xFF667eea),
                    size: 22,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
              gapPadding: 0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMobile ? 14 : 16,
            ),
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: isMobile ? 14 : 15,
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '$label wajib diisi';
                  }
                  return null;
                }
              : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String value, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}