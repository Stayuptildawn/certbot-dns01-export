
# ssl-cert-apache2.4

Automates Let's Encrypt SSL certificate generation via DNS-01 challenge and packages the output for Apache 2.4 deployment, including on offline or Windows-hosted servers.

---

## Overview

Most SSL automation tools assume your web server has direct internet access. This script solves a real-world problem: your Apache 2.4 server sits in a closed or internal network, but you still need a valid, trusted SSL certificate.

I built this to handle that exact gap. The script runs on any internet-connected Ubuntu 22 machine, handles the full Certbot DNS-01 flow, validates the output, and bundles everything into a transfer-ready zip file.

The result is three clean `.pem` files (certificate, private key, and chain) that you drop directly into your Apache config and go.

---

## Project Structure

```
ssl-cert-apache2.4/
├── ssl_cert_apache2.4.sh   # Main script, runs the full cert generation pipeline
└── README.md
```

The script is self-contained. It checks for and installs its own dependencies (`certbot`, `openssl`, `zip`) and writes all output to `/opt/ssl-export/<domain>/`.

---

## How to Run

1. Clone the repository onto an **internet-connected Ubuntu 22** machine:
   ```bash
   git clone https://github.com/your-username/ssl-cert-apache2.4.git
   cd ssl-cert-apache2.4
   ```

2. Make the script executable:
   ```bash
   chmod +x ssl_cert_apache2.4.sh
   ```

3. Run it with your target domain:
   ```bash
   sudo bash ssl_cert_apache2.4.sh app.yourdomain.com
   ```

4. When Certbot pauses, log in to your DNS provider and add the TXT record it shows you:
   - **Name:** `_acme-challenge.app.yourdomain.com`
   - **Value:** *(provided by Certbot at runtime)*

5. Verify DNS propagation before pressing Enter:
   ```bash
   nslookup -type=TXT _acme-challenge.app.yourdomain.com 8.8.8.8
   ```

6. After the script finishes, transfer the zip to your Apache server:
   ```bash
   scp root@<this-server>:/opt/ssl-export/app.yourdomain.com-ssl.zip .
   ```

7. Add the following to your Apache 2.4 virtual host config:
   ```apache
   SSLCertificateFile      "/path/to/app.yourdomain.com-crt.pem"
   SSLCertificateKeyFile   "/path/to/app.yourdomain.com-key.pem"
   SSLCertificateChainFile "/path/to/app.yourdomain.com-chain.pem"
   ```

For help: `sudo bash ssl_cert_apache2.4.sh --help`

---

## Key Output

After a successful run, you get three files in `/opt/ssl-export/<domain>/`:

| File | Apache Directive | Permission |
|---|---|---|
| `<domain>-crt.pem` | `SSLCertificateFile` | `644` |
| `<domain>-key.pem` | `SSLCertificateKeyFile` | `600` |
| `<domain>-chain.pem` | `SSLCertificateChainFile` | `644` |

The script also verifies that the certificate and private key match before packaging, so you are never left with a mismatched pair silently causing Apache to fail.

---

## Notes

- This script **must run on a machine with internet access**. It is not meant for the target Apache server itself.
- Let's Encrypt certificates expire every **90 days**. Re-run the script to renew.
- DNS propagation can take a few minutes depending on your provider. Always verify with `nslookup` before proceeding past the Certbot prompt.
- The script uses `set -euo pipefail`, so it exits immediately on any error and will not leave broken state silently.
- Tested on Ubuntu 22.04. Other Debian-based distros should work but are not officially tested.

---

Mohammad Soleimani Roudi  
[LinkedIn](https://www.linkedin.com/in/mohammad-soleimani-roudi)
```
