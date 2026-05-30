#!/data/data/com.termux/files/usr/bin/bash

set -u

SERVER_DIR="$HOME/mc-server"
CONFIG_FILE="$SERVER_DIR/.mcctl.env"
BACKUP_DIR="$SERVER_DIR/backups"
MODS_DIR="$SERVER_DIR/mods"
PLUGINS_DIR="$SERVER_DIR/plugins"
PLAYIT_DIR="$SERVER_DIR/playit"

UA="termux-mcctl/3.0"

MC_VERSION="1.21.1"
SERVER_TYPE="paper"
RAM_MIN="512M"
RAM_MAX="1200M"

PAPER_API="https://fill.papermc.io/v3"
FABRIC_META="https://meta.fabricmc.net/v2"
MODRINTH_API="https://api.modrinth.com/v2"
MOJANG_MANIFEST="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
FORGE_MAVEN_META="https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml"

mkdir -p "$SERVER_DIR" "$BACKUP_DIR" "$MODS_DIR" "$PLUGINS_DIR" "$PLAYIT_DIR"
cd "$SERVER_DIR" || exit 1

load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi
}

save_config() {
  cat > "$CONFIG_FILE" <<CFG
MC_VERSION="$MC_VERSION"
SERVER_TYPE="$SERVER_TYPE"
RAM_MIN="$RAM_MIN"
RAM_MAX="$RAM_MAX"
CFG
}

pause() {
  printf "\nTekan ENTER untuk lanjut..."
  read -r _
}

set_prop_file() {
  KEY="$1"
  VALUE="$2"
  FILE="${3:-server.properties}"

  [ -f "$FILE" ] || touch "$FILE"

  if grep -q "^$KEY=" "$FILE"; then
    sed -i "s/^$KEY=.*/$KEY=$VALUE/" "$FILE"
  else
    echo "$KEY=$VALUE" >> "$FILE"
  fi
}

install_deps() {
  echo "[*] Install dependency Termux..."
  pkg update -y
  pkg upgrade -y

  echo "[*] Install dependency dasar..."
  pkg install -y curl jq grep sed coreutils tar iproute2 python tmux proot-distro file openssl

  echo "[*] Mencari Java terbaru yang tersedia di repo Termux..."

  JAVA_PKG="$(pkg search '^openjdk-[0-9]+$' 2>/dev/null \
    | grep -oE '^openjdk-[0-9]+' \
    | sort -t- -k2,2n \
    | tail -n 1)"

  if [ -z "$JAVA_PKG" ]; then
    echo "[!] Tidak bisa auto-detect Java terbaru. Fallback ke openjdk-21."
    JAVA_PKG="openjdk-21"
  fi

  JAVA_NUM="$(echo "$JAVA_PKG" | grep -oE '[0-9]+$')"
  JAVA_X_PKG="openjdk-${JAVA_NUM}-x"

  echo "[*] Java terpilih: $JAVA_PKG"

  if pkg search "^${JAVA_X_PKG}$" 2>/dev/null | grep -q "^${JAVA_X_PKG}/"; then
    pkg install -y "$JAVA_PKG" "$JAVA_X_PKG"
  else
    pkg install -y "$JAVA_PKG"
  fi

  echo "[*] Membersihkan binary Java lama jika bentrok..."

  rm -f "$PREFIX/bin/java" \
        "$PREFIX/bin/jar" \
        "$PREFIX/bin/jarsigner" \
        "$PREFIX/bin/javac" \
        "$PREFIX/bin/javadoc" \
        "$PREFIX/bin/javap" \
        "$PREFIX/bin/jconsole" \
        "$PREFIX/bin/jrunscript" \
        "$PREFIX/bin/keytool" 2>/dev/null

  pkg reinstall -y "$JAVA_PKG" || true

  if pkg list-installed 2>/dev/null | grep -q "^${JAVA_X_PKG}/"; then
    pkg reinstall -y "$JAVA_X_PKG" || true
  fi

  hash -r

  echo
  echo "[OK] Java aktif:"
  java -version

  echo
  echo "[*] Setup Debian proot untuk Playit.gg..."

  if ! proot-distro login debian -- true >/dev/null 2>&1; then
    echo "[*] Debian belum ada. Installing Debian..."
    proot-distro install debian
  else
    echo "[OK] Debian proot sudah ada."
  fi

  echo "[*] Install dependency Debian untuk Playit..."
  proot-distro login --bind "$SERVER_DIR:/mc-server" debian -- bash -lc '
    set -e
    apt update
    apt install -y curl file ca-certificates procps tmux
  '

  echo "[*] Install / update Playit v0.15.0 ke $PLAYIT_DIR ..."
  playit_install_binary

  echo
  echo "[OK] Dependency selesai."
}

backup_old_server() {
  TS="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR/$TS"

  [ -f server.jar ] && cp -f server.jar "$BACKUP_DIR/$TS/server.jar"
  [ -f start.sh ] && cp -f start.sh "$BACKUP_DIR/$TS/start.sh"
  [ -f server.properties ] && cp -f server.properties "$BACKUP_DIR/$TS/server.properties"
  [ -f eula.txt ] && cp -f eula.txt "$BACKUP_DIR/$TS/eula.txt"
  [ -d mods ] && cp -r mods "$BACKUP_DIR/$TS/mods" 2>/dev/null || true
  [ -d plugins ] && cp -r plugins "$BACKUP_DIR/$TS/plugins" 2>/dev/null || true

  echo "[*] Backup tersimpan di: $BACKUP_DIR/$TS"
}

write_eula() {
  echo "eula=true" > "$SERVER_DIR/eula.txt"
}

get_server_port() {
  PORT="25565"

  if [ -f "$SERVER_DIR/server.properties" ]; then
    PROP_PORT="$(grep '^server-port=' "$SERVER_DIR/server.properties" | cut -d= -f2 | tr -d ' ')"
    [ -n "$PROP_PORT" ] && PORT="$PROP_PORT"
  fi

  echo "$PORT"
}

get_lan_ip() {
  LAN_IP=""

  LAN_IP="$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print $2}' | head -n 1)"

  if [ -z "$LAN_IP" ]; then
    LAN_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}' | head -n 1)"
  fi

  echo "$LAN_IP"
}

show_server_address() {
  PORT="$(get_server_port)"
  LAN_IP="$(get_lan_ip)"

  echo "===================================================="
  echo " SERVER ADDRESS"
  echo "===================================================="
  echo "Local device : 127.0.0.1:$PORT"

  if [ -n "$LAN_IP" ]; then
    echo "LAN / WiFi    : $LAN_IP:$PORT"
  else
    echo "LAN / WiFi    : tidak terdeteksi"
  fi

  echo
  echo "Untuk HP yang sama: 127.0.0.1:$PORT"

  if [ -n "$LAN_IP" ]; then
    echo "Untuk teman satu WiFi/hotspot: $LAN_IP:$PORT"
  fi

  echo "Untuk publik/internet pakai Playit.gg / tunnel / port forwarding."
  echo "===================================================="
  echo
}

get_java_major() {
  JAVA_VER="$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | head -n 1)"
  JAVA_MAJOR="$(echo "$JAVA_VER" | awk -F. '{ if ($1 == "1") print $2; else print $1 }')"
  [ -z "$JAVA_MAJOR" ] && JAVA_MAJOR="0"
  echo "$JAVA_MAJOR"
}

check_java_compat() {
  JAVA_VER="$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | head -n 1)"
  JAVA_MAJOR="$(get_java_major)"

  echo "[*] Java aktif: $JAVA_VER"

  case "$MC_VERSION" in
    1.21*|1.20.5|1.20.6)
      if [ "$JAVA_MAJOR" -lt 21 ]; then
        echo "[ERROR] Minecraft $MC_VERSION membutuhkan Java 21 atau lebih baru."
        echo "Jalankan opsi 1. Install dependency dulu."
        return 1
      fi
      ;;
    1.20.4|1.20.3|1.20.2|1.20.1|1.20|1.19*|1.18*|1.17*)
      if [ "$JAVA_MAJOR" -lt 17 ]; then
        echo "[ERROR] Minecraft $MC_VERSION membutuhkan minimal Java 17."
        echo "Jalankan opsi 1. Install dependency dulu."
        return 1
      fi
      ;;
    1.16*|1.15*|1.14*|1.13*|1.12*)
      echo "[WARN] Minecraft $MC_VERSION adalah versi lama. Java terbaru bisa saja tidak cocok."
      ;;
  esac

  return 0
}

write_start_generic() {
  cat > "$SERVER_DIR/start.sh" <<START
#!/data/data/com.termux/files/usr/bin/bash
cd "$SERVER_DIR"

PORT="\$(grep '^server-port=' server.properties 2>/dev/null | cut -d= -f2)"
[ -z "\$PORT" ] && PORT="25565"

LAN_IP="\$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print \$2}' | head -n 1)"
[ -z "\$LAN_IP" ] && LAN_IP="\$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print \$2}' | head -n 1)"

echo "===================================================="
echo " SERVER ADDRESS"
echo "===================================================="
echo "Local device : 127.0.0.1:\$PORT"
if [ -n "\$LAN_IP" ]; then
  echo "LAN / WiFi    : \$LAN_IP:\$PORT"
else
  echo "LAN / WiFi    : tidak terdeteksi"
fi
echo "===================================================="
echo

java \\
-Dterminal.jline=false \\
-Dterminal.ansi=false \\
-Dorg.jline.terminal.dumb=true \\
-Djava.net.preferIPv4Stack=true \\
-Xms$RAM_MIN -Xmx$RAM_MAX \\
-jar server.jar nogui
START

  chmod +x "$SERVER_DIR/start.sh"
}

write_start_forge() {
  cat > "$SERVER_DIR/start.sh" <<START
#!/data/data/com.termux/files/usr/bin/bash
cd "$SERVER_DIR"

PORT="\$(grep '^server-port=' server.properties 2>/dev/null | cut -d= -f2)"
[ -z "\$PORT" ] && PORT="25565"

LAN_IP="\$(ip -4 addr show wlan0 2>/dev/null | grep -oE 'inet [0-9.]+' | awk '{print \$2}' | head -n 1)"
[ -z "\$LAN_IP" ] && LAN_IP="\$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print \$2}' | head -n 1)"

echo "===================================================="
echo " SERVER ADDRESS"
echo "===================================================="
echo "Local device : 127.0.0.1:\$PORT"
if [ -n "\$LAN_IP" ]; then
  echo "LAN / WiFi    : \$LAN_IP:\$PORT"
else
  echo "LAN / WiFi    : tidak terdeteksi"
fi
echo "===================================================="
echo

if [ -f user_jvm_args.txt ]; then
  sed -i '/^-Xms/d;/^-Xmx/d' user_jvm_args.txt
else
  touch user_jvm_args.txt
fi

printf "%s\n%s\n" "-Xms$RAM_MIN" "-Xmx$RAM_MAX" >> user_jvm_args.txt

if [ -f run.sh ]; then
  chmod +x run.sh
  bash run.sh nogui
else
  FORGE_JAR=\$(ls forge-*.jar 2>/dev/null | grep -v installer | head -n 1)
  if [ -n "\$FORGE_JAR" ]; then
    java \\
    -Dterminal.jline=false \\
    -Dterminal.ansi=false \\
    -Dorg.jline.terminal.dumb=true \\
    -Djava.net.preferIPv4Stack=true \\
    -Xms$RAM_MIN -Xmx$RAM_MAX \\
    -jar "\$FORGE_JAR" nogui
  else
    echo "Forge jar/run.sh tidak ditemukan."
    exit 1
  fi
fi
START

  chmod +x "$SERVER_DIR/start.sh"
}

regenerate_start_script() {
  if [ "$SERVER_TYPE" = "forge" ]; then
    write_start_forge
  else
    write_start_generic
  fi
}

set_ram() {
  echo "RAM sekarang: -Xms$RAM_MIN -Xmx$RAM_MAX"
  echo
  printf "RAM minimum, contoh 512M / 1G: "
  read -r NEW_MIN
  printf "RAM maksimum, contoh 1G / 1200M / 1500M: "
  read -r NEW_MAX

  [ -n "$NEW_MIN" ] && RAM_MIN="$NEW_MIN"
  [ -n "$NEW_MAX" ] && RAM_MAX="$NEW_MAX"

  save_config
  regenerate_start_script

  echo "[OK] RAM diubah menjadi -Xms$RAM_MIN -Xmx$RAM_MAX"
}

download_vanilla() {
  SERVER_TYPE="vanilla"

  printf "Masukkan versi Minecraft, contoh 1.20.4 / 1.21.1: "
  read -r INPUT_VER
  [ -n "$INPUT_VER" ] && MC_VERSION="$INPUT_VER"

  backup_old_server

  echo "[*] Ambil manifest Mojang/Piston..."
  VERSION_JSON_URL="$(curl -fsSL -H "User-Agent: $UA" "$MOJANG_MANIFEST" \
    | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id == $v) | .url' | head -n 1)"

  if [ -z "$VERSION_JSON_URL" ] || [ "$VERSION_JSON_URL" = "null" ]; then
    echo "[ERROR] Versi $MC_VERSION tidak ditemukan."
    return 1
  fi

  SERVER_URL="$(curl -fsSL -H "User-Agent: $UA" "$VERSION_JSON_URL" \
    | jq -r '.downloads.server.url // empty')"

  if [ -z "$SERVER_URL" ]; then
    echo "[ERROR] Server jar vanilla untuk $MC_VERSION tidak tersedia."
    return 1
  fi

  echo "[*] Download Vanilla $MC_VERSION..."
  curl -fL -H "User-Agent: $UA" -o server.jar "$SERVER_URL"

  write_eula
  write_start_generic
  save_config

  echo "[OK] Vanilla $MC_VERSION siap."
}

download_paper() {
  SERVER_TYPE="paper"

  printf "Masukkan versi Paper/Minecraft, contoh 1.20.4 / 1.21.1: "
  read -r INPUT_VER
  [ -n "$INPUT_VER" ] && MC_VERSION="$INPUT_VER"

  backup_old_server

  echo "[*] Ambil build Paper untuk $MC_VERSION..."
  BUILDS_JSON="$(curl -fsSL -H "User-Agent: $UA" \
    "$PAPER_API/projects/paper/versions/$MC_VERSION/builds" 2>/dev/null || true)"

  PAPER_URL="$(echo "$BUILDS_JSON" | jq -r '
    if type == "array" then
      (([.[] | select(.channel == "STABLE")] | sort_by(.build) | last)
      // (. | sort_by(.build) | last)).downloads."server:default".url // empty
    else
      empty
    end
  ' 2>/dev/null)"

  if [ -z "$PAPER_URL" ] || [ "$PAPER_URL" = "null" ]; then
    echo "[ERROR] Build Paper untuk $MC_VERSION tidak ditemukan."
    echo "Coba versi lain, misalnya 1.19.4, 1.20.4, atau 1.21.1."
    return 1
  fi

  echo "[*] Download Paper $MC_VERSION..."
  curl -fL -H "User-Agent: $UA" -o server.jar "$PAPER_URL"

  write_eula
  write_start_generic
  save_config

  echo "[OK] Paper $MC_VERSION siap."
}

download_fabric() {
  SERVER_TYPE="fabric"

  printf "Masukkan versi Fabric/Minecraft, contoh 1.20.4 / 1.21.1: "
  read -r INPUT_VER
  [ -n "$INPUT_VER" ] && MC_VERSION="$INPUT_VER"

  backup_old_server

  echo "[*] Ambil Fabric Loader terbaru untuk $MC_VERSION..."
  LOADER_JSON="$(curl -fsSL -H "User-Agent: $UA" \
    "$FABRIC_META/versions/loader/$MC_VERSION" 2>/dev/null || true)"

  LOADER_VER="$(echo "$LOADER_JSON" \
    | jq -r '([.[] | select(.loader.stable == true)][0].loader.version // .[0].loader.version // empty)' 2>/dev/null)"

  echo "[*] Ambil Fabric Installer stable terbaru..."
  INSTALLER_VER="$(curl -fsSL -H "User-Agent: $UA" \
    "$FABRIC_META/versions/installer" \
    | jq -r '([.[] | select(.stable == true)][0].version // .[0].version // empty)' 2>/dev/null)"

  if [ -z "$LOADER_VER" ] || [ -z "$INSTALLER_VER" ]; then
    echo "[ERROR] Fabric loader/installer untuk $MC_VERSION tidak ditemukan."
    return 1
  fi

  FABRIC_SERVER_URL="$FABRIC_META/versions/loader/$MC_VERSION/$LOADER_VER/$INSTALLER_VER/server/jar"

  echo "[*] Download Fabric Server Launcher:"
  echo "    MC        : $MC_VERSION"
  echo "    Loader    : $LOADER_VER"
  echo "    Installer : $INSTALLER_VER"

  curl -fL -H "User-Agent: $UA" -o server.jar "$FABRIC_SERVER_URL"

  write_eula
  write_start_generic
  save_config

  echo "[OK] Fabric $MC_VERSION siap."
}

download_forge() {
  SERVER_TYPE="forge"

  printf "Masukkan versi Forge/Minecraft, contoh 1.19.4 / 1.20.1: "
  read -r INPUT_VER
  [ -n "$INPUT_VER" ] && MC_VERSION="$INPUT_VER"

  backup_old_server

  echo "[*] Cari Forge build terbaru untuk Minecraft $MC_VERSION..."
  FORGE_VERSION="$(curl -fsSL -H "User-Agent: $UA" "$FORGE_MAVEN_META" \
    | grep -o "${MC_VERSION}-[0-9][^<]*" \
    | tail -n 1)"

  if [ -z "$FORGE_VERSION" ]; then
    echo "[ERROR] Forge untuk Minecraft $MC_VERSION tidak ditemukan."
    echo "Forge di Termux lebih rawan error dibanding Fabric/Paper."
    return 1
  fi

  FORGE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/$FORGE_VERSION/forge-$FORGE_VERSION-installer.jar"

  echo "[*] Download Forge installer $FORGE_VERSION..."
  curl -fL -H "User-Agent: $UA" -o forge-installer.jar "$FORGE_URL"

  echo "[*] Install Forge server..."
  java -jar forge-installer.jar --installServer

  write_eula
  write_start_forge
  save_config

  echo "[OK] Forge $FORGE_VERSION selesai."
}

modrinth_download_mod() {
  SLUG="$1"
  LOADER="$2"

  mkdir -p "$MODS_DIR"

  API_URL="$MODRINTH_API/project/$SLUG/version?loaders=%5B%22$LOADER%22%5D&game_versions=%5B%22$MC_VERSION%22%5D"

  JSON="$(curl -fsSL -H "User-Agent: $UA" "$API_URL" 2>/dev/null || true)"

  URL="$(echo "$JSON" | jq -r '
    if type == "array" and length > 0 then
      ([.[] | select(.version_type == "release")][0] // .[0]) as $v
      | (($v.files | map(select(.primary == true))[0]) // $v.files[0]).url // empty
    else
      empty
    end
  ' 2>/dev/null)"

  FILENAME="$(echo "$JSON" | jq -r '
    if type == "array" and length > 0 then
      ([.[] | select(.version_type == "release")][0] // .[0]) as $v
      | (($v.files | map(select(.primary == true))[0]) // $v.files[0]).filename // empty
    else
      empty
    end
  ' 2>/dev/null)"

  if [ -z "$URL" ] || [ -z "$FILENAME" ]; then
    echo "[SKIP] $SLUG tidak ditemukan untuk $LOADER $MC_VERSION"
    return 0
  fi

  if [ -f "$MODS_DIR/$FILENAME" ]; then
    echo "[ADA] $FILENAME"
    return 0
  fi

  echo "[*] Download $SLUG -> mods/$FILENAME"
  curl -fL -H "User-Agent: $UA" -o "$MODS_DIR/$FILENAME" "$URL"
}

install_fabric_minimal_mods() {
  SERVER_TYPE="fabric"
  save_config

  echo "[*] Install mod optimasi Fabric minimal untuk MC $MC_VERSION..."
  echo "[*] Mod yang tidak cocok versi akan otomatis di-skip."
  echo

  modrinth_download_mod "lithium" "fabric"
  modrinth_download_mod "ferrite-core" "fabric"
  modrinth_download_mod "krypton" "fabric"
  modrinth_download_mod "servercore" "fabric"

  echo
  echo "[OK] Selesai. Jalankan ulang server dengan opsi 6."
}

install_fabric_full_mods() {
  SERVER_TYPE="fabric"
  save_config

  echo "[*] Install mod optimasi Fabric lengkap untuk MC $MC_VERSION..."
  echo "[*] Mod yang tidak cocok versi akan otomatis di-skip."
  echo

  modrinth_download_mod "fabric-api" "fabric"
  modrinth_download_mod "lithium" "fabric"
  modrinth_download_mod "ferrite-core" "fabric"
  modrinth_download_mod "modernfix" "fabric"
  modrinth_download_mod "memoryleakfix" "fabric"
  modrinth_download_mod "krypton" "fabric"
  modrinth_download_mod "servercore" "fabric"
  modrinth_download_mod "starlight" "fabric"

  echo
  echo "[OK] Selesai. Jalankan ulang server dengan opsi 6."
}

install_forge_optimization_mods() {
  SERVER_TYPE="forge"
  save_config

  echo "[*] Install mod optimasi Forge untuk MC $MC_VERSION..."
  echo "[*] Mod yang tidak cocok versi akan otomatis di-skip."
  echo

  modrinth_download_mod "ferrite-core" "forge"
  modrinth_download_mod "modernfix" "forge"
  modrinth_download_mod "memoryleakfix" "forge"
  modrinth_download_mod "saturn" "forge"
  modrinth_download_mod "canary" "forge"
  modrinth_download_mod "radium" "forge"

  echo
  echo "[OK] Selesai. Jalankan ulang server dengan opsi 6."
}

disable_all_mods() {
  mkdir -p mods-disabled mods

  if ls mods/*.jar >/dev/null 2>&1; then
    mv mods/*.jar mods-disabled/
    echo "[OK] Semua mod dipindahkan ke mods-disabled/"
  else
    echo "[INFO] Tidak ada mod .jar aktif di folder mods/"
  fi
}

list_optimization_mods() {
  clear
  echo "===================================================="
  echo " LIST MOD OPTIMASI RAM / TPS"
  echo "===================================================="
  echo
  echo "REKOMENDASI TERMUX / OPPO A3S:"
  echo
  echo "1. Paper"
  echo "   - Paling simpel."
  echo "   - Cocok untuk server ringan tanpa mod."
  echo
  echo "2. Fabric + mod optimasi minimal"
  echo "   - Cocok untuk server modded ringan."
  echo "   - Lebih disarankan daripada Forge untuk HP/Termux."
  echo
  echo "FABRIC MINIMAL:"
  echo "- Lithium"
  echo "- FerriteCore"
  echo "- Krypton"
  echo "- ServerCore"
  echo
  echo "FABRIC FULL:"
  echo "- Fabric API"
  echo "- Lithium"
  echo "- FerriteCore"
  echo "- ModernFix"
  echo "- MemoryLeakFix"
  echo "- Krypton"
  echo "- ServerCore"
  echo "- Starlight"
  echo
  echo "FORGE SERVER-SIDE:"
  echo "- FerriteCore"
  echo "- ModernFix"
  echo "- MemoryLeakFix"
  echo "- Saturn"
  echo "- Canary"
  echo "- Radium"
  echo
  echo "OPTIFINE:"
  echo "- OptiFine bukan untuk server Termux."
  echo "- OptiFine untuk client Minecraft, FPS, shader, dan visual."
  echo
  echo "JANGAN CAMPUR:"
  echo "- Paper pakai folder plugins/"
  echo "- Fabric/Forge pakai folder mods/"
  echo "- Mod Fabric tidak bisa dipakai di Forge."
  echo "- Mod Forge tidak bisa dipakai di Fabric."
}

optimize_server_properties() {
  if [ ! -f server.properties ]; then
    echo "[!] server.properties belum ada."
    echo "Jalankan server sekali dulu sampai server.properties dibuat."
    return 1
  fi

  set_prop_file "view-distance" "3"
  set_prop_file "simulation-distance" "3"
  set_prop_file "max-players" "3"
  set_prop_file "sync-chunk-writes" "false"
  set_prop_file "network-compression-threshold" "512"
  set_prop_file "enable-command-block" "false"
  set_prop_file "spawn-protection" "0"

  echo "[OK] server.properties dioptimasi untuk RAM rendah."
  echo
  grep -E "^(view-distance|simulation-distance|max-players|sync-chunk-writes|network-compression-threshold|enable-command-block|spawn-protection)=" server.properties
}

fix_playit_disconnected() {
  clear
  echo "===================================================="
  echo " FIX LOST CONNECTION / DISCONNECTED"
  echo "===================================================="
  echo
  echo "Fungsi ini akan mengubah server.properties agar tidak mudah"
  echo "menolak koneksi dari Playit/tunnel."
  echo

  if [ ! -f server.properties ]; then
    echo "[ERROR] server.properties belum ada."
    echo "Jalankan server sekali dulu sampai server.properties dibuat."
    return 1
  fi

  echo "Pilih jenis akun client:"
  echo "1. Akun resmi Microsoft / premium"
  echo "2. Non-premium / cracked / offline launcher"
  echo "3. Jangan ubah online-mode"
  echo
  printf "Pilih [1/2/3]: "
  read -r MODE_CHOICE

  set_prop_file "server-port" "25565"
  set_prop_file "white-list" "false"
  set_prop_file "enforce-whitelist" "false"
  set_prop_file "enforce-secure-profile" "false"
  set_prop_file "prevent-proxy-connections" "false"

  case "$MODE_CHOICE" in
    1)
      set_prop_file "online-mode" "true"
      echo
      echo "[OK] online-mode=true untuk akun resmi."
      ;;
    2)
      set_prop_file "online-mode" "false"
      echo
      echo "[OK] online-mode=false untuk non-premium/offline launcher."
      ;;
    3)
      echo
      echo "[OK] online-mode tidak diubah."
      ;;
    *)
      echo
      echo "[WARN] Pilihan tidak valid. online-mode tidak diubah."
      ;;
  esac

  echo
  echo "[OK] Fix disconnected sudah diterapkan."
  echo
  echo "Konfigurasi sekarang:"
  grep -E '^(server-port|online-mode|white-list|enforce-whitelist|enforce-secure-profile|prevent-proxy-connections)=' server.properties
  echo
  echo "Restart server, lalu coba join lagi."
}

show_logs_filter() {
  if [ ! -f logs/latest.log ]; then
    echo "[ERROR] logs/latest.log belum ada."
    return 1
  fi

  echo "===================================================="
  echo " LOG FILTER"
  echo "===================================================="
  grep -iE "disconnect|lost connection|failed|profile|whitelist|incompatible|mod|outdated|verify|mismatch|required|fabric|error|warn" logs/latest.log | tail -n 150
}

setup_dashboard() {
  cd "$SERVER_DIR" || exit 1

  cat > mc-dashboard.py <<'PY'
#!/usr/bin/env python3
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

SERVER_DIR = Path(os.environ.get("MC_SERVER_DIR", "~/mc-server")).expanduser()
DASH_HOST = os.environ.get("MC_DASH_HOST", "0.0.0.0")
DASH_PORT = int(os.environ.get("MC_DASH_PORT", "8080"))

STATE = {"last_total": None, "last_idle": None, "last_proc_ticks": None}

HTML = r'''<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Minecraft Termux Dashboard</title>
<style>
:root { color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0d1117; color: #e6edf3; }
header { padding: 18px 20px; background: #161b22; border-bottom: 1px solid #30363d; position: sticky; top: 0; z-index: 10; }
h1 { margin: 0; font-size: 20px; }
.sub { margin-top: 6px; color: #8b949e; font-size: 13px; }
main { padding: 18px; max-width: 1250px; margin: auto; }
.grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px; }
.card { background: #161b22; border: 1px solid #30363d; border-radius: 14px; padding: 14px; min-height: 110px; }
.wide { grid-column: span 2; }
.full { grid-column: 1 / -1; }
.label { color: #8b949e; font-size: 13px; margin-bottom: 8px; }
.value { font-size: 28px; font-weight: 700; word-break: break-word; }
.small { font-size: 13px; color: #8b949e; margin-top: 8px; line-height: 1.5; }
.ok { color: #3fb950; }
.bad { color: #f85149; }
.warn { color: #d29922; }
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
.bar { height: 9px; background: #30363d; border-radius: 999px; overflow: hidden; margin-top: 12px; }
.fill { height: 100%; width: 0%; background: #58a6ff; transition: width .25s ease; }
button { border: 1px solid #30363d; background: #21262d; color: #e6edf3; border-radius: 9px; padding: 8px 11px; margin: 4px 6px 4px 0; cursor: pointer; font-size: 13px; }
button:hover { background: #30363d; }
pre { white-space: pre-wrap; word-break: break-word; margin: 0; padding: 12px; background: #0d1117; border: 1px solid #30363d; border-radius: 10px; max-height: 360px; overflow: auto; }
@media (max-width: 900px) { .grid { grid-template-columns: repeat(2, 1fr); } .wide { grid-column: span 2; } }
@media (max-width: 560px) { .grid { grid-template-columns: 1fr; } .wide { grid-column: span 1; } }
</style>
</head>
<body>
<header>
  <h1>Minecraft Termux Dashboard</h1>
  <div class="sub">Auto refresh tiap 2 detik · dashboard bind ke 0.0.0.0 agar bisa dibuka dari PC satu WiFi/hotspot</div>
</header>
<main>
<div class="grid">
  <div class="card"><div class="label">Server</div><div id="serverStatus" class="value">...</div><div id="serverDetail" class="small"></div></div>
  <div class="card"><div class="label">Players</div><div id="players" class="value">...</div><div id="version" class="small"></div></div>
  <div class="card"><div class="label">CPU Server Java</div><div id="procCpu" class="value">...</div><div class="bar"><div id="procCpuBar" class="fill"></div></div></div>
  <div class="card"><div class="label">RAM Server Java</div><div id="procRam" class="value">...</div><div id="pid" class="small"></div></div>
  <div class="card"><div class="label">CPU System</div><div id="sysCpu" class="value">...</div><div class="bar"><div id="sysCpuBar" class="fill"></div></div></div>
  <div class="card"><div class="label">RAM System</div><div id="sysRam" class="value">...</div><div class="bar"><div id="sysRamBar" class="fill"></div></div></div>
  <div class="card"><div class="label">Disk ~/mc-server</div><div id="disk" class="value">...</div><div class="bar"><div id="diskBar" class="fill"></div></div></div>
  <div class="card"><div class="label">Uptime Server</div><div id="uptime" class="value">...</div><div id="refresh" class="small"></div></div>
  <div class="card wide"><div class="label">Alamat Minecraft untuk Join</div><div id="mcAddresses" class="mono"></div></div>
  <div class="card wide"><div class="label">Alamat Dashboard untuk PC Browser</div><div id="dashAddresses" class="mono"></div></div>
  <div class="card full"><div class="label">Info Server</div><div id="props" class="small mono"></div></div>
  <div class="card full"><div class="label">Log Minecraft Terakhir</div><pre id="logs">Loading...</pre></div>
</div>
</main>
<script>
function fmtBytes(bytes){if(!bytes&&bytes!==0)return'-';const units=['B','KB','MB','GB','TB'];let n=bytes,i=0;while(n>=1024&&i<units.length-1){n/=1024;i++}return `${n.toFixed(i===0?0:1)} ${units[i]}`}
function pct(n){if(n===null||n===undefined)return'...';return `${n.toFixed(1)}%`}
function setBar(id,val){document.getElementById(id).style.width=`${Math.max(0,Math.min(100,val||0))}%`}
function copyText(t){navigator.clipboard.writeText(t).catch(()=>{})}
function addrButtons(list){if(!list||!list.length)return'<span class="small">Tidak terdeteksi</span>';return list.map(a=>`<button onclick="copyText('${a}')">Copy</button> ${a}`).join('<br>')}
async function refresh(){try{const res=await fetch('/api/status',{cache:'no-store'});const d=await res.json();const online=d.minecraft.online;document.getElementById('serverStatus').innerHTML=online?'<span class="ok">ONLINE</span>':'<span class="bad">OFFLINE</span>';document.getElementById('serverDetail').textContent=online?'Port lokal terbuka dan merespons ping.':'Server belum merespons di port lokal.';document.getElementById('players').textContent=d.minecraft.ping&&d.minecraft.ping.players?`${d.minecraft.ping.players.online}/${d.minecraft.ping.players.max}`:'-';document.getElementById('version').textContent=d.minecraft.ping&&d.minecraft.ping.version?d.minecraft.ping.version.name:d.config.mc_version||'';document.getElementById('procCpu').textContent=pct(d.process.cpu_percent);setBar('procCpuBar',d.process.cpu_percent);document.getElementById('procRam').textContent=fmtBytes(d.process.rss_bytes);document.getElementById('pid').textContent=d.process.pids.length?`PID: ${d.process.pids.join(', ')}`:'Java server tidak ditemukan';document.getElementById('sysCpu').textContent=pct(d.system.cpu_percent);setBar('sysCpuBar',d.system.cpu_percent);document.getElementById('sysRam').textContent=pct(d.system.ram_percent);setBar('sysRamBar',d.system.ram_percent);document.getElementById('disk').textContent=pct(d.disk.percent);setBar('diskBar',d.disk.percent);document.getElementById('uptime').textContent=d.process.uptime||'-';document.getElementById('refresh').textContent=new Date().toLocaleTimeString();document.getElementById('mcAddresses').innerHTML=addrButtons(d.minecraft.addresses);document.getElementById('dashAddresses').innerHTML=addrButtons(d.dashboard.addresses);document.getElementById('props').textContent=[`Folder: ${d.config.server_dir}`,`Type: ${d.config.server_type||'-'}`,`MC Version: ${d.config.mc_version||'-'}`,`Minecraft Port: ${d.minecraft.port}`,`Dashboard Port: ${d.dashboard.port}`,`online-mode: ${d.properties['online-mode']||'-'}`,`view-distance: ${d.properties['view-distance']||'-'}`,`simulation-distance: ${d.properties['simulation-distance']||'-'}`].join('\n');document.getElementById('logs').textContent=d.logs||'Belum ada log.';}catch(e){document.getElementById('serverStatus').innerHTML='<span class="bad">ERROR</span>';document.getElementById('logs').textContent=String(e)}}
refresh();setInterval(refresh,2000);
</script>
</body>
</html>'''

def read_props(path):
    props={}
    if not path.exists(): return props
    try:
        for line in path.read_text(errors="ignore").splitlines():
            line=line.strip()
            if not line or line.startswith("#") or "=" not in line: continue
            k,v=line.split("=",1); props[k.strip()]=v.strip()
    except Exception: pass
    return props

def read_config():
    cfg={}; p=SERVER_DIR/".mcctl.env"
    if not p.exists(): return cfg
    try:
        for line in p.read_text(errors="ignore").splitlines():
            if "=" in line:
                k,v=line.split("=",1); cfg[k.strip()]=v.strip().strip('"').strip("'")
    except Exception: pass
    return cfg

def get_lan_ips():
    ips=[]
    try:
        out=subprocess.check_output(["ip","-4","-o","addr","show","scope","global"],text=True,stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            m=re.search(r"inet\s+([0-9.]+)/",line)
            if m:
                ip=m.group(1)
                if not ip.startswith("127.") and ip not in ips: ips.append(ip)
    except Exception: pass
    if not ips:
        try:
            s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.connect(("1.1.1.1",80)); ip=s.getsockname()[0]; s.close()
            if not ip.startswith("127."): ips.append(ip)
        except Exception: pass
    return ips

def get_server_port(props):
    try: return int(props.get("server-port","25565"))
    except Exception: return 25565

def read_proc_total():
    try:
        vals=[int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
        idle=vals[3]+(vals[4] if len(vals)>4 else 0)
        return sum(vals),idle
    except Exception: return None,None

def read_meminfo():
    data={}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            k,v=line.split(":",1); data[k]=int(v.strip().split()[0])*1024
    except Exception: pass
    total=data.get("MemTotal",0); avail=data.get("MemAvailable",0); used=max(0,total-avail)
    return {"total":total,"used":used,"available":avail,"percent":(used/total*100) if total else 0}

def read_pid_stat(pid):
    try:
        st=Path(f"/proc/{pid}/stat").read_text(); r=st.rfind(")"); after=st[r+2:].split()
        return int(after[11])+int(after[12]), int(after[19])
    except Exception: return 0,0

def read_pid_rss(pid):
    try:
        for line in Path(f"/proc/{pid}/status").read_text(errors="ignore").splitlines():
            if line.startswith("VmRSS:"): return int(line.split()[1])*1024
    except Exception: pass
    return 0

def find_mc_java_processes():
    found=[]
    for name in os.listdir("/proc"):
        if not name.isdigit(): continue
        pid=int(name)
        try:
            raw=Path(f"/proc/{pid}/cmdline").read_bytes(); cmd=raw.replace(b"\x00",b" ").decode(errors="ignore"); low=cmd.lower()
            if "java" not in low: continue
            cwd=""
            try: cwd=os.readlink(f"/proc/{pid}/cwd")
            except Exception: pass
            score=0
            if str(SERVER_DIR) in cwd: score+=2
            for token in ("server.jar","fabric","paper","forge","minecraft","nogui"):
                if token in low: score+=1
            if score>0: found.append({"pid":pid,"cmd":cmd.strip(),"cwd":cwd})
        except Exception: continue
    return found

def format_duration(sec):
    d,rem=divmod(sec,86400); h,rem=divmod(rem,3600); m,s=divmod(rem,60)
    if d: return f"{d}d {h}h {m}m"
    if h: return f"{h}h {m}m {s}s"
    if m: return f"{m}m {s}s"
    return f"{s}s"

def get_process_metrics():
    procs=find_mc_java_processes(); pids=[p["pid"] for p in procs]
    rss=sum(read_pid_rss(pid) for pid in pids); proc_ticks=0; oldest=None
    for pid in pids:
        ticks,start=read_pid_stat(pid); proc_ticks+=ticks
        if start and (oldest is None or start<oldest): oldest=start
    total,idle=read_proc_total(); cpu_percent=None; sys_cpu_percent=None
    if total is not None and STATE["last_total"] is not None:
        td=total-STATE["last_total"]; idd=idle-STATE["last_idle"]; pd=proc_ticks-(STATE["last_proc_ticks"] or 0)
        if td>0:
            sys_cpu_percent=max(0,min(100,(1-idd/td)*100)); cpu_percent=max(0,(pd/td)*(os.cpu_count() or 1)*100)
    STATE["last_total"]=total; STATE["last_idle"]=idle; STATE["last_proc_ticks"]=proc_ticks
    uptime=""
    if oldest:
        try:
            hz=os.sysconf(os.sysconf_names["SC_CLK_TCK"]); up=float(Path("/proc/uptime").read_text().split()[0])-(oldest/hz); uptime=format_duration(max(0,int(up)))
        except Exception: pass
    return {"pids":pids,"rss_bytes":rss,"cpu_percent":cpu_percent,"system_cpu_percent":sys_cpu_percent,"uptime":uptime}

def disk_usage():
    try:
        u=shutil.disk_usage(SERVER_DIR); return {"total":u.total,"used":u.used,"free":u.free,"percent":(u.used/u.total*100) if u.total else 0}
    except Exception: return {"total":0,"used":0,"free":0,"percent":0}

def encode_varint(value):
    out=bytearray(); value&=0xFFFFFFFF
    while True:
        temp=value&0x7F; value >>= 7
        if value: temp|=0x80
        out.append(temp)
        if not value: break
    return bytes(out)

def read_varint(sock):
    num=0; shift=0
    for _ in range(5):
        b=sock.recv(1)
        if not b: raise EOFError
        val=b[0]; num|=(val&0x7F)<<shift
        if not (val&0x80): return num
        shift+=7
    raise ValueError("varint too big")

def minecraft_ping(port):
    try:
        with socket.create_connection(("127.0.0.1",port),timeout=0.7) as sock:
            sock.settimeout(0.7); host=b"127.0.0.1"
            packet=b"\x00"+encode_varint(767)+encode_varint(len(host))+host+struct.pack(">H",port)+b"\x01"
            sock.sendall(encode_varint(len(packet))+packet); sock.sendall(b"\x01\x00")
            _=read_varint(sock); packet_id=read_varint(sock)
            if packet_id!=0: return {"ok":False,"error":"unexpected packet"}
            json_len=read_varint(sock); data=b""
            while len(data)<json_len:
                chunk=sock.recv(json_len-len(data))
                if not chunk: break
                data+=chunk
            js=json.loads(data.decode("utf-8",errors="replace"))
            return {"ok":True,"version":js.get("version"),"players":js.get("players"),"description":js.get("description")}
    except Exception as e: return {"ok":False,"error":str(e)}

def tail_log():
    p=SERVER_DIR/"logs"/"latest.log"
    if not p.exists(): return ""
    try: return "\n".join(p.read_text(errors="ignore").splitlines()[-80:])
    except Exception: return ""

def build_status():
    props=read_props(SERVER_DIR/"server.properties"); cfg=read_config(); port=get_server_port(props); ips=get_lan_ips(); ping=minecraft_ping(port); proc=get_process_metrics(); mem=read_meminfo(); disk=disk_usage()
    mc_addresses=[f"127.0.0.1:{port}"]+[f"{ip}:{port}" for ip in ips]
    dash_addresses=[f"http://127.0.0.1:{DASH_PORT}"]+[f"http://{ip}:{DASH_PORT}" for ip in ips]
    return {"time":time.time(),"config":{"server_dir":str(SERVER_DIR),"server_type":cfg.get("SERVER_TYPE",""),"mc_version":cfg.get("MC_VERSION",""),"ram_min":cfg.get("RAM_MIN",""),"ram_max":cfg.get("RAM_MAX","")},"properties":props,"minecraft":{"port":port,"online":bool(ping.get("ok")),"ping":ping if ping.get("ok") else None,"ping_error":ping.get("error"),"addresses":mc_addresses},"dashboard":{"host":DASH_HOST,"port":DASH_PORT,"addresses":dash_addresses},"process":{"pids":proc["pids"],"rss_bytes":proc["rss_bytes"],"cpu_percent":proc["cpu_percent"],"uptime":proc["uptime"]},"system":{"cpu_percent":proc["system_cpu_percent"],"ram_total":mem["total"],"ram_used":mem["used"],"ram_available":mem["available"],"ram_percent":mem["percent"]},"disk":disk,"logs":tail_log()}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args): return
    def send_bytes(self, code, content_type, data):
        self.send_response(code); self.send_header("Content-Type",content_type); self.send_header("Cache-Control","no-store"); self.send_header("Access-Control-Allow-Origin","*"); self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        path=urlparse(self.path).path
        if path=="/": self.send_bytes(200,"text/html; charset=utf-8",HTML.encode())
        elif path=="/api/status": self.send_bytes(200,"application/json; charset=utf-8",json.dumps(build_status()).encode())
        else: self.send_bytes(404,"text/plain; charset=utf-8",b"Not found")

def main():
    SERVER_DIR.mkdir(parents=True,exist_ok=True); ips=get_lan_ips()
    print("===================================================="); print(" Minecraft Termux Dashboard"); print("===================================================="); print(f"Folder     : {SERVER_DIR}"); print(f"Local      : http://127.0.0.1:{DASH_PORT}")
    for ip in ips: print(f"PC Browser : http://{ip}:{DASH_PORT}")
    if not ips: print("PC Browser : IP LAN tidak terdeteksi. Pastikan WiFi/hotspot aktif.")
    print("====================================================")
    ThreadingHTTPServer((DASH_HOST,DASH_PORT),Handler).serve_forever()

if __name__=="__main__": main()
PY

  cat > dashboard.sh <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
cd ~/mc-server
export MC_SERVER_DIR="${MC_SERVER_DIR:-$HOME/mc-server}"
export MC_DASH_HOST="${MC_DASH_HOST:-0.0.0.0}"
export MC_DASH_PORT="${MC_DASH_PORT:-8080}"
python mc-dashboard.py
SH

  chmod +x mc-dashboard.py dashboard.sh

  echo "[OK] Dashboard dibuat."
}

start_dashboard_background() {
  DASH_PORT="${MC_DASH_PORT:-8080}"

  if [ ! -f "$SERVER_DIR/mc-dashboard.py" ]; then
    setup_dashboard
  fi

  if python - "$DASH_PORT" <<'PYDASHCHECK' >/dev/null 2>&1
import socket, sys
port = int(sys.argv[1])
s = socket.socket(); s.settimeout(0.3)
try:
    s.connect(("127.0.0.1", port)); sys.exit(0)
except Exception:
    sys.exit(1)
finally:
    s.close()
PYDASHCHECK
  then
    echo "[OK] Dashboard sudah berjalan di port $DASH_PORT."
  else
    echo "[*] Menjalankan dashboard di background..."
    cd "$SERVER_DIR" || return 0
    nohup env MC_SERVER_DIR="$SERVER_DIR" MC_DASH_HOST="0.0.0.0" MC_DASH_PORT="$DASH_PORT" python mc-dashboard.py > dashboard.log 2>&1 &
    sleep 1
  fi

  PORT="$(get_server_port 2>/dev/null || echo 25565)"
  LAN_IP="$(get_lan_ip 2>/dev/null || true)"

  echo "===================================================="
  echo " DASHBOARD"
  echo "===================================================="
  echo "Local      : http://127.0.0.1:$DASH_PORT"
  if [ -n "$LAN_IP" ]; then
    echo "PC Browser : http://$LAN_IP:$DASH_PORT"
    echo "MC Join    : $LAN_IP:$PORT"
  else
    echo "PC Browser : IP LAN tidak terdeteksi"
  fi
  echo "===================================================="
}

playit_debian_exec() {
  CMD="$1"
  proot-distro login --bind "$SERVER_DIR:/mc-server" debian -- bash -lc "$CMD"
}

playit_check_debian() {
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "[ERROR] proot-distro belum terinstall. Jalankan opsi 1. Install dependency dulu."
    return 1
  fi

  if ! proot-distro login debian -- true >/dev/null 2>&1; then
    echo "[ERROR] Debian proot belum siap. Jalankan opsi 1. Install dependency dulu."
    return 1
  fi

  return 0
}

playit_install_binary() {
  playit_check_debian || return 1
  mkdir -p "$PLAYIT_DIR"

  echo "[*] Install dependency Debian untuk Playit..."
  playit_debian_exec '
    apt update
    apt install -y curl file ca-certificates procps
  ' || return 1

  echo "[*] Download Playit v0.15.0 ke $PLAYIT_DIR ..."

  playit_debian_exec '
    set -e
    mkdir -p /mc-server/playit
    cd /mc-server/playit

    ARCH="$(uname -m)"

    case "$ARCH" in
      aarch64|arm64)
        URL="https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-aarch64"
        ;;
      armv7*|arm*)
        URL="https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-armv7"
        ;;
      x86_64|amd64)
        URL="https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-amd64"
        ;;
      *)
        echo "Arsitektur tidak dikenali: $ARCH"
        exit 1
        ;;
    esac

    echo "ARCH: $ARCH"
    echo "URL : $URL"

    curl -fL -o playit "$URL"
    chmod +x playit
    file playit || true
  '

  echo "[OK] Playit binary tersimpan di: $PLAYIT_DIR/playit"
}

playit_first_setup() {
  playit_check_debian || return 1
  mkdir -p "$PLAYIT_DIR"

  if [ ! -x "$PLAYIT_DIR/playit" ]; then
    playit_install_binary || return 1
  fi

  echo
  echo "===================================================="
  echo " PLAYIT FIRST SETUP / CLAIM ACCOUNT"
  echo "===================================================="
  echo "Playit akan dijalankan interaktif."
  echo "Jika muncul claim link, buka link tersebut di browser."
  echo "Tekan CTRL + C setelah claim selesai."
  echo "===================================================="
  echo

  playit_debian_exec '
    set -e
    mkdir -p /mc-server/playit/config
    cd /mc-server/playit
    ./playit --secret_path /mc-server/playit/config/playit.toml
  '
}

playit_reset_account() {
  playit_check_debian || return 1

  echo "[*] Stop Playit..."
  pkill -f "proot-distro.*playit" 2>/dev/null || true
  playit_debian_exec 'pkill -f "[p]layit" 2>/dev/null || true' >/dev/null 2>&1 || true

  echo "[*] Menghapus config account Playit lama..."
  rm -rf "$PLAYIT_DIR/config"
  rm -f "$PLAYIT_DIR/playit.log" "$PLAYIT_DIR/playit.pid"
  mkdir -p "$PLAYIT_DIR/config"

  echo "[OK] Account Playit lama dihapus. Jalankan menu Playit first setup / claim account."
}

setup_playit() {
  playit_install_binary
}

start_playit() {
  playit_check_debian || return 1
  mkdir -p "$PLAYIT_DIR/config"

  if [ ! -x "$PLAYIT_DIR/playit" ]; then
    playit_install_binary || return 1
  fi

  echo "[*] Stop Playit lama jika ada..."
  pkill -f "proot-distro.*playit" 2>/dev/null || true
  playit_debian_exec 'pkill -f "[p]layit" 2>/dev/null || true' >/dev/null 2>&1 || true

  echo "[*] Start Playit dari $PLAYIT_DIR ..."

  nohup proot-distro login --bind "$SERVER_DIR:/mc-server" debian -- bash -lc '
    cd /mc-server/playit
    ./playit --secret_path /mc-server/playit/config/playit.toml
  ' > "$PLAYIT_DIR/playit.log" 2>&1 &

  echo $! > "$PLAYIT_DIR/playit.pid"

  sleep 3

  echo "[OK] Playit started."
  echo
  echo "PID Termux wrapper:"
  cat "$PLAYIT_DIR/playit.pid" 2>/dev/null || true
  echo
  echo "Log:"
  tail -n 80 "$PLAYIT_DIR/playit.log" 2>/dev/null || true
}

stop_playit() {
  echo "[*] Stop Playit..."
  pkill -f "proot-distro.*playit" 2>/dev/null || true
  playit_debian_exec 'pkill -f "[p]layit" 2>/dev/null || true' >/dev/null 2>&1 || true
  rm -f "$PLAYIT_DIR/playit.pid"
  echo "[OK] Playit stopped."
}

show_playit_status() {
  echo "===================================================="
  echo " PLAYIT STATUS"
  echo "===================================================="
  echo "Directory : $PLAYIT_DIR"
  echo "Binary    : $PLAYIT_DIR/playit"
  echo "Config    : $PLAYIT_DIR/config/playit.toml"
  echo "Log       : $PLAYIT_DIR/playit.log"
  echo

  if [ -x "$PLAYIT_DIR/playit" ]; then
    echo "Binary    : OK"
  else
    echo "Binary    : NOT FOUND"
  fi

  if [ -f "$PLAYIT_DIR/config/playit.toml" ]; then
    echo "Account   : CONFIG FOUND"
  else
    echo "Account   : NOT CLAIMED / CONFIG NOT FOUND"
  fi

  echo
  echo "Process:"
  pgrep -af "proot-distro.*playit|/playit --secret_path|/mc-server/playit/playit" || echo "Playit tidak berjalan."
  echo "===================================================="
}

show_playit_log() {
  if [ -f "$PLAYIT_DIR/playit.log" ]; then
    tail -n 120 "$PLAYIT_DIR/playit.log"
  else
    echo "Log belum ada: $PLAYIT_DIR/playit.log"
  fi
}

playit_menu() {
  clear
  echo "===================================================="
  echo " PLAYIT.GG MENU"
  echo "===================================================="
  echo "Directory: $PLAYIT_DIR"
  echo "===================================================="
  echo "1. Playit first setup / claim account"
  echo "2. Install / Update Playit binary"
  echo "3. Start Playit"
  echo "4. Stop Playit"
  echo "5. Reset Playit account"
  echo "6. Show Playit status"
  echo "7. Show Playit log"
  echo "0. Kembali"
  echo
  printf "Pilih: "
  read -r CH

  case "$CH" in
    1) playit_first_setup ;;
    2) playit_install_binary ;;
    3) start_playit ;;
    4) stop_playit ;;
    5) playit_reset_account ;;
    6) show_playit_status ;;
    7) show_playit_log ;;
    0) return ;;
    *) echo "Pilihan tidak valid." ;;
  esac
}

get_current_world() {
  if [ -f server.properties ]; then
    WORLD_NAME="$(grep '^level-name=' server.properties | cut -d= -f2- | tr -d '\r')"
    [ -n "$WORLD_NAME" ] && echo "$WORLD_NAME" && return
  fi
  echo "world"
}

safe_world_name() {
  echo "$1" | sed 's#[/\\:*?"<>|]#_#g' | sed 's/^ *//;s/ *$//' | tr -s ' '
}

list_worlds() {
  echo "===================================================="
  echo " WORLD LIST"
  echo "===================================================="

  CURRENT_WORLD="$(get_current_world)"
  FOUND=0

  for dir in "$SERVER_DIR"/*; do
    [ -d "$dir" ] || continue
    NAME="$(basename "$dir")"

    case "$NAME" in
      backups|mods|mods-disabled|plugins|logs|cache|libraries|versions|config|playit|crash-reports)
        continue
        ;;
    esac

    if [ -f "$dir/level.dat" ] || [ -d "$dir/region" ] || [ -d "$dir/DIM-1" ] || [ -d "$dir/DIM1" ]; then
      FOUND=1
      if [ "$NAME" = "$CURRENT_WORLD" ]; then
        echo "* $NAME  [ACTIVE]"
      else
        echo "- $NAME"
      fi
    fi
  done

  [ "$FOUND" = "0" ] && echo "Belum ada world terdeteksi."
  echo "===================================================="
}

backup_current_world() {
  CURRENT_WORLD="$(get_current_world)"
  WORLD_PATH="$SERVER_DIR/$CURRENT_WORLD"

  if [ ! -d "$WORLD_PATH" ]; then
    echo "[INFO] World aktif belum ada foldernya: $CURRENT_WORLD"
    return 0
  fi

  TS="$(date +%Y%m%d-%H%M%S)"
  DEST="$BACKUP_DIR/world-$CURRENT_WORLD-$TS"

  mkdir -p "$BACKUP_DIR"

  echo "[*] Backup current world: $CURRENT_WORLD -> $DEST"
  cp -a "$WORLD_PATH" "$DEST"

  [ -d "$SERVER_DIR/${CURRENT_WORLD}_nether" ] && cp -a "$SERVER_DIR/${CURRENT_WORLD}_nether" "$DEST"_nether
  [ -d "$SERVER_DIR/${CURRENT_WORLD}_the_end" ] && cp -a "$SERVER_DIR/${CURRENT_WORLD}_the_end" "$DEST"_the_end

  echo "[OK] Backup world selesai."
}

create_new_world() {
  clear
  echo "===================================================="
  echo " CREATE NEW WORLD"
  echo "===================================================="
  echo "World aktif sekarang: $(get_current_world)"
  echo
  printf "Nama world baru, contoh survival-1: "
  read -r NEW_WORLD_RAW

  NEW_WORLD="$(safe_world_name "$NEW_WORLD_RAW")"

  if [ -z "$NEW_WORLD" ]; then
    echo "[ERROR] Nama world tidak boleh kosong."
    return 1
  fi

  if [ -d "$SERVER_DIR/$NEW_WORLD" ]; then
    echo "[ERROR] World '$NEW_WORLD' sudah ada. Gunakan menu Choose existing world."
    return 1
  fi

  echo
  echo "Pilih game mode:"
  echo "1. survival"
  echo "2. creative"
  echo "3. adventure"
  echo "4. spectator"
  echo "5. biarkan default"
  printf "Pilih [1/2/3/4/5]: "
  read -r GM_CHOICE

  case "$GM_CHOICE" in
    1) GAMEMODE="survival" ;;
    2) GAMEMODE="creative" ;;
    3) GAMEMODE="adventure" ;;
    4) GAMEMODE="spectator" ;;
    *) GAMEMODE="" ;;
  esac

  echo
  echo "Pilih difficulty:"
  echo "1. peaceful"
  echo "2. easy"
  echo "3. normal"
  echo "4. hard"
  echo "5. biarkan default"
  printf "Pilih [1/2/3/4/5]: "
  read -r DIFF_CHOICE

  case "$DIFF_CHOICE" in
    1) DIFFICULTY="peaceful" ;;
    2) DIFFICULTY="easy" ;;
    3) DIFFICULTY="normal" ;;
    4) DIFFICULTY="hard" ;;
    *) DIFFICULTY="" ;;
  esac

  echo
  printf "Seed world, kosongkan untuk random: "
  read -r WORLD_SEED

  echo
  echo "Backup current world sebelum ganti?"
  echo "1. Ya"
  echo "2. Tidak"
  printf "Pilih [1/2]: "
  read -r BACKUP_CHOICE

  [ "$BACKUP_CHOICE" = "1" ] && backup_current_world

  set_prop_file "level-name" "$NEW_WORLD"
  [ -n "$GAMEMODE" ] && set_prop_file "gamemode" "$GAMEMODE"
  [ -n "$DIFFICULTY" ] && set_prop_file "difficulty" "$DIFFICULTY"

  if [ -n "$WORLD_SEED" ]; then
    set_prop_file "level-seed" "$WORLD_SEED"
  else
    set_prop_file "level-seed" ""
  fi

  echo
  echo "[OK] World baru diset: level-name=$NEW_WORLD"
  echo "Folder world akan dibuat otomatis saat server startup."
}

choose_existing_world() {
  clear
  list_worlds
  echo
  echo "World aktif sekarang: $(get_current_world)"
  printf "Masukkan nama world yang ingin dipakai: "
  read -r WORLD_RAW

  WORLD_NAME="$(safe_world_name "$WORLD_RAW")"

  if [ -z "$WORLD_NAME" ]; then
    echo "[ERROR] Nama world kosong."
    return 1
  fi

  if [ ! -d "$SERVER_DIR/$WORLD_NAME" ]; then
    echo "[ERROR] Folder world tidak ditemukan: $SERVER_DIR/$WORLD_NAME"
    return 1
  fi

  if [ ! -f "$SERVER_DIR/$WORLD_NAME/level.dat" ] && [ ! -d "$SERVER_DIR/$WORLD_NAME/region" ]; then
    echo "[WARN] Folder ada, tapi tidak terlihat seperti world Minecraft biasa. Tetap pakai?"
    echo "1. Ya"
    echo "2. Tidak"
    printf "Pilih [1/2]: "
    read -r CONFIRM
    [ "$CONFIRM" != "1" ] && return 1
  fi

  echo
  echo "Backup current world sebelum ganti?"
  echo "1. Ya"
  echo "2. Tidak"
  printf "Pilih [1/2]: "
  read -r BACKUP_CHOICE

  [ "$BACKUP_CHOICE" = "1" ] && backup_current_world

  set_prop_file "level-name" "$WORLD_NAME"

  echo
  echo "[OK] World aktif diganti ke: level-name=$WORLD_NAME"
  echo "Restart server agar world berubah."
}

show_current_world() {
  clear
  echo "===================================================="
  echo " CURRENT WORLD"
  echo "===================================================="

  CURRENT_WORLD="$(get_current_world)"

  echo "Active world : $CURRENT_WORLD"
  echo "Path         : $SERVER_DIR/$CURRENT_WORLD"

  if [ -d "$SERVER_DIR/$CURRENT_WORLD" ]; then
    echo "Status       : folder ditemukan"
    du -sh "$SERVER_DIR/$CURRENT_WORLD" 2>/dev/null || true
  else
    echo "Status       : folder belum ada / akan dibuat saat server start"
  fi

  echo
  if [ -f server.properties ]; then
    grep -E '^(level-name|level-seed|gamemode|difficulty|hardcore|generate-structures|allow-nether)=' server.properties
  else
    echo "server.properties belum ada."
  fi
  echo "===================================================="
}

world_menu() {
  clear
  echo "===================================================="
  echo " WORLD MANAGER"
  echo "===================================================="
  echo "Current world: $(get_current_world)"
  echo "===================================================="
  echo "1. Show current world"
  echo "2. List worlds"
  echo "3. Create new world"
  echo "4. Choose existing world"
  echo "5. Backup current world"
  echo "0. Kembali"
  echo
  printf "Pilih: "
  read -r CH

  case "$CH" in
    1) show_current_world ;;
    2) list_worlds ;;
    3) create_new_world ;;
    4) choose_existing_world ;;
    5) backup_current_world ;;
    0) return ;;
    *) echo "Pilihan tidak valid." ;;
  esac
}

install_crossplay() {
  clear
  echo "===================================================="
  echo " INSTALL CROSSPLAY JAVA + BEDROCK"
  echo "===================================================="
  echo
  echo "Installer ini akan memasang Geyser-Spigot dan Floodgate-Spigot."
  echo "Direkomendasikan untuk server Paper/Spigot."
  echo

  mkdir -p "$SERVER_DIR/plugins"

  echo "[*] Download Geyser-Spigot..."
  curl -fL -o "$SERVER_DIR/plugins/Geyser-Spigot.jar" \
    "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" || return 1

  echo "[*] Download Floodgate-Spigot..."
  curl -fL -o "$SERVER_DIR/plugins/floodgate-spigot.jar" \
    "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" || return 1

  echo
  echo "[OK] Geyser + Floodgate berhasil diinstall."
  echo
  echo "Langkah berikutnya:"
  echo "1. Jalankan server sekali agar config Geyser dibuat."
  echo "2. Stop server."
  echo "3. Jalankan menu Crossplay -> Configure Geyser."
}

configure_crossplay() {
  clear
  echo "===================================================="
  echo " CONFIGURE CROSSPLAY"
  echo "===================================================="

  GEYSER_CONFIG="$SERVER_DIR/plugins/Geyser-Spigot/config.yml"

  if [ ! -f "$GEYSER_CONFIG" ]; then
    echo "[ERROR] Config Geyser belum ditemukan: $GEYSER_CONFIG"
    echo "Jalankan server sekali dulu setelah install Geyser."
    return 1
  fi

  cp "$GEYSER_CONFIG" "$GEYSER_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"

  python3 <<PYCFG
from pathlib import Path
import re
path = Path("$GEYSER_CONFIG")
text = path.read_text()
text = re.sub(r"bedrock:\n(?:  .*\n)*", "bedrock:\n  address: 0.0.0.0\n  port: 19132\n  clone-remote-port: false\n", text, count=1)
text = re.sub(r"remote:\n(?:  .*\n)*", "remote:\n  address: 127.0.0.1\n  port: 25565\n  auth-type: floodgate\n", text, count=1)
path.write_text(text)
PYCFG

  echo "[OK] Config Geyser diatur:"
  echo "Bedrock: 0.0.0.0:19132"
  echo "Remote Java: 127.0.0.1:25565"
  echo "auth-type: floodgate"
  echo "Restart server agar aktif."
}

show_crossplay_info() {
  clear
  echo "===================================================="
  echo " CROSSPLAY INFO"
  echo "===================================================="

  LAN_IP="$(get_lan_ip 2>/dev/null || true)"
  JAVA_PORT="$(get_server_port 2>/dev/null || echo 25565)"
  BEDROCK_PORT="19132"

  echo "Java Edition:"
  if [ -n "$LAN_IP" ]; then
    echo "  $LAN_IP:$JAVA_PORT"
  else
    echo "  127.0.0.1:$JAVA_PORT"
  fi

  echo
  echo "Bedrock Edition:"
  if [ -n "$LAN_IP" ]; then
    echo "  Address: $LAN_IP"
    echo "  Port   : $BEDROCK_PORT"
  else
    echo "  Address: IP server"
    echo "  Port   : $BEDROCK_PORT"
  fi

  echo
  echo "Jika pakai Playit:"
  echo "- Java    : TCP 25565"
  echo "- Bedrock : UDP 19132"
  echo
  echo "Plugin:"
  ls -lh "$SERVER_DIR/plugins" 2>/dev/null | grep -iE "geyser|floodgate" || echo "Geyser/Floodgate belum terlihat."
}

crossplay_menu() {
  clear
  echo "===================================================="
  echo " CROSSPLAY JAVA + BEDROCK"
  echo "===================================================="
  echo "1. Install Geyser + Floodgate"
  echo "2. Configure Geyser"
  echo "3. Show crossplay join info"
  echo "0. Kembali"
  echo
  printf "Pilih: "
  read -r CH

  case "$CH" in
    1) install_crossplay ;;
    2) configure_crossplay ;;
    3) show_crossplay_info ;;
    0) return ;;
    *) echo "Pilihan tidak valid." ;;
  esac
}

show_status() {
  clear
  echo "===================================================="
  echo " MINECRAFT SERVER STATUS"
  echo "===================================================="
  echo "Folder       : $SERVER_DIR"
  echo "Type         : $SERVER_TYPE"
  echo "MC Version   : $MC_VERSION"
  echo "RAM          : -Xms$RAM_MIN -Xmx$RAM_MAX"
  echo
  show_server_address
  echo "Java:"
  java -version
  echo
  echo "File server:"
  ls -lh server.jar 2>/dev/null || echo "server.jar belum ada"
  echo
  echo "server.properties penting:"
  if [ -f server.properties ]; then
    grep -E '^(server-port|online-mode|white-list|enforce-whitelist|enforce-secure-profile|prevent-proxy-connections|view-distance|simulation-distance|max-players|level-name)=' server.properties
  else
    echo "server.properties belum ada"
  fi
  echo
  echo "Mods aktif:"
  if [ -d mods ] && [ "$(ls -A mods 2>/dev/null)" ]; then
    ls -1 mods
  else
    echo "mods/ kosong"
  fi
  echo
  echo "Plugins aktif:"
  if [ -d plugins ] && [ "$(ls -A plugins 2>/dev/null)" ]; then
    ls -1 plugins
  else
    echo "plugins/ kosong"
  fi
}

run_server() {
  if [ ! -f server.jar ]; then
    echo "[!] server.jar belum ada. Pilih install/ganti versi dulu."
    return 1
  fi

  check_java_compat || return 1
  start_dashboard_background
  regenerate_start_script
  chmod +x start.sh
  ./start.sh
}

change_version_menu() {
  clear
  echo "===================================================="
  echo " GANTI VERSI / SERVER TYPE"
  echo "===================================================="
  echo "1. Vanilla"
  echo "2. Paper"
  echo "3. Fabric"
  echo "4. Forge"
  echo "0. Kembali"
  echo
  printf "Pilih: "
  read -r CH

  case "$CH" in
    1) download_vanilla ;;
    2) download_paper ;;
    3) download_fabric ;;
    4) download_forge ;;
    0) return ;;
    *) echo "Pilihan tidak valid." ;;
  esac
}

mods_menu() {
  clear
  echo "===================================================="
  echo " MOD OPTIMASI"
  echo "===================================================="
  echo "1. Lihat list mod optimasi RAM/TPS"
  echo "2. Install Fabric minimal: Lithium + FerriteCore + Krypton + ServerCore"
  echo "3. Install Fabric full optimization"
  echo "4. Install Forge optimization"
  echo "5. Disable semua mod aktif"
  echo "0. Kembali"
  echo
  printf "Pilih: "
  read -r CH

  case "$CH" in
    1) list_optimization_mods ;;
    2) install_fabric_minimal_mods ;;
    3) install_fabric_full_mods ;;
    4) install_forge_optimization_mods ;;
    5) disable_all_mods ;;
    0) return ;;
    *) echo "Pilihan tidak valid." ;;
  esac
}

main_menu() {
  load_config

  while true; do
    clear
    echo "===================================================="
    echo " TERMUX MINECRAFT SERVER MANAGER"
    echo "===================================================="
    echo "Folder     : $SERVER_DIR"
    echo "Type       : $SERVER_TYPE"
    echo "MC Version : $MC_VERSION"
    echo "RAM        : -Xms$RAM_MIN -Xmx$RAM_MAX"
    echo "===================================================="
    echo "1. Install dependency + Java terbaru"
    echo "2. Ganti versi / server type"
    echo "3. Set RAM"
    echo "4. List / install mod optimasi"
    echo "5. Optimasi server.properties RAM rendah"
    echo "6. Jalankan server + dashboard"
    echo "7. Status + IP + port"
    echo "8. Fix Playit / Lost connection: Disconnected"
    echo "9. Lihat log error/disconnect"
    echo "10. Playit.gg menu"
    echo "11. Setup dashboard"
    echo "12. World manager"
    echo "13. Crossplay Java + Bedrock"
    echo "0. Keluar"
    echo
    printf "Pilih: "
    read -r CHOICE

    case "$CHOICE" in
      1) install_deps; pause ;;
      2) change_version_menu; pause ;;
      3) set_ram; pause ;;
      4) mods_menu; pause ;;
      5) optimize_server_properties; pause ;;
      6) run_server; pause ;;
      7) show_status; pause ;;
      8) fix_playit_disconnected; pause ;;
      9) show_logs_filter; pause ;;
      10) playit_menu; pause ;;
      11) setup_dashboard; pause ;;
      12) world_menu; pause ;;
      13) crossplay_menu; pause ;;
      0) exit 0 ;;
      *) echo "Pilihan tidak valid."; pause ;;
    esac
  done
}

main_menu
