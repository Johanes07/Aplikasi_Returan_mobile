class ReturBarang {
  final int? id;
  final String tanggal;
  final String namaToko;
  final String namaIT;
  final String namaBarang;
  final String snBarang;         // ✅ Tambah ini
  final String nomorDokumen;     // ✅ Tambah ini
  final String kategori;
  final String keterangan;
  final String? ttdBase64;

  ReturBarang({
    this.id,
    required this.tanggal,
    required this.namaToko,
    required this.namaIT,
    required this.namaBarang,
    required this.snBarang,
    required this.nomorDokumen,
    required this.kategori,
    required this.keterangan,
    this.ttdBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tanggal': tanggal,
      'nama_toko': namaToko,
      'nama_it': namaIT,
      'nama_barang': namaBarang,
      'sn_barang': snBarang,
      'nomor_dokumen': nomorDokumen,
      'kategori': kategori,
      'keterangan': keterangan,
      'ttd_base64': ttdBase64,
    };
  }

  factory ReturBarang.fromMap(Map<String, dynamic> map) {
    return ReturBarang(
      id: map['id'],
      tanggal: map['tanggal'],
      namaToko: map['nama_toko'],
      namaIT: map['nama_it'],
      namaBarang: map['nama_barang'],
      snBarang: map['sn_barang'] ?? '',
      nomorDokumen: map['nomor_dokumen'] ?? '',
      kategori: map['kategori'],
      keterangan: map['keterangan'],
      ttdBase64: map['ttd_base64'],
    );
  }
}
