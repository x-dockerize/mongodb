#!/usr/bin/env bash
set -e

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "❌ $ENV_EXAMPLE bulunamadı."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "✅ $ENV_EXAMPLE → $ENV_FILE kopyalandı"
else
  echo "ℹ️  $ENV_FILE zaten mevcut, devam ediliyor"
fi

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
gen_password() {
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20
}

set_env() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# --------------------------------------------------
# MongoDB Admin (dba) Bilgileri
# --------------------------------------------------
MONGO_INITDB_ROOT_USERNAME="dba"

read -rsp "MONGO_INITDB_ROOT_PASSWORD (boş bırakılırsa otomatik oluşturulur): " INPUT_PASSWORD
echo

if [ -z "$INPUT_PASSWORD" ]; then
  MONGO_INITDB_ROOT_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan MONGO_INITDB_ROOT_PASSWORD: $MONGO_INITDB_ROOT_PASSWORD"
else
  MONGO_INITDB_ROOT_PASSWORD="$INPUT_PASSWORD"
fi

# --------------------------------------------------
# Docker Network
# --------------------------------------------------
if docker network inspect mongodb-network &>/dev/null; then
  echo "ℹ️ mongodb-network zaten mevcut"
else
  docker network create mongodb-network
  echo "✅ mongodb-network oluşturuldu"
fi

# --------------------------------------------------
# .env Güncelle
# --------------------------------------------------
set_env MONGO_INITDB_ROOT_USERNAME "$MONGO_INITDB_ROOT_USERNAME"
set_env MONGO_INITDB_ROOT_PASSWORD "$MONGO_INITDB_ROOT_PASSWORD"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ MongoDB .env başarıyla hazırlandı!"
echo "-----------------------------------------------"
echo "👤 Admin Kullanıcı   : $MONGO_INITDB_ROOT_USERNAME"
echo "🔑 Şifre             : $MONGO_INITDB_ROOT_PASSWORD"
echo "-----------------------------------------------"
echo "⚠️ Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
