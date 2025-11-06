import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:image/image.dart' as img;
import 'package:returan_apps/model/retur_model.dart';

class PrinterService {
  static final BlueThermalPrinter printer = BlueThermalPrinter.instance;

  /// Pastikan printer sudah terkoneksi
  static Future<bool> ensureConnected() async {
    try {
      bool? isConnected = await printer.isConnected;
      if (isConnected == true) return true;

      List<BluetoothDevice> devices = await printer.getBondedDevices();
      if (devices.isEmpty) {
        print("❌ Tidak ada printer yang terhubung.");
        return false;
      }

      // Coba connect ke printer pertama yang terdaftar
      await printer.connect(devices.first);
      await Future.delayed(const Duration(seconds: 1));

      bool? connected = await printer.isConnected;
      print(connected == true
          ? "✅ Printer berhasil terhubung."
          : "⚠️ Gagal terhubung ke printer.");
      return connected == true;
    } catch (e) {
      print("⚠️ Gagal menghubungkan printer: $e");
      return false;
    }
  }

  /// Helper: Print separator line
  static void _printSeparator({String char = "-", int size = 1}) {
    String line = char * 32;
    printer.printCustom(line, size, 1);
  }

  /// Helper: Print label-value pair dengan alignment
  static void _printLabelValue(String label, String value, {int size = 1}) {
    // Format: "Label    : Value"
    String paddedLabel = label.padRight(12);
    printer.printCustom("$paddedLabel: $value", size, 0);
  }

  /// Helper: Process and resize signature image
  static Uint8List? _processSignatureImage(Uint8List? ttdImage) {
    if (ttdImage == null) return null;

    try {
      img.Image? signature = img.decodeImage(ttdImage);
      if (signature == null) return null;

      // Resize ke lebar max 384px (standar thermal printer)
      // Maintain aspect ratio
      int targetWidth = 300;
      if (signature.width > targetWidth) {
        signature = img.copyResize(
          signature,
          width: targetWidth,
          interpolation: img.Interpolation.linear,
        );
      }

      // Convert ke grayscale untuk hasil lebih baik
      signature = img.grayscale(signature);

      // Tingkatkan kontras
      signature = img.adjustColor(signature, contrast: 1.2);

      return Uint8List.fromList(img.encodePng(signature));
    } catch (e) {
      print("⚠️ Gagal memproses gambar TTD: $e");
      return null;
    }
  }

  /// Helper: Print multi-line text (untuk keterangan panjang)
  static void _printMultiLineText(String text, {int maxChars = 32, int size = 1}) {
    if (text.isEmpty) {
      printer.printCustom("-", size, 0);
      return;
    }

    List<String> words = text.split(' ');
    String currentLine = '';

    for (String word in words) {
      if ((currentLine + word).length > maxChars) {
        if (currentLine.isNotEmpty) {
          printer.printCustom(currentLine.trim(), size, 0);
          currentLine = '';
        }
        // Jika satu kata terlalu panjang, potong
        if (word.length > maxChars) {
          printer.printCustom(word.substring(0, maxChars), size, 0);
          currentLine = word.substring(maxChars) + ' ';
        } else {
          currentLine = word + ' ';
        }
      } else {
        currentLine += word + ' ';
      }
    }

    if (currentLine.isNotEmpty) {
      printer.printCustom(currentLine.trim(), size, 0);
    }
  }

  /// Cetak data retur (versi diperbaiki dengan format lebih bagus)
  static Future<void> printRetur(ReturBarang retur, {Uint8List? ttdImage}) async {
    try {
      bool connected = await ensureConnected();
      if (!connected) {
        print("❌ Printer belum terkoneksi, proses print dibatalkan.");
        return;
      }

      // ========== HEADER ==========
      printer.printNewLine();
      _printSeparator(char: "=", size: 1);
      printer.printCustom("RETUR GUDANG IT", 3, 1); // Size 3, Center
      _printSeparator(char: "=", size: 1);
      printer.printNewLine();

      // ========== INFO TANGGAL ==========
      printer.printCustom("Tanggal Retur", 1, 1);
      printer.printCustom(retur.tanggal, 2, 1);
      printer.printNewLine();

      // ========== DATA RETUR ==========
      _printSeparator(char: "-", size: 0);
      _printLabelValue("Nama Toko", retur.namaToko, size: 1);
      _printLabelValue("IT Checker", retur.namaIT, size: 1);
      _printLabelValue("Nama Barang", retur.namaBarang, size: 1);

      // ✅ Tambahan dua kolom baru:
      _printLabelValue("SN Barang", retur.snBarang, size: 1);
      _printLabelValue("No Dokumen", retur.nomorDokumen, size: 1);
      
      _printSeparator(char: "-", size: 0);
      printer.printNewLine();

      // ========== KATEGORI (BOLD & CENTER) ==========
      printer.printCustom("KATEGORI", 1, 1);
      
      // Print kategori dengan style berbeda (ASCII safe)
      String kategoriSymbol = "";
      switch (retur.kategori) {
        case 'OK':
          kategoriSymbol = "[ OK ]";
          break;
        case 'Service':
          kategoriSymbol = "[ SERVICE ]";
          break;
        case 'Waste':
          kategoriSymbol = "[ WASTE ]";
          break;
        default:
          kategoriSymbol = retur.kategori;
      }
      printer.printCustom(kategoriSymbol, 2, 1); // Size 2, Center
      printer.printNewLine();

      // ========== KETERANGAN ==========
      _printSeparator(char: "-", size: 0);
      printer.printCustom("Keterangan:", 1, 0);
      _printMultiLineText(retur.keterangan, maxChars: 32, size: 1);
      _printSeparator(char: "-", size: 0);
      printer.printNewLine();

      // ========== TANDA TANGAN ==========
      if (ttdImage != null) {
        printer.printCustom("Tanda Tangan:", 1, 1);
        printer.printNewLine();

        // Process image untuk hasil lebih baik
        Uint8List? processedImage = _processSignatureImage(ttdImage);
        if (processedImage != null) {
          printer.printImageBytes(processedImage);
        } else {
          // Fallback jika processing gagal
          img.Image? signature = img.decodeImage(ttdImage);
          if (signature != null) {
            printer.printImageBytes(Uint8List.fromList(img.encodePng(signature)));
          }
        }
        printer.printNewLine();
        _printSeparator(char: "-", size: 0);
        printer.printNewLine();
      }

      // ========== FOOTER ==========
      printer.printCustom("Terima Kasih", 2, 1);
      printer.printCustom("Sistem Retur IT", 0, 1);
      _printSeparator(char: "=", size: 1);
      printer.printNewLine();
      printer.printNewLine();
      printer.printNewLine();
      
      // Uncomment jika printer support paper cut
      // printer.paperCut();

      print("✅ Print retur selesai, koneksi tetap aktif.");
    } catch (e) {
      print("⚠️ Gagal print: $e");
    }
  }

  /// Test print sederhana (versi diperbaiki)
  static Future<void> printTest({Uint8List? ttdImage}) async {
    try {
      bool connected = await ensureConnected();
      if (!connected) {
        print("❌ Printer belum terkoneksi, test print dibatalkan.");
        return;
      }

      printer.printNewLine();
      _printSeparator(char: "=", size: 1);
      printer.printCustom("TEST PRINT", 3, 1);
      _printSeparator(char: "=", size: 1);
      printer.printNewLine();

      printer.printCustom("Sistem Retur IT", 1, 1);
      printer.printCustom("Thermal Printer Test", 1, 1);
      printer.printNewLine();

      _printSeparator(char: "-", size: 0);
      _printLabelValue("Status", "Connected", size: 1);
      _printLabelValue("Printer", "Bluetooth", size: 1);
      _printLabelValue("Test Date", DateTime.now().toString().substring(0, 10), size: 1);
      _printSeparator(char: "-", size: 0);
      printer.printNewLine();

      // Test berbagai ukuran font
      printer.printCustom("Font Size 0", 0, 1);
      printer.printCustom("Font Size 1", 1, 1);
      printer.printCustom("Font Size 2", 2, 1);
      printer.printCustom("Font Size 3", 3, 1);
      printer.printNewLine();

      // Test alignment
      printer.printCustom("Left Align", 1, 0);
      printer.printCustom("Center Align", 1, 1);
      printer.printCustom("Right Align", 1, 2);
      printer.printNewLine();

      if (ttdImage != null) {
        printer.printCustom("Test Signature:", 1, 1);
        printer.printNewLine();
        
        Uint8List? processedImage = _processSignatureImage(ttdImage);
        if (processedImage != null) {
          printer.printImageBytes(processedImage);
        } else {
          img.Image? signature = img.decodeImage(ttdImage);
          if (signature != null) {
            printer.printImageBytes(Uint8List.fromList(img.encodePng(signature)));
          }
        }
        printer.printNewLine();
      }

      _printSeparator(char: "=", size: 1);
      printer.printCustom("Test Selesai", 2, 1);
      _printSeparator(char: "=", size: 1);
      printer.printNewLine();
      printer.printNewLine();
      printer.printNewLine();

      // Uncomment jika printer support paper cut
      // printer.paperCut();

      print("✅ Test print selesai, koneksi tetap aktif.");
    } catch (e) {
      print("⚠️ Gagal test print: $e");
    }
  }

  /// Tambahan: putuskan koneksi manual (opsional)
  static Future<void> disconnectPrinter() async {
    try {
      await printer.disconnect();
      print("🔌 Printer terputus manual.");
    } catch (e) {
      print("⚠️ Gagal disconnect printer: $e");
    }
  }

  /// Tambahan: Get list of bonded devices
  static Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await printer.getBondedDevices();
    } catch (e) {
      print("⚠️ Gagal get bonded devices: $e");
      return [];
    }
  }

  /// Tambahan: Check connection status
  static Future<bool> isConnected() async {
    try {
      bool? connected = await printer.isConnected;
      return connected ?? false;
    } catch (e) {
      print("⚠️ Gagal cek status koneksi: $e");
      return false;
    }
  }
}