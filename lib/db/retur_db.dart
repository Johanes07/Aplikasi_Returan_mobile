import 'package:returan_apps/model/retur_model.dart';
import 'package:returan_apps/model/user_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class ReturDatabase {
  static final ReturDatabase instance = ReturDatabase._init();
  static Database? _database;
  ReturDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('retur_barang.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE retur_barang (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tanggal TEXT,
      nama_toko TEXT,
      nama_it TEXT,
      nama_barang TEXT,
      sn_barang TEXT,   
      nomor_dokumen TEXT,     
      kategori TEXT,
      keterangan TEXT,
      ttd_base64 TEXT
    )
  ''');

  // Tabel toko
  await db.execute('''
    CREATE TABLE toko (
      kode_toko TEXT PRIMARY KEY,
      nama_toko TEXT NOT NULL
    )
  ''');

  // Tabel user
  await db.execute('''
    CREATE TABLE user (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_it TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL
    )
  ''');
}


  Future<int> insertRetur(ReturBarang retur) async {
    final db = await instance.database;
    return await db.insert('retur_barang', retur.toMap());
  }

  Future<List<ReturBarang>> getAllRetur() async {
    final db = await instance.database;
    final result = await db.query('retur_barang');
    return result.map((e) => ReturBarang.fromMap(e)).toList();
  }

  // ================= USER ===================
Future<int> registerUser(User user) async {
  final db = await instance.database;
  return await db.insert('user', user.toMap());
}

Future<User?> loginUser(String namaIT, String password) async {
  final db = await instance.database;
  final result = await db.query(
    'user',
    where: 'nama_it = ? AND password = ?',
    whereArgs: [namaIT, password],
  );

  if (result.isNotEmpty) {
    return User(
      id: result.first['id'] as int,
      namaIT: result.first['nama_it'] as String,
      password: result.first['password'] as String,
    );
  }
  return null;
}

}
