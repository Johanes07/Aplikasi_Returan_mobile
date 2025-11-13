<?php
include '../../db/connection.php';
$data = json_decode(file_get_contents("php://input"), true);

$nama_it = $data['nama_it'] ?? '';
$password = $data['password'] ?? '';

if (empty($nama_it) || empty($password)) {
    echo json_encode(["success" => false, "message" => "Semua field wajib diisi"]);
    exit;
}

// Cek apakah user sudah ada
$check = mysqli_prepare($conn, "SELECT id FROM user WHERE nama_it = ?");
mysqli_stmt_bind_param($check, "s", $nama_it);
mysqli_stmt_execute($check);
$result = mysqli_stmt_get_result($check);

if (mysqli_num_rows($result) > 0) {
    echo json_encode(["success" => false, "message" => "Nama IT sudah terdaftar"]);
    exit;
}

// Hash password sebelum simpan
$hashedPassword = password_hash($password, PASSWORD_DEFAULT);

$sql = "INSERT INTO user (nama_it, password) VALUES (?, ?)";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "ss", $nama_it, $hashedPassword);
$success = mysqli_stmt_execute($stmt);

if ($success) {
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["success" => false, "message" => "Gagal menyimpan user"]);
}
?>
