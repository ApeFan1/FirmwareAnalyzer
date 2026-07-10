#!/bin/bash
echo "==============="
echo "firmware parser"
echo "==============="
echo "First we need to see if you have binwalk installed as it is essential for this script."
# Check for required tools
REQUIRED_TOOLS=("binwalk" "john" "curl" "jq" "strings")

for TOOL in "${REQUIRED_TOOLS[@]}"
do
    if ! command -v "$TOOL" &> /dev/null
    then
        echo -e "${YELLOW}$TOOL not found.${NC}"
        echo -e "${BLUE}Installing $TOOL...${NC}"

        if command -v apt &> /dev/null
        then
            case "$TOOL" in
                strings)
                    sudo apt update
                    sudo apt install -y binutils
                    ;;
                john)
                    sudo apt update
                    sudo apt install -y john
                    ;;
                *)
                    sudo apt update
                    sudo apt install -y "$TOOL"
                    ;;
            esac

        elif command -v dnf &> /dev/null
        then
            case "$TOOL" in
                strings)
                    sudo dnf install -y binutils
                    ;;
                john)
                    sudo dnf install -y john
                    ;;
                *)
                    sudo dnf install -y "$TOOL"
                    ;;
            esac

        elif command -v pacman &> /dev/null
        then
            case "$TOOL" in
                strings)
                    sudo pacman -S --noconfirm binutils
                    ;;
                john)
                    sudo pacman -S --noconfirm john
                    ;;
                *)
                    sudo pacman -S --noconfirm "$TOOL"
                    ;;
            esac

        else
            echo -e "${RED}Could not determine package manager.${NC}"
            echo "Please install $TOOL manually."
            exit 1
        fi

        # Verify installation
        if ! command -v "$TOOL" &> /dev/null
        then
            echo -e "${RED}Failed to install $TOOL.${NC}"
            exit 1
        fi

    else
        echo -e "${GREEN}$TOOL detected.${NC}"
    fi
done
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

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Starting Password Audit${NC}"
echo -e "${BLUE}=========================================${NC}"

read -p "Enter password list path (press Enter for rockyou.txt): " WORDLIST

if [ -z "$WORDLIST" ]; then
    WORDLIST="/usr/share/wordlists/rockyou.txt"
    echo -e "${YELLOW}Using default wordlist: $WORDLIST${NC}"
fi

if [ ! -f "$WORDLIST" ]; then
    echo -e "${RED}Wordlist not found: $WORDLIST${NC}"
    exit 1
fi


CRACK_REPORT="$OUTPUT_DIR/password_audit_report.txt"

echo "Password Audit Report" > "$CRACK_REPORT"
echo "Generated: $(date)" >> "$CRACK_REPORT"
echo "========================================" >> "$CRACK_REPORT"


find "$OUTPUT_DIR" -type f \( \
    -name "shadow" -o \
    -name "passwd" \
\) | while read -r HASHFILE
do

    echo -e "${BLUE}Testing:${NC} $HASHFILE"

    TEMP_HASH=$(mktemp)

    cat "$HASHFILE" > "$TEMP_HASH"


    {
        echo
        echo "========================================"
        echo "File Tested:"
        echo "$HASHFILE"
        echo "========================================"
        echo
        echo "Hashes Tested:"
        cat "$HASHFILE"
        echo
    } >> "$CRACK_REPORT"


    john --wordlist="$WORDLIST" "$TEMP_HASH" >/dev/null 2>&1

    RESULTS=$(john --show "$TEMP_HASH" 2>/dev/null)


    if echo "$RESULTS" | grep -q ":"; then

        echo -e "${GREEN}Password found for $HASHFILE${NC}"

        {
            echo "STATUS: PASSWORD FOUND"
            echo
            echo "Recovered Credentials:"
            echo "$RESULTS"
        } >> "$CRACK_REPORT"

    else

        echo -e "${YELLOW}No password found for $HASHFILE${NC}"

        {
            echo "STATUS: FAILED"
            echo "No password recovered using supplied wordlist."
        } >> "$CRACK_REPORT"

    fi


    rm "$TEMP_HASH"

done


echo
echo -e "${GREEN}Password audit complete.${NC}"
echo -e "${GREEN}Report saved to:${NC} $CRACK_REPORT"

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Searching Extracted Firmware Files${NC}"
echo -e "${BLUE}=========================================${NC}"

FILE_REPORT="$OUTPUT_DIR/file_discovery_report.txt"

echo "Firmware Interesting File Report" > "$FILE_REPORT"
echo "Generated: $(date)" >> "$FILE_REPORT"


for EXTRACTED in "$OUTPUT_DIR"/* 
do

    if [ -d "$EXTRACTED" ]; then

        echo -e "${CYAN}Scanning:${NC} $EXTRACTED"

        {
            echo
            echo "##################################################"
            echo "Extracted Folder:"
            echo "$(basename "$EXTRACTED")"
            echo "##################################################"
        } >> "$FILE_REPORT"


        # Shell Scripts
        {
            echo
            echo "------------------------------"
            echo "Shell Scripts (.sh)"
            echo "------------------------------"
        } >> "$FILE_REPORT"

        find "$EXTRACTED" -type f -name "*.sh" | while read -r file
        do
            {
                echo
                echo "File: $(basename "$file")"
                echo "Path: $(realpath "$file")"
            } >> "$FILE_REPORT"
        done


        # Configuration Files
        {
            echo
            echo "------------------------------"
            echo "Configuration Files"
            echo "------------------------------"
        } >> "$FILE_REPORT"

        find "$EXTRACTED" -type f \( \
            -name "*.conf" -o \
            -name "*.cfg" -o \
            -name "*.ini" \
        \) | while read -r file
        do
            {
                echo
                echo "File: $(basename "$file")"
                echo "Path: $(realpath "$file")"
            } >> "$FILE_REPORT"
        done


        # Certificates / Keys
        {
            echo
            echo "------------------------------"
            echo "Certificates and Keys"
            echo "------------------------------"
        } >> "$FILE_REPORT"

        find "$EXTRACTED" -type f \( \
            -name "*.pem" -o \
            -name "*.key" \
        \) | while read -r file
        do
            {
                echo
                echo "File: $(basename "$file")"
                echo "Path: $(realpath "$file")"
            } >> "$FILE_REPORT"
        done

    fi

done


echo
echo -e "${GREEN}Interesting file scan complete.${NC}"
echo -e "${GREEN}Report saved to:${NC} $FILE_REPORT"

echo
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}BusyBox CVE Lookup${NC}"
echo -e "${BLUE}=========================================${NC}"

BUSYBOX_CVE_REPORT="$OUTPUT_DIR/busybox_cve_report.txt"

echo "BusyBox CVE Report" > "$BUSYBOX_CVE_REPORT"
echo "Generated: $(date)" >> "$BUSYBOX_CVE_REPORT"
echo "========================================" >> "$BUSYBOX_CVE_REPORT"

# Find BusyBox binary
BUSYBOX=$(find "$OUTPUT_DIR" -type f -name "busybox" | head -n1)

if [ -z "$BUSYBOX" ]; then
    echo -e "${YELLOW}BusyBox not found. Skipping CVE lookup.${NC}"
    echo "BusyBox not found." >> "$BUSYBOX_CVE_REPORT"
else

    echo -e "${GREEN}BusyBox found:${NC} $BUSYBOX"

    VERSION=$(strings "$BUSYBOX" | grep -oE "BusyBox v[0-9]+\.[0-9]+(\.[0-9]+)?" | head -n1)

    if [ -z "$VERSION" ]; then
        echo -e "${YELLOW}Unable to determine BusyBox version.${NC}"
        echo "Version not detected." >> "$BUSYBOX_CVE_REPORT"
    else

        VERSION_NUMBER=$(echo "$VERSION" | grep -oE "[0-9]+\.[0-9]+(\.[0-9]+)?")

        echo -e "${GREEN}Detected:${NC} $VERSION"

        {
            echo
            echo "BusyBox Binary:"
            echo "$BUSYBOX"
            echo
            echo "Version:"
            echo "$VERSION"
            echo
            echo "Searching NVD..."
            echo
        } >> "$BUSYBOX_CVE_REPORT"

        RESPONSE=$(curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=BusyBox%20$VERSION_NUMBER")

        COUNT=$(echo "$RESPONSE" | jq '.totalResults')

        if [ "$COUNT" -eq 0 ]; then

            echo -e "${YELLOW}No CVEs found.${NC}"
            echo "No CVEs found." >> "$BUSYBOX_CVE_REPORT"

        else

            echo -e "${GREEN}$COUNT CVEs Found${NC}"

            echo "$RESPONSE" | jq -r '
                .vulnerabilities[] |
                "========================================",
                .cve.id,
                "Description:",
                .cve.descriptions[0].value,
                "Severity: " + (
                    if .cve.metrics.cvssMetricV31 then
                        .cve.metrics.cvssMetricV31[0].cvssData.baseSeverity
                    elif .cve.metrics.cvssMetricV30 then
                        .cve.metrics.cvssMetricV30[0].cvssData.baseSeverity
                    elif .cve.metrics.cvssMetricV2 then
                        .cve.metrics.cvssMetricV2[0].baseSeverity
                    else
                        "Unknown"
                    end
                ),
                "CVSS: " + (
                    if .cve.metrics.cvssMetricV31 then
                        (.cve.metrics.cvssMetricV31[0].cvssData.baseScore|tostring)
                    elif .cve.metrics.cvssMetricV30 then
                        (.cve.metrics.cvssMetricV30[0].cvssData.baseScore|tostring)
                    elif .cve.metrics.cvssMetricV2 then
                        (.cve.metrics.cvssMetricV2[0].cvssData.baseScore|tostring)
                    else
                        "Unknown"
                    end
                ),
                ""
            ' >> "$BUSYBOX_CVE_REPORT"

            echo -e "${GREEN}Results saved to:${NC} $BUSYBOX_CVE_REPORT"

        fi

    fi

fi
