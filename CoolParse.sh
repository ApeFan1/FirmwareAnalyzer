#!/bin/bash
echo "==============="
echo "firmware parser"
echo "==============="
echo "First we need to see if you have binwalk installed as it is essential for this script."
# Check for binwalk installation
if ! command -v binwalk &> /dev/null
then
    echo -e "${YELLOW}Binwalk not found.${NC}"
    echo -e "${BLUE}Installing binwalk...${NC}"

    if command -v apt &> /dev/null
    then
        sudo apt update
        sudo apt install -y binwalk

    elif command -v dnf &> /dev/null
    then
        sudo dnf install -y binwalk

    elif command -v pacman &> /dev/null
    then
        sudo pacman -S --noconfirm binwalk

    else
        echo -e "${RED}Could not determine package manager.${NC}"
        echo "Please install binwalk manually."
        exit 1
    fi

else
    echo -e "${GREEN}Binwalk detected.${NC}"
fi
sleep 2
echo "                          "
echo "Please note stuff like ~ will not work and you must use /home/User. Also this will only work on your user and not on root."
sleep 4
read -p "Enter firmware directory: " DIR
cd "$DIR" || exit 1
binwalk -e *.bin
echo "                                            "
echo "============================================"
echo "Extracted Files"
echo "==================================================================================================================================================="
echo "Note if a file has failed it will not have a .extracted file named the same as the file extracted. If it did fail you coulld try [strings -n16 -tx]"
echo "==================================================================================================================================================="
OUTPUT_DIR="$DIR/Extracted_Firmware"

if [ -d "$OUTPUT_DIR" ]; then
    echo "Using existing directory: $OUTPUT_DIR"
else
    mkdir "$OUTPUT_DIR"
    echo "Created directory: $OUTPUT_DIR"
fi

mv _*.extracted Extracted_Firmware/
echo "                                                 "
echo "                                                 "
ls "$DIR"/Extracted_Firmware

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Searching for password files...${NC}"
echo -e "${BLUE}=========================================${NC}"

REPORT="$OUTPUT_DIR/password_report.txt"

echo "Password File Report" > "$REPORT"
echo "Generated: $(date)" >> "$REPORT"
echo "========================================" >> "$REPORT"

FOUND=0

find "$OUTPUT_DIR" -type f \( \
    -name "passwd" -o \
    -name "shadow" -o \
    -name "gshadow" -o \
    -name "master.passwd" \
\) | while read -r file
do
    FOUND=1

    echo -e "${GREEN}Found:${NC} $file"

    {
        echo
        echo "========================================"
        echo "File: $file"
        echo "========================================"
        cat "$file"
    } >> "$REPORT"
done

if [ -s "$REPORT" ]; then
    echo
    echo -e "${GREEN}Password report saved to:${NC}"
    echo "$REPORT"
else
    echo -e "${YELLOW}No password files were found.${NC}"
    rm -f "$REPORT"
fi

############################################################
# Firmware Reconnaissance Module
############################################################

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Firmware Reconnaissance Module${NC}"
echo -e "${BLUE}=========================================${NC}"

read -p "Run firmware reconnaissance? (Y/N): " RUN_RECON

if [[ ! "$RUN_RECON" =~ ^[Yy]$ ]]; then
    echo "Skipping reconnaissance."
else

RECON_REPORT="$OUTPUT_DIR/firmware_recon_report.txt"

echo "Firmware Reconnaissance Report" > "$RECON_REPORT"
echo "Generated: $(date)" >> "$RECON_REPORT"
echo "======================================================" >> "$RECON_REPORT"
echo >> "$RECON_REPORT"

echo "Beginning reconnaissance..."

############################################################
# Counters
############################################################

SHELL_COUNT=0
CONFIG_COUNT=0
CERT_COUNT=0
PRIVATE_KEY_COUNT=0
SSH_KEY_COUNT=0
SSL_CERT_COUNT=0
IP_COUNT=0
PORT_COUNT=0
HOSTNAME_COUNT=0
DOMAIN_COUNT=0
URL_COUNT=0
EMAIL_COUNT=0
API_COUNT=0
DNS_COUNT=0
NTP_COUNT=0
SSID_COUNT=0
MAC_COUNT=0

############################################################
# Temporary files for duplicate removal
############################################################

TMPDIR=$(mktemp -d)

touch "$TMPDIR/shells"
touch "$TMPDIR/configs"
touch "$TMPDIR/certs"
touch "$TMPDIR/privatekeys"
touch "$TMPDIR/sshkeys"
touch "$TMPDIR/sslcerts"
touch "$TMPDIR/ip"
touch "$TMPDIR/ports"
touch "$TMPDIR/hostnames"
touch "$TMPDIR/domains"
touch "$TMPDIR/urls"
touch "$TMPDIR/emails"
touch "$TMPDIR/apis"
touch "$TMPDIR/dns"
touch "$TMPDIR/ntp"
touch "$TMPDIR/ssid"
touch "$TMPDIR/mac"

############################################################
# Helper Function
############################################################

record_item() {

    CATEGORY="$1"
    VALUE="$2"
    FILE="$3"
    STORE="$4"

    if [ -z "$VALUE" ]; then
        return
    fi

    if ! grep -Fxq "$VALUE" "$STORE"; then

        echo "$VALUE" >> "$STORE"

        {
            echo "[$CATEGORY]"
            echo "Value : $VALUE"
            echo "File  : $FILE"
            echo
        } >> "$RECON_REPORT"

        case "$CATEGORY" in
            "Shell Script") ((SHELL_COUNT++));;
            "Configuration") ((CONFIG_COUNT++));;
            "Certificate") ((CERT_COUNT++));;
            "Private Key") ((PRIVATE_KEY_COUNT++));;
            "SSH Host Key") ((SSH_KEY_COUNT++));;
            "SSL Certificate") ((SSL_CERT_COUNT++));;
            "IP Address") ((IP_COUNT++));;
            "Port") ((PORT_COUNT++));;
            "Hostname") ((HOSTNAME_COUNT++));;
            "Domain") ((DOMAIN_COUNT++));;
            "URL") ((URL_COUNT++));;
            "Email") ((EMAIL_COUNT++));;
            "API Key") ((API_COUNT++));;
            "DNS Server") ((DNS_COUNT++));;
            "NTP Server") ((NTP_COUNT++));;
            "WiFi SSID") ((SSID_COUNT++));;
            "MAC Address") ((MAC_COUNT++));;
        esac

    fi

}

############################################################
# Scan Every Extracted Directory
############################################################

for EXTRACTED in "$OUTPUT_DIR"/*
do

    [ -d "$EXTRACTED" ] || continue

    echo
    echo "Scanning: $(basename "$EXTRACTED")"

    find "$EXTRACTED" -type f | while read -r FILE
    do

        MIME=$(file -b "$FILE")

        case "$MIME" in
            *image*|*archive*|*compressed*|*data*)
                continue
                ;;
        esac

   ####################################################
# Shell Scripts
####################################################

if [[ "$FILE" == *.sh ]]; then
    record_item "Shell Script" "$FILE" "$FILE" "$TMPDIR/shells"
fi

####################################################
# Configuration Files
####################################################

if [[ "$FILE" == *.conf || "$FILE" == *.cfg || "$FILE" == *.ini ]]; then
    record_item "Configuration" "$FILE" "$FILE" "$TMPDIR/configs"
fi

####################################################
# Certificates / Keys
####################################################

if [[ "$FILE" == *.pem || "$FILE" == *.crt || "$FILE" == *.cer ]]; then
    record_item "Certificate" "$FILE" "$FILE" "$TMPDIR/certs"
fi

if [[ "$FILE" == *.key ]]; then
    record_item "Private Key" "$FILE" "$FILE" "$TMPDIR/privatekeys"
fi

####################################################
# SSH Host Keys
####################################################

grep -q "BEGIN OPENSSH PRIVATE KEY" "$FILE" 2>/dev/null &&
record_item "SSH Host Key" "$FILE" "$FILE" "$TMPDIR/sshkeys"

####################################################
# SSL Certificates
####################################################

grep -q "BEGIN CERTIFICATE" "$FILE" 2>/dev/null &&
record_item "SSL Certificate" "$FILE" "$FILE" "$TMPDIR/sslcerts"

####################################################
# IP Addresses
####################################################

grep -Eo '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$FILE" 2>/dev/null |
sort -u |
while read -r IP
do
    record_item "IP Address" "$IP" "$FILE" "$TMPDIR/ip"
done

####################################################
# MAC Addresses
####################################################

grep -Eio '([0-9A-F]{2}:){5}[0-9A-F]{2}' "$FILE" 2>/dev/null |
sort -u |
while read -r MAC
do
    record_item "MAC Address" "$MAC" "$FILE" "$TMPDIR/mac"
done

####################################################
# URLs
####################################################

grep -Eo 'https?://[^"[:space:]]+' "$FILE" 2>/dev/null |
sort -u |
while read -r URL
do
    record_item "URL" "$URL" "$FILE" "$TMPDIR/urls"
done

####################################################
# Domain Names
####################################################

grep -Eo '([A-Za-z0-9-]+\.)+[A-Za-z]{2,}' "$FILE" 2>/dev/null |
sort -u |
while read -r DOMAIN
do
    record_item "Domain" "$DOMAIN" "$FILE" "$TMPDIR/domains"
done

####################################################
# Email Addresses
####################################################

grep -Eio '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$FILE" 2>/dev/null |
sort -u |
while read -r EMAIL
do
    record_item "Email" "$EMAIL" "$FILE" "$TMPDIR/emails"
done

####################################################
# Ports
####################################################

grep -Eio '(port|listen)[[:space:]]*[=:]?[[:space:]]*[0-9]{1,5}' "$FILE" 2>/dev/null |
grep -Eo '[0-9]{1,5}' |
awk '$1>0 && $1<=65535' |
sort -nu |
while read -r PORT
do
    record_item "Port" "$PORT" "$FILE" "$TMPDIR/ports"
done

####################################################
# Hostnames
####################################################

grep -Eio 'hostname[[:space:]]*[=:][[:space:]]*[A-Za-z0-9._-]+' "$FILE" 2>/dev/null |
awk -F= '{print $2}' |
sed 's/^ *//;s/ *$//' |
sort -u |
while read -r HOST
do
    record_item "Hostname" "$HOST" "$FILE" "$TMPDIR/hostnames"
done

####################################################
# DNS Servers
####################################################

grep -Eio '(nameserver|dns)[[:space:]]*[=:]?[[:space:]]*([0-9]{1,3}\.){3}[0-9]{1,3}' "$FILE" 2>/dev/null |
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' |
sort -u |
while read -r DNS
do
    record_item "DNS Server" "$DNS" "$FILE" "$TMPDIR/dns"
done

####################################################
# NTP Servers
####################################################

grep -Eio '(ntp|server)[[:space:]]*[=:][[:space:]]*[A-Za-z0-9._-]+' "$FILE" 2>/dev/null |
awk -F= '{print $2}' |
sed 's/^ *//;s/ *$//' |
sort -u |
while read -r NTP
do
    record_item "NTP Server" "$NTP" "$FILE" "$TMPDIR/ntp"
done

####################################################
# Wi-Fi SSIDs
####################################################

grep -Eio 'ssid[[:space:]]*[=:][[:space:]]*.*' "$FILE" 2>/dev/null |
sed -E 's/.*ssid[[:space:]]*[=:][[:space:]]*//' |
sort -u |
while read -r SSID
do
    record_item "WiFi SSID" "$SSID" "$FILE" "$TMPDIR/ssid"
done

####################################################
# API Keys / Tokens
####################################################

grep -Eio '(api[_-]?key|apikey|token|access[_-]?token|bearer)[[:space:]]*[=:][[:space:]]*[^[:space:]"]+' "$FILE" 2>/dev/null |
while read -r API
do
    record_item "API Key" "$API" "$FILE" "$TMPDIR/apis"
done
####################################################
# End File Scan
####################################################

    done

done

####################################################
# Build Summary
####################################################

SUMMARY=$(mktemp)

{
echo "======================================================"
echo "Firmware Reconnaissance Summary"
echo "======================================================"
echo
printf "%-25s %s\n" "Shell Scripts:" "$SHELL_COUNT"
printf "%-25s %s\n" "Configuration Files:" "$CONFIG_COUNT"
printf "%-25s %s\n" "Certificates:" "$CERT_COUNT"
printf "%-25s %s\n" "Private Keys:" "$PRIVATE_KEY_COUNT"
printf "%-25s %s\n" "SSH Host Keys:" "$SSH_KEY_COUNT"
printf "%-25s %s\n" "SSL Certificates:" "$SSL_CERT_COUNT"
printf "%-25s %s\n" "IP Addresses:" "$IP_COUNT"
printf "%-25s %s\n" "MAC Addresses:" "$MAC_COUNT"
printf "%-25s %s\n" "Ports:" "$PORT_COUNT"
printf "%-25s %s\n" "Hostnames:" "$HOSTNAME_COUNT"
printf "%-25s %s\n" "Domain Names:" "$DOMAIN_COUNT"
printf "%-25s %s\n" "URLs:" "$URL_COUNT"
printf "%-25s %s\n" "Email Addresses:" "$EMAIL_COUNT"
printf "%-25s %s\n" "API Keys / Tokens:" "$API_COUNT"
printf "%-25s %s\n" "DNS Servers:" "$DNS_COUNT"
printf "%-25s %s\n" "NTP Servers:" "$NTP_COUNT"
printf "%-25s %s\n" "Wi-Fi SSIDs:" "$SSID_COUNT"
echo
echo "======================================================"
echo
} > "$SUMMARY"

cat "$RECON_REPORT" >> "${SUMMARY}.tmp"
cat "$SUMMARY" "${SUMMARY}.tmp" > "$RECON_REPORT"

rm -f "${SUMMARY}.tmp"
rm -f "$SUMMARY"

####################################################
# Cleanup
####################################################

rm -rf "$TMPDIR"

####################################################
# Finished
####################################################

echo
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Firmware Reconnaissance Complete${NC}"
echo -e "${GREEN}=========================================${NC}"
echo
echo "Report saved to:"
echo "$RECON_REPORT"

fi
