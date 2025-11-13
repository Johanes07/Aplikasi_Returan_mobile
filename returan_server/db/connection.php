<?php
$host = "localhost";
$user = "root"; // ganti sesuai MySQL kamu
$pass = "";
$dbname = "returan_db";

$conn = mysqli_connect($host, $user, $pass, $dbname);

if (!$conn) {
    die(json_encode([
        "success" => false,
        "message" => "Koneksi gagal: " . mysqli_connect_error()
    ]));
}
?>
