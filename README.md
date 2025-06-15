# Block Embargoed Countries Script and Ansible Playbook

## Overview

This repository contains a bash script (`block-embargoed-iptables.sh`) and an accompanying Ansible playbook (`deploy_blocklist_playbook.yml`). Together, they are designed to help administrators block traffic from embargoed countries using `iptables` and `ipset`. This can be useful in scenarios where compliance with government regulations or organizational policies requires that services not be accessed from specific countries.

The bash script downloads country-specific IP lists, creates a blocklist, and configures `iptables` rules to block any traffic originating from those IP ranges. The Ansible playbook automates the deployment of this script across multiple servers.

## Currently Blocked Countries
- Cuba
- Iran
- North Korea
- Russia 
- Sudan
- Syria

## Components

### 1. Bash Script (`block-embargoed-iptables.sh`)

The bash script does the following:
- Downloads IP lists from `ipdeny.com` for specified embargoed countries.
- Creates an `ipset` blocklist containing the downloaded IP addresses.
- Applies `iptables` rules to:
  - **Log** any incoming traffic from blocked IPs for monitoring purposes.
  - **Drop** traffic from these IPs to prevent access to the server's services.
- Sets up a daily cron job to update the blocklist and ensure new IP ranges are blocked as they become available.

### 2. Ansible Playbook (`deploy_blocklist_playbook.yml`)

The Ansible playbook automates the deployment of the bash script. Specifically, it:
- Copies the `block-embargoed-iptables.sh` script to the remote server.
- Makes the script executable.
- Runs the script to initialize the IP blocklist and configure the firewall rules.
- Sets up a cron job on the remote server to run the script daily, ensuring that IP lists stay current.

## Why Use This?

Blocking network traffic from embargoed countries can be critical for the following reasons:

1. **Compliance**: Organizations may be required to comply with legal regulations, such as sanctions enforced by governments. This script helps meet these compliance requirements by actively blocking IP ranges associated with those countries.

2. **Security**: In some cases, network traffic from certain regions might pose security risks. Blocking these IP addresses can help reduce the server's attack surface and prevent unauthorized access.

3. **Automation**: Manually managing IP blocklists and firewall rules can be cumbersome. The Ansible playbook ensures that the script is deployed consistently across multiple hosts, automates its execution, and sets up a cron job to keep it updated without manual intervention.

## Requirements
- **Bash**: The script is a bash script and needs to be run on a Unix-based system.
- **iptables** and **ipset**: Both are required to apply the IP blocklist rules effectively.
- **Ansible**: The playbook is intended to be run from an Ansible controller to manage remote hosts.

## Usage
1. Clone this repository.
2. Use the Ansible playbook to deploy the script to your remote servers:
   ```sh
   ansible-playbook -i inventory deploy_blocklist_playbook.yml
   ```
3. The script will run immediately and establish the necessary firewall rules, and a daily cron job will keep it updated.

## License

This project is open-source. Feel free to modify and use it according to your needs.

## Disclaimer

Blocking network traffic based on geographical regions may have unintended side effects, including potential disruptions for legitimate users. Make sure to assess the impact of such rules before deploying them to production systems.

