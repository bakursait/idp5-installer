#!/bin/bash

# --- Configuration Variables ---
IDP_HOME="/opt/shibboleth-idp"
JETTY_VERSION="12.1.3" # Using a recent stable version
SHIB_IDP_VERSION="5.1.6" # As per original script
SHIB_IDP_HOSTNAME="idp1.home.lab"
SHIB_IDP_FQDN="${SHIB_IDP_HOSTNAME}"
SHIB_IDP_SECRETS_PROPERTIES_FILE="${IDP_HOME}/credentials/secrets.properties"
JAVA_HOME_ENV='/usr/lib/jvm/java-17-amazon-corretto'

# Using the server's actual IP is better, but for a local setup, loopback is fine.
# The user can change this if needed.
LOOP_IP_ADDRESS="127.0.1.1"
IP_ADDRESS="192.168.4.220"

# see: https://stackoverflow.com/a/39340259/5423024
MAIN_SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
SUPPORTING_FILES_PATH="${MAIN_SCRIPT_PATH}/idp5_supporting_files"

# --- LDAP Configuration ---
LDAP_FILES_PATH="${MAIN_SCRIPT_PATH}/ldif_files"
LDAP_PROPERTIES_FILE="${IDP_HOME}/conf/ldap.properties"

LDAP_DC_1=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{print $1}')    # "idp1"
LDAP_DC_2=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{print $(NF-1)}')       # "home"
LDAP_DC_3=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{print $NF}')       # "lab"
LDAP_DC_COMPOSITE="dc=${LDAP_DC_2},dc=${LDAP_DC_3}"     # you can set it like this: "dc=${LDAP_DC_1},dc=${LDAP_DC_2}"
LDAP_DOMAIN=$(echo "${SHIB_IDP_HOSTNAME}" | awk -F'.' '{for(i=2;i<=NF;i++) printf "%s%s", $i, (i<NF?".":"")}')
echo "LDAP_DC_COMPOSITE = ${LDAP_DC_COMPOSITE}"
echo "LDAP_DOMAIN = ${LDAP_DOMAIN}"

LDAP_ADMIN_PASSWORD='admin123'
LDAP_IDPUSER_PASSWORD='idpuser123'

# --- Helper Functions ---

# Function to print messages
echo_message() {
    echo -e "\n--- $1 ---"
}

# Function to check for root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: This script must be run as root or with sudo"
        echo ""
        echo "Usage: sudo $0 --install"
        exit 1
    fi
}



show_usage() {
    cat << EOF
╔════════════════════════════════════════════════════════════════╗
║     Shibboleth IdP v5 Automated Installer                      ║
╚════════════════════════════════════════════════════════════════╝

USAGE:
    $(basename "$0") [OPTION]

OPTIONS:
    -i, --install           Start the installation process
    -p, --print-remaining   Print post-installation tasks (remaining work)
    -h, --help              Show this help message

EXAMPLES:
    # Start installation
    sudo $(basename "$0") --install

    # View remaining tasks after installation
    $(basename "$0") --print-remaining

    # Show help
    $(basename "$0") --help

REQUIREMENTS:
    - Must run with root privileges (use sudo)
    - Ubuntu 22.04 or Debian 11+
    - Internet connectivity
    - Supporting files directory must exist: idp5_supporting_files/

For more information, see README.md

EOF
}








print_env_variables() {
    check_root
    # --- Configuration Variables ---
    echo $IDP_HOME
    echo $JETTY_VERSION
    echo $SHIB_IDP_VERSION
    echo $SHIB_IDP_HOSTNAME
    echo $SHIB_IDP_FQDN
    echo $SHIB_IDP_SECRETS_PROPERTIES_FILE
    
    # Using the server's actual IP is better, but for a local setup, loopback is fine.
    # The user can change this if needed.
    echo "LOOP_IP_ADDRESS ${LOOP_IP_ADDRESS}"
    echo "IP_ADDRESS ${IP_ADDRESS}"
    
    # see: https://stackoverflow.com/a/39340259/5423024
    echo "MAIN_SCRIPT_PATH ${MAIN_SCRIPT_PATH}"
    echo "SUPPORTING_FILES_PATH ${SUPPORTING_FILES_PATH}"
    
    # --- LDAP Configuration ---
    echo "LDAP_FILES_PATH ${LDAP_FILES_PATH}"
    echo "LDAP_PROPERTIES_FILE ${LDAP_PROPERTIES_FILE}"
    
    echo "LDAP_DC_1 ${LDAP_DC_1}"
    echo "LDAP_DC_2 ${LDAP_DC_2}"
    echo "LDAP_DC_COMPOSITE ${LDAP_DC_COMPOSITE}"

    echo "LDAP_ADMIN_PASSWORD ${LDAP_ADMIN_PASSWORD}"
    echo "LDAP_IDPUSER_PASSWORD ${LDAP_IDPUSER_PASSWORD}"
}



# Function to check Ubuntu version
check_os_version() {
    echo_message "Check OS Version, for Compatibility"
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        echo "Warning: This script is tested for Ubuntu 22.04. Your version is $ID-$VERSION_ID."
    else
        echo "OS Check: Ubuntu 22.04 detected."
    fi
}

check_supporting_files_exist() {
    echo_message "Checking Supporting files Availability"
    if [[ ! -d "${SUPPORTING_FILES_PATH}" ]]; then
        echo "Error: Directory ${SUPPORTING_FILES_PATH} does not exist."
        exit 1
    fi
    echo "The directory ${SUPPORTING_FILES_PATH} has been found."
}

check_ldap_dir_availbility(){
    if [ ! -d "${LDAP_FILES_PATH}" ]; then
	echo "${LDAP_FILES_PATH} does not exist... creating"
	mkdir -p "${LDAP_FILES_PATH}"
	chown -R "$(ls -ld ${MAIN_SCRIPT_PATH}/install_local_idp5.sh | awk '{print $3}'):" "${LDAP_FILES_PATH}"
	chmod -R 755 "${LDAP_FILES_PATH}"
    fi
}


# Function to check for internet connectivity
check_internet() {
    echo_message "Checking Internet Connectivity"
    if ! ping -c 3 8.8.8.8 > /dev/null 2>&1; then
        echo "Error: No internet connection. Please check your network settings." >&2
        exit 1
    fi
    echo "Internet connection is available."
}

# Function to restart and check Jetty service
restart_and_check_jetty() {
    echo_message "Restarting Jetty Service"
    if systemctl restart jetty; then
        echo "Jetty restart command issued."
    else
        echo "Error: Failed to issue Jetty restart command." >&2
        journalctl -xeu jetty
        exit 1
    fi

    echo "Waiting for Jetty to initialize..."
    sleep 10

    if systemctl is-active --quiet jetty; then
        echo "Jetty is running successfully."
    else
        echo "Error: Jetty failed to start after restart." >&2
        journalctl -xeu jetty
        exit 1
    fi
    echo "Show the PID for the Jetty service:"
    systemctl show --property MainPID --value jetty.service
}

# Function to update a property in a file
update_property() {
    local property="$1"
    local value="$2"
    local file="$3"

    # Remove existing property to avoid duplicates, then add the new one
    sed -i "/^[#[:space:]]*${property}[[:space:]]*=.*/d" "$file"
    echo "$property = $value" >> "$file"
}


# Function to request confirmation before proceeding
request_confirmation() {
    local message=$1  # Message to display to the user
    echo -e "\n---------------------------------------------------------------------------------------\n"
    echo "$message"
    echo -e "\n---------------------------------------------------------------------------------------\n"
    echo "Please verify the information above carefully."
    echo "Type 'done' to confirm and continue or 'exit' to abort the installation process."

    while true; do
        read -p "Enter your choice (done/exit): " user_input
        case $user_input in
            [Dd][Oo][Nn][Ee])
                echo "Confirmation received. Continuing..."
		return 0  # Success status
                ;;
            [Ee][Xx][Ii][Tt])
                echo "Installation aborted by user."
		return 1  # Failure status
                ;;
            *)
                echo "Invalid input. Please type 'done' to continue or 'exit' to abort."
                ;;
        esac
    done
}

# Function to exit if response ==0:
perform_exit_on_reject_request(){
    local result=$1
    local function_name=$2
    if [ "$1" -ne 0 ]; then
	echo -e "\nExiting configuration process... -- as you did not confirm if the value exist or not; see function ${function_name}"
	exit 1
    fi
}




# --- Installation Functions ---

# Configure Hostname and /etc/hosts
configure_hostname() {
    echo_message "Configuring Hostname and /etc/hosts"
    check_root

    # Set hostname
    if [ "$(hostname)" != "${SHIB_IDP_HOSTNAME}" ]; then
        hostnamectl set-hostname "${SHIB_IDP_HOSTNAME}"
        echo "Hostname set to ${SHIB_IDP_HOSTNAME}."
    else
        echo "Hostname is already set."
    fi

    # Update /etc/hosts
    local hosts_entry="${LOOP_IP_ADDRESS} ${SHIB_IDP_FQDN} ${SHIB_IDP_HOSTNAME}"
    if grep -q "^${LOOP_IP_ADDRESS}" /etc/hosts; then
        sed -i "s/^${LOOP_IP_ADDRESS}.*/${hosts_entry}/" /etc/hosts
        echo "/etc/hosts updated."
    else
        echo "${hosts_entry}" >> /etc/hosts
        echo "Entry added to /etc/hosts."
    fi
}

# Install package dependencies
install_dependencies() {
    echo_message "Installing Dependencies and Apache2 web-server"
    check_root
    
    apt-get update && apt-get upgrade -y --no-install-recommends
    # apt-get install -y fail2ban vim wget gnupg ca-certificates openssl ntp curl apache2 cron xmlstarlet --no-install-recommends
    apt-get install -y fail2ban vim wget gnupg ca-certificates openssl chrony curl apache2 cron xmlstarlet --no-install-recommends
    apt-get autoremove -y
}

# Configure JAVA_HOME environment variable
configure_java_environment() {
    echo_message "Configuring JAVA_HOME"
    check_root
    
    if ! grep -q "^JAVA_HOME" /etc/environment; then
        echo "JAVA_HOME=${JAVA_HOME_ENV}" >> /etc/environment
        echo "JAVA_HOME set in /etc/environment. Please log out and log back in for it to take effect everywhere."
    fi
    export JAVA_HOME="${JAVA_HOME_ENV}"
    source /etc/environment
    echo "JAVA_HOME=${JAVA_HOME}"
    echo
}

# Install Amazon Corretto JDK 17
install_amazon_corretto() {
    echo_message "Installing Amazon Corretto JDK 17"
    # 1. Become ROOT
    check_root
    
    if dpkg -l | grep -qw java-17-amazon-corretto-jdk; then
        echo "Amazon Corretto JDK 17 is already installed."
	java --version
	echo
        return
    fi

    # Correct GPG key import as per HOWTO
    mkdir -p /etc/apt/keyrings
    # 2. Download the Public Key B04F24E3.pub:
    # see the link, if there is any updates: https://docs.aws.amazon.com/corretto/latest/corretto-17-ug/downloads-list.html#signature
    # wget -O /tmp/B04F24E3.pub https://corretto.aws/downloads/resources/17.0.16.8.1/B04F24E3.pub
    wget -O /tmp/B04F24E3.pub https://corretto.aws/downloads/resources/17.0.17.10.1/B04F24E3.pub

    # 3. Convert Public Key into "amazon-corretto.gpg":
    gpg --no-default-keyring --keyring /tmp/temp-keyring.gpg --import /tmp/B04F24E3.pub
    gpg --no-default-keyring --keyring /tmp/temp-keyring.gpg --export --output /etc/apt/keyrings/amazon-corretto.gpg
    rm -f /tmp/temp-keyring.gpg /tmp/B04F24E3.pub /tmp/temp-keyring.gpg~

    # 4. Create an APT source list for Amazon Corretto:
    echo "deb [signed-by=/etc/apt/keyrings/amazon-corretto.gpg] https://apt.corretto.aws stable main" > /etc/apt/sources.list.d/corretto.list

    echo "#deb-src [signed-by=/etc/apt/keyrings/amazon-corretto.gpg] https://apt.corretto.aws stable main" >> /etc/apt/sources.list.d/amazon-corretto.list

    # 5. Install Amazon Corretto:
    apt update
    apt install -y java-17-amazon-corretto-jdk

    # 6. Check that Java is working:
    java --version
    
    echo 
    echo
}



# Install and Configure Jetty
install_jetty() {
    echo_message "Installing Jetty Servlet Container"
    check_root
    local jetty_service_file_path='/etc/systemd/system/jetty.service'
    
    if [ -d "/usr/local/src/jetty-src" ]; then
        echo "Jetty appears to be already installed."
	service jetty check
	#systemctl status jetty.service
        return
    fi

    # 2. Download and Extract Jetty:
    cd /usr/local/src
    wget "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz"
    tar xzvf "jetty-home-${JETTY_VERSION}.tar.gz"

    # 3. Create the jetty-src folder as a symbolic link. It will be useful for future Jetty updates:
    ln -nsf "jetty-home-${JETTY_VERSION}" jetty-src

    # 4. Create the system user jetty that can run the web server (without home directory):
    if ! id "jetty" &>/dev/null; then
        useradd -r -M jetty
    fi

    # 5. & 6. & 7.:
    mkdir -p /opt/jetty/tmp /var/log/jetty /opt/jetty/logs
    chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src /var/log/jetty /opt/jetty/logs

    # Use configuration from the official HOWTO source
    wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-start.ini" -O /opt/jetty/start.ini

    # 8. Configure /etc/default/jetty:
    cat > /etc/default/jetty <<EOF
JETTY_HOME=/usr/local/src/jetty-src
JETTY_BASE=/opt/jetty
JETTY_PID=/opt/jetty/jetty.pid
JETTY_USER=jetty
JETTY_START_LOG=/var/log/jetty/start.log
TMPDIR=/opt/jetty/tmp
EOF

    # 9. Create the service loadable from command line:
    # Configure Jetty Service
    cd /etc/init.d
    ln -s /usr/local/src/jetty-src/bin/jetty.sh jetty
    
    cp /usr/local/src/jetty-src/bin/jetty.service "${jetty_service_file_path}"
    
    # Fix the PIDFile parameter with the JETTY_PID path:
    echo 'Fix the PIDFile parameter with the JETTY_PID path'
    sed -i 's|^PIDFile=.*|PIDFile=/opt/jetty/jetty.pid|' "${jetty_service_file_path}"
    # we can use crudini:
    # crudini --set "${jetty_service_file_path}" Service PIDFile '/opt/jetty/jetty.pid'
    echo
    cat "${jetty_service_file_path}"
    echo
    echo
    
    echo 'enabling Jetty service'
    systemctl daemon-reload
    systemctl enable jetty.service
    
    echo
    # 10. Install Servlet Jakarta API and configure LogBack
    echo 'Install Servlet Jakarta API and configure LogBack'
    apt-get install -y libjakarta-servlet-api-java
    echo
    
    
    # 11. Install & configure LogBack for all Jetty logging:
    echo 'Install & configure LogBack for all Jetty logging'
    cd /opt/jetty
    java -jar /usr/local/src/jetty-src/start.jar --add-module=logging-logback
    mkdir -p /opt/jetty/etc /opt/jetty/resources
    wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-requestlog.xml" -O /opt/jetty/etc/jetty-requestlog.xml
    
    wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-logging.properties" -O /opt/jetty/resources/jetty-logging.properties

    chown -R jetty:jetty /opt/jetty
    
    echo
    echo
    
    # 12. Check if all settings are OK:
    echo "Checking Jetty for the first time... should be not Running:"
    service jetty check
    # service jetty start
    echo 'Starting the Jetty service...'
    # systemctl start jetty.service
    sleep 5
    restart_and_check_jetty
    
    echo "Now checking if the status of Jetty service"
    if ! systemctl start jetty.service >/dev/null; then 
      echo 
      echo
      echo 'Something went wrong, we will try another way around:'
      rm /opt/jetty/jetty.pid
      if ! systemctl start jetty.service; then
        echo "We still having the an issue sarting Jetty service. Fix it manually. Exiting for now."
        exit 1
      fi
    fi
    echo "Jetty service has been successfully installed"
    service jetty check
    echo "Show the PID for the Jetty service:"
    systemctl show --property MainPID --value jetty.service
    
    
    echo
    echo
    echo
}



# Install and Configure Shibboleth IdP
install_shibboleth() {
    echo_message "Installing Shibboleth Identity Provider"
    check_root

    
    if [ -d "${IDP_HOME}" ]; then
        echo "Shibboleth IdP appears to be already installed."
        return
    fi
    

    local ENTITY_ID="https://${SHIB_IDP_FQDN}/idp/shibboleth"
    local SCOPE=$(echo ${SHIB_IDP_FQDN} | cut -d "." -f 2-)

    # 2. Download the Shibboleth Identity Provider, see the link: https://shibboleth.net/downloads/identity-provider/
    cd /usr/local/src
    wget "http://shibboleth.net/downloads/identity-provider/${SHIB_IDP_VERSION}/shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz"
    wget "https://shibboleth.net/downloads/identity-provider/${SHIB_IDP_VERSION}/shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz.asc"
    wget https://shibboleth.net/downloads/PGP_KEYS

    # 3. Validate the package downloaded:
    gpg --import /usr/local/src/PGP_KEYS
    if ! gpg --verify "shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz.asc" "shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz"; then
        echo "Error: Shibboleth IdP download verification failed." >&2
        exit 1
    fi
    echo "Shibboleth IdP download verified."
    
    # 4. extract IdP package:
    tar -xzf "shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz"
    
    cd /usr/local/src
    cd "shibboleth-identity-provider-${SHIB_IDP_VERSION}/bin"

    # 5. Install Identity Provider Shibboleth:
    # see the link: https://shibboleth.atlassian.net/wiki/spaces/IDP5/pages/3199500577/Installation
    ./install.sh \
        --hostName "${SHIB_IDP_FQDN}" \
        --noPrompt \
        --targetDir "${IDP_HOME}" \
        --entityID "${ENTITY_ID}" \
        --scope "${SCOPE}"

    # 6.fix the IdP metadata at /opt/shibboleth-idp/idp-metadata.xml
    # Fix for specific version typo
    if [ "${SHIB_IDP_VERSION}" == "5.1.6" ]; then
        fix_metadata_typo
    fi
    
    
    restart_and_check_jetty
}

fix_metadata_typo() {
    echo_message "Applying metadata typo fix for IdP v5.1.6"
    check_root
    
    local METADATA_FILE="${IDP_HOME}/metadata/idp-metadata.xml"
    if [ -f "$METADATA_FILE" ]; then
        sed -i 's|<md:EntityDescriptorentityID|<md:EntityDescriptor entityID|' "$METADATA_FILE"
        echo "Typo in idp-metadata.xml fixed."
    fi
}

# Disable Jetty Directory Indexing and Rebuild WAR
disable_directory_indexing() {
    echo_message "Disabling Directory Indexing"
    check_root

    
    #rm -rf "${IDP_HOME}/edit-webapp/WEB-INF"
    mkdir -p "${IDP_HOME}/edit-webapp/WEB-INF"
    cp "${IDP_HOME}/dist/webapp/WEB-INF/web.xml" "${IDP_HOME}/edit-webapp/WEB-INF/web.xml"
    
    echo "Rebuilding IdP WAR file..."
    bash "${IDP_HOME}/bin/build.sh"
    restart_and_check_jetty
}

# Configure Jetty Context for the IdP
configure_jetty_context() {
    echo_message "Configuring Jetty Context for IdP"
    check_root
    
    mkdir -p /opt/jetty/webapps
    # Using the provided context file
    echo "getting Jetty Webapp sample IdP file from the main repo:"
    wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.xml" -O /opt/jetty/webapps/idp.xml

    cd "${IDP_HOME}"  # /opt/shibboleth-idp/
    chown -R jetty:jetty "${IDP_HOME}/logs" "${IDP_HOME}/metadata" "${IDP_HOME}/credentials" "${IDP_HOME}/conf" "${IDP_HOME}/war"
    
    restart_and_check_jetty
}





# Configure Apache as a Reverse Proxy
configure_apache() {
    echo_message "Configuring Apache as Reverse Proxy"
    check_root

    
    # Create DocumentRoot
    local doc_root="/var/www/html/${SHIB_IDP_FQDN}"

    # 2. Create the DocumentRoot:
    echo "2"
    mkdir -p "${doc_root}"
    chown -R www-data: "${doc_root}"
    echo '<h1>Shibboleth IdP is running!</h1>' > "${doc_root}/index.html"

    # 3. Generate Self-Signed SSL Certificate
    echo "3"
    local subj="/C=US/ST=Local/L=City/O=Local Org/OU=IT/CN=${SHIB_IDP_FQDN}"
    openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
        -keyout "/etc/ssl/private/${SHIB_IDP_FQDN}.key" \
        -out "/etc/ssl/certs/${SHIB_IDP_FQDN}.crt" \
        -subj "${subj}"

    # 4. Configure the right privileges for the SSL Certificate and Key used by HTTPS:
    echo "4"
    chmod 400 "/etc/ssl/private/${SHIB_IDP_FQDN}.key"
    chmod 644 "/etc/ssl/certs/${SHIB_IDP_FQDN}.crt"

    
    # 5. Enable required Apache modules
    echo "5"
    a2enmod proxy_http ssl headers alias include negotiation



    # Use the provided Apache configuration template
    echo "6"
    #wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.example.org.conf -O /etc/apache2/sites-available/$(hostname -f).conf
    cp "${SUPPORTING_FILES_PATH}/Apache2_as_front_end_of_Jetty_template.conf" "/etc/apache2/sites-available/${SHIB_IDP_FQDN}.conf"
    
    
    
    # Customize the template
    echo "7"
    local apache_conf="/etc/apache2/sites-available/${SHIB_IDP_FQDN}.conf"
    echo "update the Apache file: '${apache_conf}' to fit our needs"
    
    sed -i "s/idp.example.org/${SHIB_IDP_FQDN}/g" "${apache_conf}"
    sed -i "s|/var/www/html/idp.example.org|${doc_root}|g" "${apache_conf}"
    sed -i 's|ServerAdmin admin@example.org|ServerAdmin admin@${SHIB_IDP_FQDN}|g' "${apache_conf}"
    sed -i "s|/etc/ssl/certs/idp.example.org.crt|/etc/ssl/certs/${SHIB_IDP_FQDN}.crt|g" "${apache_conf}"
    sed -i "s|/etc/ssl/private/idp.example.org.key|/etc/ssl/private/${SHIB_IDP_FQDN}.key|g" "${apache_conf}"
    sed -i "s|[#[:space:]]SSLCACertificateFile|# SSLCACertificateFile|g" "${apache_conf}"
    sed -i "/[#[:space:]]SSLCACertificateFile.*/d" "${apache_conf}"
    
    echo 
    echo
    echo "display the Apache file: '${apache_conf}':"
    cat  "${apache_conf}"
    echo 
    echo
    


    # Disable default sites and enable the new IdP site
    echo "8"
    a2dissite 000-default.conf default-ssl.conf
    a2ensite "${SHIB_IDP_FQDN}.conf"
    
    
    echo "9"
    systemctl enable apache2.service
    systemctl restart apache2.service
    echo "Apache configuration is complete."
}

# Install and Configure OpenLDAP
install_openldap() {
    echo_message "Installing and Configuring OpenLDAP"
    check_root

    
    if dpkg -l | grep -qw slapd; then
        echo "OpenLDAP is already installed."
        return
    fi

    # Pre-seed debconf to avoid interactive prompts
    cat <<EOF > "${LDAP_FILES_PATH}/slapd.seed"
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/domain string ${LDAP_DOMAIN}
slapd slapd/organization string "${LDAP_DOMAIN}"
slapd slapd/no_configuration boolean false
slapd slapd/backend select MDB
slapd slapd/purge_database boolean false
EOF

    debconf-set-selections "${LDAP_FILES_PATH}/slapd.seed"
    apt-get install -y slapd ldap-utils

    # Setup DIT structure
    setup_ldap_dit
}

# Setup LDAP Directory Information Tree (DIT)
setup_ldap_dit() {
    echo_message "Setting up LDAP DIT"
    check_root

    
    # Create OUs
    cat <<EOF > "${LDAP_FILES_PATH}/ou-structure.ldif"
dn: ou=system,${LDAP_DC_COMPOSITE}
objectClass: organizationalUnit
ou: system

dn: ou=people,${LDAP_DC_COMPOSITE}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_DC_COMPOSITE}
objectClass: organizationalUnit
ou: groups
EOF
    ldapadd -x -D "cn=admin,${LDAP_DC_COMPOSITE}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_FILES_PATH}/ou-structure.ldif"

    # Add idpuser for Shibboleth
    local hashed_password=$(slappasswd -s "$LDAP_IDPUSER_PASSWORD")
    cat <<EOF > "${LDAP_FILES_PATH}/idpuser.ldif"
dn: cn=idpuser,ou=system,${LDAP_DC_COMPOSITE}
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: idpuser
userPassword: ${hashed_password}
description: Service account for Shibboleth IdP
EOF
    ldapadd -x -D "cn=admin,${LDAP_DC_COMPOSITE}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_FILES_PATH}/idpuser.ldif"

    # Add sample users
    add_ldap_user "johnsmith" "smith123" "John Smith" "1001"
    add_ldap_user "jacobdan" "dan123" "Jacob Dan" "1002"
}

# Helper to add a sample user to LDAP
add_ldap_user() {
    local uid="$1"
    local password="$2"
    local cn="$3"
    local uid_number="$4"
    local hashed_password=$(slappasswd -s "$password")

    cat <<EOF > "${LDAP_FILES_PATH}/${uid}.ldif"
dn: uid=${uid},ou=people,${LDAP_DC_COMPOSITE}
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: ${cn}
sn: ${cn##* }
uid: ${uid}
uidNumber: ${uid_number}
gidNumber: ${uid_number}
homeDirectory: /home/${uid}
loginShell: /bin/bash
userPassword: ${hashed_password}
mail: ${uid}@${LDAP_DC_COMPOSITE}
EOF
    ldapadd -x -D "cn=admin,${LDAP_DC_COMPOSITE}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDAP_FILES_PATH}/${uid}.ldif"
}

# Configure Shibboleth to use LDAP - Solution 3 - plain LDAP:
configure_shibboleth_ldap() {
    echo_message "Configuring Shibboleth for LDAP Authentication"
    check_root
    
    echo "Check we can reach the LDAP directory from the IdP server:"
    if ldapsearch -x -LLL -H ldap://localhost -D "cn=idpuser,ou=system,${LDAP_DC_COMPOSITE}" -w "${LDAP_IDPUSER_PASSWORD}" -b "ou=people,${LDAP_DC_COMPOSITE}" "(uid=jacobdan)" > /dev/null 2>&1; then
	echo "✓ LDAP connection successful -- via idpuser"
    else
        echo "✗ LDAP connection failed -- via idpuser"
        #return 1
	exit 1
    fi
    
    # 1. Update secrets.properties for LDAP credentials
    update_property "idp.authn.LDAP.bindDNCredential" "${LDAP_IDPUSER_PASSWORD}" "${SHIB_IDP_SECRETS_PROPERTIES_FILE}"
    update_property "idp.attribute.resolver.LDAP.bindDNCredential" '%{idp.authn.LDAP.bindDNCredential:undefined}' "${SHIB_IDP_SECRETS_PROPERTIES_FILE}"

    # 2. Update ldap.properties for plain LDAP connection
    update_property "idp.authn.LDAP.authenticator" "bindSearchAuthenticator" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.ldapURL" "ldap://${SHIB_IDP_FQDN}" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.useStartTLS" "false" "$LDAP_PROPERTIES_FILE"

    update_property "idp.authn.LDAP.baseDN" "ou=people,${LDAP_DC_COMPOSITE}" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.bindDN" "cn=idpuser,ou=system,${LDAP_DC_COMPOSITE}" "$LDAP_PROPERTIES_FILE"
    

    
    update_property "idp.authn.LDAP.userFilter" "(uid={user})" "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.searchFilter" "(uid=\$resolutionContext.principal)" "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.exportAttributes" "uid cn sn givenName mail eduPersonAffiliation" "$LDAP_PROPERTIES_FILE"


    # additional properties:
    update_property "idp.authn.LDAP.returnAttributes" "passwordExpirationTime,loginGraceRemaining" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.subtreeSearch" "false" "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.useStartTLS" '%{idp.authn.LDAP.useStartTLS:true}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.trustCertificates" '%{idp.authn.LDAP.trustCertificates:undefined}' "$LDAP_PROPERTIES_FILE"
    
    update_property "idp.attribute.resolver.LDAP.ldapURL" '%{idp.authn.LDAP.ldapURL}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.connectTimeout" '%{idp.authn.LDAP.connectTimeout:PT3S}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.responseTimeout" '%{idp.authn.LDAP.responseTimeout:PT3S}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.connectionStrategy" '%{idp.authn.LDAP.connectionStrategy:ACTIVE_PASSIVE}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.baseDN" '%{idp.authn.LDAP.baseDN:undefined}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.bindDN" '%{idp.authn.LDAP.bindDN:undefined}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.startTLSTimeout" '%{idp.authn.LDAP.startTLSTimeout:PT3S}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.trustCertificates" '%{idp.authn.LDAP.trustCertificates:undefined}' "$LDAP_PROPERTIES_FILE"

    

    restart_and_check_jetty
    bash "${IDP_HOME}/bin/status.sh"
}



test_ldap_installation() {
    echo_message "Testing LDAP Installation"
    
    if ldapsearch -x -LLL -H ldap://localhost -b "${LDAP_DC_COMPOSITE}" \
        -D "cn=admin,${LDAP_DC_COMPOSITE}" -w "${LDAP_ADMIN_PASSWORD}" > /dev/null 2>&1; then
        echo "✓ LDAP connection successful"
    else
        echo "✗ LDAP connection failed"
        #return 1
	exit 1
    fi
    if ldapsearch -x -LLL -H ldap://localhost -D "cn=idpuser,ou=system,${LDAP_DC_COMPOSITE}" -w "${LDAP_IDPUSER_PASSWORD}" -b "ou=people,${LDAP_DC_COMPOSITE}" "(uid=jacobdan)" > /dev/null 2>&1; then
	echo "✓ LDAP connection successful -- via idpuser"
    else
        echo "✗ LDAP connection failed -- via idpuser"
        #return 1
	exit 1
    fi
	
}






# Configure Persistent NameID
configure_persistent_nameid() {
    echo_message "Configuring Persistent NameID -- Strategy A"
    check_root

    local configuration_details=$(cat <<EOF
on another terminal, please make sure to add the following lines in the files:

1. open file '/opt/shibboleth-idp/conf/saml-nameid.properties':
  1.1. The sourceAttribute MUST be an attribute, or a list of comma-separated attributes, that uniquely identify the subject of the generated persistent-id. The sourceAttribute MUST be a Stable, Permanent and Not-reassignable directory attribute.

       # ... other things ...#
       # OpenLDAP has the UserID into "uid" attribute
       idp.persistentId.sourceAttribute = uid

       # Active Directory has the UserID into "sAMAccountName"
       #idp.persistentId.sourceAttribute = sAMAccountName
       # ... other things ...#

2. open file '/opt/shibboleth-idp/conf/saml-nameid.xml':
  2.1. Uncomment the line:

       <ref bean="shibboleth.SAML2PersistentGenerator" />

3. set the salt value:
  3.1. run the command:

       openssl rand -base64 36

  3.2. open the file: '/opt/shibboleth-idp/credentials/secrets.properties' and run the past the value of point 3.1.:
       idp.persistentId.salt = ### result of command 'openssl rand -base64 36' ###
EOF
	  )
    request_confirmation "${configuration_details}"
    perform_exit_on_reject_request "$?" "${FUNCNAME[0]}"

    
#    local saml_nameid_properties="${IDP_HOME}/conf/saml-nameid.properties"
#    local saml_nameid_xml="${IDP_HOME}/conf/saml-nameid.xml"
#    local salt_secret="${IDP_HOME}/credentials/secrets.properties"
#
#    update_property "idp.persistentId.sourceAttribute" "uid" "${saml_nameid_properties}"
#    
#    # Ensure PersistentGenerator is enabled
#    if ! grep -q 'ref bean="shibboleth.SAML2PersistentGenerator"' "${saml_nameid_xml}"; then
#        sed -i '/<ref bean="shibboleth.SAML2TransientGenerator" \/>/a \        <ref bean="shibboleth.SAML2PersistentGenerator" />' "${saml_nameid_xml}"
#    fi
#
#    # Generate and add salt to secrets.properties
#    local salt=$(#openssl rand -base64 36)
#    update_property "idp.persistentId.salt" "${salt}" "${salt_secret}"

    restart_and_check_jetty
    bash "${IDP_HOME}/bin/status.sh"
    
}

# Configure Attribute Resolver
configure_attribute_resolver() {
    echo_message "Configuring Attribute Resolver"
    check_root
    
    wget https://conf.idem.garr.it/idem-attribute-resolver-shib-v5.xml -O "${IDP_HOME}/conf/attribute-resolver.xml"
    if ! wget https://conf.idem.garr.it/idem-attribute-resolver-shib-v5.xml -O "${IDP_HOME}/conf/attribute-resolver.xml"; then
        echo "we could not find the file 'attribute-resolver.xml'"
        echo 'check the the github repo: https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-the-attribute-resolver-sample'
        exit 1
    fi
    
#    if ! cp "${SUPPORTING_FILES_PATH}/attribute-resolver-v5-idem-sample.xml" "${IDP_HOME}/conf/attribute-resolver.xml"; then
#	if ! wget https://conf.idem.garr.it/idem-attribute-resolver-shib-v5.xml -O "${IDP_HOME}/conf/attribute-resolver.xml"; then
#	    echo "we could not find the file 'attribute-resolver.xml'"
#	    echo 'check the the github repo: https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-the-attribute-resolver-sample'
#	    exit 1
#	fi
#    fi


    local configuration_details=$(cat <<EOF
Open a new terminal, and perform the following:
1. since we are using the plain text LDAP solution (see the HOWTO GitHub repo 'https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-the-attribute-resolver-sample' ), remove or comment the following directives from your Attribute Resolver file '/opt/shibboleth-idp/conf/attribute-resolver.xml':

  Line 1:  useStartTLS="%{idp.attribute.resolver.LDAP.useStartTLS:true}"
  Line 2:  trustFile="%{idp.attribute.resolver.LDAP.trustCertificates}"

EOF
	  )
    request_confirmation "${configuration_details}"
    perform_exit_on_reject_request "$?" "${FUNCNAME[0]}"
    

#    # Remove TLS-related settings for plain LDAP
#    sed -i '/useStartTLS/d' "${IDP_HOME}/conf/attribute-resolver.xml"
#    sed -i '/trustFile/d' "${IDP_HOME}/conf/attribute-resolver.xml"
#
    
    chown jetty "${IDP_HOME}/conf/attribute-resolver.xml"
    
    restart_and_check_jetty
    bash "${IDP_HOME}/bin/status.sh"
}





# Configure eduPersonTargetedID
configure_eduPersonTargetedID_confirm_required() {
    # We are following Strategy A - Computed mode - using the computed persistent NameID - Recommended
    
    echo_message "Configuring eduPersonTargetedID"
    check_root
    
    
    # Ensure the attribute resolver XML includes the necessary definitions for eduPersonTargetedID
    # Add or ensure the following entries exist in /opt/shibboleth-idp/conf/attribute-resolver.xml
    local configuration_details=$(cat <<EOF
please make sure the following script is added into '/opt/shibboleth-idp/conf/attribute-resolver.xml' file:


<!-- AttributeDefinition for eduPersonTargetedID - Computed Mode -->
<!--
      WARN [DEPRECATED:173] - xsi:type 'SAML2NameID'
      This feature is at-risk for removal in a future version

      NOTE: eduPersonTargetedID is DEPRECATED and should not be used.
-->

<AttributeDefinition xsi:type="SAML2NameID" nameIdFormat="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent" id="eduPersonTargetedID">
    <InputDataConnector ref="computed" attributeNames="computedId" />
</AttributeDefinition>

<!-- ... other things... -->

<!-- Data Connector for eduPersonTargetedID - Computed Mode -->
<DataConnector id="computed" xsi:type="ComputedId"
    generatedAttributeID="computedId"
    salt="%{idp.persistentId.salt}"
    algorithm="%{idp.persistentId.algorithm:SHA}"
    encoding="%{idp.persistentId.encoding:BASE32}">
    <InputDataConnector ref="myLDAP" attributeNames="%{idp.persistentId.sourceAttribute}" />
</DataConnector>
EOF
	  )
    
    request_confirmation "${configuration_details}"
    perform_exit_on_reject_request "$?" "${FUNCNAME[0]}"
    
    
    echo "Proceeding with further configuration..."

    
    # Download custom eduPersonTargetedID properties
    echo "Create the custom eduPersonTargetedID.properties file.."
    wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/eduPersonTargetedID.properties" -O "${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties"
    # cp "${SUPPORTING_FILES_PATH}/eduPersonTargetedID.properties.txt" "${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties"

    

    # Set the correct owner
    echo "Set proper owner/group with:"
    chown jetty:root "${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties"

    # Restart Jetty to apply changes
    #service jetty restart
    restart_and_check_jetty

    # Check IdP status
    bash "${IDP_HOME}/bin/status.sh"
}


# Configure IdP Logging
configure_idp_logging() {
    echo_message "Configuring IdP Logging"
    check_root

    
    local logback_file="${IDP_HOME}/conf/logback.xml"
    if ! grep -q '<!-- Logs on LDAP user authentication - ADDED BY CORRECTED SCRIPT -->' "$logback_file"; then
        sed -i '|^[[:space:]]<logger name="org.ldaptive".*|a \
    <!-- Logs on LDAP user authentication - ADDED BY CORRECTED SCRIPT -->\
    <logger name="org.ldaptive.auth.Authenticator" level="INFO" />' "$logback_file"
    fi

#    # Insert a comment for clarity in the logback configuration
#    sed -i '/^    <logger name="org.ldaptive".*/a \\n    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->' "${IDP_HOME}/conf/logback.xml"
#
#    # Add a new logger entry specifically for LDAP authentication errors
#    sed -i '/^    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->/a \ \ \ \ <logger name="org.ldaptive.auth.Authenticator" level="INFO" />' "${IDP_HOME}/conf/logback.xml"
    bash "${IDP_HOME}/bin/status.sh"
}



# Secure Cookies and IdP Data
secure_cookies_and_idp_data(){
    echo_message "Securing Cookies and IdP Data"
    check_root
    
    
    wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/updateIDPsecrets.sh -O /opt/shibboleth-idp/bin/updateIDPsecrets.sh
    #cp "${SUPPORTING_FILES_PATH}/updateIDPsecrets.sh" "${IDP_HOME}/bin/updateIDPsecrets.sh"
    chmod +x "${IDP_HOME}/bin/updateIDPsecrets.sh"
    
    cat > /etc/cron.daily/updateIDPsecrets <<EOF
#!/bin/bash
${IDP_HOME}/bin/updateIDPsecrets.sh
EOF
    chmod +x /etc/cron.daily/updateIDPsecrets

    run-parts --test /etc/cron.daily
    bash "${IDP_HOME}/bin/status.sh"
}


# --- Remain Work ---
Remaining_work() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          POST-INSTALLATION TASKS                               ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "The automated installation is complete! However, some manual tasks"
    echo "remain to fully configure and customize your Shibboleth IdP."
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  1. CUSTOMIZE IDP LOGIN PAGE"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "Add your institutional logo and branding:"
    echo ""
    echo "  • Logo requirements: 80x60 pixels, PNG format"
    echo "  • Location: ${IDP_HOME}/edit-webapp/images/"
    echo "  • File name: logo.png"
    echo ""
    echo "Steps:"
    echo "  1. Copy your logo:"
    echo "     cp /path/to/your/logo.png ${IDP_HOME}/edit-webapp/images/logo.png"
    echo ""
    echo "  2. Add the logo's path to: ${IDP_HOME}/messages/messages.properties:"
    echo "     idp.logo = /images/idp-logo.png"
    echo ""
    echo "  3. Update the IdP metadata logo path to (metadata file: ${IDP_HOME}/metadata/idp-metadata.xml)"
    echo "     <mdui:Logo xml:lang='en' width='80' height='80'>https://${SHIB_IDP_FQDN}/images/idp-logo.png</mdui:Logo>"
    echo ""
    echo "  4. Rebuild IdP WAR file:"
    echo "     bash ${IDP_HOME}/bin/build.sh"
    echo ""
    echo "  5. Restart Jetty:"
    echo "     systemctl restart jetty"
    echo ""
    echo "Reference:"
    echo "  https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#enrich-idp-login-page-with-the-institutional-logo"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  2. CONNECT A SERVICE PROVIDER (SP)"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "To test authentication, connect a Service Provider to your IdP:"
    echo ""
    echo "Steps:"
    echo "  1. Obtain SP metadata (XML file from your SP)"
    echo ""
    echo "  2. Add SP metadata to IdP:"
    echo "     emacs ${IDP_HOME}/conf/metadata-providers.xml"
    echo ""
    echo "     Add inside <MetadataProvider> tag:"
    echo '     <MetadataProvider id="LocalSP"'
    echo '         xsi:type="FilesystemMetadataProvider"'
    echo -e "      backingFile=\"${IDP_HOME}/metadata/sp-metadata.xml\""
    echo -e "      metadataFile=\"https://sp.example.org/Shibboleth.sso/Metadata\""
    echo -e "      failFastInitialization=\"false\"/>"
    
    echo "     OR, if you have the SP metadata file stored in your IdP:"
    echo "     Add inside <MetadataProvider> tag:"
    echo '     <MetadataProvider id="LocalSP"'
    echo '         xsi:type="FilesystemMetadataProvider"'
    echo -e "      backingFile=\"${IDP_HOME}/metadata/sp-metadata.xml\" />"
    
    echo "     NOTE: change the 'id' value for each block '<MetadataProvider>' you add."
    echo ""
    echo "  3. Configure attribute release policy:"
    echo "       wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idem-example-arp.txt -O ${IDP_HOME}/conf/example-arp.txt"
    echo "     cat ${IDP_HOME}/conf/example-arp.txt"
    echo "     Copy the content of the file '${IDP_HOME}/conf/example-arp.txt' and paste it before </AttributeFilterPolicyGroup> in the file:"
    echo "         '${IDP_HOME}/conf/attribute-filter.xml'"
    echo ""
    echo "     Update ### SP-ENTITYID ### with the actual SP entityID."
    echo ""
    echo "     Example policy:"
    echo '     <AttributeFilterPolicy id="releasePolicyToSP">'
    echo '         <PolicyRequirementRule xsi:type="Requester"'
    echo '             value="### SP-ENTITYID ###" />'
    echo '         <AttributeRule attributeID="eduPersonPrincipalName">'
    echo '             <PermitValueRule xsi:type="ANY" />'
    echo '             d'
    echo '         </AttributeRule>'
    echo '     </AttributeFilterPolicy>'
    echo ""
    echo "  4. Restart Jetty:"
    echo "     systemctl restart jetty"
    echo ""
    echo "Reference:"
    echo "  https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#appendix-d-connect-an-sp-with-the-idp"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  3. REPLACE SELF-SIGNED SSL CERTIFICATES (PRODUCTION)"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "For production use, replace self-signed certificates with CA-signed ones:"
    echo ""
    echo "Steps:"
    echo "  1. Obtain certificates from your Certificate Authority"
    echo ""
    echo "  2. Copy certificates:"
    echo "     cp your-cert.crt /etc/ssl/certs/${SHIB_IDP_HOSTNAME}.crt"
    echo "     cp your-key.key /etc/ssl/private/${SHIB_IDP_HOSTNAME}.key"
    echo ""
    echo "  3. Set permissions:"
    echo "     chmod 644 /etc/ssl/certs/${SHIB_IDP_HOSTNAME}.crt"
    echo "     chmod 600 /etc/ssl/private/${SHIB_IDP_HOSTNAME}.key"
    echo ""
    echo "  4. Restart Apache:"
    echo "     systemctl restart apache2"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  4. REGISTER HOSTNAMES IN '/etc/hosts'"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "If your are not using DNS server to control your machines, do the following:"
    echo "Add the machine's IP and hostname to all devices in the network:"
    echo ""
    echo -e "Steps:"
    echo -e "\t3.1 Access \"/etc/hosts\" and add the following line:"
    echo -e "\t    \"${IP_ADDRESS}	${SHIB_IDP_FQDN}\""
    echo -e "\t    where:"
    echo -e "\t      \"${IP_ADDRESS}\" is the IdP's private IP in my network, locally. -- YOURS MIGHT BE DIFFERENT. just check your IdP's IP address"
    echo -e "\t      \"${SHIB_IDP_FQDN}\" is the IdPs's Fully Qualified Domain Name."
    echo
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  5. CONFIGURE FIREWALL (PRODUCTION)"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "Allow necessary ports:"
    echo ""
    echo "  ufw allow 80/tcp    # HTTP"
    echo "  ufw allow 443/tcp   # HTTPS"
    echo "  ufw enable"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  6. CHANGE DEFAULT PASSWORDS (CRITICAL)"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "Change LDAP passwords for production:"
    echo ""
    echo "  • LDAP admin password: admin123 (CHANGE THIS!)"
    echo "  • LDAP idpuser password: idpuser123 (CHANGE THIS!)"
    echo "  • Sample user passwords: smith123, dan123 (CHANGE OR DELETE!)"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo "  USEFUL COMMANDS"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "  # Check IdP status"
    echo "  bash /opt/shibboleth-idp/bin/status.sh"
    echo ""
    echo "  # View IdP logs"
    echo "  tail -f /opt/shibboleth-idp/logs/idp-process.log"
    echo ""
    echo "  # Restart services"
    echo "  systemctl restart jetty"
    echo "  systemctl restart apache2"
    echo ""
    echo "  # Test LDAP"
    echo "  ldapsearch -x -H ldap://localhost -D \"cn=admin,${LDAP_DC_COMPOSITE}\" -w \"admin123\" -b \"${LDAP_DC_COMPOSITE}\""
    echo ""
    echo "  # Access IdP metadata"
    echo "  curl -k https://${SHIB_IDP_HOSTNAME}/idp/shibboleth"
    echo ""
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "To view these tasks again, run:"
    echo "  $(basename "$0") --print-remaining"
    echo ""
    echo "For more information, see README.md"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
}





# --- Main Execution ---
main() {
    check_root
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║          INSTALLATION START!                                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    print_env_variables
    check_os_version
    check_internet
    check_supporting_files_exist
    check_ldap_dir_availbility
    
    

    configure_hostname
    configure_java_environment
    install_dependencies
    install_amazon_corretto
    install_jetty
    # exit 0
    install_shibboleth
    disable_directory_indexing
    configure_jetty_context
    configure_apache
    #exit 0

    # step: Configure Shibboleth Identity Provider Storage Service -- recommended approach no action required
    
    
    install_openldap
    configure_shibboleth_ldap
    test_ldap_installation
    
    configure_persistent_nameid  # MUST be done MANUALLY
    configure_attribute_resolver # for safety: done it MANUALLY
    configure_eduPersonTargetedID_confirm_required # MUST be done MANUALLY

    configure_idp_logging
    secure_cookies_and_idp_data
    
    
    echo_message "Shibboleth IdP Installation and Configuration Complete!"
    echo "Please review all logs and test the IdP functionality."
    echo "You can check the IdP status with: bash ${IDP_HOME}/bin/status.sh"
    echo "IdP metadata is available at: https://${SHIB_IDP_FQDN}/idp/shibboleth"
    echo
    echo
    echo
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "           INSTALLATION COMPLETE!                                 "
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    Remaining_work
}







# ----------------------------------------------------------------------------
# Main Menu
# ----------------------------------------------------------------------------
# Parse command-line arguments
case "${1:-}" in
    -i|--install)
        # Check if running as root
        check_root
        
        # Run the main installation
        main "$@"
        ;;
        
    -p|--print-remaining)
        # Print remaining tasks (doesn't require root)
        Remaining_work
        ;;
        
    -h|--help)
        # Show help
        show_usage
        ;;
        
    "")
        # No arguments - show usage
        show_usage
        exit 0
        ;;
        
    *)
        # Unknown option
        echo "Error: Unknown option: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

