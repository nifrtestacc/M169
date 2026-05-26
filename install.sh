#!/bin/bash

SCRIPT_DIR="$(pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SHELL_RC="/home/$SUDO_USER/.bashrc"
TIMESTAMP=$(date "+%Y.%m.%d-%H.%M")
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9.]*\).*/\1/p" /var/www/html/version.php)
VER="V1.0"

print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    print_cmsg ".env-Datei gefunden und geladen."
else
    print_cmsg ".env-Datei wurde unter $SCRIPT_DIR/docker nicht gefunden. Beende Skript."
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  print_cmsg "Dieses Skript muss mit sudo oder als root ausgefuehrt werden." >&2
  exec sudo "$0" "$@"
  exit 1
fi

mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install.log"
MIGRATION_DUMP_DIR="$INSTALL_DIR/dumps/migration"

clear

cat <<EOF | tee -a "$LOG_FILE"
$(printf '\033[38;5;33m')
-------------------------------------------------------------------------------------------
 __  __              _ _       ___          _             _         _        _ _
|  \/  |___  ___  __| | |___  |   \ ___  __| |_____ _ _  (_)_ _  __| |_ __ _| | |___ _ _
| |\/| / _ \/ _ \/ _\` | / -_) | |) / _ \/ _| / / -_) '_| | | ' \(_-<  _/ _\` | | / -_) '_|
|_|  |_\___/\___/\__,_|_\___| |___/\___/\__|_\_\___|_|   |_|_||_/__/\__\__,_|_|_\___|_|
-------------------------------------------------------------------------------------------
$(printf '\033[0m')
EOF

echo -e "\e[1;91mFalls Probleme auftreten, pruefe bitte das GitHub-Repository: https://github.com/luccaa79/m169\e[0m"

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update
sudo apt install gum -y

sudo apt install jq -y

print_cmsg "Erforderliche Verzeichnisse unter $INSTALL_DIR werden erstellt..." | tee -a "$LOG_FILE"
mkdir -p "$INSTALL_DIR/tools"
mkdir -p "$INSTALL_DIR/tools/moodle-migration"
mkdir -p "$INSTALL_DIR/tools/moodle-status"
mkdir -p "$INSTALL_DIR/dumps"
mkdir -p "$INSTALL_DIR/dumps/migration"
mkdir -p "$INSTALL_DIR/logs/moodle"
mkdir -p "$LOG_DIR/apache"
mkdir -p "$LOG_DIR/mariadb"

print_cmsg "Dateien werden von $SCRIPT_DIR/docker nach $INSTALL_DIR kopiert..." | tee -a "$LOG_FILE"
cp -r "$SCRIPT_DIR/docker/"* "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/moodle-status" "$INSTALL_DIR/tools"
cp -r "$SCRIPT_DIR/moodle-migration" "$INSTALL_DIR/tools"
cp -r "$SCRIPT_DIR/.env" "$INSTALL_DIR"

ln -sf "$SCRIPT_DIR/.env" "$INSTALL_DIR/tools/moodle-migration/.env"
ln -sf "$SCRIPT_DIR/.env" "$INSTALL_DIR/tools/moodle-status/.env"

print_cmsg "Apache-Ports und Moodle-Konfiguration werden angepasst..." | tee -a "$LOG_FILE"
sed -i 's/^\s*Listen\s\+80$/Listen 8080/' /etc/apache2/ports.conf

site_conf="/etc/apache2/sites-available/000-default.conf"
cp "$site_conf" "${site_conf}.bak"
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:8080>/g" "$site_conf"

moodle_cfg="/var/www/html/config.php"
cp "$moodle_cfg" "${moodle_cfg}.bak"
sed -i "s|\\$CFG->wwwroot\s*=.*|\\$CFG->wwwroot = 'http://localhost:8080';|g" "$moodle_cfg"

f="/var/www/html/theme/boost/templates/columns2.mustache"
cp "$f" "$f.bak"
awk '/{{> theme_boost\/navbar }}/ {print; print "<div style=\"background-color: #f8d7da; color: #721c24; text-align: center; padding: 20px; font-weight: bold; font-size: 24px;\"><br>Diese Moodle-Seite ist <strong>veraltet</strong> und wird <strong>nicht mehr gewartet</strong>. Bitte verwende stattdessen <a href=\"http://localhost:80\" style=\"color: #721c24; font-weight: bold; text-decoration: none;\">http://localhost:80</a></div>"; next}1' "$f.bak" > "$f"

systemctl reload apache2

mkdir -p "$MIGRATION_DUMP_DIR"
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD_OLD" "moodle" > "${MIGRATION_DUMP_DIR}/${MOODLE_VERSION}-${TIMESTAMP}.sql"

cd "$INSTALL_DIR/tools/moodle-migration"

docker build -t moodle-custom:latest -t moodle-custom:401 --no-cache -f Dockerfile .
docker compose up -d
print_cmsg "Moodle wird auf Version 401 aktualisiert. Bitte warten..." | tee -a "$LOG_FILE"
sleep 10
docker exec -u www-data moodle-migration php /var/www/html/admin/cli/upgrade.php --non-interactive
docker compose down

sed -i 's/--branch MOODLE_401_STABLE/--branch MOODLE_402_STABLE/' Dockerfile
sed -i 's|^FROM moodlehq/moodle-php-apache:7\.4|FROM moodlehq/moodle-php-apache:8.2|' Dockerfile
docker build -t moodle-custom:latest -t moodle-custom:402 --no-cache -f Dockerfile .
docker compose up -d
print_cmsg "Moodle wird auf Version 402 aktualisiert. Bitte warten..." | tee -a "$LOG_FILE"
sleep 10
docker exec -u www-data moodle-migration php /var/www/html/admin/cli/upgrade.php --non-interactive
docker compose down

sed -i 's/--branch MOODLE_402_STABLE/--branch MOODLE_500_STABLE/' Dockerfile
sed -i 's|image: mariadb:10\.6|image: mariadb:10.11|' docker-compose.yml
docker build -t moodle-custom:latest -t moodle-custom:500 --no-cache -f Dockerfile .
docker compose up -d
print_cmsg "Moodle wird auf Version 500 aktualisiert. Bitte warten..." | tee -a "$LOG_FILE"
sleep 10
docker exec -u www-data moodle-migration php /var/www/html/admin/cli/upgrade.php --non-interactive
docker image prune -a -f
docker compose down

if ! grep -q "moodle-up()" "$SHELL_RC"; then
    {
        echo ""
        echo "moodle-up() { (cd \"$INSTALL_DIR\" && docker compose up -d && docker compose ps && firefox http://localhost); }"
        echo "moodle-down() { (cd \"$INSTALL_DIR\" && docker compose down); }"
        echo "moodle-status() { (cd \"$INSTALL_DIR\" && sudo ./tools/moodle-status/moodle-status.sh \"\$@\"); }"
    } >> "$SHELL_RC"
    print_cmsg "Funktionen 'moodle-up', 'moodle-down' und 'moodle-status' wurden zu $SHELL_RC hinzugefuegt." | tee -a "$LOG_FILE"
else
    print_cmsg "Funktionen existieren bereits in $SHELL_RC - ueberspringe Hinzufuegen." | tee -a "$LOG_FILE"
fi

print_cmsg "Fuehre 'source ~/.bashrc' aus oder starte dein Terminal neu, um die neuen Funktionen zu aktivieren." | tee -a "$LOG_FILE"

gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 << EOF | tee -a "$LOG_FILE"
-----------------------------------------------------------------------------------------
                           Moodle-Docker-Installation abgeschlossen!
-----------------------------------------------------------------------------------------

 Moodle starten:
   cd /opt/moodle-docker && docker compose up -d
   Status: docker compose ps
   Zugriff: http://localhost:80

 Moodle stoppen:
   docker compose down

 Funktionen:
   moodle-up     -> Startet Moodle und oeffnet die Webseite
   moodle-down   -> Stoppt die Container
   moodle-status -> Zeigt die Moodle-Statusseite an


 Altes System: http://localhost:8080

 Logdatei: $LOG_FILE
EOF

exit