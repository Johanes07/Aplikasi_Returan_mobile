<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}
include '../db/connection.php';

// === FILTER TANGGAL ===
$where = "";
$tanggal = "";
if (isset($_GET['tanggal']) && $_GET['tanggal'] != "") {
    $tanggal = $_GET['tanggal'];
    $where = "WHERE tanggal = '$tanggal'";
}

// === AMBIL DATA ===
$query = "SELECT * FROM retur_barang $where ORDER BY id DESC";
$result = mysqli_query($conn, $query);
$total_retur = mysqli_num_rows($result);
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Data Retur Barang - Sistem Retur</title>
  <link rel="stylesheet" href="template.css">
  <style>
    .filter-box {
      margin-bottom: 20px;
      background: #f8f9fa;
      border-radius: 10px;
      padding: 15px;
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 10px;
    }
    .filter-box label {
      font-weight: 600;
      color: #333;
    }
    .filter-box input[type="date"] {
      padding: 6px 10px;
      border: 1px solid #ccc;
      border-radius: 6px;
    }
    .filter-box button {
      background-color: #667eea;
      color: white;
      border: none;
      border-radius: 6px;
      padding: 8px 14px;
      cursor: pointer;
    }
    .filter-box button:hover {
      background-color: #5563d6;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>📊 Data Retur Barang</h2>
      <a href="report_retur_pdf.php" class="btn-download" target="_blank">📄 View PDF</a>
      <p style="color: #666; margin-top: 10px;">Total: <strong style="color: #667eea;"><?= $total_retur ?></strong> data retur</p>
    </div>
    
    <a href="index.php" class="back-link">Kembali ke Dashboard</a>

    <!-- 🔍 FILTER TANGGAL -->
    <form method="get" class="filter-box">
      <label for="tanggal">Filter Tanggal:</label>
      <input type="date" name="tanggal" id="tanggal" value="<?= htmlspecialchars($tanggal) ?>">
      <button type="submit">Tampilkan</button>
      <?php if($tanggal != ""): ?>
        <a href="retur_list.php" style="color:#667eea; text-decoration:none;">🔄 Reset</a>
      <?php endif; ?>
    </form>
    
    <div class="table-wrapper">
      <table>
        <thead>
          <tr>
            <th>No</th>
            <th>Tanggal</th>
            <th>Toko</th>
            <th>Nama IT</th>
            <th>Barang</th>
            <th>SN Barang</th>
            <th>No Dokumen</th>
            <th>Kategori</th>
            <th>Keterangan</th>
          </tr>
        </thead>
        <tbody>
          <?php if($total_retur > 0): ?>
            <?php 
            $no = 1;
            while($row = mysqli_fetch_assoc($result)): 
            ?>
            <tr>
              <td><?= $no++ ?></td>
              <td><?= date('d/m/Y', strtotime($row['tanggal'])) ?></td>
              <td><?= htmlspecialchars($row['nama_toko']) ?></td>
              <td><?= htmlspecialchars($row['nama_it']) ?></td>
              <td><?= htmlspecialchars($row['nama_barang']) ?></td>
              <td><?= htmlspecialchars($row['sn_barang']) ?></td>
              <td><?= htmlspecialchars($row['nomor_dokumen']) ?></td>
              <td>
  <?php
    $kategori = strtolower($row['kategori']);
    $badgeClass = 'badge-default';

    if ($kategori == 'ok') {
        $badgeClass = 'badge-ok';
    } elseif ($kategori == 'service') {
        $badgeClass = 'badge-service';
    } elseif ($kategori == 'waste') {
        $badgeClass = 'badge-waste';
    }
  ?>
  <span class="badge <?= $badgeClass ?>"><?= htmlspecialchars($row['kategori']) ?></span>
</td>

              <td><?= htmlspecialchars($row['keterangan']) ?></td>
            </tr>
            <?php endwhile; ?>
          <?php else: ?>
            <tr>
              <td colspan="9" style="text-align: center; padding: 40px; color: #999;">
                Belum ada data retur <?= $tanggal ? 'pada tanggal '.date('d/m/Y', strtotime($tanggal)) : 'yang tersedia' ?>
              </td>
            </tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</body>
</html>
