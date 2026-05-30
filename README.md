# Minecraft Server Manager (`mcctl.sh`)

`mcctl.sh` adalah script menu interaktif untuk membuat, menjalankan, dan mengelola Minecraft Java Server secara lokal. Script ini mendukung penggantian versi server, pengaturan RAM, dashboard monitoring, Playit.gg tunnel, world manager, mod optimisasi, crossplay Java + Bedrock, dan kontrol admin melalui dashboard.

Script ini dapat digunakan di:

```text
- Termux Android
```

---

## Fitur Utama

```text
- Install dependency dan Java terbaru
- Pilih server type:
  - Vanilla
  - Paper
  - Fabric
  - Forge
- Set RAM server
- Optimasi server.properties
- Jalankan server Minecraft
- Dashboard monitoring berbasis web
- Tampilkan IP dan port server
- Playit.gg tunnel manager
- First setup / claim akun Playit
- Reset akun Playit
- Install mod optimisasi
- World manager
- Crossplay Java + Bedrock
- Dashboard admin / player monitor
- Player online list
- Player history
- Remote command via dashboard admin
- Log viewer untuk error/disconnect
```

---

## Struktur Folder

Default folder server:

```bash
~/mc-server
```

Struktur umum:

```text
~/mc-server/
├── mcctl.sh
├── start.sh
├── server.jar
├── server.properties
├── eula.txt
├── mods/
├── mods-disabled/
├── plugins/
├── plugins-disabled/
├── playit/
│   ├── playit
│   ├── config/
│   │   └── playit.toml
│   ├── playit.log
│   └── playit.pid
├── backups/
├── logs/
├── world/
├── mc-dashboard.py
└── dashboard.sh
```

---

# 1. Instalasi Awal

## Termux Android

Pastikan Termux berasal dari F-Droid, bukan versi lama dari Play Store.

Buat folder server:

```bash
mkdir -p ~/mc-server
cd ~/mc-server
```

Letakkan `mcctl.sh` di folder tersebut, lalu jalankan:

```bash
chmod +x mcctl.sh
./mcctl.sh
```

## Linux Desktop / Server

Buat folder server:

```bash
mkdir -p ~/mc-server
cd ~/mc-server
```

Letakkan `mcctl.sh` di folder tersebut, lalu jalankan:

```bash
chmod +x mcctl.sh
./mcctl.sh
```

---

# 2. Menu Utama

Menu utama script:

```text
1. Install dependency + Java terbaru
2. Ganti versi / server type
3. Set RAM
4. List / install mod optimasi
5. Optimasi server.properties RAM rendah
6. Jalankan server + dashboard
7. Status + IP + port
8. Fix Playit / Lost connection
9. Lihat log error/disconnect
10. Playit.gg menu
11. Setup dashboard
12. World manager
13. Crossplay Java + Bedrock
14. Dashboard admin / player monitor
0. Keluar
```

---

# 3. Tahapan Setup dari Nol

## Langkah 1 — Install Dependency

Pilih:

```text
1. Install dependency + Java terbaru
```

Fungsi ini akan menginstall dependency utama, seperti:

```text
curl
jq
grep
sed
coreutils
tar
iproute2
python
tmux
file
Java / OpenJDK
```

Pada Termux, script juga dapat menyiapkan:

```text
proot-distro
Debian proot
Playit v0.15.0 untuk Debian proot
```

Cek Java:

```bash
java -version
```

Patokan versi Java:

```text
Minecraft 1.17 - 1.20.4  → Java 17+
Minecraft 1.20.5+        → Java 21+
Minecraft 1.21.x         → Java 21+
```

---

## Langkah 2 — Pilih Server Type

Pilih:

```text
2. Ganti versi / server type
```

Pilihan server:

```text
1. Vanilla
2. Paper
3. Fabric
4. Forge
```

Rekomendasi:

```text
Paper  → paling mudah dan stabil untuk server umum
Fabric → cocok untuk mod optimisasi ringan
Forge  → cocok untuk modpack, tetapi lebih berat
Vanilla → paling original, tetapi minim fitur optimisasi
```

---

## Langkah 3 — Set RAM

Pilih:

```text
3. Set RAM
```

Contoh input:

```text
RAM minimum: 512M
RAM maksimum: 1200M
```

atau untuk laptop/server dengan RAM lebih besar:

```text
RAM minimum: 2G
RAM maksimum: 4G
```

Rekomendasi umum:

```text
RAM device 3 GB  → Xmx 1G - 1.5G
RAM device 8 GB  → Xmx 3G - 4G
RAM device 12 GB → Xmx 4G - 6G
RAM device 16 GB → Xmx 6G - 8G
```

Jangan alokasikan semua RAM ke Minecraft. Sistem operasi, dashboard, tunnel, dan service lain tetap membutuhkan RAM.

---

## Langkah 4 — Optimasi Server Properties

Pilih:

```text
5. Optimasi server.properties RAM rendah
```

Setting yang biasanya diatur:

```properties
view-distance=3
simulation-distance=3
max-players=3
sync-chunk-writes=false
network-compression-threshold=512
spawn-protection=0
```

Untuk laptop/server yang lebih kuat, nilai bisa dinaikkan:

```properties
view-distance=6
simulation-distance=6
max-players=10
```

---

## Langkah 5 — Jalankan Server

Pilih:

```text
6. Jalankan server + dashboard
```

Opsi ini akan:

```text
- mengecek Java aktif
- menjalankan dashboard jika belum aktif
- menampilkan IP dan port server
- menjalankan Minecraft server
```

Contoh output:

```text
DASHBOARD
Local      : http://127.0.0.1:8080
PC Browser : http://192.168.1.25:8080
MC Join    : 192.168.1.25:25565
```

Untuk join dari perangkat lain dalam satu jaringan:

```text
192.168.1.25:25565
```

Untuk membuka dashboard:

```text
http://192.168.1.25:8080
```

---

# 4. Dashboard Monitoring

Dashboard dibuat dari:

```text
mc-dashboard.py
dashboard.sh
```

Dashboard menampilkan:

```text
- status server online/offline
- jumlah player online
- versi server
- CPU Java
- RAM Java
- CPU system
- RAM system
- disk usage
- uptime server
- alamat Minecraft
- alamat dashboard
- log terakhir
- player history
- admin panel jika diaktifkan
```

Menjalankan dashboard manual:

```bash
cd ~/mc-server
./dashboard.sh
```

Jika port `8080` bentrok:

```bash
MC_DASH_PORT=8081 ./dashboard.sh
```

---

# 5. Playit.gg

Playit.gg digunakan agar server dapat diakses dari internet tanpa port forwarding router.

Pilih:

```text
10. Playit.gg menu
```

Menu Playit:

```text
1. Playit first setup / claim account
2. Install / Update Playit binary
3. Start Playit
4. Stop Playit
5. Reset Playit account
6. Show Playit status
7. Show Playit log
```

---

## First Setup / Claim Account

Pilih:

```text
10. Playit.gg menu
1. Playit first setup / claim account
```

Jika muncul claim link, buka link tersebut di browser dan login ke akun Playit.

Setelah claim selesai, tekan:

```text
CTRL + C
```

---

## Start Playit

Pilih:

```text
10. Playit.gg menu
3. Start Playit
```

Jika sudah pernah claim, Playit tidak perlu claim ulang.

Config akun Playit tersimpan di:

```text
~/mc-server/playit/config/playit.toml
```

---

## Reset Akun Playit

Jika ingin ganti akun Playit:

```text
10. Playit.gg menu
5. Reset Playit account
```

Lalu claim ulang:

```text
10. Playit.gg menu
1. Playit first setup / claim account
```

---

## Setting Tunnel Playit untuk Java

Di dashboard Playit, buat tunnel:

```text
Minecraft Java
Protocol: TCP
Local address: 127.0.0.1
Local port: 25565
```

Jika `127.0.0.1` tidak tembus dari environment tunnel, gunakan IP lokal server yang muncul di dashboard, contoh:

```text
Local address: 192.168.1.25
Local port: 25565
```

---

# 6. Mod Optimisasi

Pilih:

```text
4. List / install mod optimasi
```

Rekomendasi Fabric:

```text
Lithium
FerriteCore
Krypton
ServerCore
ModernFix
```

Fungsi umum:

```text
Lithium     → optimasi logic server
FerriteCore → mengurangi penggunaan RAM
Krypton     → optimasi networking
ServerCore  → optimasi server dan lag spike
ModernFix   → optimasi memory/performance tambahan
```

Jika server error karena mod tidak cocok:

```text
4. List / install mod optimasi
Disable semua mod aktif
```

Mod akan dipindahkan ke:

```text
mods-disabled/
```

---

# 7. World Manager

Pilih:

```text
12. World manager
```

Menu:

```text
1. Show current world
2. List worlds
3. Create new world
4. Choose existing world
5. Backup current world
0. Kembali
```

---

## Show Current World

Menampilkan world aktif dari `server.properties`:

```properties
level-name=world
```

---

## List Worlds

Menampilkan daftar folder world yang terdeteksi di folder server.

Contoh:

```text
* world [ACTIVE]
- survival-1
- creative-test
```

---

## Create New World

Pilih:

```text
3. Create new world
```

Input yang diminta:

```text
nama world
gamemode
difficulty
seed
backup current world atau tidak
```

Script akan mengubah:

```properties
level-name=nama-world-baru
level-seed=seed
gamemode=survival
difficulty=normal
```

Folder world baru akan dibuat saat server dijalankan.

---

## Choose Existing World

Pilih:

```text
4. Choose existing world
```

Masukkan nama folder world yang sudah ada.

Script akan mengubah:

```properties
level-name=nama-world
```

Setelah mengganti world, restart server.

---

## Backup Current World

Pilih:

```text
5. Backup current world
```

Backup disimpan di:

```text
~/mc-server/backups/
```

---

# 8. Crossplay Java + Bedrock

Pilih:

```text
13. Crossplay Java + Bedrock
```

Menu:

```text
1. Install Geyser + Floodgate untuk Paper/Spigot
2. Install Geyser + Floodgate untuk Fabric
3. Configure Geyser
4. Show crossplay join info
5. Show crossplay logs
0. Kembali
```

Crossplay memungkinkan:

```text
Minecraft Java Edition
Minecraft Bedrock Edition
```

masuk ke server yang sama.

Komponen:

```text
GeyserMC  → bridge Bedrock ke Java
Floodgate → login Bedrock tanpa akun Java
```

---

## Crossplay untuk Paper

Gunakan menu:

```text
13. Crossplay Java + Bedrock
1. Install Geyser + Floodgate untuk Paper/Spigot
```

File dipasang ke:

```text
plugins/
```

Tahapan:

```text
1. Install Geyser + Floodgate untuk Paper/Spigot
2. Jalankan server sampai Done
3. Stop server
4. Configure Geyser
5. Jalankan server lagi
```

---

## Crossplay untuk Fabric

Gunakan menu:

```text
13. Crossplay Java + Bedrock
2. Install Geyser + Floodgate untuk Fabric
```

File dipasang ke:

```text
mods/
```

Catatan penting:

```text
Geyser-Spigot.jar tidak dipakai di Fabric
floodgate-spigot.jar tidak dipakai di Fabric
Fabric memakai Geyser-Fabric + Floodgate-Fabric
```

Tahapan:

```text
1. Install Geyser + Floodgate untuk Fabric
2. Jalankan server sampai Done
3. Stop server
4. Configure Geyser
5. Jalankan server lagi
```

---

## Configure Geyser

Pilih:

```text
13. Crossplay Java + Bedrock
3. Configure Geyser
```

Konfigurasi yang diterapkan:

```yaml
bedrock:
  address: 0.0.0.0
  port: 19132
  clone-remote-port: false

remote:
  address: 127.0.0.1
  port: 25565
  auth-type: floodgate
```

---

## Join dari Java

```text
IP-SERVER:25565
```

Contoh:

```text
192.168.1.25:25565
```

---

## Join dari Bedrock

Di Minecraft Bedrock:

```text
Servers → Add Server
```

Isi:

```text
Server Name: My Server
Server Address: IP-SERVER
Port: 19132
```

Contoh:

```text
Address: 192.168.1.25
Port: 19132
```

---

## Playit untuk Crossplay

Jika memakai Playit, buat dua tunnel:

```text
Java:
Protocol: TCP
Local address: 127.0.0.1
Local port: 25565
```

```text
Bedrock:
Protocol: UDP
Local address: 127.0.0.1
Local port: 19132
```

---

# 9. Dashboard Admin / Player Monitor

Pilih:

```text
14. Dashboard admin / player monitor
```

Menu:

```text
1. Setup dashboard admin + enable RCON
2. Show admin token
3. Reset admin token
0. Kembali
```

Fitur ini mengaktifkan RCON agar dashboard bisa mengirim command admin.

---

## Setup Dashboard Admin

Pilih:

```text
14. Dashboard admin / player monitor
1. Setup dashboard admin + enable RCON
```

Script akan mengatur:

```properties
enable-rcon=true
rcon.port=25575
rcon.password=<random password>
broadcast-rcon-to-ops=false
```

Script juga membuat token dashboard:

```text
~/mc-server/.dashboard/admin.token
```

Token ini dipakai di dashboard browser.

Setelah setup, restart server.

---

## Fitur Admin Dashboard

Di dashboard, admin dapat:

```text
- melihat player online
- melihat history join/leave/disconnect
- mengirim command server
- OP player
- DEOP player
- kick player
- whitelist add
- whitelist remove
- say message
```

Contoh command manual:

```text
say halo dari dashboard
time set day
weather clear
gamemode creative Steve
tp Steve 0 80 0
```

---

## Keamanan Admin Dashboard

Jangan expose dashboard admin langsung ke internet publik tanpa proteksi tambahan.

Rekomendasi:

```text
- gunakan hanya di LAN
- gunakan VPN/Tailscale/ZeroTier
- jangan share admin token
- reset token jika pernah tersebar
```

---

# 10. Fix Lost Connection / Disconnected

Jika player gagal join dengan pesan:

```text
Lost connection: Disconnected
```

Pilih:

```text
8. Fix Playit / Lost connection
```

Script akan mengatur:

```properties
server-port=25565
white-list=false
enforce-whitelist=false
enforce-secure-profile=false
prevent-proxy-connections=false
```

Lalu pilih mode akun:

```text
1. Akun resmi Microsoft / premium
2. Non-premium / offline launcher
3. Jangan ubah online-mode
```

Jika player memakai akun resmi:

```properties
online-mode=true
```

Jika player memakai offline launcher:

```properties
online-mode=false
```

Restart server setelah melakukan perubahan.

---

# 11. Log Viewer

Pilih:

```text
9. Lihat log error/disconnect
```

Script akan menampilkan log yang berkaitan dengan:

```text
disconnect
lost connection
failed
profile
whitelist
incompatible
mod
outdated
verify
mismatch
required
fabric
error
warn
```

Untuk crossplay, pilih:

```text
13. Crossplay Java + Bedrock
5. Show crossplay logs
```

---

# 12. Menjalankan Server 24 Jam

Gunakan `tmux` agar server tetap berjalan meskipun terminal ditutup.

Install:

```bash
pkg install tmux -y
```

atau di Linux:

```bash
sudo apt install tmux -y
```

Jalankan server:

```bash
tmux new -s mc
cd ~/mc-server
./mcctl.sh
```

Pilih:

```text
6. Jalankan server + dashboard
```

Detach tanpa mematikan server:

```text
CTRL + B lalu D
```

Masuk lagi:

```bash
tmux attach -t mc
```

Cek session:

```bash
tmux ls
```

---

# 13. Rekomendasi Konfigurasi

## Device RAM 3 GB

```text
Server type: Paper atau Fabric
RAM: 512M - 1200M
view-distance=3
simulation-distance=3
max-players=2-3
```

## Device RAM 8 GB

```text
RAM: 2G - 4G
view-distance=5
simulation-distance=5
max-players=5-10
```

## Device RAM 12 GB

```text
RAM: 3G - 6G
view-distance=6
simulation-distance=6
max-players=10+
```

## Server paling ringan

```text
Paper
RAM rendah
view-distance rendah
tanpa mod berlebihan
```

## Server Fabric optimisasi

```text
Fabric
Lithium
FerriteCore
Krypton
ServerCore
ModernFix
```

## Server Crossplay

```text
Paper + Geyser + Floodgate
```

atau:

```text
Fabric + Geyser-Fabric + Floodgate-Fabric
```

---

# 14. Masalah Umum

## Java salah versi

Cek:

```bash
java -version
```

Jika Minecraft 1.21.x gagal, pastikan Java 21 aktif.

---

## Mod incompatible

Cek log:

```bash
grep -iE "incompatible|requires|mod resolution failed|error" logs/latest.log | tail -n 100
```

Solusi:

```text
- disable mod yang salah
- install ulang mod sesuai versi Minecraft
- jangan ambil latest global jika tidak cocok dengan MC_VERSION
```

---

## Geyser config tidak muncul

Kemungkinan:

```text
- server belum dijalankan sampai Done
- Geyser gagal load
- memakai file Spigot di Fabric
- memakai file Fabric di Paper
- versi Geyser tidak cocok dengan Minecraft
```

Cek:

```bash
find mods plugins config -iname "*geyser*" -o -iname "*floodgate*" -o -iname "config.yml"
```

Cek log:

```bash
grep -iE "geyser|floodgate|error|exception|failed" logs/latest.log | tail -n 150
```

---

## Dashboard tidak bisa dibuka dari PC

Pastikan:

```text
- PC dan server satu jaringan
- dashboard berjalan di 0.0.0.0
- buka IP server, bukan 127.0.0.1
```

Contoh benar:

```text
http://192.168.1.25:8080
```

Contoh salah dari PC lain:

```text
http://127.0.0.1:8080
```

---

## Playit meminta claim ulang

Cek:

```bash
ls -l ~/mc-server/playit/config/playit.toml
```

Jika file hilang, lakukan first setup ulang.

---

# 15. Ringkasan Setup Cepat

Urutan setup dari nol:

```text
1. Jalankan ./mcctl.sh
2. Pilih 1. Install dependency + Java terbaru
3. Pilih 2. Ganti versi / server type
4. Pilih Paper atau Fabric
5. Set RAM
6. Optimasi server.properties
7. Jalankan server + dashboard
8. Buka dashboard dari browser
9. Jika butuh internet publik, setup Playit
10. Jika butuh Bedrock, setup Crossplay
11. Jika butuh admin dashboard, aktifkan RCON dari menu 14
```

---

# 16. Catatan Keamanan

```text
- Jangan share admin token dashboard
- Jangan expose dashboard admin ke internet publik tanpa proteksi
- Backup world secara rutin
- Jangan alokasikan semua RAM ke server
- Pantau suhu device
- Gunakan charger/adaptor yang stabil untuk perangkat 24 jam
- Gunakan tmux untuk menjaga service tetap aktif
```

---

# 17. Ringkasan

`mcctl.sh` adalah script all-in-one untuk mengelola Minecraft Java Server dengan fitur:

```text
server installer
version switcher
RAM manager
dashboard monitoring
Playit tunnel
world manager
crossplay Java + Bedrock
mod optimization
admin dashboard
player history
RCON control
log viewer
```

Script ini cocok untuk perangkat ringan, laptop bekas, mini PC, server Linux, maupun Termux Android.
