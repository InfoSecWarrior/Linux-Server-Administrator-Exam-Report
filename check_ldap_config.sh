#!/bin/bash

# Define color codes
GREEN="\e[32m"
DARK_GREEN="\e[32;1m"
BLUE="\e[34m"
RED="\e[31m"
NC="\e[0m" # No color

# Function to print info messages in blue
info() {
  echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to print error messages in red
error() {
  echo -e "${RED}[ERROR] $1${NC}"
}

# Function to print success messages in dark green
success() {
  echo -e "${DARK_GREEN}[SUCCESS] $1${NC}"
}

# Function to check if a service is active
check_service() {
  local service_name="$1"
  if systemctl is-active --quiet "$service_name"; then
    success "$service_name is running."
  else
    error "$service_name is not running."
  fi
}

# Function to check for LDAP configuration files
check_ldap_config_files() {
  local ldap_conf="/etc/ldap/ldap.conf"
  local slapd_conf="/etc/ldap/slapd.conf"
  local slapd_d_dir="/etc/ldap/slapd.d"

  if [ -f "$ldap_conf" ]; then
    info "LDAP client configuration file ($ldap_conf) found."
  else
    error "LDAP client configuration file ($ldap_conf) not found."
  fi

  if [ -f "$slapd_conf" ]; then
    info "LDAP server configuration file ($slapd_conf) found."
  elif [ -d "$slapd_d_dir" ]; then
    info "LDAP server configuration directory ($slapd_d_dir) found."
  else
    error "Neither slapd.conf file nor slapd.d directory found."
  fi
}

# Function to perform an LDAP search to test connection
test_ldap_connection() {
  local ldap_host="localhost"
  local base_dn="dc=example,dc=com"
  local search_filter="(objectClass=*)"

  info "Testing LDAP connection to $ldap_host..."
  ldapsearch -x -H "ldap://$ldap_host" -b "$base_dn" "$search_filter" -s base >/dev/null 2>&1

  if [ $? -eq 0 ]; then
    success "LDAP connection to $ldap_host successful."
  else
    error "Failed to connect to LDAP server at $ldap_host. Check server status and configuration."
  fi
}

# Function to test DNS resolution
test_dns_resolution() {
  local test_domain="example.com"
  local ldap_server="ldap.example.com"

  info "Testing DNS resolution for general domain ($test_domain)..."
  if host "$test_domain" >/dev/null 2>&1; then
    success "DNS resolution for $test_domain successful."
  else
    error "DNS resolution for $test_domain failed. Check DNS settings."
  fi

  info "Testing DNS resolution for LDAP server domain ($ldap_server)..."
  if host "$ldap_server" >/dev/null 2>&1; then
    success "DNS resolution for $ldap_server successful."
  else
    error "DNS resolution for $ldap_server failed. Check DNS settings."
  fi
}

# Function to check if DNS is listening on both TCP and UDP port 53
check_dns_netstat_ports() {
  local dns_port=53

  info "Checking if DNS is listening on port $dns_port (TCP)..."
  if netstat -tuln | grep -E ":(53)\s.*LISTEN" >/dev/null 2>&1; then
    success "DNS is listening on TCP port $dns_port."
  else
    error "DNS is not listening on TCP port $dns_port. Check DNS configuration."
  fi

  info "Checking if DNS is listening on port $dns_port (UDP)..."
  if netstat -uln | grep -E ":(53)\s" >/dev/null 2>&1; then
    success "DNS is listening on UDP port $dns_port."
  else
    error "DNS is not listening on UDP port $dns_port. Check DNS configuration."
  fi
}

# Function to add a user to LDAP using ldapadd
add_ldap_user() {
  local base_dn="dc=example,dc=com"
  local admin_dn="cn=admin,$base_dn"
  local admin_password="admin_password"  # Replace with the actual password
  local user_dn="uid=armour,ou=users,$base_dn"
  local user_password="password"  # Replace with the desired user password

  # Create LDIF file for user addition
  local ldif_file="/tmp/add_user_armour.ldif"

  cat <<EOF > "$ldif_file"
dn: $user_dn
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: top
cn: armour
sn: User
uid: armour
uidNumber: 10001
gidNumber: 10001
homeDirectory: /home/armour
loginShell: /bin/bash
userPassword: $(slappasswd -s "$user_password")
gecos: Armour User
EOF

  info "Adding user 'armour' to LDAP directory..."
  ldapadd -x -D "$admin_dn" -w "$admin_password" -f "$ldif_file"

  if [ $? -eq 0 ]; then
    success "User 'armour' added successfully."
  else
    error "Failed to add user 'armour'. Check LDAP configuration and credentials."
  fi

  # Cleanup
  rm -f "$ldif_file"
}

# Main script execution
echo "Checking LDAP, DNS, and network configuration on the system..."

# Check if LDAP server (slapd) is running
check_service "slapd"

# Check if LDAP client and server configuration files are present
check_ldap_config_files

# Test LDAP connection
test_ldap_connection

# Check if DNS service (named) is running (common DNS service)
check_service "named"

# Test DNS resolution
test_dns_resolution

# Check if DNS is listening on both TCP and UDP ports
check_dns_netstat_ports

# Add LDAP user 'armour'
add_ldap_user

echo "LDAP, DNS, network configuration check, and user addition complete."
