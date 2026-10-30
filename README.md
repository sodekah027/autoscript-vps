# 🚀 All-in-One VPS Management & Auto Installer

Script manajemen dan otomasi instalasi VPS Debian/Ubuntu yang praktis, modular, dan aman.

## 📋 Fitur Menu

1. **Install Script MarLing (Marzban & Xray)** - Setup panel VPN Web/Xray lengkap.
2. **Reinstall System** - Instalasi ulang OS Debian 12 dengan perlindungan konfirmasi password.
3. **Routing Marzban** - Tambah/hapus domain routing & akun VLESS ke Xray.
4. **Install Gotop** - Monitor beban CPU/RAM real-time di terminal.
5. **Theme Marzban Subscription** - Kustomisasi tema halaman langganan VPN.
6. **Install & Kelola Swap File** - Buat/ubah ukuran swap (1G, 2G, 4G, custom) & atur swappiness tanpa mematikan ZRAM.
7. **Kelola Landing Page Web (/var/www/html)** - Pasang template panel info, landing page modern dark VPN, atau auto-redirect URL (misal: google.com).
8. **Backup Database Marzban** - Backup aman `db.sqlite3` ke bot Telegram.
9. **Install & Kelola Cloudflare Tunnel** - Dukungan auto-token atau custom token dengan restart/reinstall service.
10. **Install Status Monitor (Docker)** - Setup panel web monitoring Status (port 9090).
11. **Jadwalkan Backup (Cron)** - Otomasi backup harian database Marzban ke Telegram.
12. **Install & Kelola Fail2ban** - Proteksi SSH dari serangan brute-force, cek status jail & unban IP.
13. **Install & Kelola ZRAM** - Swap memori terkompresi berbasis RAM (algoritma zstd/lz4, kapasitas 50%-150%).
14. **Install & Kelola Bore Tunnel** - Expose port lokal (misal: SSH Termux 8022) via Bore Server & generator oneliner client.

---

## ⚡ Cara Instalasi & Penggunaan di VPS

Jalankan perintah one-line berikut di VPS (sebagai root):

```bash
curl -fsSL https://raw.githubusercontent.com/sodekah027/autoscript-vps/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

Atau jalankan langsung:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sodekah027/autoscript-vps/main/install.sh)
```

---

## 🛠️ Persyaratan Sistem
- **OS**: Debian 11 / 12, Ubuntu 20.04 / 22.04 / 24.04
- **Akses**: Root (`sudo su`)
