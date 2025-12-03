<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}
include '../db/connection.php';

// === PAGINATION SETUP ===
$limit = 10;
$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$page = max(1, $page);
$offset = ($page - 1) * $limit;

// === FILTER SETUP ===
$where_conditions = [];
$tanggal = isset($_GET['tanggal']) && $_GET['tanggal'] != "" ? $_GET['tanggal'] : "";
$kategori = isset($_GET['kategori']) && $_GET['kategori'] != "" ? $_GET['kategori'] : "";

if ($tanggal != "") {
    $where_conditions[] = "tanggal = '$tanggal'";
}
if ($kategori != "") {
    $where_conditions[] = "kategori = '$kategori'";
}

$where = count($where_conditions) > 0 ? "WHERE " . implode(" AND ", $where_conditions) : "";

// === HITUNG TOTAL DATA ===
$count_query = "SELECT COUNT(*) as total FROM retur_barang $where";
$count_result = mysqli_query($conn, $count_query);
$total_retur = mysqli_fetch_assoc($count_result)['total'];
$total_pages = ceil($total_retur / $limit);

// === AMBIL DATA DENGAN LIMIT ===
$query = "SELECT * FROM retur_barang $where ORDER BY id DESC LIMIT $limit OFFSET $offset";
$result = mysqli_query($conn, $query);

// === HITUNG STATISTIK PER KATEGORI ===
$stats_query = "SELECT 
    SUM(CASE WHEN kategori = 'OK' THEN 1 ELSE 0 END) as total_ok,
    SUM(CASE WHEN kategori = 'Service' THEN 1 ELSE 0 END) as total_service,
    SUM(CASE WHEN kategori = 'Waste' THEN 1 ELSE 0 END) as total_waste
FROM retur_barang" . ($tanggal ? " WHERE tanggal = '$tanggal'" : "");
$stats_result = mysqli_query($conn, $stats_query);
$stats = mysqli_fetch_assoc($stats_result);
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Data Retur Barang - Sistem Retur</title>
  <link rel="stylesheet" href="template.css">
  <style>
    .filter-section {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      border-radius: 16px;
      padding: 25px;
      margin-bottom: 25px;
      box-shadow: 0 8px 24px rgba(102, 126, 234, 0.25);
    }

    .filter-header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 20px;
    }

    .filter-header svg {
      width: 24px;
      height: 24px;
      stroke: white;
      fill: none;
      stroke-width: 2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .filter-header h3 {
      color: white;
      margin: 0;
      font-size: 18px;
      font-weight: 600;
    }

    .filter-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin-bottom: 20px;
    }

    .filter-group {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .filter-group label {
      color: rgba(255, 255, 255, 0.9);
      font-size: 13px;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .filter-group input[type="date"] {
      padding: 12px 16px;
      border: 2px solid rgba(255, 255, 255, 0.2);
      border-radius: 10px;
      background: rgba(255, 255, 255, 0.15);
      color: white;
      font-size: 14px;
      transition: all 0.3s;
      backdrop-filter: blur(10px);
    }

    .filter-group input[type="date"]:focus {
      outline: none;
      border-color: rgba(255, 255, 255, 0.5);
      background: rgba(255, 255, 255, 0.25);
    }

    .filter-group input[type="date"]::-webkit-calendar-picker-indicator {
      filter: invert(1);
      cursor: pointer;
    }

    /* KATEGORI CHIPS */
    .category-filters {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
    }

    .category-chip {
      position: relative;
      padding: 12px 24px;
      border-radius: 25px;
      border: 2px solid rgba(255, 255, 255, 0.3);
      background: rgba(255, 255, 255, 0.15);
      color: white;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      backdrop-filter: blur(10px);
    }

    .category-chip:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0, 0, 0, 0.2);
      border-color: rgba(255, 255, 255, 0.5);
      background: rgba(255, 255, 255, 0.25);
    }

    .category-chip.active {
      background: white;
      border-color: white;
      color: #667eea;
      box-shadow: 0 4px 15px rgba(255, 255, 255, 0.3);
    }

    .category-chip .count {
      background: rgba(0, 0, 0, 0.15);
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 12px;
      font-weight: 700;
    }

    .category-chip.active .count {
      background: #667eea;
      color: white;
    }

    .category-chip-all {
      background: rgba(255, 255, 255, 0.2);
    }

    .category-chip-ok { border-color: rgba(76, 175, 80, 0.5); }
    .category-chip-ok.active { 
      background: #4CAF50; 
      border-color: #4CAF50;
      color: white;
    }

    .category-chip-service { border-color: rgba(255, 152, 0, 0.5); }
    .category-chip-service.active { 
      background: #FF9800; 
      border-color: #FF9800;
      color: white;
    }

    .category-chip-waste { border-color: rgba(244, 67, 54, 0.5); }
    .category-chip-waste.active { 
      background: #F44336; 
      border-color: #F44336;
      color: white;
    }

    .filter-actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
    }

    .btn-filter {
      padding: 12px 28px;
      border: none;
      border-radius: 25px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    .btn-filter-apply {
      background: white;
      color: #667eea;
      box-shadow: 0 4px 15px rgba(255, 255, 255, 0.3);
    }

    .btn-filter-apply:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(255, 255, 255, 0.4);
    }

    .btn-filter-reset {
      background: rgba(255, 255, 255, 0.15);
      color: white;
      border: 2px solid rgba(255, 255, 255, 0.3);
    }

    .btn-filter-reset:hover {
      background: rgba(255, 255, 255, 0.25);
      border-color: rgba(255, 255, 255, 0.5);
    }

    /* STATS CARDS */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 16px;
      margin-bottom: 25px;
    }

    .stat-card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
      transition: all 0.3s;
      border: 2px solid transparent;
    }

    .stat-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
    }

    .stat-card-total { border-color: #667eea; }
    .stat-card-ok { border-color: #4CAF50; }
    .stat-card-service { border-color: #FF9800; }
    .stat-card-waste { border-color: #F44336; }

    .stat-label {
      font-size: 13px;
      color: #666;
      margin-bottom: 8px;
      font-weight: 500;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .stat-value {
      font-size: 32px;
      font-weight: 700;
      margin-bottom: 4px;
    }

    .stat-card-total .stat-value { color: #667eea; }
    .stat-card-ok .stat-value { color: #4CAF50; }
    .stat-card-service .stat-value { color: #FF9800; }
    .stat-card-waste .stat-value { color: #F44336; }

    .stat-description {
      font-size: 12px;
      color: #999;
    }

    .foto-thumbnail {
      width: 60px;
      height: 60px;
      object-fit: cover;
      border-radius: 8px;
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

    @media (max-width: 768px) {
      .filter-grid {
        grid-template-columns: 1fr;
      }
      .stats-grid {
        grid-template-columns: 1fr;
      }
      .category-filters {
        justify-content: center;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2>Data Retur Barang</h2>
      <a href="report_retur_pdf.php<?= ($tanggal || $kategori) ? '?' : '' ?><?= $tanggal ? 'tanggal='.$tanggal : '' ?><?= ($tanggal && $kategori) ? '&' : '' ?><?= $kategori ? 'kategori='.$kategori : '' ?>" class="btn-download" target="_blank">View PDF</a>
    </div>
    
    <a href="index.php" class="back-link">Kembali ke Dashboard</a>

    <!-- STATS CARDS -->
    <div class="stats-grid">
      <div class="stat-card stat-card-total">
        <div class="stat-label">Total Retur</div>
        <div class="stat-value"><?= $total_retur ?></div>
        <div class="stat-description">Semua data</div>
      </div>
      <div class="stat-card stat-card-ok">
        <div class="stat-label">OK</div>
        <div class="stat-value"><?= $stats['total_ok'] ?></div>
        <div class="stat-description">Barang OK</div>
      </div>
      <div class="stat-card stat-card-service">
        <div class="stat-label">Service</div>
        <div class="stat-value"><?= $stats['total_service'] ?></div>
        <div class="stat-description">Perlu service</div>
      </div>
      <div class="stat-card stat-card-waste">
        <div class="stat-label">Waste</div>
        <div class="stat-value"><?= $stats['total_waste'] ?></div>
        <div class="stat-description">Tidak terpakai</div>
      </div>
    </div>

    <!-- FILTER SECTION -->
    <form method="get" class="filter-section">
      <div class="filter-header">
        <svg viewBox="0 0 24 24">
          <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
        </svg>
        <h3>Filter & Pencarian</h3>
      </div>

      <div class="filter-grid">
        <div class="filter-group">
          <label for="tanggal">Tanggal</label>
          <input type="date" name="tanggal" id="tanggal" value="<?= htmlspecialchars($tanggal) ?>">
        </div>
      </div>

      <div class="filter-group" style="margin-bottom: 20px;">
        <label>Kategori</label>
        <div class="category-filters">
          <a href="?<?= $tanggal ? 'tanggal='.$tanggal : '' ?>" 
             class="category-chip category-chip-all <?= $kategori == '' ? 'active' : '' ?>">
            <span>Semua</span>
            <span class="count"><?= $stats['total_ok'] + $stats['total_service'] + $stats['total_waste'] ?></span>
          </a>
          
          <a href="?<?= $tanggal ? 'tanggal='.$tanggal.'&' : '' ?>kategori=OK" 
             class="category-chip category-chip-ok <?= $kategori == 'OK' ? 'active' : '' ?>">
            <span>OK</span>
            <span class="count"><?= $stats['total_ok'] ?></span>
          </a>
          
          <a href="?<?= $tanggal ? 'tanggal='.$tanggal.'&' : '' ?>kategori=Service" 
             class="category-chip category-chip-service <?= $kategori == 'Service' ? 'active' : '' ?>">
            <span>Service</span>
            <span class="count"><?= $stats['total_service'] ?></span>
          </a>
          
          <a href="?<?= $tanggal ? 'tanggal='.$tanggal.'&' : '' ?>kategori=Waste" 
             class="category-chip category-chip-waste <?= $kategori == 'Waste' ? 'active' : '' ?>">
            <span>Waste</span>
            <span class="count"><?= $stats['total_waste'] ?></span>
          </a>
        </div>
      </div>

      <div class="filter-actions">
        <button type="submit" class="btn-filter btn-filter-apply">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
          Terapkan Filter
        </button>
        
        <?php if($tanggal != "" || $kategori != ""): ?>
          <a href="retur_list.php" class="btn-filter btn-filter-reset">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="1 4 1 10 7 10"></polyline>
              <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"></path>
            </svg>
            Reset Filter
          </a>
        <?php endif; ?>
      </div>
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
                  $kategori_val = strtolower($row['kategori']);
                  $badgeClass = 'badge-default';

                  if ($kategori_val == 'ok') $badgeClass = 'badge-ok';
                  elseif ($kategori_val == 'service') $badgeClass = 'badge-service';
                  elseif ($kategori_val == 'waste') $badgeClass = 'badge-waste';
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
                <?php if($kategori != ""): ?>
                  Tidak ada data retur dengan kategori <strong><?= htmlspecialchars($kategori) ?></strong>
                  <?= $tanggal ? ' pada tanggal '.date('d/m/Y', strtotime($tanggal)) : '' ?>
                <?php else: ?>
                  Belum ada data retur <?= $tanggal ? 'pada tanggal '.date('d/m/Y', strtotime($tanggal)) : 'yang tersedia' ?>
                <?php endif; ?>
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
        $query_params = [];
        if($tanggal) $query_params[] = "tanggal=$tanggal";
        if($kategori) $query_params[] = "kategori=$kategori";
        $query_string = count($query_params) > 0 ? "&" . implode("&", $query_params) : "";

        // First + Prev
        if($page > 1): ?>
          <a href="?page=1<?= $query_string ?>">First</a>
          <a href="?page=<?= $page - 1 ?><?= $query_string ?>">Prev</a>
        <?php else: ?>
          <span class="disabled">First</span>
          <span class="disabled">Prev</span>
        <?php endif; ?>

        <?php
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