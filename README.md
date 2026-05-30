# Termux Minecraft Server Manager

Script ini adalah menu manager untuk menjalankan dan mengelola Minecraft Java Server di Termux Android, khususnya untuk device seperti Oppo A3s. Script ini mendukung pengelolaan versi server, RAM, dashboard monitoring, Playit.gg tunnel, world manager, mod optimisasi, dan crossplay Java + Bedrock.

## Fitur Utama

* Install dependency Termux dan Java terbaru.
* Install dan ganti server type:

  * Vanilla
  * Paper
  * Fabric
  * Forge
* Set RAM server.
* Optimasi `server.properties`.
* Jalankan server Minecraft.
* Jalankan dashboard monitoring otomatis.
* Menampilkan IP dan port server.
* Install mod optimisasi.
* Fix error Playit / Lost connection.
* Menu Playit.gg.
* Playit first setup / claim account.
* Reset akun Playit.
* World manager:

  * Create new world
  * Choose existing world
  * List world
  * Backup current world
* Crossplay Java + Bedrock:

  * GeyserMC
  * Floodgate
* Log viewer untuk error/disconnect.

---

# Struktur Folder

Script ini menggunakan folder utama:

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
├── plugins/
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

# Persiapan Awal

## 1. Buka Termux

Pastikan Termux sudah berasal dari F-Droid, bukan versi lama dari Play Store.

## 2. Buat folder server

```bash
mkdir -p ~/mc-server
cd ~/mc-server
```

## 3. Simpan script

Letakkan file `mcctl.sh` di dalam folder:

```bash
~/mc-server/mcctl.sh
```

Lalu beri permission:

```bash
chmod +x mcctl.sh
```

## 4. Jalankan script

```bash
cd ~/mc-server
./mcctl.sh
```

---

# Menu Utama

Tampilan menu utama kurang lebih:

```text
TERMUX MINECRAFT SERVER MANAGER

1. Install dependency + Java terbaru
2. Ganti versi / server type
3. Set RAM
4. List / install mod optimasi
5. Optimasi server.properties RAM rendah
6. Jalankan server
7. Status + IP + port
8. Fix Playit / Lost connection: Disconnected
9. Lihat log error/disconnect
10. Playit.gg menu
11. Setup dashboard
12. World manager
13. Crossplay Java + Bedrock
0. Keluar
```

---

# Tahapan Penggunaan Awal

## Tahap 1 — Install Dependency

Pilih:

```text
1. Install dependency + Java terbaru
```

Fungsi ini akan menginstall:

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
proot-distro
file
OpenJDK terbaru
Debian proot
Playit v0.15.0 di Debian proot
```

Script juga akan membersihkan binary Java lama yang bisa menyebabkan konflik, misalnya kasus Java 8 lama masih aktif.

Cek Java:

```bash
java -version
```

Untuk Minecraft 1.21.x, Java yang disarankan adalah Java 21.

---

## Tahap 2 — Pilih Server Type dan Versi Minecraft

Pilih:

```text
2. Ganti versi / server type
```

Lalu pilih salah satu:

```text
1. Vanilla
2. Paper
3. Fabric
4. Forge
```

Rekomendasi untuk Oppo A3s:

```text
Paper 1.20.4 / 1.21.1
```

atau kalau ingin mod optimisasi:

```text
Fabric 1.20.4 / 1.21.1
```

Untuk server ringan dan stabil, Paper paling direkomendasikan.

---

## Tahap 3 — Set RAM

Pilih:

```text
3. Set RAM
```

Rekomendasi untuk Oppo A3s RAM 3 GB:

```text
RAM minimum: 512M
RAM maksimum: 1200M
```

Jika stabil, bisa mencoba:

```text
RAM minimum: 512M
RAM maksimum: 1500M
```

Jangan memakai:

```text
-Xmx2G
-Xmx3G
```

karena Android dan Termux juga membutuhkan RAM. Jika RAM terlalu penuh, Android bisa membunuh proses Termux.

---

## Tahap 4 — Optimasi server.properties

Pilih:

```text
5. Optimasi server.properties RAM rendah
```

Setting yang diterapkan biasanya:

```properties
view-distance=3 atau 4
simulation-distance=3 atau 4
max-players=3 sampai 5
sync-chunk-writes=false
network-compression-threshold=512
spawn-protection=0
```

Rekomendasi untuk Oppo A3s:

```properties
view-distance=3
simulation-distance=3
max-players=3
```

---

## Tahap 5 — Jalankan Server

Pilih:

```text
6. Jalankan server
```

Saat opsi ini dipilih, script akan:

```text
1. Mengecek Java.
2. Menjalankan dashboard otomatis.
3. Menampilkan IP dan port.
4. Menjalankan start.sh.
```

Contoh output:

```text
SERVER ADDRESS
Local device : 127.0.0.1:25565
LAN / WiFi   : 10.211.57.47:25565

DASHBOARD
Local        : http://127.0.0.1:8080
PC Browser   : http://10.211.57.47:8080
```

Untuk join dari device satu WiFi:

```text
10.211.57.47:25565
```

Untuk membuka dashboard dari PC/laptop:

```text
http://10.211.57.47:8080
```

---

# Dashboard Monitoring

Dashboard dibuat dari file:

```text
mc-dashboard.py
dashboard.sh
```

Dashboard menampilkan:

```text
- Status server online/offline
- Player count
- Versi server
- CPU Java
- RAM Java
- CPU system
- RAM system
- Disk usage
- Uptime server
- IP Minecraft
- URL dashboard
- Log terakhir
- Playit status/settings
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

Lalu buka:

```text
http://IP-HP:8081
```

---

# Playit.gg

Playit.gg digunakan agar server bisa diakses dari internet tanpa port forwarding router.

Karena Playit versi terbaru bermasalah di Termux native, script ini memakai:

```text
Playit v0.15.0 via Debian proot
```

File Playit disimpan di:

```text
~/mc-server/playit/
```

## Struktur Playit

```text
~/mc-server/playit/
├── playit
├── config/
│   └── playit.toml
├── playit.log
└── playit.pid
```

## First Setup / Claim Account

Pilih:

```text
10. Playit.gg menu
1. Playit first setup / claim account
```

Jika muncul claim link, buka link tersebut di browser lalu login ke akun Playit.

Setelah claim selesai, tekan:

```text
CTRL + C
```

## Start Playit

Pilih:

```text
10. Playit.gg menu
3. Start Playit
```

Jika file config sudah ada, Playit tidak perlu claim ulang.

## Apakah setiap start harus claim?

Tidak. Claim hanya perlu sekali.

Config akun disimpan di:

```text
~/mc-server/playit/config/playit.toml
```

Claim ulang hanya diperlukan jika:

```text
- config/playit.toml dihapus
- memilih Reset Playit account
- ingin ganti akun Playit
- config Playit rusak/hilang
```

## Reset Akun Playit

Pilih:

```text
10. Playit.gg menu
5. Reset Playit account
```

Setelah itu lakukan first setup lagi:

```text
10. Playit.gg menu
1. Playit first setup / claim account
```

## Setting Tunnel Playit untuk Java

Di dashboard Playit, buat tunnel:

```text
Minecraft Java
Protocol: TCP
Local address: 127.0.0.1
Local port: 25565
```

Jika tidak tembus dari Debian proot, gunakan IP HP yang muncul di dashboard, contoh:

```text
Local address: 10.211.57.47
Local port: 25565
```

---

# Fix Lost Connection / Disconnected

Jika saat join muncul:

```text
Lost connection: Disconnected
```

Pilih:

```text
8. Fix Playit / Lost connection: Disconnected
```

Menu ini akan mengatur:

```properties
server-port=25565
white-list=false
enforce-whitelist=false
enforce-secure-profile=false
prevent-proxy-connections=false
```

Lalu kamu akan diminta memilih mode akun:

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

Setelah itu restart server.

---

# Mod Optimisasi

Pilih:

```text
4. List / install mod optimasi
```

Untuk Oppo A3s, rekomendasi Fabric:

```text
Lithium
FerriteCore
Krypton
ServerCore
ModernFix
```

Fungsi utama:

```text
Lithium     : optimasi logic server
FerriteCore : mengurangi RAM
Krypton     : optimasi network
ServerCore  : optimasi server dan lag spike
ModernFix   : optimasi memory/performance tambahan
```

Untuk server paling ringan dan stabil, Paper tanpa mod juga sangat direkomendasikan.

## Disable Semua Mod

Jika server disconnect atau client tidak cocok:

```text
4. List / install mod optimasi
5. Disable semua mod aktif
```

Mod akan dipindahkan ke:

```text
mods-disabled/
```

---

# World Manager

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

## Show Current World

Menampilkan world aktif berdasarkan:

```properties
level-name=
```

Contoh:

```properties
level-name=world
```

## List Worlds

Mencari folder world di `~/mc-server`, misalnya:

```text
world
survival-1
creative-test
```

World aktif akan ditandai:

```text
* world [ACTIVE]
```

## Create New World

Pilih:

```text
3. Create new world
```

Isi:

```text
Nama world
Gamemode
Difficulty
Seed
Backup current world atau tidak
```

Script akan mengubah:

```properties
level-name=nama-world-baru
level-seed=seed
gamemode=survival
difficulty=normal
```

Folder world akan dibuat otomatis saat server dijalankan.

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

# Crossplay Java + Bedrock

Pilih:

```text
13. Crossplay Java + Bedrock
```

Menu:

```text
1. Install Geyser + Floodgate
2. Configure Geyser
3. Show crossplay join info
0. Kembali
```

## Fungsi Crossplay

Crossplay memungkinkan pemain:

```text
Minecraft Java Edition
Minecraft Bedrock Edition
```

masuk ke server yang sama.

Komponen:

```text
GeyserMC   : bridge Bedrock ke Java
Floodgate  : login Bedrock tanpa akun Java
```

## Rekomendasi

Untuk Oppo A3s, gunakan:

```text
Paper + Geyser-Spigot + Floodgate-Spigot
```

Fabric bisa, tetapi Paper lebih sederhana dan ringan untuk HP lama.

## Tahapan Install Crossplay

1. Pastikan server type adalah Paper.
2. Pilih:

```text
13. Crossplay Java + Bedrock
1. Install Geyser + Floodgate
```

3. Jalankan server sekali:

```text
6. Jalankan server
```

4. Setelah config Geyser dibuat, stop server:

```text
stop
```

5. Pilih:

```text
13. Crossplay Java + Bedrock
2. Configure Geyser
```

6. Jalankan server lagi:

```text
6. Jalankan server
```

## Join dari Java

```text
IP-A3S:25565
```

Contoh:

```text
10.211.57.47:25565
```

## Join dari Bedrock

Di Minecraft Bedrock:

```text
Servers → Add Server
```

Isi:

```text
Server Name: A3S Server
Server Address: 10.211.57.47
Port: 19132
```

## Playit untuk Crossplay

Jika memakai Playit, perlu dua tunnel:

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

Jika `127.0.0.1` tidak tembus dari Debian proot, gunakan IP HP:

```text
10.211.57.47
```

---

# Log Viewer

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

Jika ada masalah join, jalankan menu ini lalu cek penyebabnya.

---

# Cara Menjalankan Server 24 Jam

Agar server tetap berjalan, gunakan `tmux`.

Install:

```bash
pkg install tmux -y
```

## Session Minecraft

```bash
tmux new -s mc
cd ~/mc-server
./mcctl.sh
```

Pilih:

```text
6. Jalankan server
```

Detach tanpa mematikan server:

```text
CTRL + B lalu D
```

Masuk lagi:

```bash
tmux attach -t mc
```

## Session Dashboard

Jika dashboard belum otomatis berjalan:

```bash
tmux new -s dash
cd ~/mc-server
./dashboard.sh
```

Detach:

```text
CTRL + B lalu D
```

## Session Playit

Jika ingin menjalankan Playit manual:

```bash
tmux new -s playit
cd ~/mc-server
./mcctl.sh
```

Pilih:

```text
10. Playit.gg menu
3. Start Playit
```

---

# Rekomendasi Setting untuk Oppo A3s

## Server Ringan

```text
Server type: Paper
Minecraft: 1.20.4 / 1.21.1
RAM: 512M - 1200M
view-distance=3
simulation-distance=3
max-players=3
```

## Server Fabric Optimized

```text
Server type: Fabric
RAM: 512M - 1200M
Mods:
- Lithium
- FerriteCore
- Krypton
- ServerCore
- ModernFix
```

## Crossplay

```text
Server type: Paper
Plugins:
- Geyser-Spigot
- Floodgate-Spigot
Java port: 25565 TCP
Bedrock port: 19132 UDP
```

---

# Masalah Umum

## Java salah versi

Cek:

```bash
java -version
```

Minecraft 1.21.x butuh Java 21.

Jika Java lama masih aktif, jalankan:

```text
1. Install dependency + Java terbaru
```

## Server lag saat awal join

Penyebab umum:

```text
- chunk loading
- chunk generation
- Java warmup
- storage HP lambat
- Playit tunnel handshake
```

Solusi:

```properties
view-distance=3
simulation-distance=3
max-players=3
```

## Bedrock tidak bisa join

Cek:

```text
- Geyser sudah aktif?
- Floodgate sudah aktif?
- Port Bedrock 19132 benar?
- Playit tunnel Bedrock memakai UDP?
- Config Geyser auth-type=floodgate?
```

## Java bisa join, Bedrock tidak

Kemungkinan Playit hanya membuat tunnel TCP 25565. Bedrock butuh:

```text
UDP 19132
```

## Playit minta claim terus

Cek file:

```bash
ls -l ~/mc-server/playit/config/playit.toml
```

Jika file tidak ada, lakukan first setup ulang.

## Dashboard tidak bisa dibuka dari PC

Pastikan:

```text
- PC dan HP satu WiFi/hotspot
- dashboard jalan di 0.0.0.0
- buka http://IP-HP:8080
- jangan buka 127.0.0.1 dari PC
```

---

# Urutan Setup yang Disarankan dari Nol

```text
1. Jalankan mcctl.sh
2. Pilih 1. Install dependency + Java terbaru
3. Pilih 2. Ganti versi / server type
4. Pilih Paper
5. Masukkan versi Minecraft
6. Pilih 3. Set RAM
7. Isi 512M dan 1200M
8. Pilih 5. Optimasi server.properties
9. Pilih 6. Jalankan server
10. Buka dashboard dari PC: http://IP-HP:8080
11. Jika ingin internet publik, buka 10. Playit.gg menu
12. Pilih Playit first setup / claim account
13. Pilih Start Playit
14. Buat tunnel Minecraft Java TCP 25565 di Playit
15. Jika ingin Bedrock, pilih 13. Crossplay Java + Bedrock
16. Install Geyser + Floodgate
17. Configure Geyser
18. Buat tunnel Bedrock UDP 19132 di Playit
```

---

# Catatan Keamanan

* Jangan membagikan akses Termux/SSH sembarangan.
* Jangan membuka dashboard ke internet tanpa proteksi.
* Untuk dashboard publik, sebaiknya gunakan VPN atau tunnel dengan autentikasi.
* Backup world secara berkala.
* Jangan menjalankan server dengan RAM terlalu besar di HP.
* Pastikan HP tidak terlalu panas.
* Gunakan charger yang stabil.
* Jangan taruh HP di tempat tertutup/panas saat server 24 jam.

---

# Ringkasan

Script ini mengubah Oppo A3s menjadi mini Minecraft server dengan fitur:

```text
Minecraft Java Server
Dashboard monitoring
Playit.gg tunnel
World manager
Crossplay Bedrock
Mod optimization
Backup world
Log viewer
```

Setup paling stabil untuk Oppo A3s:

```text
Paper
Java 21
RAM 512M - 1200M
view-distance=3
simulation-distance=3
max-players=3
Geyser + Floodgate jika butuh Bedrock
Playit jika butuh akses internet
```
