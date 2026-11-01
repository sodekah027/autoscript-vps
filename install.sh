#!/bin/bash

# Cek root
if [[ $EUID -ne 0 ]]; then
    echo "Harus dijalankan sebagai root!"
    exit 1
fi

# Dependency minimal
if ! command -v curl &>/dev/null; then
    echo "Installing curl..."
    apt update && apt install -y curl
fi

clear
echo "-----------------------------------"
echo "        VPS Management Menu        "
echo "-----------------------------------"
echo "1. Install Script"
echo "2. Reinstall"
echo "3. Routing"
echo "4. Install Gotop"
echo "5. Theme Marzban Subscription"
echo "6. Install & Kelola Swap File (RAM / Disk)"
echo "7. Kelola Landing Page Web (Index.html)"
echo "8. Backup Database db.sqlite3"
echo "9. Install / Kelola Cloudflare Tunnel (cloudflared)"
echo "10. Install Status Monitor (Docker)"
echo "11. Jadwalkan Backup tele.sh (cron)"
echo "12. Install & Kelola Fail2ban (Anti Brute-Force)"
echo "13. Install & Kelola ZRAM (Kompresi RAM)"
echo "14. Install & Kelola Bore Tunnel (Server & Client Oneliner)"
echo "-----------------------------------"

read -rp "Pilih opsi (1-14): " choice

case "$choice" in
    1)
        echo "Installing script..."
        curl -fsSL https://raw.githubusercontent.com/GawrAme/MarLing/main/mar.sh -o mar.sh \
        && chmod +x mar.sh \
        && ./mar.sh
        ;;
    2)
        echo "Reinstalling system..."
        curl -fsSL https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh -o reinstall.sh \
        && bash reinstall.sh debian 12 \
        && reboot
        ;;
    3)
        echo "Running routing script..."
        curl -fsSL https://raw.githubusercontent.com/sodekah027/rutehtml/refs/heads/main/menu-routing1.sh -o menu-routing1.sh \
        && chmod +x menu-routing1.sh \
        && ./menu-routing1.sh
        ;;
    4)
        echo "Installing Gotop..."
        curl -fsSL https://github.com/sodekah027/gotop/raw/refs/heads/main/gotop -o /usr/local/bin/gotop \
        && chmod +x /usr/local/bin/gotop
        ;;
    5)
        echo "Changing Marzban subscription theme..."
        mkdir -p /var/lib/marzban/templates/subscription
        curl -fsSL https://raw.githubusercontent.com/sodekah027/marzban-subscription/refs/heads/main/index.html \
        -o /var/lib/marzban/templates/subscription/index.html
        ;;
    6)
        echo "============================================="
        echo "       Install & Kelola Swap File (RAM)      "
        echo "============================================="
        
        echo ""
        echo "Pilih aksi Swap:"
        echo "1) Cek Status Swap & Swappiness"
        echo "2) Buat / Ubah Ukuran Swap File (1G, 2G, 4G, Kustom)"
        echo "3) Atur Nilai Swappiness (Optimalisasi I/O Disk)"
        echo "4) Hapus / Nonaktifkan Swap File"
        echo "5) Kembali ke Menu Utama"
        read -rp "Pilih opsi (1-5, default: 1): " SWAP_OPT
        SWAP_OPT=${SWAP_OPT:-1}

        case "$SWAP_OPT" in
            1)
                echo ""
                echo "--- Swap Aktif ---"
                swapon --show
                echo ""
                echo "--- Penggunaan Memori ---"
                free -h
                echo ""
                CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "Unknown")
                echo "Nilai vm.swappiness saat ini: $CURRENT_SWAPPINESS (Rekomendasi VPS: 10 - 20)"
                ;;
            2)
                echo ""
                echo "Pilih ukuran Swap File baru:"
                echo "1) 1 GB"
                echo "2) 2 GB (Standar)"
                echo "3) 4 GB"
                echo "4) Ukuran Kustom (GB)"
                read -rp "Pilih opsi (1-4, default: 2): " SIZE_OPT
                SIZE_OPT=${SIZE_OPT:-2}

                case "$SIZE_OPT" in
                    1) SWAP_SIZE_GB=1 ;;
                    2) SWAP_SIZE_GB=2 ;;
                    3) SWAP_SIZE_GB=4 ;;
                    4)
                        read -rp "Masukkan ukuran dalam GB (contoh: 3): " CUSTOM_SIZE
                        SWAP_SIZE_GB=$(echo "$CUSTOM_SIZE" | tr -cd '0-9')
                        [ -z "$SWAP_SIZE_GB" ] && SWAP_SIZE_GB=2
                        ;;
                    *) SWAP_SIZE_GB=2 ;;
                esac

                echo "Memproses pembuatan Swap File sebesar ${SWAP_SIZE_GB}GB..."

                # Hanya matikan /swapfile jika sudah aktif (jangan swapoff -a agar ZRAM tidak mati)
                if swapon --show | grep -q "/swapfile"; then
                    echo "Mematikan swapfile lama..."
                    swapoff /swapfile
                fi

                # Buat file swap (coba fallocate, fallback ke dd jika filesystem tidak dukung)
                rm -f /swapfile
                if ! fallocate -l "${SWAP_SIZE_GB}G" /swapfile 2>/dev/null; then
                    echo "fallocate tidak didukung, menggunakan dd..."
                    dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress
                fi

                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile

                # Daftarkan ke /etc/fstab jika belum ada
                if ! grep -q "^/swapfile" /etc/fstab; then
                    echo "/swapfile none swap sw 0 0" >> /etc/fstab
                fi

                echo -e "\e[32m✔ Swap File ${SWAP_SIZE_GB}GB berhasil diaktifkan!\e[0m"
                echo ""
                swapon --show
                free -h
                ;;
            3)
                echo ""
                CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
                echo "Nilai vm.swappiness saat ini: $CURRENT_SWAPPINESS"
                echo "Catatan: Nilai rendah (10-20) membuat sistem memprioritaskan RAM fisik dan menghemat I/O SSD VPS."
                read -rp "Masukkan nilai swappiness baru (1 - 100, rekomendasi 10): " NEW_SWAPPINESS
                NEW_SWAPPINESS=$(echo "$NEW_SWAPPINESS" | tr -cd '0-9')
                if [ -n "$NEW_SWAPPINESS" ] && [ "$NEW_SWAPPINESS" -ge 1 ] && [ "$NEW_SWAPPINESS" -le 100 ]; then
                    sysctl vm.swappiness="$NEW_SWAPPINESS"
                    # Simpan permanen ke sysctl.conf
                    if grep -q "^vm.swappiness" /etc/sysctl.conf; then
                        sed -i "s/^vm.swappiness=.*/vm.swappiness=$NEW_SWAPPINESS/" /etc/sysctl.conf
                    else
                        echo "vm.swappiness=$NEW_SWAPPINESS" >> /etc/sysctl.conf
                    fi
                    echo -e "\e[32m✔ vm.swappiness diatur ke $NEW_SWAPPINESS secara permanen.\e[0m"
                else
                    echo -e "\e[31mNilai swappiness tidak valid!\e[0m"
                fi
                ;;
            4)
                echo ""
                echo -e "\e[33mMenonaktifkan dan menghapus /swapfile...\e[0m"
                if swapon --show | grep -q "/swapfile"; then
                    swapoff /swapfile || echo "Gagal swapoff /swapfile."
                fi
                # Hapus dari fstab
                sed -i '\|^/swapfile|d' /etc/fstab
                rm -f /swapfile
                echo -e "\e[32m✔ Swap File /swapfile telah dinonaktifkan dan dihapus.\e[0m"
                free -h
                ;;
            *)
                echo "Kembali."
                ;;
        esac
        ;;
    7)
        echo "============================================="
        echo "    Kelola Landing Page Web (/var/www/html)   "
        echo "============================================="

        WEB_DIR="/var/www/html"
        INDEX_FILE="$WEB_DIR/index.html"
        mkdir -p "$WEB_DIR"

        echo ""
        echo "Pilih opsi:"
        echo "1) Pasang Template Panel Information (sodekah027)"
        echo "2) Pasang Template Modern Dark / VPN Landing Page"
        echo "3) Pasang dari URL Custom (Link raw HTML luar)"
        echo "4) Custom Direct URL (Auto-Redirect ke URL lain, misal: google.com)"
        echo "5) Kustomisasi Teks / Kontak Admin (Telegram)"
        echo "6) Lihat / Pratinjau Teks index.html Saat Ini"
        echo "7) Backup / Restore index.html"
        echo "8) Reset ke Template Sederhana (Default LingVPN)"
        echo "9) Kembali ke Menu Utama"
        read -rp "Pilih opsi (1-9, default: 1): " HTML_OPT
        HTML_OPT=${HTML_OPT:-1}

        case "$HTML_OPT" in
            1)
                echo "Mengunduh template Panel Information..."
                [ -f "$INDEX_FILE" ] && cp "$INDEX_FILE" "${INDEX_FILE}.bak"
                if curl -fsSL https://raw.githubusercontent.com/sodekah027/panel-information/refs/heads/main/index.html -o "$INDEX_FILE"; then
                    echo -e "\e[32m✔ Template Panel Information berhasil dipasang di $INDEX_FILE\e[0m"
                else
                    echo -e "\e[31m[ERROR] Gagal mengunduh template dari GitHub.\e[0m"
                fi
                ;;
            2)
                echo "Membuat template Modern Dark VPN Landing Page..."
                [ -f "$INDEX_FILE" ] && cp "$INDEX_FILE" "${INDEX_FILE}.bak"
                cat <<'HTMLEOF' > "$INDEX_FILE"
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Status - Online</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', sans-serif;
            background: #0f172a;
            color: #f8fafc;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 20px;
        }
        .card {
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 16px;
            padding: 36px 30px;
            max-width: 480px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.4);
        }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(16, 185, 129, 0.15);
            color: #10b981;
            padding: 6px 14px;
            border-radius: 9999px;
            font-size: 0.875rem;
            font-weight: 600;
            margin-bottom: 20px;
        }
        .badge-dot {
            width: 8px;
            height: 8px;
            background: #10b981;
            border-radius: 50%;
            box-shadow: 0 0 10px #10b981;
        }
        h1 { font-size: 1.6rem; font-weight: 700; margin-bottom: 8px; color: #fff; }
        p { color: #94a3b8; font-size: 0.95rem; line-height: 1.5; margin-bottom: 24px; }
        .info-box {
            background: #0f172a;
            border-radius: 10px;
            padding: 16px;
            margin-bottom: 24px;
            text-align: left;
            font-size: 0.875rem;
        }
        .info-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #1e293b; }
        .info-row:last-child { border-bottom: none; }
        .info-label { color: #64748b; }
        .info-value { color: #38bdf8; font-weight: 600; }
        .btn {
            display: block;
            width: 100%;
            background: #3b82f6;
            color: white;
            text-decoration: none;
            padding: 12px;
            border-radius: 8px;
            font-weight: 600;
            margin-bottom: 10px;
            transition: 0.2s;
        }
        .btn:hover { background: #2563eb; }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge"><span class="badge-dot"></span> System Operational</div>
        <h1>LingVPN Gateway</h1>
        <p>Layanan server VPN & Proxy berkecepatan tinggi aktif 24/7 dengan enkripsi tingkat lanjut.</p>
        <div class="info-box">
            <div class="info-row">
                <span class="info-label">Status</span>
                <span class="info-value" style="color:#10b981;">Online & Protected</span>
            </div>
            <div class="info-row">
                <span class="info-label">Protocols</span>
                <span class="info-value">VLESS / VMess / Trojan</span>
            </div>
            <div class="info-row">
                <span class="info-label">Network</span>
                <span class="info-value">1 Gbps High Speed</span>
            </div>
        </div>
        <a href="https://t.me/" class="btn" target="_blank" id="btn-tele">Hubungi Admin Telegram</a>
    </div>
</body>
</html>
HTMLEOF
                echo -e "\e[32m✔ Template Modern Dark VPN Landing Page berhasil dipasang.\e[0m"
                ;;
            3)
                echo ""
                read -rp "Masukkan URL direct / raw HTML: " CUSTOM_URL
                CUSTOM_URL=$(echo "$CUSTOM_URL" | tr -d '[:space:]')
                if [ -n "$CUSTOM_URL" ]; then
                    [ -f "$INDEX_FILE" ] && cp "$INDEX_FILE" "${INDEX_FILE}.bak"
                    if curl -fsSL "$CUSTOM_URL" -o "$INDEX_FILE"; then
                        echo -e "\e[32m✔ File HTML dari $CUSTOM_URL berhasil diunduh ke $INDEX_FILE\e[0m"
                    else
                        echo -e "\e[31m[ERROR] Gagal mengunduh URL tersebut!\e[0m"
                    fi
                else
                    echo "URL tidak boleh kosong."
                fi
                ;;
            4)
                echo ""
                echo "--- Custom Direct URL (Auto Redirect) ---"
                read -rp "Masukkan URL tujuan (contoh: google.com atau https://google.com): " REDIRECT_URL
                REDIRECT_URL=$(echo "$REDIRECT_URL" | tr -d '[:space:]')

                if [ -z "$REDIRECT_URL" ]; then
                    echo -e "\e[31m[ERROR] URL tujuan tidak boleh kosong!\e[0m"
                    break
                fi

                # Tambahkan https:// jika user belum memasukkan protokol
                if [[ ! "$REDIRECT_URL" =~ ^https?:// ]]; then
                    REDIRECT_URL="https://$REDIRECT_URL"
                fi

                echo "Membuat index.html auto-redirect ke: $REDIRECT_URL ..."
                [ -f "$INDEX_FILE" ] && cp "$INDEX_FILE" "${INDEX_FILE}.bak"

                cat <<REDIREOF > "$INDEX_FILE"
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="refresh" content="0; url=${REDIRECT_URL}">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Redirecting...</title>
    <script>
        window.location.replace("${REDIRECT_URL}");
    </script>
    <style>
        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #0f172a;
            color: #f8fafc;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            text-align: center;
        }
        a {
            color: #38bdf8;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div>
        <p>Mengalihkan Anda ke <a href="${REDIRECT_URL}">${REDIRECT_URL}</a> ...</p>
    </div>
</body>
</html>
REDIREOF
                echo -e "\e[32m✔ Sukses! Kunjungan ke web sekarang otomatis langsung mengarah ke: $REDIRECT_URL\e[0m"
                ;;
            5)
                echo ""
                if [ ! -f "$INDEX_FILE" ]; then
                    echo -e "\e[31mFile $INDEX_FILE belum ada. Pasang template terlebih dahulu!\e[0m"
                    break
                fi
                echo "Kustomisasi Link Kontak pada $INDEX_FILE:"
                read -rp "Masukkan Username Telegram Admin (tanpa @, contoh: adminvpn): " TELE_USER
                TELE_USER=$(echo "$TELE_USER" | tr -d '@[:space:]')
                if [ -n "$TELE_USER" ]; then
                    sed -i "s|https://t.me/[a-zA-Z0-9_]*|https://t.me/${TELE_USER}|g" "$INDEX_FILE"
                    echo -e "\e[32m✔ Link Telegram diperbarui ke: https://t.me/${TELE_USER}\e[0m"
                fi
                ;;
            6)
                echo ""
                echo "--- Preview $INDEX_FILE ---"
                if [ -f "$INDEX_FILE" ]; then
                    head -n 25 "$INDEX_FILE"
                    echo "..."
                    echo "Ukuran file: $(wc -c < "$INDEX_FILE") bytes"
                else
                    echo "File $INDEX_FILE belum ada."
                fi
                ;;
            7)
                echo ""
                echo "1) Backup index.html ke index.html.bak"
                echo "2) Restore index.html dari index.html.bak"
                read -rp "Pilih aksi backup/restore (1/2): " BAK_ACT
                if [[ "$BAK_ACT" == "1" ]]; then
                    if [ -f "$INDEX_FILE" ]; then
                        cp "$INDEX_FILE" "${INDEX_FILE}.bak"
                        echo -e "\e[32m✔ Backup tersimpan di ${INDEX_FILE}.bak\e[0m"
                    else
                        echo "File $INDEX_FILE belum ada."
                    fi
                elif [[ "$BAK_ACT" == "2" ]]; then
                    if [ -f "${INDEX_FILE}.bak" ]; then
                        cp "${INDEX_FILE}.bak" "$INDEX_FILE"
                        echo -e "\e[32m✔ Restore berhasil dari ${INDEX_FILE}.bak\e[0m"
                    else
                        echo -e "\e[31mFile backup ${INDEX_FILE}.bak tidak ditemukan.\e[0m"
                    fi
                fi
                ;;
            8)
                echo "<pre>Setup by AutoScript LingVPN</pre>" > "$INDEX_FILE"
                echo -e "\e[32m✔ index.html direset ke template teks bawaan sederhana.\e[0m"
                ;;
            *)
                echo "Kembali."
                ;;
        esac
        ;;
    8)
        echo "Backing up database db.sqlite3..."
        if [ ! -f "/var/lib/marzban/db.sqlite3" ]; then
            echo -e "\e[31m[PERINGATAN] File /var/lib/marzban/db.sqlite3 belum ditemukan!\e[0m"
            echo "Pastikan Marzban sudah terinstall sebelum menjalankan backup database."
            read -rp "Tekan Enter untuk kembali ke menu..." _
            break
        fi
        curl -fsSL https://raw.githubusercontent.com/sodekah027/backup-pribadi/refs/heads/main/tele.sh -o tele.sh \
        && chmod +x tele.sh \
        && ./tele.sh \
        && clear
        ;;
    9)
        echo "============================================="
        echo "   Install / Kelola Cloudflare Tunnel (CF)   "
        echo "============================================="

        # 1. Pastikan curl dan gpg/gnupg terpasang
        for dep in curl gpg; do
            if ! command -v "$dep" &>/dev/null; then
                echo "Menginstall dependensi $dep..."
                apt-get update -y && apt-get install -y "$dep" gnupg
            fi
        done

        # 2. Setup GPG Keyring Cloudflare jika belum ada atau rusak
        mkdir -p --mode=0755 /usr/share/keyrings
        KEYRING_FILE="/usr/share/keyrings/cloudflare-public-v2.gpg"
        
        if [ ! -s "$KEYRING_FILE" ] || ! gpg --show-keys "$KEYRING_FILE" >/dev/null 2>&1; then
            echo "Mengunduh GPG Key Cloudflare..."
            curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg -o "$KEYRING_FILE"
            if ! gpg --show-keys "$KEYRING_FILE" >/dev/null 2>&1; then
                echo -e "\e[31m[ERROR] GPG key Cloudflare tidak valid. Dibatalkan.\e[0m"
                break
            fi
        fi

        # 3. Setup repo Cloudflare
        SOURCES_FILE="/etc/apt/sources.list.d/cloudflared.list"
        ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
        cat <<CF_REPO > "$SOURCES_FILE"
deb [arch=${ARCH} signed-by=${KEYRING_FILE}] https://pkg.cloudflare.com/cloudflared any main
CF_REPO

        # 4. Install / Update cloudflared package
        if ! command -v cloudflared &>/dev/null; then
            echo "Menginstall paket cloudflared..."
            apt-get update -y && apt-get install -y cloudflared || {
                echo -e "\e[31m[ERROR] Instalasi paket cloudflared gagal!\e[0m"
                break
            }
        else
            echo "Paket cloudflared sudah terpasang ($(cloudflared --version 2>/dev/null | head -n 1))."
        fi

        # 5. Konfigurasi Token Tunnel
        DEFAULT_TOKEN="eyJhIjoiOTE0NzU2ODM0OTEwZjM0ZTc4Zjc0YTgzNjMxOWJjM2IiLCJ0IjoiYjlmZDJlZmItNTk4MS00ZTk3LTk2MmYtYTJlNTg5MDE2ZmIzIiwicyI6Ill6Wm1NMk00T0dJdE1qYzBNeTAwTlRjNUxXRmlOak10TWpZek9EbGpPVEprT1dRdyJ9"
        
        echo ""
        echo "Pengaturan Token Tunnel:"
        echo "1) Gunakan Token Default"
        echo "2) Masukkan Token Baru / Custom"
        read -rp "Pilih opsi token (1/2, default: 1): " TOKEN_OPT
        if [[ "$TOKEN_OPT" == "2" ]]; then
            read -rp "Masukkan Token Cloudflare Tunnel Anda: " INPUT_TOKEN
            INPUT_TOKEN=$(echo "$INPUT_TOKEN" | tr -d '[:space:]')
            if [ -n "$INPUT_TOKEN" ]; then
                CF_TOKEN="$INPUT_TOKEN"
            else
                echo "Token kosong! Menggunakan token default."
                CF_TOKEN="$DEFAULT_TOKEN"
            fi
        else
            CF_TOKEN="$DEFAULT_TOKEN"
        fi

        # 6. Service Management
        SERVICE_FILE="/etc/systemd/system/cloudflared.service"
        TOKEN_FILE="/etc/cloudflared/token"

        if [[ -f "$SERVICE_FILE" ]]; then
            echo ""
            echo "Service cloudflared sudah terdaftar di systemd."
            echo "1) Update token & restart service (Rekomendasi)"
            echo "2) Reinstall service dari awal"
            echo "3) Cek status saja tanpa ubah service"
            read -rp "Pilih tindakan (1/2/3, default: 1): " ACT_OPT
            ACT_OPT=${ACT_OPT:-1}

            case "$ACT_OPT" in
                1)
                    mkdir -p /etc/cloudflared
                    echo "$CF_TOKEN" > "$TOKEN_FILE"
                    chmod 600 "$TOKEN_FILE"
                    systemctl restart cloudflared
                    echo -e "\e[32m✔ Token berhasil diperbarui dan service direstart.\e[0m"
                    ;;
                2)
                    systemctl stop cloudflared 2>/dev/null
                    cloudflared service uninstall 2>/dev/null || rm -f "$SERVICE_FILE"
                    cloudflared service install "$CF_TOKEN"
                    systemctl daemon-reload
                    systemctl enable --now cloudflared
                    echo -e "\e[32m✔ Service berhasil di-reinstall.\e[0m"
                    ;;
                *)
                    echo "Melewati pembaruan service."
                    ;;
            esac
        else
            echo "Mendaftarkan service cloudflared ke systemd..."
            cloudflared service install "$CF_TOKEN"
            systemctl enable --now cloudflared
        fi

        # 7. Verifikasi Status
        echo ""
        echo "Memeriksa status service..."
        sleep 2
        if systemctl is-active --quiet cloudflared; then
            echo -e "\e[32m✔ Cloudflare Tunnel BERJALAN AKTIF (running)!\e[0m"
        else
            echo -e "\e[31m[PERINGATAN] Service cloudflared belum aktif atau mengalami kendala.\e[0m"
        fi
        systemctl status cloudflared --no-pager -l
        ;;
    10)
        STATUS_DIR="/opt/Status"

        if ! command -v docker &>/dev/null; then
            echo "Docker tidak ditemukan, menginstall..."
            apt update && apt install -y docker.io docker-compose-v2 git || {
                echo "Instalasi Docker gagal."
                exit 1
            }
        fi

        if ! command -v git &>/dev/null; then
            apt update && apt install -y git || {
                echo "Instalasi git gagal."
                exit 1
            }
        fi

        # Compose v2 (docker compose) preferred, fallback ke v1 (docker-compose)
        if docker compose version &>/dev/null; then
            COMPOSE="docker compose"
        elif command -v docker-compose &>/dev/null; then
            COMPOSE="docker-compose"
        else
            echo "Docker Compose tidak ditemukan."
            exit 1
        fi

        if [ -d "$STATUS_DIR/.git" ]; then
            echo "Memperbarui repo yang sudah ada..."
            git -C "$STATUS_DIR" pull --ff-only || {
                echo "Update repo gagal."
                exit 1
            }
        else
            echo "Meng-clone repo Status..."
            git clone https://github.com/dani3l0/Status "$STATUS_DIR" || {
                echo "Clone repo gagal."
                exit 1
            }
        fi

        cd "$STATUS_DIR" || exit 1
        $COMPOSE up -d --build || {
            echo "Build container gagal."
            exit 1
        }

        $COMPOSE ps
        echo
        echo "Status Monitor berjalan di http://localhost:9090"
        ;;
    11)
        TELE_DIR="/root"
        TELE_SCRIPT="$TELE_DIR/tele.sh"
        CRON_LINE="0 0 * * * $TELE_SCRIPT > /dev/null 2>&1"

        if [ ! -f "$TELE_SCRIPT" ]; then
            echo "Mengunduh tele.sh..."
            curl -fsSL https://raw.githubusercontent.com/sodekah027/backup-pribadi/refs/heads/main/tele.sh \
            -o "$TELE_SCRIPT" || {
                echo "Gagal mengunduh tele.sh."
                exit 1
            }
            chmod +x "$TELE_SCRIPT"
        else
            echo "tele.sh sudah ada, melewati unduhan."
        fi

        # crontab -e interaktif, jadi tulis lewat pipe
        if crontab -l 2>/dev/null | grep -qF "$TELE_SCRIPT"; then
            echo "Jadwal untuk tele.sh sudah ada."
        else
            (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab - || {
                echo "Gagal menulis crontab."
                exit 1
            }
            echo "Jadwal harian pukul 00:00 ditambahkan."
        fi

        echo "Jadwal aktif:"
        crontab -l | grep -F "$TELE_SCRIPT"
        ;;
    12)
        echo "============================================="
        echo "   Install & Kelola Fail2ban (Anti Brute)    "
        echo "============================================="

        # Cek apakah fail2ban sudah terinstall
        if ! command -v fail2ban-client &>/dev/null; then
            echo "Fail2ban belum terinstall. Memulai instalasi..."
            apt-get update -y && apt-get install -y fail2ban
        fi

        # Cek atau buat konfigurasi jail.local
        JAIL_LOCAL="/etc/fail2ban/jail.local"
        if [ ! -f "$JAIL_LOCAL" ]; then
            echo "Membuat konfigurasi default $JAIL_LOCAL..."
            cat <<'F2BCFG' > "$JAIL_LOCAL"
[DEFAULT]
# Whitelist IP lokal & loopback
ignoreip = 127.0.0.1/8 ::1

# Durasi ban: 24 jam (86400 detik)
bantime  = 86400

# Rentang waktu pengecekan: 10 menit
findtime  = 600

# Maksimal salah 3 kali
maxretry = 3

# Backend systemd untuk Debian 12 Bookworm
backend = systemd

[sshd]
enabled = true
port    = 22
backend = systemd
maxretry = 3
findtime = 600
bantime  = 86400
F2BCFG
            systemctl enable fail2ban
            systemctl restart fail2ban
            echo -e "\e[32m✔ Fail2ban berhasil diinstall dan dikonfigurasi.\e[0m"
        else
            echo "Fail2ban sudah terpasang dengan konfigurasi aktif."
        fi

        echo ""
        echo "Opsi Fail2ban:"
        echo "1) Cek Status & IP yang di-ban (Jail SSH)"
        echo "2) Unban IP Address"
        echo "3) Restart Service Fail2ban"
        echo "4) Kembali ke Menu Utama"
        read -rp "Pilih opsi (1-4, default: 1): " F2B_OPT
        F2B_OPT=${F2B_OPT:-1}

        case "$F2B_OPT" in
            1)
                echo ""
                fail2ban-client status sshd 2>/dev/null || fail2ban-client status
                ;;
            2)
                read -rp "Masukkan IP yang ingin di-unban: " UNBAN_IP
                UNBAN_IP=$(echo "$UNBAN_IP" | tr -d '[:space:]')
                if [ -n "$UNBAN_IP" ]; then
                    fail2ban-client set sshd unbanip "$UNBAN_IP"
                    echo -e "\e[32m✔ Perintah unban untuk IP $UNBAN_IP telah dijalankan.\e[0m"
                else
                    echo "IP tidak boleh kosong!"
                fi
                ;;
            3)
                systemctl restart fail2ban
                echo -e "\e[32m✔ Service Fail2ban direstart.\e[0m"
                systemctl status fail2ban --no-pager
                ;;
            *)
                echo "Kembali."
                ;;
        esac
        ;;
    13)
        echo "============================================="
        echo "     Install & Kelola ZRAM (Swap Memory)     "
        echo "============================================="

        # Pastikan zram-tools terpasang
        if ! command -v zramctl &>/dev/null || ! dpkg -s zram-tools &>/dev/null; then
            echo "Paket zram-tools belum terinstall. Menginstall..."
            apt-get update -y && apt-get install -y zram-tools
        fi

        ZRAM_CONF="/etc/default/zramswap"
        [ -f "$ZRAM_CONF" ] || touch "$ZRAM_CONF"

        echo ""
        echo "Pilih aksi ZRAM:"
        echo "1) Cek Status & Utilisasi ZRAM"
        echo "2) Aktifkan / Set Kapasitas ZRAM (50%, 100%, dll)"
        echo "3) Atur Algoritma Kompresi (zstd / lz4)"
        echo "4) Restart Service ZRAM"
        echo "5) Nonaktifkan (Disable) ZRAM"
        echo "6) Kembali ke Menu Utama"
        read -rp "Pilih opsi (1-6, default: 1): " ZRAM_OPT
        ZRAM_OPT=${ZRAM_OPT:-1}

        case "$ZRAM_OPT" in
            1)
                echo ""
                echo "--- Status ZRAM ---"
                zramctl 2>/dev/null || echo "ZRAM belum aktif di kernel."
                echo ""
                echo "--- Swap & RAM Usage ---"
                swapon --show
                free -h
                ;;
            2)
                echo ""
                echo "Pilih persentase RAM untuk ZRAM:"
                echo "1) 50% RAM"
                echo "2) 100% RAM (Direkomendasikan untuk VPS 2GB)"
                echo "3) 150% RAM"
                echo "4) Input Persentase Kustom"
                read -rp "Pilih opsi (1-4, default: 2): " PCT_CHOICE
                PCT_CHOICE=${PCT_CHOICE:-2}

                case "$PCT_CHOICE" in
                    1) PERCENT_VAL="50" ;;
                    2) PERCENT_VAL="100" ;;
                    3) PERCENT_VAL="150" ;;
                    4)
                        read -rp "Masukkan persentase (contoh: 75): " CUSTOM_PCT
                        PERCENT_VAL=$(echo "$CUSTOM_PCT" | tr -cd '0-9')
                        [ -z "$PERCENT_VAL" ] && PERCENT_VAL="100"
                        ;;
                    *) PERCENT_VAL="100" ;;
                esac

                # Update /etc/default/zramswap
                if grep -q "^PERCENT=" "$ZRAM_CONF"; then
                    sed -i "s/^PERCENT=.*/PERCENT=$PERCENT_VAL/" "$ZRAM_CONF"
                else
                    echo "PERCENT=$PERCENT_VAL" >> "$ZRAM_CONF"
                fi

                # Pastikan ALGORITHM ada
                grep -q "^ALGORITHM=" "$ZRAM_CONF" || echo "ALGORITHM=zstd" >> "$ZRAM_CONF"

                systemctl enable zramswap
                systemctl restart zramswap
                echo -e "\e[32m✔ ZRAM diatur ke ${PERCENT_VAL}% RAM dan service direstart.\e[0m"
                sleep 1
                zramctl
                free -h
                ;;
            3)
                echo ""
                echo "Pilih algoritma kompresi:"
                echo "1) zstd (Kompresi lebih padat / hemat RAM, default)"
                echo "2) lz4  (Kompresi lebih cepat / hemat CPU)"
                read -rp "Pilih algoritma (1/2, default: 1): " ALG_CHOICE
                if [[ "$ALG_CHOICE" == "2" ]]; then
                    CHOSEN_ALG="lz4"
                else
                    CHOSEN_ALG="zstd"
                fi

                if grep -q "^ALGORITHM=" "$ZRAM_CONF"; then
                    sed -i "s/^ALGORITHM=.*/ALGORITHM=$CHOSEN_ALG/" "$ZRAM_CONF"
                else
                    echo "ALGORITHM=$CHOSEN_ALG" >> "$ZRAM_CONF"
                fi

                systemctl restart zramswap
                echo -e "\e[32m✔ Algoritma ZRAM diatur ke $CHOSEN_ALG dan service direstart.\e[0m"
                zramctl
                ;;
            4)
                systemctl restart zramswap
                echo -e "\e[32m✔ Service ZRAM direstart.\e[0m"
                zramctl
                free -h
                ;;
            5)
                systemctl stop zramswap
                systemctl disable zramswap
                echo -e "\e[33m✔ Service ZRAM dinonaktifkan.\e[0m"
                free -h
                ;;
            *)
                echo "Kembali."
                ;;
        esac
        ;;
    14)
        echo "============================================="
        echo "   Install & Kelola Bore Tunnel (bore.pub)   "
        echo "============================================="

        BORE_BIN="/usr/local/bin/bore"
        SERVICE_FILE="/etc/systemd/system/bore-server.service"
        BORE_VERSION="v0.6.0"

        # Dapatkan IP Public VPS
        VPS_IP=$(curl -4s https://api.ipify.org 2>/dev/null || curl -4s https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

        # Deteksi domain jika ada SSL cert di VPS, jika tidak gunakan IP
        DETECTED_DOMAIN=""
        if [ -f "/var/lib/marzban/xray.crt" ]; then
            DETECTED_DOMAIN=$(openssl x509 -in /var/lib/marzban/xray.crt -noout -subject 2>/dev/null | grep -oP '(?<=CN = )[^,\s]+' || true)
        fi
        DISPLAY_HOST="${DETECTED_DOMAIN:-$VPS_IP}"

        # Dapatkan setting port & secret saat ini jika service sudah ada
        CURRENT_PORT="7835"
        CURRENT_SECRET="renaisand_bore_2026"
        if [ -f "$SERVICE_FILE" ]; then
            EXTRACTED_SECRET=$(grep -oP '(?<=--secret\s)[^\s]+' "$SERVICE_FILE" 2>/dev/null || true)
            [ -n "$EXTRACTED_SECRET" ] && CURRENT_SECRET="$EXTRACTED_SECRET"
            EXTRACTED_PORT=$(grep -oP '(?<=--port\s)[0-9]+' "$SERVICE_FILE" 2>/dev/null || true)
            [ -n "$EXTRACTED_PORT" ] && CURRENT_PORT="$EXTRACTED_PORT"
        fi

        echo ""
        echo "Pilih opsi Bore:"
        echo "1) Cek Status & Info Koneksi Termius (IP & Port Aktif)"
        echo "2) Install / Konfigurasi Bore Server (Port & Secret)"
        echo "3) Generate Script Oneliner Client (Termux & Linux)"
        echo "4) Buka Port Tunnel di Firewall (UFW)"
        echo "5) Restart Service Bore Server"
        echo "6) Stop / Nonaktifkan Service Bore Server"
        echo "7) Uninstall Bore Server"
        echo "8) Kembali ke Menu Utama"
        read -rp "Pilih opsi (1-8, default: 1): " BORE_OPT
        BORE_OPT=${BORE_OPT:-1}

        case "$BORE_OPT" in
            1)
                echo ""
                echo "============================================="
                echo "       STATUS BORE SERVER & TUNNEL AKTIF     "
                echo "============================================="
                if systemctl is-active --quiet bore-server 2>/dev/null; then
                    echo -e "Status Service   : \e[32m✔ BERJALAN (Active)\e[0m"
                else
                    echo -e "Status Service   : \e[31m✘ MATI / Belum Terpasang\e[0m"
                fi
                echo "IP Public Server : $VPS_IP"
                [ -n "$DETECTED_DOMAIN" ] && echo "Domain Server    : $DETECTED_DOMAIN"
                echo "Port Kontrol     : $CURRENT_PORT"
                echo "Secret Key       : $CURRENT_SECRET"
                echo ""

                # Deteksi port forwarded yang sedang aktif dibuka oleh bore
                FORWARDED_PORTS=$(ss -tlnp 2>/dev/null | grep bore | awk '{print $4}' | awk -F':' '{print $NF}' | grep -v "^${CURRENT_PORT}\$" | sort -u)

                echo "---------------------------------------------"
                echo "📡 STATUS CLIENT TUNNEL TERHUBUNG:"
                echo "---------------------------------------------"
                if [ -n "$FORWARDED_PORTS" ]; then
                    for p in $FORWARDED_PORTS; do
                        echo -e "\e[32m🟢 Client Terhubung di Port: $p\e[0m"
                    done

                    echo ""
                    echo "======================================================="
                    echo "📱 DATA UNTUK DI-INPUT KE TERMIUS / APLIKASI SSH LAIN:"
                    echo "======================================================="
                    for p in $FORWARDED_PORTS; do
                        echo "  • Host / IP   : $VPS_IP (atau $DISPLAY_HOST)"
                        echo "  • Port        : $p  <-- (Masukkan angka port ini!)"
                        echo "  • Username    : <Username Termux Anda, cek: whoami>"
                        echo "  • Password    : <Password Termux Anda, diset via: passwd>"
                        echo ""
                        echo "  Contoh Perintah Terminal / Linux / Mac:"
                        echo "  ssh -p $p <user_termux>@$VPS_IP"
                        echo "-------------------------------------------------------"
                    done
                else
                    echo -e "\e[33m⚪ Belum ada client (Termux/PC) yang terhubung.\e[0m"
                    echo "Jalankan runner di Termux: ~/.bore_runner_vps.sh"
                    echo "atau generate script client melalui menu no. 3."
                fi
                echo "======================================================="
                echo ""
                systemctl status bore-server --no-pager 2>/dev/null | head -n 12
                ;;
            2)
                echo ""
                echo "--- Instalasi / Konfigurasi Bore Server ---"

                # Cek & install binary bore v0.6.0
                if ! command -v bore &>/dev/null || [ ! -f "$BORE_BIN" ] || ! "$BORE_BIN" --version 2>&1 | grep -q "$BORE_VERSION"; then
                    echo "Mengunduh binary bore ${BORE_VERSION}..."
                    ARCH=$(uname -m)
                    if [ "$ARCH" = "x86_64" ]; then
                        DOWNLOAD_URL="https://github.com/ekzhang/bore/releases/download/${BORE_VERSION}/bore-${BORE_VERSION}-x86_64-unknown-linux-musl.tar.gz"
                    elif [ "$ARCH" = "aarch64" ]; then
                        DOWNLOAD_URL="https://github.com/ekzhang/bore/releases/download/${BORE_VERSION}/bore-${BORE_VERSION}-aarch64-unknown-linux-musl.tar.gz"
                    elif [ "$ARCH" = "armv7l" ]; then
                        DOWNLOAD_URL="https://github.com/ekzhang/bore/releases/download/${BORE_VERSION}/bore-${BORE_VERSION}-armv7-unknown-linux-musleabihf.tar.gz"
                    else
                        DOWNLOAD_URL="https://github.com/ekzhang/bore/releases/download/${BORE_VERSION}/bore-${BORE_VERSION}-x86_64-unknown-linux-musl.tar.gz"
                    fi

                    TMP_DIR=$(mktemp -d)
                    if curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/bore.tar.gz"; then
                        tar -xzf "$TMP_DIR/bore.tar.gz" -C "$TMP_DIR"
                        mv "$TMP_DIR/bore" "$BORE_BIN"
                        chmod +x "$BORE_BIN"
                        rm -rf "$TMP_DIR"
                        echo -e "\e[32m✔ Binary bore ${BORE_VERSION} berhasil dipasang ke $BORE_BIN\e[0m"
                    else
                        echo -e "\e[31m[ERROR] Gagal mengunduh binary bore dari GitHub.\e[0m"
                        rm -rf "$TMP_DIR"
                        break
                    fi
                else
                    echo "Binary bore sudah terpasang: $(bore --version 2>/dev/null || echo "$BORE_BIN")"
                fi

                # Input secret
                read -rp "Masukkan Secret Key Bore [default: $CURRENT_SECRET]: " NEW_SECRET
                NEW_SECRET=${NEW_SECRET:-$CURRENT_SECRET}
                NEW_SECRET=$(echo "$NEW_SECRET" | tr -d '[:space:]')
                [ -z "$NEW_SECRET" ] && NEW_SECRET="renaisand_bore_2026"

                echo "Menyiapkan systemd service ($SERVICE_FILE)..."
                cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Bore Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=$BORE_BIN server --secret $NEW_SECRET
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

                systemctl daemon-reload
                systemctl enable bore-server
                systemctl restart bore-server
                sleep 1

                # Konfigurasi firewall UFW agar port tunnel tidak diblokir
                if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                    echo "Membuka port di firewall UFW (7835, 48923, dan range 40000-50000)..."
                    ufw allow 7835/tcp >/dev/null 2>&1 || true
                    ufw allow 48923/tcp >/dev/null 2>&1 || true
                    ufw allow 40000:50000/tcp >/dev/null 2>&1 || true
                fi

                echo -e "\e[32m✔ Bore Server berhasil dikonfigurasi & dijalankan!\e[0m"
                echo "IP Server        : $VPS_IP"
                echo "Port Kontrol     : 7835 (Default Bore)"
                echo "Secret Key       : $NEW_SECRET"
                ;;
            3)
                echo ""
                echo "============================================="
                echo "       Generate Script Oneliner Client       "
                echo "============================================="
                echo "Server: $VPS_IP | Port Kontrol: $CURRENT_PORT | Secret: $CURRENT_SECRET"
                echo ""
                read -rp "Masukkan Port Lokal Client yang mau di-forward [default: 8022 untuk SSH Termux]: " CLI_LOCAL_PORT
                CLI_LOCAL_PORT=${CLI_LOCAL_PORT:-8022}
                CLI_LOCAL_PORT=$(echo "$CLI_LOCAL_PORT" | tr -cd '0-9')
                [ -z "$CLI_LOCAL_PORT" ] && CLI_LOCAL_PORT="8022"

                read -rp "Ingin menentukan Remote Port tertentu di VPS? [default: 48923]: " CLI_REMOTE_PORT
                CLI_REMOTE_PORT=${CLI_REMOTE_PORT:-48923}
                CLI_REMOTE_PORT=$(echo "$CLI_REMOTE_PORT" | tr -cd '0-9')
                [ -z "$CLI_REMOTE_PORT" ] && CLI_REMOTE_PORT="48923"

                REMOTE_PORT_ARG=" --port $CLI_REMOTE_PORT"

                # Pastikan remote port diizinkan di UFW jika ada
                if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
                    ufw allow "${CLI_REMOTE_PORT}/tcp" >/dev/null 2>&1 || true
                fi

                echo ""
                echo -e "\e[36m=== 1. PERINTAH MANUAL CEPAT (Langsung Tes di Client) ===\e[0m"
                echo "bore local $CLI_LOCAL_PORT --to $VPS_IP --secret \"$CURRENT_SECRET\"$REMOTE_PORT_ARG"
                echo ""

                # Siapkan file oneliner di web /var/www/html jika ada Nginx aktif
                WEB_DIR="/var/www/html"
                if [ -d "$WEB_DIR" ]; then
                    mkdir -p "$WEB_DIR"

                    # Buat script client runner otomatis untuk Termux
                    cat > "$WEB_DIR/bore-client.sh" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# Bore Auto-Reconnect Client Runner for Termux
REMOTE_HOST="$VPS_IP"
BORE_SECRET="$CURRENT_SECRET"
LOCAL_PORT="$CLI_LOCAL_PORT"
DESIRED_REMOTE_PORT="$CLI_REMOTE_PORT"

# Pastikan bore terinstall
if ! command -v bore &>/dev/null; then
    echo "Menginstall bore di Termux..."
    pkg update -y && pkg install -y bore || cargo install bore-cli || {
        echo "Silakan install binary bore terlebih dahulu!"
        exit 1
    }
fi

# Pastikan openssh terpasang jika forward port 8022
if [ "\$LOCAL_PORT" = "8022" ] && ! command -v sshd &>/dev/null; then
    pkg install -y openssh
fi

echo "=== Menjalankan Tunnel Bore ke \$REMOTE_HOST ==="
while true; do
    if [ "\$LOCAL_PORT" = "8022" ] && ! pgrep -x "sshd" >/dev/null 2>&1; then
        echo "Menjalankan sshd..."
        sshd
    fi

    CMD="bore local \$LOCAL_PORT --to \$REMOTE_HOST --secret \"\$BORE_SECRET\""
    if [ -n "\$DESIRED_REMOTE_PORT" ]; then
        CMD="\$CMD --port \$DESIRED_REMOTE_PORT"
    fi

    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Starting bore tunnel: \$CMD"
    eval "\$CMD"

    EXIT_CODE=\$?
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Bore keluar dengan kode: \$EXIT_CODE. Reconnect dalam 3 detik..."
    sleep 3
done
EOF
                    chmod 644 "$WEB_DIR/bore-client.sh"
                fi

                if [ -n "$DETECTED_DOMAIN" ]; then
                    CLIENT_SCRIPT_URL="https://$DETECTED_DOMAIN/bore-client.sh"
                else
                    CLIENT_SCRIPT_URL="http://$VPS_IP/bore-client.sh"
                fi

                echo -e "\e[36m=== 2. ONELINER INSTALL & RUNNER DI TERMUX (Background + Auto Reconnect) ===\e[0m"
                echo "Jalankan perintah ini di Termux HP:"
                echo ""
                echo -e "\e[32mcurl -fsSL $CLIENT_SCRIPT_URL -o ~/.bore_runner_vps.sh && chmod +x ~/.bore_runner_vps.sh && nohup ~/.bore_runner_vps.sh > ~/bore_vps.log 2>&1 &\e[0m"
                echo ""

                echo "======================================================="
                echo "📱 PANDUAN KONEKSI DI TERMIUS / SSH APP LAIN:"
                echo "======================================================="
                echo "Buka Termius -> Tambah Host Baru (+):"
                echo "  • Label    : Termux via VPS Bore"
                echo "  • Hostname : $VPS_IP (atau $DISPLAY_HOST)"
                echo "  • Port     : $CLI_REMOTE_PORT"
                echo "  • Username : (Username Termux Anda, ketik 'whoami' di Termux)"
                echo "  • Password : (Password Termux Anda, dibuat lewat 'passwd')"
                echo "======================================================="
                echo ""
                ;;
            4)
                echo "Membuka port-port Bore di Firewall (UFW)..."
                if command -v ufw &>/dev/null; then
                    ufw allow 7835/tcp
                    ufw allow 48923/tcp
                    ufw allow 40000:50000/tcp
                    echo -e "\e[32m✔ Port 7835, 48923, dan range 40000-50000/tcp telah dibuka di UFW.\e[0m"
                    ufw status | grep -E "7835|48923|40000"
                else
                    echo "UFW tidak terpasang di VPS ini."
                fi
                ;;
            5)
                echo "Merestart service bore-server..."
                systemctl restart bore-server
                sleep 1
                if systemctl is-active --quiet bore-server; then
                    echo -e "\e[32m✔ Service bore-server berhasil direstart dan berjalan.\e[0m"
                else
                    echo -e "\e[31m[ERROR] Gagal merestart service bore-server!\e[0m"
                fi
                ;;
            6)
                echo "Menghentikan service bore-server..."
                systemctl stop bore-server
                systemctl disable bore-server 2>/dev/null || true
                echo -e "\e[33m✔ Service bore-server telah dihentikan & dinonaktifkan.\e[0m"
                ;;
            7)
                echo "Menghapus instalasi bore server..."
                read -rp "Yakin ingin menghapus bore server? [y/N]: " UNCONFIRM
                if [[ "$UNCONFIRM" =~ ^[Yy]$ ]]; then
                    systemctl stop bore-server 2>/dev/null || true
                    systemctl disable bore-server 2>/dev/null || true
                    rm -f "$SERVICE_FILE"
                    systemctl daemon-reload
                    rm -f "$BORE_BIN"
                    echo -e "\e[32m✔ Bore Server berhasil di-uninstall sepenuhnya.\e[0m"
                else
                    echo "Uninstall dibatalkan."
                fi
                ;;
            *)
                echo "Kembali ke Menu Utama."
                ;;
        esac
        ;;
    *)
        echo "Opsi tidak valid!"
        ;;
esac

