<?php
include '../../db/connection.php';
header("Content-Type: application/json");

$id = isset($_GET['id']) ? (int)$_GET['id'] : 0;

if ($id <= 0) {
    echo json_encode(["success" => false, "message" => "ID tidak valid"]);
    exit;
}

// ? Ambil SEMUA data termasuk foto dan ttd
$query = "SELECT * FROM retur_barang WHERE id = $id";
$result = mysqli_query($conn, $query);

if ($row = mysqli_fetch_assoc($result)) {
    echo json_encode(["success" => true, "data" => $row]);
} else {
    echo json_encode(["success" => false, "message" => "Data tidak ditemukan"]);
}

mysqli_close($conn);
?>