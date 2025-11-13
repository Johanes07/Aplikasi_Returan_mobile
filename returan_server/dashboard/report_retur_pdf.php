<?php
session_start();
date_default_timezone_set('Asia/Jakarta'); // ✅ Tambahkan ini
if (!isset($_SESSION['admin'])) {
    header("Location: login.php");
    exit;
}

include '../db/connection.php';
require_once '../libs/dompdf/autoload.inc.php'; // ✅ sudah sesuai struktur kamu

use Dompdf\Dompdf;
use Dompdf\Options;

// Ambil data retur
$query = mysqli_query($conn, "SELECT * FROM retur_barang ORDER BY id DESC");
$data = array();
while ($row = mysqli_fetch_assoc($query)) {
    $data[] = $row;
}

// Setup Dompdf
$options = new Options();
$options->setIsHtml5ParserEnabled(true);
$options->setIsRemoteEnabled(true);
$dompdf = new Dompdf($options);

// HTML tampilan PDF
$html = '
<html>
<head>
  <meta charset="UTF-8">
  <style>
    @page { margin: 40px 25px; }
    body {
      font-family: DejaVu Sans, sans-serif;
      font-size: 12px;
      color: #333;
    }
    .header {
      text-align: center;
      border-bottom: 3px solid #667eea;
      padding-bottom: 10px;
      margin-bottom: 25px;
    }
    .header h2 {
      margin: 0;
      color: #2a2a2a;
      letter-spacing: 1px;
    }
    .header p {
      font-size: 13px;
      color: #666;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 15px;
    }
    th, td {
      border: 1px solid #aaa;
      padding: 7px;
    }
    th {
      background: #667eea;
      color: #fff;
      text-transform: uppercase;
      font-size: 11px;
      letter-spacing: 0.5px;
    }
    tr:nth-child(even) { background-color: #f4f6fb; }
    .footer {
      text-align: right;
      margin-top: 30px;
      font-size: 12px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <h2>LAPORAN DATA RETUR BARANG</h2>
    <p>Dicetak pada: ' . date('d/m/Y H:i') . '</p>
  </div>

  <table>
    <thead>
      <tr>
        <th>No</th>
        <th>Tanggal</th>
        <th>Nama Toko</th>
        <th>Nama IT</th>
        <th>Nama Barang</th>
        <th>SN Barang</th>
        <th>No Dokumen</th>
        <th>Kategori</th>
        <th>Keterangan</th>
      </tr>
    </thead>
    <tbody>';

if (count($data) > 0) {
    $no = 1;
    foreach ($data as $row) {
        $html .= '
        <tr>
          <td align="center">' . $no++ . '</td>
          <td>' . date('d/m/Y', strtotime($row['tanggal'])) . '</td>
          <td>' . htmlspecialchars($row['nama_toko']) . '</td>
          <td>' . htmlspecialchars($row['nama_it']) . '</td>
          <td>' . htmlspecialchars($row['nama_barang']) . '</td>
          <td>' . htmlspecialchars($row['sn_barang']) . '</td>
          <td>' . htmlspecialchars($row['nomor_dokumen']) . '</td>
          <td align="center">' . htmlspecialchars($row['kategori']) . '</td>
          <td>' . htmlspecialchars($row['keterangan']) . '</td>
        </tr>';
    }
} else {
    $html .= '
      <tr>
        <td colspan="9" align="center" style="padding:20px;">Tidak ada data retur barang</td>
      </tr>';
}

$html .= '
    </tbody>
  </table>

  <div class="footer">
    <p><em>Laporan ini dihasilkan otomatis oleh Sistem Retur Barang</em></p>
  </div>
</body>
</html>';

// Buat PDF
$dompdf->loadHtml($html);
$dompdf->setPaper('A4', 'landscape');
$dompdf->render();

// Nama file download
$filename = "Laporan_Retur_" . date('Ymd_His') . ".pdf";
$dompdf->stream($filename, array("Attachment" => false));
exit;
?>
