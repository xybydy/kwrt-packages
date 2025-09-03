#!/bin/bash

find . -path "*/root/usr/share/ucitrack/*.json" -type f | while read -r json_file; do
  # Use sed to check and replace the format, matching any string that does not contain commas
    if grep -q '"init": \[.*\]' "$json_file"; then
       # Use perl regular expression to process, because its regular expression function is more powerful
        perl -i -pe 's/"init":\s*\[\s*"([^,"\n]+)"\s*\]/"init": "$1"/g' "$json_file"
        echo "Processed json file: $json_file"
    fi
done

find . -type f \
    -not -path "*.github*" \
    -not -name "Makefile" \
    | while read -r file; do
    
    if grep -q "add ucitrack" "$file"; then
        # Extract the value of xx
        xx=$(grep "add ucitrack" "$file" | awk '{print $3}' | head -1 | tr -d '\r' | tr -d ' ')
        
        # Read the first line
        first_line=$(head -n 1 "$file")
        
        # Build new file content
        {
            # Check if the first line contains #!/bin/
            if [[ "$first_line" == "#!/bin/"* ]]; then
                echo "$first_line"
            fi
            echo "[ ! -f \"/usr/share/ucitrack/luci-app-${xx}.json\" ] && {"
            echo "    cat > /usr/share/ucitrack/luci-app-${xx}.json << EEOF"
            echo "{"
            echo "    \"config\": \"${xx}\","
            echo "    \"init\": \"${xx}\""
            echo "}"
            echo "EEOF"
            echo "}"
             # If the first line does not contain #!/bin/, output it here
            if [[ "$first_line" != "#!/bin/"* && -n "$first_line" ]]; then
                echo "$first_line"
            fi
            # Get the rest
            sed '1d' "$file"
        } > "${file}.tmp"
        
        # Replace the original file
        mv "${file}.tmp" "$file"
        
        echo "Processed files: $file (ucitrack)"
        
    else
        # Check if you need to add reload_service
    if (grep -q "stop_service\|service_stopped" "$file") && ! grep -q "reload_service" "$file"; then
        echo >> "$file"
        echo "reload_service() {" >> "$file"
        echo -e "\trestart" >> "$file"
        echo "}" >> "$file"
        
        echo "Added reload_service to the file: $file"
    fi

if awk '/^USE_PROCD/{a=1} /start_service/{b=1} /config_load/{c=1} /service_triggers/{d=1} END{exit !(a&&b&&c&&!d)}' "$file"; then
        needs_service_triggers=1
        config=$(grep -m 1 "config_load" "$file" | sed 's/.*config_load[[:space:]]\+["'\'']\?\([^"'\''[:space:]]*\)["'\'']\?.*$/\1/')
        echo >> "$file"
        echo "service_triggers() {" >> "$file"
        echo -e "\tprocd_add_reload_trigger \"$config\"" >> "$file"
        echo "}" >> "$file"
        
        echo "Added service_triggers to the file: $file"
    fi
    fi
done
touch /tmp/ok3
