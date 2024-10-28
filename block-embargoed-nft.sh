#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Define paths for the IP range files and set variables
NFT_TABLE_NAME="inet_filter"
NFT_CHAIN_NAME="input"
NFT_SET_NAME="blocklist"
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

# Step 2: Define a function to create nftables table, chain, and set if not exists
setup_nftables_structure() {
    echo "Setting up nftables structure..."
    nft list table inet "$NFT_TABLE_NAME" > /dev/null 2>&1 || nft add table inet "$NFT_TABLE_NAME"
    nft list chain inet "$NFT_TABLE_NAME" "$NFT_CHAIN_NAME" > /dev/null 2>&1 || nft add chain inet "$NFT_TABLE_NAME" "$NFT_CHAIN_NAME" { type filter hook input priority 0\; }
    nft list set inet "$NFT_TABLE_NAME" "$NFT_SET_NAME" > /dev/null 2>&1 || nft add set inet "$NFT_TABLE_NAME" "$NFT_SET_NAME" { type ipv4_addr\; flags interval\; }
    echo "nftables structure set up."
}

# Step 3: Define a function to refresh the nftables set blocklist
update_nft_set() {
    echo "Creating or refreshing nftables set..."
    nft flush set inet "$NFT_TABLE_NAME" "$NFT_SET_NAME"
    
    temp_file=$(mktemp)
    for url in "${IPLIST_URLS[@]}"; do
        country_code=$(basename "$url" .zone)
        echo "Fetching IP ranges for $country_code..."
        curl -s "$url" -o "$BLOCKLIST_DIR/$country_code.zone"
        
        # Append IP ranges to temporary file
        cat "$BLOCKLIST_DIR/$country_code.zone" >> "$temp_file"
    done

    # Load all IPs into nftables set in bulk
    ip_list=$(awk '{printf "%s, ", $1}' "$temp_file" | sed 's/, $//')
    if [ -n "$ip_list" ]; then
        nft add element inet "$NFT_TABLE_NAME" "$NFT_SET_NAME" { $ip_list }
    fi

    rm "$temp_file"
    echo "nftables set updated."
}

# Step 4: Set up nftables rule to drop traffic from the nftables set and log blocked IPs
apply_nftables_rules() {
    echo "Applying nftables rules..."
    nft list ruleset | grep -q "ip saddr @$NFT_SET_NAME drop" || \
    nft add rule inet "$NFT_TABLE_NAME" "$NFT_CHAIN_NAME" ip saddr "@${NFT_SET_NAME}" log prefix "BLOCKED-IP " drop comment "Embargoed-Country-Block"
    echo "nftables rules applied."
}

# Step 5: Run the functions
setup_nftables_structure
update_nft_set
apply_nftables_rules

echo "Blocking completed."

# Step 6: Set up a cron job for daily updates (if not already present)
CRONJOB="@daily /bin/bash /path/to/block_embargoed_countries.sh"
(crontab -l | grep -Fx "$CRONJOB") || (crontab -l; echo "$CRONJOB") | crontab -

echo "Daily cron job set up for automatic updates."

