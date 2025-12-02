<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}
include '../db/connection.php';

// === PAGINATION SETUP ===
$limit = 10; // Data per halaman
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$page = max(1, $page); // Minimal halaman 1
$offset = ($page - 1) * $limit;

// === FILTER TANGGAL ===
$where = "";
$tanggal = "";
if (isset($_GET['tanggal']) && $_GET['tanggal'] != "") {
    $tanggal = $_GET['tanggal'];
    $where = "WHERE tanggal = '$tanggal'";
}

// === HITUNG TOTAL DATA ===
$count_query = "SELECT COUNT(*) as total FROM retur_barang $where";
$count_result = mysqli_query($conn, $count_query);
$total_retur = mysqli_fetch_assoc($count_result)['total'];
$total_pages = ceil($total_retur / $limit);

// === AMBIL DATA DENGAN LIMIT ===
$query = "SELECT * FROM retur_barang $where ORDER BY id DESC LIMIT $limit OFFSET $offset";
$result = mysqli_query($conn, $query);
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

    .foto-thumbnail {
      width: 60px;
      height: 60px;
      object-fit: cover;
      border-radius: 6px;
      cursor: pointer;
      transition: transform 0.2s;
      border: 2px solid #e0e0e0;
    }
    .foto-thumbnail:hover {
      transform: scale(1.1);
      border-color: #667eea;
    }
    .no-foto {
      color: #999;
      font-style: italic;
      font-size: 13px;
    }

    .modal-lightbox {
      display: none;
      position: fixed;
      z-index: 9999;
      left: 0;
      top: 0;
      width: 100%;
      height: 100%;
      background-color: rgba(0,0,0,0.9);
      animation: fadeIn 0.3s;
    }
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .modal-content-img {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      max-width: 90%;
      max-height: 90%;
      object-fit: contain;
      border-radius: 8px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.5);
    }
    .close-modal {
      position: absolute;
      top: 20px;
      right: 35px;
      color: #f1f1f1;
      font-size: 40px;
      font-weight: bold;
      cursor: pointer;
      transition: 0.3s;
    }
    .close-modal:hover {
      color: #ff4444;
    }
    .modal-caption {
      position: absolute;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      color: #fff;
      background: rgba(0,0,0,0.7);
      padding: 10px 20px;
      border-radius: 20px;
      font-size: 14px;
    }

    /* PAGINATION STYLE */
    .pagination {
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 8px;
      margin-top: 25px;
      flex-wrap: wrap;
    }
    .pagination a, .pagination span {
      padding: 10px 15px;
      border: 1px solid #ddd;
      border-radius: 6px;
      text-decoration: none;
      color: #667eea;
      font-weight: 500;
      transition: all 0.3s;
    }
    .pagination a:hover {
      background-color: #667eea;
      color: white;
      border-color: #667eea;
    }
    .pagination .active {
      background-color: #667eea;
      color: white;
      border-color: #667eea;
      cursor: default;
    }
    .pagination .disabled {
      color: #ccc;
      cursor: not-allowed;
      pointer-events: none;
    }
    .pagination-info {
      text-align: center;
      color: #666;
      margin-top: 10px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>Data Retur Barang</h2>
      <a href="report_retur_pdf.php<?= $tanggal ? '?tanggal='.$tanggal : '' ?>" class="btn-download" target="_blank">View PDF</a>
      <p style="color: #666; margin-top: 10px;">Total: <strong style="color: #667eea;"><?= $total_retur ?></strong> data retur</p>
    </div>
    
    <a href="index.php" class="back-link">Kembali ke Dashboard</a>

    <!-- FILTER -->
    <form method="get" class="filter-box">
      <label for="tanggal">Filter Tanggal:</label>
      <input type="date" name="tanggal" id="tanggal" value="<?= htmlspecialchars($tanggal) ?>">
      <button type="submit">Tampilkan</button>
      <?php if($tanggal != ""): ?>
        <a href="retur_list.php" style="color:#667eea; text-decoration:none;">Reset</a>
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
            <th>Foto</th>
            <th>Keterangan</th>
          </tr>
        </thead>
        <tbody>
          <?php if($total_retur > 0): ?>
            <?php 
            $no = $offset + 1;
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

                  if ($kategori == 'ok') $badgeClass = 'badge-ok';
                  elseif ($kategori == 'service') $badgeClass = 'badge-service';
                  elseif ($kategori == 'waste') $badgeClass = 'badge-waste';
                ?>
                <span class="badge <?= $badgeClass ?>"><?= htmlspecialchars($row['kategori']) ?></span>
              </td>
              <td style="text-align: center;">
                <?php 
                $foto = $row['foto_barang'] ?? '';
                if(!empty($foto) && $foto != '' && $foto != 'null'): 
                  $foto_src = $foto;
                  if (strpos($foto, 'data:image') === false && strpos($foto, 'http') === false) {
                    $foto_src = 'data:image/jpeg;base64,' . $foto;
                  }
                ?>
                  <img 
                    src="<?= $foto_src ?>" 
                    alt="Foto Barang" 
                    class="foto-thumbnail"
                    onclick="openModal('<?= htmlspecialchars($foto_src, ENT_QUOTES) ?>', '<?= htmlspecialchars($row['nama_barang'], ENT_QUOTES) ?>')"
                    onerror="this.parentElement.innerHTML='<span class=\'no-foto\'>Error load</span>'"
                  >
                <?php else: ?>
                  <span class="no-foto">Tidak ada foto</span>
                <?php endif; ?>
              </td>
              <td><?= htmlspecialchars($row['keterangan']) ?></td>
            </tr>
            <?php endwhile; ?>
          <?php else: ?>
            <tr>
              <td colspan="10" style="text-align: center; padding: 40px; color: #999;">
                Belum ada data retur <?= $tanggal ? 'pada tanggal '.date('d/m/Y', strtotime($tanggal)) : 'yang tersedia' ?>
              </td>
            </tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>

    <!-- PAGINATION -->
    <?php if($total_pages > 1): ?>
      <div class="pagination">
        <?php
        $query_string = $tanggal ? "&tanggal=$tanggal" : "";

        // First + Prev
        if($page > 1): ?>
          <a href="?page=1<?= $query_string ?>">First</a>
          <a href="?page=<?= $page - 1 ?><?= $query_string ?>">Prev</a>
        <?php else: ?>
          <span class="disabled">First</span>
          <span class="disabled">Prev</span>
        <?php endif; ?>

        <?php
        // Nomor halaman
        $start = max(1, $page - 3);
        $end = min($total_pages, $page + 3);

        if($start > 1): ?>
          <a href="?page=1<?= $query_string ?>">1</a>
          <?php if($start > 2): ?><span>...</span><?php endif; ?>
        <?php endif; ?>

        <?php for($i = $start; $i <= $end; $i++): ?>
          <?php if($i == $page): ?>
            <span class="active"><?= $i ?></span>
          <?php else: ?>
            <a href="?page=<?= $i ?><?= $query_string ?>"><?= $i ?></a>
          <?php endif; ?>
        <?php endfor; ?>

        <?php if($end < $total_pages): ?>
          <?php if($end < $total_pages - 1): ?><span>...</span><?php endif; ?>
          <a href="?page=<?= $total_pages ?><?= $query_string ?>"><?= $total_pages ?></a>
        <?php endif; ?>

        <?php
        // Next + Last
        if($page < $total_pages): ?>
          <a href="?page=<?= $page + 1 ?><?= $query_string ?>">Next</a>
          <a href="?page=<?= $total_pages ?><?= $query_string ?>">Last</a>
        <?php else: ?>
          <span class="disabled">Next</span>
          <span class="disabled">Last</span>
        <?php endif; ?>
      </div>

      <div class="pagination-info">
        Menampilkan data <?= $offset + 1 ?> - <?= min($offset + $limit, $total_retur) ?> dari total <?= $total_retur ?> data (Halaman <?= $page ?> dari <?= $total_pages ?>)
      </div>
    <?php endif; ?>
  </div>

  <!-- MODAL -->
  <div id="lightboxModal" class="modal-lightbox" onclick="closeModal()">
    <span class="close-modal">&times;</span>
    <img id="lightboxImage" class="modal-content-img" src="">
    <div id="lightboxCaption" class="modal-caption"></div>
  </div>

  <script>
    function openModal(imageSrc, caption) {
      document.getElementById('lightboxModal').style.display = 'block';
      document.getElementById('lightboxImage').src = imageSrc;
      document.getElementById('lightboxCaption').textContent = caption;
      document.body.style.overflow = 'hidden';
    }

    function closeModal() {
      document.getElementById('lightboxModal').style.display = 'none';
      document.body.style.overflow = 'auto';
    }

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') closeModal();
    });
  </script>
</body>
</html>
