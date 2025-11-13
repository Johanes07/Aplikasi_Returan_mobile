<?php
header('Content-Type: application/json');
require_once '../../db/connection.php';

if (!isset($_GET['id'])) {
    echo json_encode(["status" => "error", "message" => "Parameter ID diperlukan"]);
    exit;
}

$id = intval($_GET['id']);
$query = $conn->query("SELECT * FROM retur_barang WHERE id = $id");

if ($query->num_rows > 0) {
    $data = $query->fetch_assoc();
    echo json_encode(["status" => "success", "data" => $data]);
} else {
    echo json_encode(["status" => "error", "message" => "Data tidak ditemukan"]);
}

$conn->close();
?>
