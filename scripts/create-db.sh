#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE bulunamadı. Önce install.sh çalıştırın."
  exit 1
fi

if ! docker inspect mongodb &>/dev/null; then
  echo "❌ MongoDB container çalışmıyor. Önce 'docker compose up -d' çalıştırın."
  exit 1
fi

# --------------------------------------------------
# Root Şifresini Oku
# --------------------------------------------------
MONGO_INITDB_ROOT_USERNAME="$(grep -E '^MONGO_INITDB_ROOT_USERNAME=' "$ENV_FILE" | cut -d '=' -f2-)"
MONGO_INITDB_ROOT_PASSWORD="$(grep -E '^MONGO_INITDB_ROOT_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2-)"

if [ -z "$MONGO_INITDB_ROOT_PASSWORD" ]; then
  echo "❌ MONGO_INITDB_ROOT_PASSWORD .env içinde boş."
  exit 1
fi

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
gen_password() {
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20
}

mongo_exec() {
  docker exec mongodb mongosh --quiet \
    -u "$MONGO_INITDB_ROOT_USERNAME" \
    -p "$MONGO_INITDB_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --eval "$1"
}

# --------------------------------------------------
# Veritabanı Bilgileri
# --------------------------------------------------
read -rp "DB adı: " DB_NAME

if [ -z "$DB_NAME" ]; then
  echo "❌ DB adı boş bırakılamaz."
  exit 1
fi

read -rp "DB kullanıcısı (boş bırakılırsa: ${DB_NAME}): " DB_USER
DB_USER="${DB_USER:-$DB_NAME}"

read -rsp "DB şifresi (boş bırakılırsa otomatik oluşturulur): " INPUT_DB_PASSWORD
echo

if [ -z "$INPUT_DB_PASSWORD" ]; then
  DB_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan DB şifresi: $DB_PASSWORD"
else
  DB_PASSWORD="$INPUT_DB_PASSWORD"
fi

# --------------------------------------------------
# Mevcut Kontrol
# --------------------------------------------------
USER_EXISTS=$(mongo_exec "
  db.getSiblingDB('${DB_NAME}').getUser('${DB_USER}') ? 'exists' : ''
" 2>/dev/null)

if echo "$USER_EXISTS" | grep -q "exists"; then
  echo "⚠️  '${DB_USER}' kullanıcısı '${DB_NAME}' veritabanında zaten mevcut."
  echo "   Şifreyi güncellemek için reset-password.sh kullanın."
  read -rp "Yine de devam etmek istiyor musunuz? (e/H): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[eE]$ ]]; then
    echo "İptal edildi."
    exit 0
  fi
fi

# --------------------------------------------------
# Veritabanı ve Kullanıcı Oluştur
# --------------------------------------------------
mongo_exec "
  db.getSiblingDB('${DB_NAME}').createUser({
    user: '${DB_USER}',
    pwd: '${DB_PASSWORD}',
    roles: [{ role: 'dbOwner', db: '${DB_NAME}' }]
  })
"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Veritabanı başarıyla oluşturuldu"
echo "-----------------------------------------------"
echo "🗄️ Veritabanı    : $DB_NAME"
echo "👤 Kullanıcı     : $DB_USER"
echo "🔑 Şifre         : $DB_PASSWORD"
echo "🌐 Host          : mongodb"
echo "🔌 Port          : 27017"
echo "-----------------------------------------------"
echo "⚠️ Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
