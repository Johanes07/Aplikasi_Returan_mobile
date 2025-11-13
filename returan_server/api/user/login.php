<?php
include '../../db/connection.php';
$data = json_decode(file_get_contents("php://input"), true);

$nama_it = $data['nama_it'] ?? '';
$password = $data['password'] ?? '';

$sql = "SELECT * FROM user WHERE nama_it = ?";
$stmt = mysqli_prepare($conn, $sql);
mysqli_stmt_bind_param($stmt, "s", $nama_it);
mysqli_stmt_execute($stmt);
$res = mysqli_stmt_get_result($stmt);
$user = mysqli_fetch_assoc($res);

if ($user && password_verify($password, $user['password'])) {
    // return user data (jangan sertakan password)
    unset($user['password']);
    echo json_encode(["success" => true, "user" => $user]);
} else {
    echo json_encode(["success" => false, "message" => "Login gagal"]);
}
?>
