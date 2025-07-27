#!/bin/bash
# ==============================================
# Script Bash - analyse_rsync.sh
# ==============================================
# Date        : 01 juillet 2025
# Auteur      : LACHERY Simon
# Version     : 1.0
# Description : Analyse un fichier log de transfert (rsync, etc.) pour extraire
#               la durée, le volume transféré, le débit moyen, et les statistiques
#               sur les fichiers.
# ==============================================

# --- Variables globales ---

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

OK=$'[ \e[32mOK\e[0m ] -'
NOTE=$'\n[ \e[36mNOTE\e[0m ] -'
INFO=$'[ \e[37mINFO\e[0m ] -'
WARNING=$'[ \e[33mATTENTION\e[0m ] -'
ERROR=$'[ \e[31mERREUR\e[0m ] -'

SCRIPT_NAME=$(basename "$0")
WORKDIR="$(pwd)"
HOMEDIR="$HOME"
DATE_TAG="$(date +%F_%H-%M-%S)"
TMPDIR="/tmp/${SCRIPT_NAME%.sh}"
mkdir -p "$TMPDIR" 2>/dev/null

LOGFILE="/var/log/${SCRIPT_NAME}.log"
OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)

# --- Initialisation du fichier log ---

touch "$LOGFILE" || { echo -e "$ERROR Impossible de créer le fichier log : $LOGFILE" ; exit 1; }
exec > >(tee -a "$LOGFILE") 2>&1

echo "$NOTE Début d'exécution du script : $SCRIPT_NAME"
echo "$INFO Environnement : $OS ($CODENAME)"
echo "$INFO Date : $(date)"
echo "$INFO Fichier log : $LOGFILE"

# --- Vérification des droits ---

if [ "$(id -u)" -ne 0 ]; then
    echo -e "$ERROR Ce script doit être exécuté en tant que root."
    exit 1
fi

# --- Vérification des arguments ---

if [ $# -ne 1 ]; then
    echo -e "$ERROR Usage : $0 /chemin/vers/fichier.log"
    exit 1
fi

LOG_INPUT="$1"
if [ ! -f "$LOG_INPUT" ]; then
    echo -e "$ERROR Fichier introuvable : $LOG_INPUT"
    exit 2
fi

# --- Fonctions utilitaires ---

convert_bytes_adaptative() {
    local bytes=$1
    if (( bytes >= 1073741824 )); then
        awk "BEGIN {printf \"%.2f Go\", $bytes / 1073741824}" | sed 's/\./,/'
    else
        awk "BEGIN {printf \"%.2f Mo\", $bytes / 1048576}" | sed 's/\./,/'
    fi
}

convert_bps_to_mbps() {
    local bps=$1
    awk "BEGIN {printf \"%.2f Mb/s\", ($bps * 8) / 1048576}" | sed 's/\./,/'
}

format_number() {
    echo "$1" | sed ':a;s/\B[0-9]\{3\}\>/ &/;ta'
}

convert_time_seconds_to_hms() {
    local seconds=$1
    printf '%02d:%02d:%02d' $((seconds/3600)) $(((seconds%3600)/60)) $((seconds%60))
}

get_clean_bytes() {
    grep "$1" "$LOG_INPUT" | tail -1 | awk -F': ' '{print $2}' | tr -cd '0-9'
}

# --- Traitement principal ---

START_TS=$(head -n 1 "$LOG_INPUT" | cut -d' ' -f1,2)
END_TS=$(tail -n 1 "$LOG_INPUT" | cut -d' ' -f1,2)
START_EPOCH=$(date -d "$START_TS" +%s)
END_EPOCH=$(date -d "$END_TS" +%s)
DURATION_SEC=$((END_EPOCH - START_EPOCH))

BYTES_TRANSFERRED=$(get_clean_bytes "Total transferred file size")
BYTES_TOTAL=$(get_clean_bytes "Total file size")
FILES_TRANSFERRED=$(grep "Number of regular files transferred" "$LOG_INPUT" | awk -F': ' '{print $2}' | tr -d ' .')
TOTAL_FILES=$(grep "Number of files" "$LOG_INPUT" | awk -F': ' '{print $2}' | cut -d' ' -f1 | tr -d '.')

if (( DURATION_SEC > 0 )); then
    SPEED_BPS=$((BYTES_TRANSFERRED / DURATION_SEC))
else
    SPEED_BPS=0
fi

# Formatage
val_time=$(convert_time_seconds_to_hms "$DURATION_SEC")
val_transferred=$(convert_bytes_adaptative "$BYTES_TRANSFERRED")
val_total=$(convert_bytes_adaptative "$BYTES_TOTAL")
val_speed=$(convert_bps_to_mbps "$SPEED_BPS")
val_total_files=$(format_number "$TOTAL_FILES")
val_files_transferred=$(format_number "$FILES_TRANSFERRED")

# Affichage
echo ""
echo "Analyse du log : $LOG_INPUT"
echo "=============================================="
echo -e "Durée d'exécution          : \t$val_time"
echo -e "Données transférées        : \t$val_transferred"
echo -e "Taille totale              : \t$val_total"
echo -e "Débit moyen                : \t$val_speed"
echo -e "Nombre total de fichiers   : \t$val_total_files"
echo -e "Fichiers transférés        : \t$val_files_transferred"
echo "=============================================="
echo ""

# --- Fin d'execution du script ---
exit 0
