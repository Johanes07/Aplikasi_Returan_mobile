class User {
  final int? id;
  final String namaIT;
  final String password;

  User({this.id, required this.namaIT, required this.password});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_it': namaIT,
      'password': password,
    };
  }
}
