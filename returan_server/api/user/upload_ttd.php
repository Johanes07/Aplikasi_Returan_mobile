<?php
include '../../db/connection.php';

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(["success" => false, "message" => "Invalid request method"]);
    exit;
}

$nama_it = $_POST['nama_it'] ?? '';
$ttd_base64 = $_POST['ttd_base64'] ?? '';

if (empty($nama_it) || empty($ttd_base64)) {
    echo json_encode(["success" => false, "message" => "Data tidak lengkap"]);
    exit;
}

// Pastikan kolom 'ttd_base64' ada di tabel 'users' (atau buat kolom baru di database)
$query = "UPDATE users SET ttd_base64 = ? WHERE nama_it = ?";
$stmt = $conn->prepare($query);
$stmt->bind_param("ss", $ttd_base64, $nama_it);

if ($stmt->execute()) {
    echo json_encode(["success" => true, "message" => "TTD berhasil diupload"]);
} else {
    echo json_encode(["success" => false, "message" => "Gagal menyimpan TTD"]);
}

$stmt->close();
$conn->close();
?>
