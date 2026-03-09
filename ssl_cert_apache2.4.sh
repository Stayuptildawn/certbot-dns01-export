#!/bin/bash
# ================================================================
#  gen-ssl.sh — Let's Encrypt DNS-01 Certificate Generator
#  Purpose : Generate SSL certs on an internet-connected Ubuntu 22
#            server and export ready-to-use files for Apache 2.4
#  Author  : sysadmin script
#  Usage   : sudo bash gen-ssl.sh <domain>
#            sudo bash gen-ssl.sh --help
# ================================================================

set -euo pipefail

# ── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Constants ────────────────────────────────────────────────────
OUTPUT_BASE="/opt/ssl-export"
CERTBOT_BIN="certbot"

# ── Functions ─────────────────────────────────────────────────────

print_banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║       Let's Encrypt DNS-01 Certificate Generator     ║"
    echo "  ║       For offline Apache 2.4 / Windows transfer      ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_help() {
    print_banner
    echo -e "${BOLD}USAGE:${RESET}"
    echo "    sudo bash gen-ssl.sh <domain>"
    echo "    sudo bash gen-ssl.sh --help"
    echo ""
    echo -e "${BOLD}ARGUMENTS:${RESET}"
    echo "    <domain>       Fully qualified domain name (FQDN)"
    echo "                   Example: app.utelco.ir"
    echo ""
    echo -e "${BOLD}OPTIONS:${RESET}"
    echo "    --help, -h     Show this help message and exit"
    echo ""
    echo -e "${BOLD}DESCRIPTION:${RESET}"
    echo "    This script uses Certbot's DNS-01 manual challenge to"
    echo "    generate a Let's Encrypt SSL certificate WITHOUT needing"
    echo "    port 80/443 open. It is designed for scenarios where the"
    echo "    target Apache server has no internet access."
    echo ""
    echo "    During execution, you will be prompted to add a TXT record"
    echo "    to your DNS provider under the name:"
    echo -e "    ${YELLOW}_acme-challenge.<domain>${RESET}"
    echo ""
    echo -e "${BOLD}OUTPUT FILES (in /opt/ssl-export/<domain>/):${RESET}"
    echo "    <domain>-crt.pem    →  SSLCertificateFile"
    echo "    <domain>-key.pem    →  SSLCertificateKeyFile"
    echo "    <domain>-chain.pem  →  SSLCertificateChainFile"
    echo "    <domain>-ssl.zip    →  All 3 files bundled for transfer"
    echo ""
    echo -e "${BOLD}APACHE 2.4 CONFIG EXAMPLE:${RESET}"
    echo '    SSLCertificateFile    "C:\ProgramData\win-acme\<domain>-crt.pem"'
    echo '    SSLCertificateKeyFile "C:\ProgramData\win-acme\<domain>-key.pem"'
    echo '    SSLCertificateChainFile "C:\ProgramData\win-acme\<domain>-chain.pem"'
    echo ""
    echo -e "${BOLD}NOTES:${RESET}"
    echo "    - Must be run as root (sudo)"
    echo "    - Requires internet access on THIS Ubuntu server"
    echo "    - Let's Encrypt certs expire every 90 days — re-run to renew"
    echo "    - Verify DNS propagation before pressing Enter during challenge:"
    echo -e "      ${CYAN}nslookup -type=TXT _acme-challenge.<domain> 8.8.8.8${RESET}"
    echo ""
    exit 0
}

log_info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_section() { echo -e "\n${CYAN}${BOLD}── $* ──────────────────────────────────${RESET}"; }

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_error "This script must be run as root. Use: sudo bash $0 <domain>"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    # Basic FQDN pattern: at least one dot, valid characters
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$ ]]; then
        log_error "Invalid domain name: '${domain}'"
        log_error "Expected format: subdomain.example.com"
        exit 1
    fi
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ! curl -s --max-time 5 https://acme-v02.api.letsencrypt.org > /dev/null; then
        log_error "Cannot reach Let's Encrypt API. This server must have internet access."
        exit 1
    fi
    log_info "Internet connectivity OK."
}

install_dependencies() {
    log_section "Checking Dependencies"
    local pkgs_needed=()

    command -v certbot &>/dev/null || pkgs_needed+=("certbot")
    command -v zip     &>/dev/null || pkgs_needed+=("zip")
    command -v openssl &>/dev/null || pkgs_needed+=("openssl")

    if [[ ${#pkgs_needed[@]} -gt 0 ]]; then
        log_info "Installing missing packages: ${pkgs_needed[*]}"
        apt-get update -qq
        apt-get install -y "${pkgs_needed[@]}" -qq
        log_info "Dependencies installed."
    else
        log_info "All dependencies already satisfied."
    fi
}

request_certificate() {
    local domain="$1"
    log_section "Requesting Certificate — DNS-01 Challenge"
    echo ""
    echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────┐"
    echo -e "  │  IMPORTANT — What you need to do:                    │"
    echo -e "  │  1. Wait for certbot to show the TXT record value    │"
    echo -e "  │  2. Log in to your DNS provider                      │"
    echo -e "  │  3. Add a TXT record:                                │"
    echo -e "  │     Name : _acme-challenge.${domain}   │"
    echo -e "  │     Value: <shown by certbot>                        │"
    echo -e "  │  4. Verify propagation, then press ENTER in certbot  │"
    echo -e "  └─────────────────────────────────────────────────────┘${RESET}"
    echo ""
    log_warn "Tip — verify propagation BEFORE pressing Enter:"
    echo -e "  ${CYAN}nslookup -type=TXT _acme-challenge.${domain} 8.8.8.8${RESET}"
    echo ""

    certbot certonly \
        --manual \
        --preferred-challenges dns-01 \
        --agree-tos \
        --no-eff-email \
        --email "admin@${domain}" \
        --cert-name "${domain}" \
        -d "${domain}"
}

export_certificates() {
    local domain="$1"
    local out_dir="${OUTPUT_BASE}/${domain}"
    local le_live="/etc/letsencrypt/live/${domain}"

    log_section "Exporting Certificate Files"

    # Verify certbot actually produced the files
    for f in cert.pem privkey.pem chain.pem; do
        if [[ ! -f "${le_live}/${f}" ]]; then
            log_error "Expected file not found: ${le_live}/${f}"
            log_error "Certificate generation may have failed."
            exit 1
        fi
    done

    mkdir -p "${out_dir}"

    cp "${le_live}/cert.pem"    "${out_dir}/${domain}-crt.pem"
    cp "${le_live}/privkey.pem" "${out_dir}/${domain}-key.pem"
    cp "${le_live}/chain.pem"   "${out_dir}/${domain}-chain.pem"

    # Permissions: key must be private, others readable
    chmod 644 "${out_dir}/${domain}-crt.pem"
    chmod 644 "${out_dir}/${domain}-chain.pem"
    chmod 600 "${out_dir}/${domain}-key.pem"

    log_info "Files exported to: ${out_dir}"
}

verify_certificate() {
    local domain="$1"
    local crt="${OUTPUT_BASE}/${domain}/${domain}-crt.pem"

    log_section "Certificate Verification"

    local subject issuer not_before not_after
    subject=$(openssl x509 -in "$crt" -noout -subject 2>/dev/null | sed 's/subject=//')
    issuer=$(openssl x509 -in "$crt" -noout -issuer 2>/dev/null | sed 's/issuer=//')
    not_before=$(openssl x509 -in "$crt" -noout -startdate 2>/dev/null | sed 's/notBefore=//')
    not_after=$(openssl x509 -in "$crt" -noout -enddate 2>/dev/null | sed 's/notAfter=//')

    echo -e "  ${BOLD}Subject    :${RESET} ${subject}"
    echo -e "  ${BOLD}Issuer     :${RESET} ${issuer}"
    echo -e "  ${BOLD}Valid From :${RESET} ${not_before}"
    echo -e "  ${BOLD}Expires    :${RESET} ${not_after}"

    # Verify key matches certificate
    local cert_modulus key_modulus
    cert_modulus=$(openssl x509 -noout -modulus -in "$crt" | md5sum)
    key_modulus=$(openssl rsa -noout -modulus -in "${OUTPUT_BASE}/${domain}/${domain}-key.pem" 2>/dev/null | md5sum)

    if [[ "$cert_modulus" == "$key_modulus" ]]; then
        log_info "Certificate and private key MATCH. ✓"
    else
        log_error "Certificate and private key DO NOT match!"
        exit 1
    fi
}

create_zip() {
    local domain="$1"
    local out_dir="${OUTPUT_BASE}/${domain}"
    local zip_file="${OUTPUT_BASE}/${domain}-ssl.zip"

    log_section "Creating Transfer Package"

    zip -j "${zip_file}" \
        "${out_dir}/${domain}-crt.pem" \
        "${out_dir}/${domain}-key.pem" \
        "${out_dir}/${domain}-chain.pem" > /dev/null

    log_info "Zip created: ${zip_file}"
}

print_summary() {
    local domain="$1"
    local out_dir="${OUTPUT_BASE}/${domain}"
    local zip_file="${OUTPUT_BASE}/${domain}-ssl.zip"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║                  ✓  ALL DONE                         ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${BOLD}  Output directory:${RESET} ${out_dir}"
    echo -e "${BOLD}  Transfer zip    :${RESET} ${zip_file}"
    echo ""
    echo -e "${BOLD}  Files to copy to C:\\ProgramData\\win-acme\\ :${RESET}"
    echo -e "    ${CYAN}${domain}-crt.pem${RESET}    →  SSLCertificateFile"
    echo -e "    ${CYAN}${domain}-key.pem${RESET}    →  SSLCertificateKeyFile"
    echo -e "    ${CYAN}${domain}-chain.pem${RESET}  →  SSLCertificateChainFile"
    echo ""
    echo -e "${BOLD}  SCP transfer command example:${RESET}"
    echo -e "  ${CYAN}scp root@<this-server-ip>:${zip_file} .${RESET}"
    echo ""
    echo -e "${YELLOW}  ⚠  Reminder: Certs expire in 90 days — re-run this script to renew.${RESET}"
    echo ""
}

# ── Argument Parsing ──────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    log_error "No domain provided."
    echo -e "Usage: sudo bash $0 <domain>"
    echo -e "       sudo bash $0 --help"
    exit 1
fi

case "$1" in
    --help|-h|help)
        print_help
        ;;
    --*)
        log_error "Unknown option: $1"
        echo -e "Usage: sudo bash $0 <domain>"
        echo -e "       sudo bash $0 --help"
        exit 1
        ;;
esac

DOMAIN="$1"

# ── Main Flow ─────────────────────────────────────────────────────

print_banner
check_root
validate_domain     "$DOMAIN"
check_internet
install_dependencies
request_certificate "$DOMAIN"
export_certificates "$DOMAIN"
verify_certificate  "$DOMAIN"
create_zip          "$DOMAIN"
print_summary       "$DOMAIN"
