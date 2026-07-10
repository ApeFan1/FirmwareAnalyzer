#!/bin/bash

echo "================================="
echo "Firmware Recon Report Parser"
echo "================================="

read -p "Enter recon report path: " REPORT

if [ ! -f "$REPORT" ]; then
    echo "Report not found."
    exit 1
fi

REPORT_DIR="$(dirname "$REPORT")/AggregatedReports"

if [ ! -d "$REPORT_DIR" ]; then
    mkdir -p "$REPORT_DIR"
fi

OUTPUT="$REPORT_DIR/filtered_recon_report.txt"

echo
echo "Select categories to include:"
echo
echo "1) IP Addresses"
echo "2) Configuration Files"
echo "3) URLs"
echo "4) Domains"
echo "5) Certificates"
echo "6) Private Keys"
echo "7) SSH Keys"
echo "8) Emails"
echo "9) API Keys"
echo "10) All"
echo


read -p "Enter choices separated by spaces: " CHOICES


> "$OUTPUT"

echo "Firmware Recon Filtered Report" >> "$OUTPUT"
echo "Generated: $(date)" >> "$OUTPUT"
echo "====================================" >> "$OUTPUT"


TMP=$(mktemp)


grep -E "^\[|^Value|^File" "$REPORT" > "$TMP"


CURRENT=""

while read -r LINE
do

    if [[ "$LINE" =~ ^\[.*\]$ ]]; then
        CURRENT="${LINE}"
    fi


    if [[ "$LINE" == Value* ]]; then

        VALUE="${LINE#Value : }"

    fi


    if [[ "$LINE" == File* ]]; then

        FILE="${LINE#File  : }"

        FILE=$(echo "$FILE" | sed 's#.*\/Firmwares#/Firmwares#')


        INCLUDE=0


        for CHOICE in $CHOICES
        do

            case "$CHOICE" in

                1)
                    [[ "$CURRENT" == "[IP Address]" ]] && INCLUDE=1
                    ;;

                2)
                    [[ "$CURRENT" == "[Configuration]" ]] && INCLUDE=1
                    ;;

                3)
                    [[ "$CURRENT" == "[URL]" ]] && INCLUDE=1
                    ;;

                4)
                    [[ "$CURRENT" == "[Domain]" ]] && INCLUDE=1
                    ;;

                5)
                    [[ "$CURRENT" == "[Certificate]" ]] && INCLUDE=1
                    ;;

                6)
                    [[ "$CURRENT" == "[Private Key]" ]] && INCLUDE=1
                    ;;

                7)
                    [[ "$CURRENT" == "[SSH Host Key]" ]] && INCLUDE=1
                    ;;

                8)
                    [[ "$CURRENT" == "[Email]" ]] && INCLUDE=1
                    ;;

                9)
                    [[ "$CURRENT" == "[API Key]" ]] && INCLUDE=1
                    ;;

                10)
                    INCLUDE=1
                    ;;

            esac

        done


        if [ "$INCLUDE" -eq 1 ]; then

            {

            echo
            echo "================================="
            echo "Origin File:"
            echo "$FILE"
            echo "---------------------------------"
            echo "$CURRENT"
            echo "Value:"
            echo "$VALUE"

            } >> "$OUTPUT"

        fi

    fi


done < "$TMP"


rm "$TMP"


echo
echo "Report created:"
echo "$OUTPUT"
