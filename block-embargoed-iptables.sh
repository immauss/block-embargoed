#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Define paths for the IP range files and set variables
IPTABLES_CHAINS="INPUT FORWARD"
BLOCKLIST_DIR="/etc/ipblock"
IPLIST_URLS=(
    "https://www.ipdeny.com/ipblocks/data/countries/cu.zone"
    "https://www.ipdeny.com/ipblocks/data/countries/ir.zone"
    "https://www.ipdeny.com/ipblocks/data/countries/kp.zone"
    "https://www.ipdeny.com/ipblocks/data/countries/ru.zone"
    "https://www.ipdeny.com/ipblocks/data/countries/sd.zone"
    "https://www.ipdeny.com/ipblocks/data/countries/sy.zone"
)

# Step 1: Create the blocklist directory if it doesn't exist
mkdir -p "$BLOCKLIST_DIR"

# Step 2: Define a function to refresh the IP blocklist
update_iptables_blocklist() {
    echo "Updating iptables blocklist..."
    
    temp_file=$(mktemp)
    for url in "${IPLIST_URLS[@]}"; do
        country_code=$(basename "$url" .zone)
        echo "Fetching IP ranges for $country_code..."
        curl -s "$url" -o "$BLOCKLIST_DIR/$country_code.zone"
        
        # Append IP ranges to temporary file
        cat "$BLOCKLIST_DIR/$country_code.zone" >> "$temp_file"
    done

    # Flush old iptables rules related to the blocklist
    for  IPTABLES_CHAIN_NAME in $IPTABLES_CHAINS; do
        echo "Deleting from $IPTABLES_CHAIN_NAME chain"
        iptables -D "$IPTABLES_CHAIN_NAME" -m set --match-set blocklist src -j LOG --log-prefix "[BLOCKED-IP] " --log-level 4 #2>/dev/null
        iptables -D "$IPTABLES_CHAIN_NAME" -m set --match-set blocklist src -j DROP #2>/dev/null
    done
    # Give the kernel 2 seconds to catch up.
    sleep 2
    echo " Destroy existing blocklist "
    ipset destroy blocklist # 2> logger
    if [ $? -ne 0 ]; then
        echo "blocklist destroy failed with $?"
        ipset destroy blocklist
    fi
    # Create a new ipset for the blocklist
    echo "Create ipset"
    ipset create blocklist hash:net
    echo -n "Adding $(wc -l $temp_file | awk '{print $1}') entries to blocklist"
    while read -r ip; do
        ipset add blocklist "$ip"
    done < "$temp_file"

    # Apply iptables rule to log and drop traffic from IPs in the blocklist
    for  IPTABLES_CHAIN_NAME in $IPTABLES_CHAINS; do
        echo "Applying to $IPTABLES_CHAIN_NAME"
        iptables -I "$IPTABLES_CHAIN_NAME" -m set --match-set blocklist src -j LOG --log-prefix "[BLOCKED-IP] " --log-level 4
        iptables -I "$IPTABLES_CHAIN_NAME" -m set --match-set blocklist src -j DROP
    done
    rm "$temp_file"
    echo "iptables blocklist updated in $IPTABLES_CHAINS."
}

# Step 3: Run the function to update the blocklist
update_iptables_blocklist

echo "Blocking completed."

# Step 4: Set up a cron job for daily updates (if not already present)
CRONJOB="@daily /bin/bash /usr/local/sbin/block_embargoed_iptables.sh"
(crontab -l | grep -Fx "$CRONJOB") || (crontab -l; echo "$CRONJOB") | crontab -

echo "Daily cron job set up for automatic updates."

