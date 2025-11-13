<?php
session_start();
include '../db/connection.php';

if (isset($_POST['login'])) {
    $nama_it = $_POST['nama_it'] ?? '';
    $password = $_POST['password'] ?? '';

    $sql = "SELECT * FROM user WHERE nama_it = ?";
    $stmt = mysqli_prepare($conn, $sql);
    mysqli_stmt_bind_param($stmt, "s", $nama_it);
    mysqli_stmt_execute($stmt);
    $res = mysqli_stmt_get_result($stmt);
    $user = mysqli_fetch_assoc($res);

    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['admin'] = $user['nama_it'];
        header("Location: index.php");
        exit;
    } else {
        $error = "Username atau password salah";
    }
}
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Login Admin - Sistem Retur Barang</title>
  <link rel="stylesheet" href="template.css">
</head>
<body>
  <div class="login-box">
    <h2>🔐 Login Admin</h2>
    <?php if(!empty($error)): ?>
      <div class="error">❌ <?= htmlspecialchars($error) ?></div>
    <?php endif; ?>
    <form method="post">
      <label>Nama IT</label>
      <input type="text" name="nama_it" required placeholder="Masukkan nama IT">
      
      <label>Password</label>
      <input type="password" name="password" required placeholder="Masukkan password">
      
      <button type="submit" name="login">Masuk ke Dashboard</button>
    </form>
  </div>
</body>
</html>