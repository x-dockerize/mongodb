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
# Root Bilgilerini Oku
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
read -rp "Silinecek DB adı: " DB_NAME

if [ -z "$DB_NAME" ]; then
  echo "❌ DB adı boş bırakılamaz."
  exit 1
fi

DB_EXISTS=$(mongo_exec "
  db.adminCommand({ listDatabases: 1 }).databases.some(d => d.name === '${DB_NAME}') ? 'exists' : ''
" 2>/dev/null)

if ! echo "$DB_EXISTS" | grep -q "exists"; then
  echo "❌ '${DB_NAME}' veritabanı bulunamadı."
  exit 1
fi

# --------------------------------------------------
# Onay
# --------------------------------------------------
echo "⚠️  '${DB_NAME}' veritabanı ve tüm içeriği kalıcı olarak silinecek."
read -rp "Onaylamak için DB adını tekrar girin: " CONFIRM

if [ "$CONFIRM" != "$DB_NAME" ]; then
  echo "İptal edildi."
  exit 0
fi

# --------------------------------------------------
# Kullanıcıyı da Sil?
# --------------------------------------------------
read -rp "İlişkili DB kullanıcısı da silinsin mi? (boş bırakılırsa atlanır): " DB_USER

# --------------------------------------------------
# Veritabanını Sil
# --------------------------------------------------
mongo_exec "db.getSiblingDB('${DB_NAME}').dropDatabase()"

if [ -n "$DB_USER" ]; then
  USER_EXISTS=$(mongo_exec "
    db.getSiblingDB('${DB_NAME}').getUser('${DB_USER}') ? 'exists' : ''
  " 2>/dev/null)

  if echo "$USER_EXISTS" | grep -q "exists"; then
    mongo_exec "db.getSiblingDB('${DB_NAME}').dropUser('${DB_USER}')"
    echo "🗑️  Kullanıcı silindi: $DB_USER"
  else
    echo "⚠️  '${DB_USER}' kullanıcısı bulunamadı, atlandı."
  fi
fi

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Veritabanı başarıyla silindi"
echo "-----------------------------------------------"
echo "🗄️ Veritabanı    : $DB_NAME"
echo "==============================================="
