#!/usr/bin/env bash
set -e

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
check_container() {
  local name="$1"
  if ! docker inspect "$name" &>/dev/null; then
    echo "❌ '$name' container çalışmıyor."
    return 1
  fi
}

backup_local() {
  check_container mongodb-backup-local || return
  echo "⏳ Local yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec mongodb-backup-local mongo-bkup backup --storage local -d "${DB_NAME}" --path /backup
  else
    docker exec mongodb-backup-local mongo-bkup backup --storage local --all-in-one --path /backup
  fi
  echo "✅ Local yedekleme tamamlandı."
}

backup_do() {
  check_container mongodb-backup-do || return
  echo "⏳ DigitalOcean yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec mongodb-backup-do mongo-bkup backup --storage s3 -d "${DB_NAME}" --path /devops/mongodb
  else
    docker exec mongodb-backup-do mongo-bkup backup --storage s3 --all-in-one --path /devops/mongodb
  fi
  echo "✅ DigitalOcean yedekleme tamamlandı."
}

backup_oci() {
  check_container mongodb-backup-oci || return
  echo "⏳ Oracle OCI yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec mongodb-backup-oci mongo-bkup backup --storage s3 -d "${DB_NAME}" --path /devops/mongodb
  else
    docker exec mongodb-backup-oci mongo-bkup backup --storage s3 --all-in-one --path /devops/mongodb
  fi
  echo "✅ Oracle OCI yedekleme tamamlandı."
}

# --------------------------------------------------
# Menü
# --------------------------------------------------
read -rp "Yedeklenecek veritabanı (boş bırakılırsa tümü): " DB_NAME
echo

echo "Yedekleme hedefi seçin:"
echo "  1) Tümü"
echo "  2) Local"
echo "  3) DigitalOcean"
echo "  4) Oracle OCI"
read -rp "Seçim (1-4, boş bırakılırsa: Tümü): " CHOICE
CHOICE="${CHOICE:-1}"

echo

case "$CHOICE" in
  1) backup_local; backup_do; backup_oci ;;
  2) backup_local ;;
  3) backup_do ;;
  4) backup_oci ;;
  *) echo "❌ Geçersiz seçim."; exit 1 ;;
esac
