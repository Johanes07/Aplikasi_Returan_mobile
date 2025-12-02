<?php
session_start();
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}
$admin = $_SESSION['admin'];

// Koneksi database
include '../db/connection.php';

// Total retur
$total_query = mysqli_query($conn, "SELECT COUNT(*) as total FROM retur_barang");
$total_retur = mysqli_fetch_assoc($total_query)['total'];

// Retur bulan ini
$bulan_ini = date('Y-m');
$bulan_query = mysqli_query($conn, "SELECT COUNT(*) as total FROM retur_barang WHERE DATE_FORMAT(tanggal, '%Y-%m') = '$bulan_ini'");
$retur_bulan_ini = mysqli_fetch_assoc($bulan_query)['total'];

// Total toko
$toko_query = mysqli_query($conn, "SELECT COUNT(DISTINCT nama_toko) as total FROM retur_barang");
$total_toko = mysqli_fetch_assoc($toko_query)['total'];

// Retur per kategori
$kategori_query = mysqli_query($conn, "SELECT kategori, COUNT(*) as jumlah FROM retur_barang GROUP BY kategori ORDER BY jumlah DESC");

// Retur per bulan (6 bulan terakhir)
$hari_query = mysqli_query($conn, "
    SELECT 
        DATE(tanggal) AS hari, 
        COUNT(*) AS jumlah
    FROM retur_barang
    WHERE tanggal >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
    GROUP BY DATE(tanggal)
    ORDER BY hari ASC
");


// Top 5 toko dengan retur terbanyak
$top_toko_query = mysqli_query($conn, "
    SELECT nama_toko, COUNT(*) as jumlah 
    FROM retur_barang 
    GROUP BY nama_toko 
    ORDER BY jumlah DESC 
    LIMIT 5
");

// Retur terbaru
$recent_query = mysqli_query($conn, "SELECT * FROM retur_barang ORDER BY id DESC LIMIT 5");
?>
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dashboard - Sistem Retur Barang IT</title>
  <link rel="stylesheet" href="template.css">
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <style>
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 20px;
      margin: 30px 0;
    }
    .stat-card {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      padding: 25px;
      border-radius: 12px;
      color: white;
      box-shadow: 0 4px 16px rgba(102, 126, 234, 0.3);
      transition: transform 0.3s ease;
      opacity: 0;
      animation: slideInUp 0.6s ease forwards;
    }
    .stat-card:nth-child(1) { animation-delay: 0.1s; }
    .stat-card:nth-child(2) { animation-delay: 0.2s; }
    .stat-card:nth-child(3) { animation-delay: 0.3s; }
    
    @keyframes slideInUp {
      from {
        opacity: 0;
        transform: translateY(30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    
    .stat-card:hover {
      transform: translateY(-5px) scale(1.02);
    }
    .stat-card h3 {
      font-size: 14px;
      font-weight: 500;
      margin-bottom: 10px;
      opacity: 0.9;
    }
    .stat-card .number {
      font-size: 36px;
      font-weight: 700;
      margin-bottom: 5px;
    }
    .stat-card .label {
      font-size: 12px;
      opacity: 0.8;
    }
    .chart-container {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
      margin: 20px 0;
      opacity: 0;
      animation: fadeInScale 0.8s ease forwards;
      position: relative;
      overflow: hidden;
    }
    
    .chart-container::before {
      content: '';
      position: absolute;
      top: 0;
      left: -100%;
      width: 100%;
      height: 100%;
      background: linear-gradient(90deg, transparent, rgba(102, 126, 234, 0.1), transparent);
      transition: left 0.5s ease;
    }
    
    .chart-container:hover::before {
      left: 100%;
    }
    
    @keyframes fadeInScale {
      from {
        opacity: 0;
        transform: scale(0.95);
      }
      to {
        opacity: 1;
        transform: scale(1);
      }
    }
    
    .chart-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
      gap: 20px;
      margin: 20px 0;
    }
    
    .chart-grid .chart-container:nth-child(1) { animation-delay: 0.2s; }
    .chart-grid .chart-container:nth-child(2) { animation-delay: 0.4s; }
    
    .chart-title {
      font-size: 18px;
      font-weight: 600;
      color: #333;
      margin-bottom: 20px;
      position: relative;
      padding-left: 15px;
    }
    
    .chart-title::before {
      content: '';
      position: absolute;
      left: 0;
      top: 50%;
      transform: translateY(-50%);
      width: 4px;
      height: 100%;
      background: linear-gradient(180deg, #667eea, #764ba2);
      border-radius: 2px;
      animation: pulse 2s ease-in-out infinite;
    }
    
    @keyframes pulse {
      0%, 100% {
        opacity: 1;
        height: 100%;
      }
      50% {
        opacity: 0.6;
        height: 60%;
      }
    }
    
    .recent-table {
      background: white;
      padding: 25px;
      border-radius: 12px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
      margin: 20px 0;
      opacity: 0;
      animation: fadeInScale 0.8s ease forwards;
      animation-delay: 0.6s;
    }
    .recent-table table {
      width: 100%;
      border-collapse: collapse;
    }
    .recent-table th {
      background: #f8f9fa;
      padding: 12px;
      text-align: left;
      font-weight: 600;
      color: #667eea;
      border-bottom: 2px solid #667eea;
    }
    .recent-table td {
      padding: 12px;
      border-bottom: 1px solid #eee;
    }
    .recent-table tbody tr {
      opacity: 0;
      animation: fadeIn 0.5s ease forwards;
    }
    .recent-table tbody tr:nth-child(1) { animation-delay: 0.7s; }
    .recent-table tbody tr:nth-child(2) { animation-delay: 0.8s; }
    .recent-table tbody tr:nth-child(3) { animation-delay: 0.9s; }
    .recent-table tbody tr:nth-child(4) { animation-delay: 1.0s; }
    .recent-table tbody tr:nth-child(5) { animation-delay: 1.1s; }
    
    .recent-table tr:hover {
      background: #f8f9fa;
      transform: translateX(5px);
      transition: all 0.3s ease;
    }
    
    canvas {
      animation: chartAppear 1s ease-in-out;
    }
    
    @keyframes chartAppear {
      from {
        opacity: 0;
        filter: blur(10px);
      }
      to {
        opacity: 1;
        filter: blur(0);
      }
    }
    
    /* Loading skeleton for charts */
    .chart-loading {
      width: 100%;
      height: 300px;
      background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%);
      background-size: 200% 100%;
      animation: shimmer 1.5s infinite;
      border-radius: 8px;
    }
    
    @keyframes shimmer {
      0% { background-position: -200% 0; }
      100% { background-position: 200% 0; }
    }

    /* Badge Color Variants */
    .badge-ok {
      background: #e6ffed;
      color: #2f855a;
      border: 1px solid #68d391;
    }

    .badge-service {
      background: #fffbea;
      color: #975a16;
      border: 1px solid #f6e05e;
    }

    .badge-waste {
      background: #ffeaea;
      color: #c53030;
      border: 1px solid #fc8181;
    }

    .badge-default {
      background: #e7f3ff;
      color: #1976d2;
      border: 1px solid #90cdf4;
    }

  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>ðŸ“¦ Dashboard Sistem Retur Barang IT</h1>
      <div class="user-info">
        <p>Selamat datang, <strong><?= htmlspecialchars($admin) ?></strong></p>
        <a href="logout.php" class="logout-btn">Logout</a>
      </div>
    </div>

    <!-- Statistik Cards -->
    <div class="stats-grid">
      <div class="stat-card">
        <h3>ðŸ“Š Total Retur</h3>
        <div class="number" data-target="<?= $total_retur ?>">0</div>
        <div class="label">Total keseluruhan</div>
      </div>
      <div class="stat-card" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);">
        <h3>ðŸ“… Retur Bulan Ini</h3>
        <div class="number" data-target="<?= $retur_bulan_ini ?>">0</div>
        <div class="label"><?= date('F Y') ?></div>
      </div>
      <div class="stat-card" style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);">
        <h3>ðŸª Total Toko</h3>
        <div class="number" data-target="<?= $total_toko ?>">0</div>
        <div class="label">Toko terdaftar</div>
      </div>
    </div>

    <!-- Charts -->
    <div class="chart-grid">
      <div class="chart-container">
        <div class="chart-title">ðŸ“ˆ Retur per Hari (14 Hari Terakhir)</div>
        <canvas id="monthlyChart"></canvas>
      </div>
      <div class="chart-container">
        <div class="chart-title">ðŸ·ï¸ Retur per Kategori</div>
        <canvas id="categoryChart"></canvas>
      </div>
    </div>

    <!-- Top Toko -->
    <div class="chart-container">
      <div class="chart-title">ðŸ† Top 5 Toko dengan Retur Terbanyak</div>
      <canvas id="tokoChart"></canvas>
    </div>

    <!-- Retur Terbaru -->
    <div class="recent-table">
      <div class="chart-title">ðŸ•’ Retur Terbaru</div>
      <table>
        <thead>
          <tr>
            <th>Tanggal</th>
            <th>Toko</th>
            <th>Nama IT</th>
            <th>Barang</th>
            <th>Kategori</th>
          </tr>
        </thead>
        <tbody>
          <?php while($row = mysqli_fetch_assoc($recent_query)): ?>
          <tr>
            <td><?= date('d/m/Y', strtotime($row['tanggal'])) ?></td>
            <td><?= htmlspecialchars($row['nama_toko']) ?></td>
            <td><?= htmlspecialchars($row['nama_it']) ?></td>
            <td><?= htmlspecialchars($row['nama_barang']) ?></td>
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
          </tr>
          <?php endwhile; ?>
        </tbody>
      </table>
    </div>

    <!-- Menu Navigation -->
    <ul class="nav-menu">
      <li>
        <a href="retur_list.php">
          ðŸ“‹ Lihat Semua Data Retur
        </a>
      </li>
    </ul>
  </div>

  <script>
    // Animasi counter untuk angka statistik
    function animateCounter() {
      const counters = document.querySelectorAll('.stat-card .number');
      counters.forEach(counter => {
        const target = parseInt(counter.getAttribute('data-target'));
        const duration = 2000; // 2 detik
        const increment = target / (duration / 16); // 60 FPS
        let current = 0;
        
        const updateCounter = () => {
          current += increment;
          if (current < target) {
            counter.textContent = Math.floor(current);
            requestAnimationFrame(updateCounter);
          } else {
            counter.textContent = target;
          }
        };
        
        // Delay untuk sinkron dengan animasi card
        setTimeout(() => updateCounter(), 500);
      });
    }
    
    // Jalankan animasi counter setelah halaman load
    window.addEventListener('load', animateCounter);

    // Data untuk chart harian dengan animasi
    <?php
    $hari_labels = [];
    $hari_data = [];
    mysqli_data_seek($hari_query, 0);
    while($row = mysqli_fetch_assoc($hari_query)) {
      $hari_labels[] = date('d M', strtotime($row['hari']));
      $hari_data[] = $row['jumlah'];
    }
    ?>
    const dailyCtx = document.getElementById('monthlyChart').getContext('2d');
    new Chart(dailyCtx, {
      type: 'line',
      data: {
        labels: <?= json_encode($hari_labels) ?>,
        datasets: [{
          label: 'Jumlah Retur per Hari',
          data: <?= json_encode($hari_data) ?>,
          borderColor: '#667eea',
          backgroundColor: 'rgba(102, 126, 234, 0.15)',
          tension: 0.4,
          fill: true,
          pointRadius: 5,
          pointHoverRadius: 8,
          pointBackgroundColor: '#667eea',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointHoverBackgroundColor: '#764ba2',
          pointHoverBorderColor: '#fff',
          pointHoverBorderWidth: 3
        }]
      },
      options: {
        responsive: true,
        plugins: { 
          legend: { display: false },
          tooltip: {
            backgroundColor: 'rgba(102, 126, 234, 0.9)',
            padding: 12,
            titleColor: '#fff',
            bodyColor: '#fff',
            displayColors: false,
            callbacks: {
              title: function(context) {
                return context[0].label;
              },
              label: function(context) {
                return 'Retur: ' + context.parsed.y + ' item';
              }
            }
          }
        },
        scales: {
          y: { 
            beginAtZero: true,
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: { 
            ticks: { 
              autoSkip: false, 
              maxRotation: 45, 
              minRotation: 0 
            },
            grid: {
              display: false
            }
          }
        },
        animation: {
          duration: 2000,
          easing: 'easeInOutQuart',
          onProgress: function(animation) {
            // Animasi drawing line
          }
        }
      }
    });

    // Data untuk chart kategori dengan animasi rotation
    <?php
    $kategori_labels = [];
    $kategori_data = [];
    $kategori_colors = [];

    mysqli_data_seek($kategori_query, 0);
    while($row = mysqli_fetch_assoc($kategori_query)) {
      $kategori_labels[] = $row['kategori'];
      $kategori_data[] = $row['jumlah'];
      
      $kategori_lower = strtolower($row['kategori']);
      if ($kategori_lower == 'ok') {
        $kategori_colors[] = '#81C784';
      } elseif ($kategori_lower == 'service') {
        $kategori_colors[] = '#FFD54F';
      } elseif ($kategori_lower == 'waste') {
        $kategori_colors[] = '#E57373';
      } else {
        $kategori_colors[] = '#90CAF9';
      }
    }
    ?>
    const categoryCtx = document.getElementById('categoryChart').getContext('2d');
    new Chart(categoryCtx, {
      type: 'doughnut',
      data: {
        labels: <?= json_encode($kategori_labels) ?>,
        datasets: [{
          data: <?= json_encode($kategori_data) ?>,
          backgroundColor: <?= json_encode($kategori_colors) ?>,
          borderWidth: 3,
          borderColor: '#fff',
          hoverBorderWidth: 4,
          hoverBorderColor: '#667eea'
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { 
            position: 'bottom',
            labels: {
              padding: 15,
              font: {
                size: 12
              },
              usePointStyle: true,
              pointStyle: 'circle'
            }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            callbacks: {
              label: function(context) {
                const label = context.label || '';
                const value = context.parsed || 0;
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((value / total) * 100).toFixed(1);
                return label + ': ' + value + ' (' + percentage + '%)';
              }
            }
          }
        },
        animation: {
          animateRotate: true,
          animateScale: true,
          duration: 2000,
          easing: 'easeInOutQuart'
        }
      }
    });

    // Data untuk chart top toko dengan animasi bounce
    <?php
    $toko_labels = [];
    $toko_data = [];
    mysqli_data_seek($top_toko_query, 0);
    while($row = mysqli_fetch_assoc($top_toko_query)) {
      $toko_labels[] = $row['nama_toko'];
      $toko_data[] = $row['jumlah'];
    }
    ?>
    const tokoCtx = document.getElementById('tokoChart').getContext('2d');
    new Chart(tokoCtx, {
      type: 'bar',
      data: {
        labels: <?= json_encode($toko_labels) ?>,
        datasets: [{
          label: 'Jumlah Retur',
          data: <?= json_encode($toko_data) ?>,
          backgroundColor: [
            'rgba(102, 126, 234, 0.8)',
            'rgba(249, 147, 251, 0.8)',
            'rgba(79, 172, 254, 0.8)',
            'rgba(129, 199, 132, 0.8)',
            'rgba(255, 213, 79, 0.8)'
          ],
          borderColor: [
            '#667eea',
            '#f993fb',
            '#4facfe',
            '#81C784',
            '#FFD54F'
          ],
          borderWidth: 2,
          borderRadius: 8,
          hoverBackgroundColor: [
            'rgba(102, 126, 234, 1)',
            'rgba(249, 147, 251, 1)',
            'rgba(79, 172, 254, 1)',
            'rgba(129, 199, 132, 1)',
            'rgba(255, 213, 79, 1)'
          ]
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            callbacks: {
              label: function(context) {
                return 'Total Retur: ' + context.parsed.y + ' item';
              }
            }
          }
        },
        scales: {
          y: { 
            beginAtZero: true,
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        },
        animation: {
          duration: 2000,
          easing: 'easeOutBounce'
        }
      }
    });

    // Hover effect untuk charts
    const chartContainers = document.querySelectorAll('.chart-container');
    chartContainers.forEach(container => {
      container.addEventListener('mouseenter', function() {
        this.style.transform = 'scale(1.02)';
        this.style.transition = 'transform 0.3s ease';
      });
      
      container.addEventListener('mouseleave', function() {
        this.style.transform = 'scale(1)';
      });
    });
  </script>
</body>
</html>