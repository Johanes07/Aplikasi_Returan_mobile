<?php
include '../../db/connection.php';
header("Content-Type: application/json");

// Ambil data JSON
$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["success" => false, "message" => "Data tidak valid"]);
    exit;
}

$tanggal        = mysqli_real_escape_string($conn, $data['tanggal']);
$nama_toko      = mysqli_real_escape_string($conn, $data['nama_toko']);
$nama_it        = mysqli_real_escape_string($conn, $data['nama_it']);
$nama_barang    = mysqli_real_escape_string($conn, $data['nama_barang']);
$sn_barang      = mysqli_real_escape_string($conn, $data['sn_barang']);           // ✅ Tambahan
$nomor_dokumen  = mysqli_real_escape_string($conn, $data['nomor_dokumen']);       // ✅ Tambahan
$kategori       = mysqli_real_escape_string($conn, $data['kategori']);
$keterangan     = mysqli_real_escape_string($conn, $data['keterangan']);
$ttd_base64     = mysqli_real_escape_string($conn, $data['ttd_base64']);

$query = "INSERT INTO retur_barang (
    tanggal, nama_toko, nama_it, nama_barang, sn_barang, nomor_dokumen, kategori, keterangan, ttd_base64
) VALUES (
    '$tanggal', '$nama_toko', '$nama_it', '$nama_barang', '$sn_barang', '$nomor_dokumen', '$kategori', '$keterangan', '$ttd_base64'
)";

if (mysqli_query($conn, $query)) {
    echo json_encode(["success" => true, "message" => "Data berhasil disimpan"]);
} else {
    echo json_encode(["success" => false, "message" => mysqli_error($conn)]);
}
?>
