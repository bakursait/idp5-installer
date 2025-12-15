# Important updates:
## Update [15-12-2025]:
- The main branch uses `Jetty-11` and other older documents (`wget` command to get those files) from the source we follow: [HOWTO guide provided by Consortium GARR](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md).
- Our branch: [jetty-12](https://github.com/bakursait/idp5-installer/tree/jetty-12) has solved this issue. all files up-to-date, up to the date of this announcement. so please consider review it first. 

---

# Shibboleth IdP v5 Automated Installer

---

## Overview

This project provides an **automated installation and configuration script** for setting up Shibboleth Identity Provider (IdP) v5 on Ubuntu/Debian servers with Apache as the front-end reverse proxy and Jetty as the application server. The script is based on the official [HOWTO guide provided by Consortium GARR](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md), automating the majority of manual steps while maintaining flexibility for customization.

The installer includes **integrated OpenLDAP server installation** and configuration, making it a complete solution for local testing and development environments.

> **Note:** All IdP5 supporting configuration files are sourced from the official Consortium GARR IDEM tutorials repository.

---

## Features

- ✅ **Fully automated installation** of Shibboleth IdP v5.x
- ✅ **Jetty servlet container** setup and configuration
- ✅ **Apache reverse proxy** with SSL/TLS support
- ✅ **OpenLDAP server** installation and configuration
- ✅ **LDAP-based authentication** integration with Shibboleth
- ✅ **Self-signed SSL certificates** generation (for testing)
- ✅ **Attribute resolver** configuration with sample attributes
- ✅ **Interactive manual steps** for advanced configurations
- ✅ **Idempotent design** - safe to re-run
- ✅ **Progress tracking** and clear status messages
- ✅ **Compatible** with local VMs and private networks

---

## System Requirements

### Operating System
- **Ubuntu 22.04 LTS** (recommended)
- Debian 11+ (compatible)

### Hardware
- **CPU:** 2 cores (64-bit)
- **RAM:** 4 GB minimum
- **Disk:** 10 GB free space
- **Network:** Internet connection required for package downloads

### Permissions
- **Root access required** - The script must be run as root or with sudo

### Network
- Port 80 (HTTP) and 443 (HTTPS) must be accessible
- Port 389 (LDAP) for local LDAP server

---

## Software Versions

The installer uses the following software versions (configurable in the script):

| Component | Version | Variable Name |
|-----------|---------|---------------|
| **Shibboleth IdP** | 5.1.6 | `SHIB_IDP_VERSION` |
| **Jetty** | 11.0.25 | `JETTY_VERSION` |
| **Java** | Amazon Corretto 17 | `JAVA_HOME_ENV` |
| **Apache** | 2.4+ | (from apt) |
| **OpenLDAP** | Latest from apt | (from apt) |

> **Note:** You can update these versions by modifying the variables at the top of the `install_local_idp5_corrected.sh` script.

---

## Directory Structure

```
idp5-installer/
├── install_local_idp5_corrected.sh          # Main installation script
├── idp5_supporting_files/                   # Configuration templates and files
│   ├── Apache2_as_front_end_of_Jetty_template.conf
│   ├── attribute-resolver-v5-idem-sample.xml
│   ├── eduPersonTargetedID.properties.txt
│   ├── idem-example-arp.txt
│   ├── idp_jetty_context.xml
│   ├── jetty-logging.properties.txt
│   ├── jetty-requestlog.xml
│   ├── jetty-start.ini.txt
│   ├── updateIDPsecrets.sh
│   └── ...
├── ldif_files/                              # Auto-generated LDAP directory files
│   ├── ou-structure.ldif
│   ├── idpuser.ldif
│   ├── johnsmith.ldif
│   ├── jacobdan.ldif
│   └── ...
└── README.md                                # This file
```

---

## Configuration Variables

### Network Configuration

```bash
# Machine's IP addresses
IP_ADDRESS="192.168.4.220"           # Your machine's private IP address
LOOP_IP_ADDRESS="127.0.1.1"          # Loopback IP for /etc/hosts

# IdP hostname configuration
SHIB_IDP_HOSTNAME="idp.localtest2"   # Your IdP hostname
SHIB_IDP_FQDN="${SHIB_IDP_HOSTNAME}" # Fully Qualified Domain Name
```

> **Important:** Update `SHIB_IDP_HOSTNAME` to match your desired hostname before running the script.

### Installation Paths

```bash
IDP_HOME="/opt/shibboleth-idp"                                    # IdP installation directory
MAIN_SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"                 # Script directory
SUPPORTING_FILES_PATH="${MAIN_SCRIPT_PATH}/idp5_supporting_files" # Supporting files directory
LDAP_FILES_PATH="${MAIN_SCRIPT_PATH}/ldif_files"                  # LDAP files directory
```

> **Critical:** The `idp5_supporting_files` directory **must exist** in the same directory as the installation script. The script will exit with an error if this directory is missing.

### LDAP Configuration

```bash
# LDAP domain components (auto-extracted from hostname)
LDAP_DC_1=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{print $1}')    # e.g., "idp"
LDAP_DC_2=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{print $NF}')   # e.g., "localtest2"
LDAP_DC_COMPOSITE="dc=${LDAP_DC_2}"                                   # e.g., "dc=localtest2"

# LDAP credentials
LDAP_ADMIN_PASSWORD='admin123'       # LDAP admin password
LDAP_IDPUSER_PASSWORD='idpuser123'   # LDAP service account password
```

> **Security Note:** Change these default passwords for production environments!

### Sample LDAP Users

The script automatically creates two sample users for testing:

| Username | Password | Email | UID |
|----------|----------|-------|-----|
| johnsmith | smith123 | johnsmith@localtest2 | 1001 |
| jacobdan | dan123 | jacobdan@localtest2 | 1002 |

---

## Script Usage

The installer script supports the following command-line options:

```bash
# Show usage information
./install_local_idp5_corrected.sh

# Show help message
./install_local_idp5_corrected.sh --help

# Start the installation process (requires root)
sudo ./install_local_idp5_corrected.sh --install

# View post-installation tasks (can be run anytime)
./install_local_idp5_corrected.sh --print-remaining
```

### Command-Line Options

| Option | Short | Description | Root Required |
|--------|-------|-------------|---------------|
| `--install` | `-i` | Start the installation process | ✓ Yes |
| `--print-remaining` | `-p` | Display post-installation tasks | ✗ No |
| `--help` | `-h` | Show help message | ✗ No |
| (no option) | | Show usage information | ✗ No |

---

## Installation Steps

### 1. Prerequisites Check

Before running the installer, ensure:

- [ ] You have **root access** to the system
- [ ] The system is **Ubuntu 22.04** or compatible
- [ ] You have **internet connectivity**
- [ ] The **`idp5_supporting_files`** directory exists
- [ ] You have updated the **configuration variables** (hostname, IP addresses)

### 2. Clone or Download the Repository

```bash
git clone https://github.com/yourusername/idp5-installer.git
cd idp5-installer
```

Or download and extract the ZIP file.

### 3. Verify Supporting Files

```bash
# Check that the supporting files directory exists
ls -la idp5_supporting_files/

# You should see files like:
# - Apache2_as_front_end_of_Jetty_template.conf
# - attribute-resolver-v5-idem-sample.xml
# - idp_jetty_context.xml
# - updateIDPsecrets.sh
# etc.
```

### 4. Customize Configuration

Edit the script to update your environment-specific settings:

```bash
vim install_local_idp5_corrected.sh
```

Update these variables:
- `SHIB_IDP_HOSTNAME` - Your IdP hostname
- `IP_ADDRESS` - Your machine's IP address (optional)
- `LDAP_ADMIN_PASSWORD` - LDAP admin password
- `LDAP_IDPUSER_PASSWORD` - LDAP service account password

### 5. Run the Installation Script

```bash
# Make the script executable
chmod +x install_local_idp5_corrected.sh

# Run the installation with --install option
sudo ./install_local_idp5_corrected.sh --install
```

> **Important:** The script **must be run with root privileges** using `sudo` or as the root user.

### 6. Interactive Manual Steps

The script will **pause at certain steps** that require manual verification or configuration. These steps are:

1. **`configure_persistent_nameid`** - Configure persistent NameID generation
2. **`configure_attribute_resolver`** - Review and confirm attribute resolver configuration
3. **`configure_eduPersonTargetedID_confirm_required`** - Verify eduPersonTargetedID configuration
4. **`configure_idp_logging`** - Review logging configuration

When the script pauses:
- **Open another terminal** to review the configuration files
- **Verify** the settings are correct
- **Return to the installation terminal**
- Type **`done`** to continue, or **`exit`** to stop the installation

Example:
```
╔════════════════════════════════════════════════════════════╗
║          MANUAL VERIFICATION REQUIRED                      ║
╚════════════════════════════════════════════════════════════╝

Please verify the configuration in:
  /opt/shibboleth-idp/conf/saml-nameid.properties

Have you reviewed and confirmed the configuration?
Type 'done' to continue or 'exit' to abort: done
```

### 7. Post-Installation Verification

After installation completes, verify the services:

```bash
# Check Jetty status
systemctl status jetty

# Check Apache status
systemctl status apache2

# Check OpenLDAP status
systemctl status slapd

# Check IdP status
bash /opt/shibboleth-idp/bin/status.sh
```

---

## Testing the Installation

### 1. Test LDAP Connectivity

```bash
# Test LDAP connection with admin user
ldapsearch -x -H ldap://localhost \
  -D "cn=admin,dc=localtest2" \
  -w "admin123" \
  -b "dc=localtest2"

# Test LDAP connection with idpuser service account
ldapsearch -x -H ldap://localhost \
  -D "cn=idpuser,ou=system,dc=localtest2" \
  -w "idpuser123" \
  -b "ou=people,dc=localtest2" \
  "(uid=johnsmith)"
```

### 2. Test IdP Metadata Access

From the IdP server:
```bash
# Using curl (bypass SSL verification for self-signed cert)
curl -k https://idp.localtest2/idp/shibboleth
```

From your local machine:
```bash
# First, add the IdP to your /etc/hosts file
echo "192.168.4.220 idp.localtest2" | sudo tee -a /etc/hosts

# Then access the metadata
curl -k https://idp.localtest2/idp/shibboleth
```

You should see XML metadata output starting with:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata" ...>
```

### 3. Test IdP Login Page

Open a web browser and navigate to:
```
https://idp.localtest2/idp/profile/SAML2/Unsolicited/SSO?providerId=https://sp.example.org
```

You should see the Shibboleth IdP login page.

### 4. Test LDAP Authentication

Try logging in with one of the sample users:
- **Username:** `johnsmith`
- **Password:** `smith123`

Or:
- **Username:** `jacobdan`
- **Password:** `dan123`

---

## Automated Installation Steps

The script automates the following steps from the official HOWTO guide:

### System Preparation
- ✅ Hostname and `/etc/hosts` configuration
- ✅ JAVA_HOME environment variable setup
- ✅ System package updates and dependency installation

### Java Installation
- ✅ Amazon Corretto JDK 17 installation
- ✅ GPG key import and repository configuration

### Jetty Installation
- ✅ Jetty download and extraction
- ✅ Jetty user and directory creation
- ✅ Jetty systemd service configuration
- ✅ LogBack logging setup
- ✅ Jakarta Servlet API installation

### Shibboleth IdP Installation
- ✅ IdP download and GPG signature verification
- ✅ IdP installation with proper parameters
- ✅ Metadata typo fix (for v5.1.3)
- ✅ Directory indexing disabled
- ✅ Jetty context descriptor configuration

### Apache Configuration
- ✅ DocumentRoot creation
- ✅ Self-signed SSL certificate generation
- ✅ Apache modules enablement (proxy_http, ssl, headers, etc.)
- ✅ Virtual host configuration
- ✅ Reverse proxy to Jetty setup

### OpenLDAP Installation
- ✅ OpenLDAP server installation
- ✅ DIT (Directory Information Tree) structure creation
- ✅ Service account (idpuser) creation
- ✅ Sample user accounts creation (johnsmith, jacobdan)

### Shibboleth-LDAP Integration
- ✅ LDAP authentication configuration
- ✅ Attribute resolver setup
- ✅ Persistent NameID configuration
- ✅ eduPersonTargetedID configuration
- ✅ IdP logging configuration

### Security Hardening
- ✅ Cookie security configuration
- ✅ Secret rotation script setup
- ✅ Cron job for daily secret updates

---

## Manual Steps Required

The following steps require **manual verification** during installation:

### 1. Configure Persistent NameID
**When:** After LDAP integration
**What:** Verify the persistent NameID generation settings
**File:** `/opt/shibboleth-idp/conf/saml-nameid.properties`
**Action:** Review and confirm the configuration is correct

### 2. Configure Attribute Resolver
**When:** After persistent NameID configuration
**What:** Verify attribute resolution from LDAP
**File:** `/opt/shibboleth-idp/conf/attribute-resolver.xml`
**Action:** Ensure LDAP attributes are correctly mapped

### 3. Configure eduPersonTargetedID
**When:** After attribute resolver configuration
**What:** Verify eduPersonTargetedID attribute definition
**File:** `/opt/shibboleth-idp/conf/attribute-resolver.xml`
**Action:** Confirm the XML configuration is present and correct

### 4. Configure IdP Logging
**When:** Near the end of installation
**What:** Verify logging configuration for LDAP authentication
**File:** `/opt/shibboleth-idp/conf/logback.xml`
**Action:** Confirm LDAP authentication logging is enabled

---

## Post-Installation Tasks

After the automated installation completes, the script will display a list of remaining tasks. You can view this list again at any time by running:

```bash
./install_local_idp5_corrected.sh --print-remaining
```

The remaining tasks include:

### 1. Customize IdP Branding
- Add your institutional logo (80x60 px PNG)
- Customize login page messages
- Update footer text

See: [HOWTO - Enrich IdP Login Page](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#enrich-idp-login-page-with-the-institutional-logo)

### 2. Connect a Service Provider (SP)
- Add SP metadata to `/opt/shibboleth-idp/conf/metadata-providers.xml`
- Configure attribute release policy in `/opt/shibboleth-idp/conf/attribute-filter.xml`
- Restart Jetty

See: [HOWTO - Appendix D: Connect an SP with the IdP](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#appendix-d-connect-an-sp-with-the-idp)

### 3. Replace Self-Signed Certificates
For production use, replace the self-signed SSL certificates with CA-signed certificates:

```bash
# Copy your CA-signed certificates
cp your-cert.crt /etc/ssl/certs/idp.localtest2.crt
cp your-key.key /etc/ssl/private/idp.localtest2.key

# Set proper permissions
chmod 644 /etc/ssl/certs/idp.localtest2.crt
chmod 600 /etc/ssl/private/idp.localtest2.key

# Restart Apache
systemctl restart apache2
```

### 4. Configure Firewall
```bash
# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# If accessing LDAP remotely (not recommended for production)
ufw allow 389/tcp  # LDAP
ufw allow 636/tcp  # LDAPS
```

### 5. Join a Federation
- Register your IdP with IDEM or another federation
- Download and configure federation metadata
- Update metadata refresh configuration

---

## Troubleshooting

### Jetty Issues

**Problem:** Jetty fails to start

**Solution:**
```bash
# Check Jetty logs
journalctl -xeu jetty
tail -f /var/log/jetty/start.log

# Verify JAVA_HOME is set
echo $JAVA_HOME

# Check if Jetty is listening on port 8080
netstat -tulpn | grep 8080

# Restart Jetty
systemctl restart jetty
```

### Apache Issues

**Problem:** 502 Bad Gateway error

**Solution:**
```bash
# Ensure Jetty is running
systemctl status jetty

# Check Apache configuration
apache2ctl configtest

# Check Apache error logs
tail -f /var/log/apache2/idp.localtest2-error.log

# Restart both services
systemctl restart jetty
systemctl restart apache2
```

### LDAP Issues

**Problem:** LDAP authentication fails

**Solution:**
```bash
# Test LDAP connectivity
ldapsearch -x -H ldap://localhost \
  -D "cn=admin,dc=localtest2" \
  -w "admin123" \
  -b "dc=localtest2"

# Check LDAP logs
journalctl -u slapd

# Verify IdP LDAP configuration
cat /opt/shibboleth-idp/conf/ldap.properties
cat /opt/shibboleth-idp/credentials/secrets.properties

# Check IdP logs for LDAP errors
grep -i ldap /opt/shibboleth-idp/logs/idp-process.log
```

### IdP Metadata Not Accessible

**Problem:** Cannot access `https://idp.localtest2/idp/shibboleth`

**Solution:**
```bash
# Check if IdP WAR is deployed
ls -la /opt/shibboleth-idp/war/idp.war

# Check if Jetty context is configured
ls -la /opt/jetty/webapps/idp.xml

# Test direct Jetty access
curl http://localhost:8080/idp/shibboleth

# Test through Apache
curl -k https://localhost/idp/shibboleth

# Check ownership
ls -la /opt/shibboleth-idp/logs
ls -la /opt/shibboleth-idp/metadata
```

### SSL Certificate Issues

**Problem:** Browser shows SSL warning

**Solution:**
This is expected with self-signed certificates. For testing:
- Accept the security exception in your browser
- Use `curl -k` to bypass verification

For production, obtain a CA-signed certificate.

---

## Important Notes

### For Local Testing
- The script generates **self-signed SSL certificates** suitable only for testing
- Update `/etc/hosts` on client machines to resolve the IdP hostname
- Default LDAP passwords are weak - change them for any non-testing use

### For Production Use
- Replace self-signed certificates with CA-signed certificates
- Use strong, randomly generated passwords for LDAP
- Consider using LDAPS (LDAP over SSL/TLS) instead of plain LDAP
- Implement proper firewall rules
- Set up monitoring and log rotation
- Configure regular backups
- Review and harden security settings

### Network Configuration
- For local VM testing, the loopback IP (127.0.1.1) is used in `/etc/hosts`
- For network-accessible IdP, you may want to use the actual IP address
- Ensure DNS resolution works for your IdP hostname

---

## File Locations

| Component | Location |
|-----------|----------|
| IdP Home | `/opt/shibboleth-idp` |
| IdP Configuration | `/opt/shibboleth-idp/conf/` |
| IdP Credentials | `/opt/shibboleth-idp/credentials/` |
| IdP Logs | `/opt/shibboleth-idp/logs/` |
| IdP Metadata | `/opt/shibboleth-idp/metadata/` |
| Jetty Home | `/usr/local/src/jetty-src` |
| Jetty Base | `/opt/jetty` |
| Jetty Logs | `/var/log/jetty/` |
| Apache Config | `/etc/apache2/sites-available/` |
| Apache Logs | `/var/log/apache2/` |
| SSL Certificates | `/etc/ssl/certs/` and `/etc/ssl/private/` |
| LDAP Config | `/etc/ldap/` |

---

## Useful Commands

```bash
# View post-installation tasks
./install_local_idp5_corrected.sh --print-remaining

# Check IdP status
bash /opt/shibboleth-idp/bin/status.sh

# Rebuild IdP WAR file
bash /opt/shibboleth-idp/bin/build.sh

# Restart all services
systemctl restart jetty
systemctl restart apache2
systemctl restart slapd

# View logs in real-time
tail -f /opt/shibboleth-idp/logs/idp-process.log
tail -f /var/log/jetty/start.log
tail -f /var/log/apache2/idp.localtest2-error.log

# Test LDAP user authentication
ldapsearch -x -H ldap://localhost \
  -D "uid=johnsmith,ou=people,dc=localtest2" \
  -w "smith123" \
  -b "ou=people,dc=localtest2"
```

---

## References

- [Shibboleth Project](https://www.shibboleth.net/)
- [Consortium GARR IDEM Tutorials](https://github.com/ConsortiumGARR/idem-tutorials)
- [Official HOWTO Guide](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md)
- [Eclipse Jetty](https://www.eclipse.org/jetty/)
- [Amazon Corretto](https://aws.amazon.com/corretto/)
- [OpenLDAP](https://www.openldap.org/)

---

## License

This project follows the same licensing as the Consortium GARR IDEM tutorials. Please refer to the original repository for license details.

---

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## Support

For issues related to:
- **This installer script:** Open an issue in this repository
- **Shibboleth IdP:** Consult the [official documentation](https://shibboleth.atlassian.net/wiki/spaces/IDP5/overview)
- **IDEM Federation:** Contact [Consortium GARR](https://www.idem.garr.it/)

---

## Changelog

### Version 2.0 (Current)
- ✅ Updated to Shibboleth IdP 5.1.6
- ✅ Updated to Jetty 11.0.25
- ✅ Improved error handling and validation
- ✅ Added interactive manual verification steps
- ✅ Enhanced LDAP integration
- ✅ Better progress tracking
- ✅ Improved idempotency
- ✅ Fixed GPG key import issues
- ✅ Added JAVA_HOME configuration
- ✅ Updated configuration file sources

### Version 1.0
- Initial release with basic automation

---

**Author:** Abubakur Sait
**Last Updated:** 13 October 2025
**Tested On:** Ubuntu 22.04 LTS


