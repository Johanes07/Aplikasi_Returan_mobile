<?php
// Hanya jalankan sekali dari browser: http://localhost/returan_server/sql/create_admin.php
include '../db/connection.php';

$nama_it = 'admin';
$password_plain = 'admin123'; // ganti sesuai yang kamu mau
$password_hash = password_hash($password_plain, PASSWORD_DEFAULT);

$sql = "INSERT INTO user (nama_it, password) VALUES (?, ?)";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "ss", $nama_it, $password_hash);
$ok = mysqli_stmt_execute($stmt);

if ($ok) {
  echo "Admin created: username = $nama_it, password = $password_plain";
} else {
  echo "Gagal: " . mysqli_error($conn);
}
?>
