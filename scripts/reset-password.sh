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
# Kullanıcı Bilgileri
# --------------------------------------------------
read -rp "Veritabanı adı: " DB_NAME

if [ -z "$DB_NAME" ]; then
  echo "❌ Veritabanı adı boş bırakılamaz."
  exit 1
fi

read -rp "Şifresi sıfırlanacak kullanıcı: " DB_USER

if [ -z "$DB_USER" ]; then
  echo "❌ Kullanıcı adı boş bırakılamaz."
  exit 1
fi

USER_EXISTS=$(mongo_exec "
  db.getSiblingDB('${DB_NAME}').getUser('${DB_USER}') ? 'exists' : ''
" 2>/dev/null)

if ! echo "$USER_EXISTS" | grep -q "exists"; then
  echo "❌ '${DB_NAME}' veritabanında '${DB_USER}' kullanıcısı bulunamadı."
  exit 1
fi

read -rsp "Yeni şifre (boş bırakılırsa otomatik oluşturulur): " INPUT_PASSWORD
echo

if [ -z "$INPUT_PASSWORD" ]; then
  NEW_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan şifre: $NEW_PASSWORD"
else
  NEW_PASSWORD="$INPUT_PASSWORD"
fi

# --------------------------------------------------
# Şifreyi Güncelle
# --------------------------------------------------
mongo_exec "db.getSiblingDB('${DB_NAME}').updateUser('${DB_USER}', { pwd: '${NEW_PASSWORD}' })"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Şifre başarıyla sıfırlandı"
echo "-----------------------------------------------"
echo "🗄️ Veritabanı    : $DB_NAME"
echo "👤 Kullanıcı     : $DB_USER"
echo "🔑 Yeni Şifre    : $NEW_PASSWORD"
echo "-----------------------------------------------"
echo "⚠️ Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
