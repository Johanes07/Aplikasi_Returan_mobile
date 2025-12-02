<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include '../../db/connection.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

$id = $input['id'] ?? null;
$tanggal = $input['tanggal'] ?? '';
$nama_toko = $input['nama_toko'] ?? '';
$nama_it = $input['nama_it'] ?? '';
$nama_barang = $input['nama_barang'] ?? '';
$sn_barang = $input['sn_barang'] ?? '';
$nomor_dokumen = $input['nomor_dokumen'] ?? '';
$kategori = $input['kategori'] ?? '';
$keterangan = $input['keterangan'] ?? '';
$ttd_base64 = $input['ttd_base64'] ?? null;
$foto_barang = $input['foto_barang'] ?? null; // ? TAMBAHAN

if (!$id) {
    echo json_encode(['success' => false, 'message' => 'ID tidak boleh kosong']);
    exit;
}

if (empty($tanggal) || empty($nama_toko) || empty($nama_it) || empty($nama_barang) || empty($kategori)) {
    echo json_encode(['success' => false, 'message' => 'Field wajib tidak boleh kosong']);
    exit;
}

// ? LOGIKA UPDATE: Cek apakah ada TTD baru DAN Foto baru
$updateTTD = ($ttd_base64 !== null);
$updateFoto = ($foto_barang !== null);

if ($updateTTD && $updateFoto) {
    // Update TTD dan Foto
    $query = "UPDATE retur_barang SET 
                tanggal = ?,
                nama_toko = ?,
                nama_it = ?,
                nama_barang = ?,
                sn_barang = ?,
                nomor_dokumen = ?,
                kategori = ?,
                keterangan = ?,
                ttd_base64 = ?,
                foto_barang = ?
              WHERE id = ?";
    
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, "ssssssssssi", 
        $tanggal, $nama_toko, $nama_it, $nama_barang, 
        $sn_barang, $nomor_dokumen, $kategori, $keterangan, 
        $ttd_base64, $foto_barang, $id
    );
} elseif ($updateTTD && !$updateFoto) {
    // Update TTD saja
    $query = "UPDATE retur_barang SET 
                tanggal = ?,
                nama_toko = ?,
                nama_it = ?,
                nama_barang = ?,
                sn_barang = ?,
                nomor_dokumen = ?,
                kategori = ?,
                keterangan = ?,
                ttd_base64 = ?
              WHERE id = ?";
    
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, "sssssssssi", 
        $tanggal, $nama_toko, $nama_it, $nama_barang, 
        $sn_barang, $nomor_dokumen, $kategori, $keterangan, 
        $ttd_base64, $id
    );
} elseif (!$updateTTD && $updateFoto) {
    // Update Foto saja
    $query = "UPDATE retur_barang SET 
                tanggal = ?,
                nama_toko = ?,
                nama_it = ?,
                nama_barang = ?,
                sn_barang = ?,
                nomor_dokumen = ?,
                kategori = ?,
                keterangan = ?,
                foto_barang = ?
              WHERE id = ?";
    
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, "sssssssssi", 
        $tanggal, $nama_toko, $nama_it, $nama_barang, 
        $sn_barang, $nomor_dokumen, $kategori, $keterangan, 
        $foto_barang, $id
    );
} else {
    // Update tanpa TTD dan Foto (tidak mengubah yang lama)
    $query = "UPDATE retur_barang SET 
                tanggal = ?,
                nama_toko = ?,
                nama_it = ?,
                nama_barang = ?,
                sn_barang = ?,
                nomor_dokumen = ?,
                kategori = ?,
                keterangan = ?
              WHERE id = ?";
    
    $stmt = mysqli_prepare($conn, $query);
    mysqli_stmt_bind_param($stmt, "ssssssssi", 
        $tanggal, $nama_toko, $nama_it, $nama_barang, 
        $sn_barang, $nomor_dokumen, $kategori, $keterangan, $id
    );
}

if (mysqli_stmt_execute($stmt)) {
    echo json_encode([
        'success' => true, 
        'message' => 'Data berhasil diupdate'
    ]);
} else {
    echo json_encode([
        'success' => false, 
        'message' => 'Gagal update data: ' . mysqli_error($conn)
    ]);
}

mysqli_stmt_close($stmt);
mysqli_close($conn);
?>