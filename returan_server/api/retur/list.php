<?php
include '../../db/connection.php';
header("Content-Type: application/json");

// ? Ambil parameter filter dari query string
$tanggal = isset($_GET['tanggal']) ? mysqli_real_escape_string($conn, $_GET['tanggal']) : null;
$kategori = isset($_GET['kategori']) ? mysqli_real_escape_string($conn, $_GET['kategori']) : null;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
$offset = ($page - 1) * $limit;

// ? PENTING: Jangan select foto_barang dan ttd_base64 di list
$query = "SELECT 
    id, tanggal, nama_toko, nama_it, nama_barang, 
    sn_barang, nomor_dokumen, kategori, keterangan,
    CASE WHEN foto_barang IS NOT NULL AND foto_barang != '' THEN 1 ELSE 0 END as has_foto,
    CASE WHEN ttd_base64 IS NOT NULL AND ttd_base64 != '' THEN 1 ELSE 0 END as has_ttd
FROM retur_barang WHERE 1=1";

// ? Filter by tanggal (server-side)
if ($tanggal) {
    $query .= " AND tanggal = '$tanggal'";
}

// ? Filter by kategori (server-side)
if ($kategori && $kategori != 'All') {
    $query .= " AND kategori = '$kategori'";
}

$query .= " ORDER BY id DESC";

// ? Get total count untuk pagination
$countQuery = "SELECT COUNT(*) as total FROM retur_barang WHERE 1=1";
if ($tanggal) {
    $countQuery .= " AND tanggal = '$tanggal'";
}
if ($kategori && $kategori != 'All') {
    $countQuery .= " AND kategori = '$kategori'";
}
$countResult = mysqli_query($conn, $countQuery);
$totalItems = mysqli_fetch_assoc($countResult)['total'];

// ? Add pagination
$query .= " LIMIT $limit OFFSET $offset";

$result = mysqli_query($conn, $query);

$data = [];
while ($row = mysqli_fetch_assoc($result)) {
    $data[] = $row;
}

echo json_encode([
    "success" => true, 
    "data" => $data,
    "pagination" => [
        "current_page" => $page,
        "total_items" => (int)$totalItems,
        "items_per_page" => $limit,
        "total_pages" => ceil($totalItems / $limit)
    ]
]);

mysqli_close($conn);
?>