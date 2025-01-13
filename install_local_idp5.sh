#!/bin/bash

IDP_HOME="/opt/shibboleth-idp"
IP_ADDRESS="192.168.4.120"
LOOP_IP_ADDRESS="127.0.1.1"
JETTY_VERSION="11.0.22"
SHIB_IDP_VERSION="5.1.3
"
SHIB_IDP_HOSTNAME="idp.localtest1"
SHIB_IDP_FQDN="${SHIB_IDP_HOSTNAME}"
SHIB_IDP_SECRETS_PROPERTIES_FILE="${IDP_HOME}/credentials/secrets.properties"



# see: https://stackoverflow.com/a/39340259/5423024
SUPPORTING_FILES_PATH="$(cd "$(dirname "$0")" && pwd)/idp5_supporting_files"

LDAP_PROPERTIES_FILE="${IDP_HOME}/conf/ldap.properties"
LDAP_FILES_PATH="$(cd "$(dirname "$0")" && pwd)/ldif_files"
LDAP_DC_1="idp"
LDAP_DC_2="localtest1"

# ensure you accessed as a root:

if [ "$(id -u)" != "0" ]; then
    echo "This script must run as root" 1>&2
    exit 1
fi

# Check if the Ubuntu version is 22.04:
# you can source the file and use var's value

source /etc/os-release
if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "22.04" ]; then
    echo "this installation works ONLY on $ID-$VERSION_ID"
    exit 1
else
    echo "It works. you system is $ID-$VERSION_ID"
fi


# check if you have internet access; otherwise stop the process:
#...




restart_and_check_jetty() {
    echo "Restarting Jetty service..."
    
    # Restart the Jetty service
    if systemctl restart jetty; then
        echo "Jetty restart command executed successfully."
    else
        echo "Error: Failed to execute the Jetty restart command."
        echo "Please check the service logs for details:"
        echo "  journalctl -xeu jetty"
        exit 1  # Exit with a failure status
    fi

    # Give the service a few seconds to settle
    echo "Waiting for Jetty to stabilize..."
    sleep 5

    # Check if Jetty is running
    if systemctl is-active --quiet jetty; then
        echo "Jetty is running successfully."
    else
        echo "Error: Jetty failed to start."
        echo "Please check the service logs for details:"
        echo "  journalctl -xeu jetty"
        echo "Ensure all configuration files are set correctly."
        echo "Try restarting the service manually:"
        echo "  systemctl restart jetty"
        exit 1  # Exit with a failure status
    fi
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



# Normalize spaces in /etc/hosts for checking
normalize_hosts() {
    sed 's/[[:blank:]]\+/ /g' /etc/hosts
}


update_hosts_file() {
    echo "Updating /etc/hosts..."


    # Define the new entry
    HOSTS_ENTRY="${LOOP_IP_ADDRESS} ${SHIB_IDP_FQDN} ${SHIB_IDP_HOSTNAME}"


    # Backup the current /etc/hosts
    cp /etc/hosts /etc/hosts.bak

    # Check if the loopback entry exists and replace it with the desired entry:
    if grep -q "^${LOOP_IP_ADDRESS}" /etc/hosts; then
	echo -e "Replacing existing loopback entry for\n ${HOSTS_ENTRY}...\n"
	sed -i "s/^${LOOP_IP_ADDRESS}.*/${HOSTS_ENTRY}/" /etc/hosts
    else
	echo "Adding new hosts entry..."
	echo "${HOSTS_ENTRY}" >> /etc/hosts
    fi


    # Verify Changes:
    if grep -q "^${LOOP_IP_ADDRESS}" /etc/hosts; then
	echo "/etc/hosts updated successfully."
    else
	echo "Failed to update /etc/hosts!" >&2
	exit 1
    fi
    
}


# Set the hostname for the machine:
update_hostname() {

    echo "Updating hostname..."

    # Get the current hostname:
    current_hostname=$(hostname)

    if [ "$current_hostname" != "${SHIB_IDP_HOSTNAME}" ]; then
	echo "Setting hostname to ${SHIB_IDP_HOSTNAME}..."
	hostnamectl hostname "${SHIB_IDP_HOSTNAME}"
    else
	echo "Host name is already set to ${SHIB_IDP_HOSTNAME}"
    fi
}

install_dependencies(){
    echo "Install the dependencies"
    # step4: Placeholder for further installation steps...
    apt update && apt-get upgrade -y --no-install-recommends

    # step5: Install Dependencies
    apt install -y fail2ban vim wget gnupg ca-certificates openssl ntp curl --no-install-recommends

    #clean up the progarms from computer's harddisk that we installed
    apt autoremove -y
}

check_java_version() {
    if type java > /dev/null 2>&1; then
	echo "Java is already installed. Verifying version..."
	echo

	# Capture the output of java -version
	JAVA_VERSION=$(java -version 2>&1)
	echo "$JAVA_VERSION"

	#check for string "Corretto" in the version output:
	if [[ "$JAVA_VERSION" == *"Corretto"* ]]; then
	    echo "Amazon Corretto is already installed."
	else
	    echo "Java version installed is not Amazon Corretto. Installig Amazon Corretto..."
	    install_amazon_corretto
	fi
    else
	echo "Java is not installed. Installig Amazon Corretto..."
	install_amazon_corretto
    fi
}


install_amazon_corretto() {
    # src: https://docs.aws.amazon.com/corretto/latest/corretto-17-ug/generic-linux-install.html
    echo "Installing Amazon Corretto JDK..."

    echo
    echo "importing the Corretto public key; and register the the Correto Repos in system APT repo:"
    echo
    wget -O - https://apt.corretto.aws/corretto.key | sudo gpg --dearmor -o /usr/share/keyrings/corretto-keyring.gpg && echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" | sudo tee /etc/apt/sources.list.d/corretto.list
    
    echo
    echo "Install Amazon Corretto:"
    echo
    apt-get update; apt-get install -y java-17-amazon-corretto-jdk

    # Check that Java is installed correctly
    echo
    echo "Checking the Java Version:"
    java -version
    echo
}


install_jetty() {
    # download from: https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/
    echo -e "\n-------------Installing Jetty...-------------\n"
    

    echo -e "\tDownload and extract Jetty\n"
    cd /usr/local/src
    if [ ! -f "jetty-home-${JETTY_VERSION}.tar.gz" ]; then
        wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/${JETTY_VERSION}/jetty-home-${JETTY_VERSION}.tar.gz
        tar xzvf jetty-home-${JETTY_VERSION}.tar.gz
    fi

    echo -e "\tCreate symbolic link for future updates\n"
    ln -nsf jetty-home-${JETTY_VERSION} jetty-src

    echo -e "\tCreate jetty user if not exists\n"
    if ! id "jetty" &>/dev/null; then
        useradd -r -M jetty
    fi

    echo -e "\tCreate JETTY directories, subdirectories and set permissions\n"
    mkdir -p /opt/jetty /opt/jetty/tmp /var/log/jetty /opt/jetty/logs
    chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src /var/log/jetty /opt/jetty/logs

    echo -e "\tDownload custom Jetty configuration (start.ini from )idem.garr.it\n"
    wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/jetty-conf/start.ini -O /opt/jetty/start.ini
    chown -R jetty:jetty /opt/jetty /usr/local/src/jetty-src /var/log/jetty /opt/jetty/logs

    

    echo "\tConfigure /etc/default/jetty\n"
    cat > /etc/default/jetty <<EOF
JETTY_HOME=/usr/local/src/jetty-src
JETTY_BASE=/opt/jetty
JETTY_PID=/opt/jetty/jetty.pid
JETTY_USER=jetty
JETTY_START_LOG=/var/log/jetty/start.log
TMPDIR=/opt/jetty/tmp
EOF

    echo -e "\tCreate systemd service for Jetty\n" 
    cd /etc/init.d
    ln -s /usr/local/src/jetty-src/bin/jetty.sh /etc/init.d/jetty
    cp /usr/local/src/jetty-src/bin/jetty.service /etc/systemd/system/jetty.service

    echo -e "\tFix PIDFile in systemd service file\n"
    sed -i 's|^PIDFile=.*|PIDFile=/opt/jetty/jetty.pid|' /etc/systemd/system/jetty.service
    systemctl daemon-reload
    systemctl enable jetty.service

    echo -e "\tInstall Servlet Jakarta API API 5.0.0\n"
    apt install libjakarta-servlet-api-java


    echo -e "\tConfigure LogBack for Jetty logging\n"
    cd /opt/jetty
    java -jar /usr/local/src/jetty-src/start.jar --add-module=logging-logback
    mkdir /opt/jetty/etc /opt/jetty/resources
    wget "https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/jetty-conf/jetty-requestlog.xml" -O /opt/jetty/etc/jetty-requestlog.xml
    wget "https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/jetty-conf/jetty-logging.properties" -O /opt/jetty/resources/jetty-logging.properties

    echo -e "Start Jetty and check status"
    service jetty start
    echo
    echo
    service jetty check

#    # Final check and start
#    echo "Checking Jetty status..."
#    if service jetty check; then
#        echo "Jetty is running correctly."
#    else
#        echo "Jetty not running, attempting to start..."
#        service jetty start
#        if ! service jetty check; then
#            echo "Jetty failed to start. Attempting to resolve..."
#            rm -f /opt/jetty/jetty.pid
#            systemctl start jetty.service
#            if service jetty check; then
#                echo "Jetty started successfully."
#            else
#                echo "Failed to start Jetty. Check logs for details."
#            fi
#        fi
#    fi
}


#7: # Check if Shibboleth IdP is already installed
install_shibboleth() {
    local HOSTNAME=$(hostname -f)
    local IDP_DIR="${IDP_HOME}"
    local ENTITY_ID="https://${SHIB_IDP_HOSTNAME}/idp/shibboleth"
    local SCOPE=$(echo ${SHIB_IDP_HOSTNAME} | cut -d "." -f 2-)

    echo -e "\nInstalling Shibboleth Identity Provider...\n"

    echo -e "\tDownload and verify Shibboleth IdP version ${IDP_VERSION}\n"
    cd /usr/local/src
    wget http://shibboleth.net/downloads/identity-provider/${SHIB_IDP_VERSION}/shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz

    wget https://shibboleth.net/downloads/identity-provider/${SHIB_IDP_VERSION}/shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz.asc

    wget https://shibboleth.net/downloads/PGP_KEYS

    gpg --import /usr/local/src/PGP_KEYS

    gpg --verify shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz.asc shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz

    echo -e "\tExtract and install Shibboleth IdP\n"
    tar -xzf shibboleth-identity-provider-${SHIB_IDP_VERSION}.tar.gz
    cd /usr/local/src/shibboleth-identity-provider-${SHIB_IDP_VERSION}/bin

    # Run the installer script with silent options
    echo "Running installer with predefined options..."
    ./install.sh \
        --hostName "${HOSTNAME}" \
        --noPrompt \
        --targetDir "${IDP_DIR}" \
        --entityID "${ENTITY_ID}" \
        --scope "$SCOPE"

#    bash install.sh --hostName $(#hostname -f)
}


fix_metadata_typo() {
    echo
    echo "From the v5.1.3, the installer miss a space between <md:EntityDescriptor and entityID into the ${IDP_HOME}/idp-metadata.xml. Make sure to add it before procede."
    echo
    METADATA_FILE="${IDP_HOME}/metadata/idp-metadata.xml"

    if [ -f "$METADATA_FILE" ]; then
        echo "Fixing typo in the IdP metadata file..."
        # Use sed to correct the typo
        sed -i 's|<md:EntityDescriptorentityID|<md:EntityDescriptor entityID|' "$METADATA_FILE"

        # Verify the fix
        if grep -q '<md:EntityDescriptor entityID=' "$METADATA_FILE"; then
            echo "Typo fixed successfully in $METADATA_FILE."
        else
            echo "Failed to fix the typo in $METADATA_FILE!" >&2
        fi
    else
        echo "Metadata file $METADATA_FILE not found!" >&2
        exit 1
    fi
}



fix_installed_idp_errors() {
    fix_metadata_typo
}



# Function to create and prepare the DocumentRoot
configure_document_root() {
    local fqdn="${SHIB_IDP_HOSTNAME}"
    local doc_root="/var/www/html/${fqdn}"
    echo "Creating DocumentRoot at ${doc_root}..."
    mkdir -p "$doc_root"
    chown -R www-data: "$doc_root"
    echo '<h1>It Works! again :) </h1>' > "${doc_root}/index.html"
}

setup_ssl_credentials() {
    local fqdn="${SHIB_IDP_HOSTNAME}"
    
    echo "Setting up SSL credentials for ${fqdn}..."

    
    # Define certificate details for non-interactive generation
    local subj="/C=US/ST=OHIO/L=BEAVERCREEK/O=${fqdn} LTD./OU=${fqdn} LTD. IT/CN=${fqdn}"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/${fqdn}.key \
    -out /etc/ssl/certs/${fqdn}.crt \
    -subj "${subj}"

    # Set the right permissions
    chmod 400 "/etc/ssl/private/${fqdn}.key"
    chmod 644 "/etc/ssl/certs/${fqdn}.crt"
    echo
    echo "SSL credentials have been set up for ${fqdn}."
    echo    
}

# Function to configure Apache server and create consolidated VHOST file
configure_apache() {
    local fqdn="${SHIB_IDP_HOSTNAME}"
    echo "Configuring Apache Web Server..."
    a2enmod proxy_http ssl headers alias include negotiation

    # Disable default sites
    a2dissite 000-default.conf default-ssl

    # Create consolidated VHOST file for HTTP and HTTPS
    cat > /etc/apache2/sites-available/${fqdn}.conf <<EOF
<VirtualHost *:80>
    ServerName $fqdn
    Redirect permanent / https://$fqdn/
</VirtualHost>

<VirtualHost *:443>
    ServerName $fqdn
    DocumentRoot /var/www/html/$fqdn

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/$fqdn.crt
    SSLCertificateKeyFile /etc/ssl/private/$fqdn.key

    <Directory /var/www/html/$fqdn>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # Enable the site
    a2ensite ${fqdn}.conf
    systemctl restart apache2.service
    echo "Apache configuration complete."
}



main_apache_configuration_method() {
    configure_document_root
    setup_ssl_credentials
    configure_apache
}



# Function to disable Jetty directory indexing
disable_directory_indexing() {
    echo -e "\nDisabling Jetty directory indexing...\n"


    # Check if the directory exists and delete it if it does
    if [ -d "$IDP_HOME/edit-webapp/WEB-INF" ]; then
        echo "Existing WEB-INF directory found. Deleting..."
        rm -rf $IDP_HOME/edit-webapp/WEB-INF
    fi

    # Create the necessary directory
    echo "Creating new WEB-INF directory..."
    mkdir -p $IDP_HOME/edit-webapp/WEB-INF

    # Copy the web.xml to the editable directory
    echo "Copying web.xml to the editable directory..."
    cp "${IDP_HOME}/dist/webapp/WEB-INF/web.xml" "${IDP_HOME}/edit-webapp/WEB-INF/web.xml"

    # Rebuild IdP war file
    echo "Rebuilding IdP war file..."
    bash $IDP_HOME/bin/build.sh

    echo "Directory indexing disabled."
}




# Function to configure Jetty Context Descriptor for Shibboleth IdP
configure_jetty_context() {
    echo -e "\n-------------Configuring Jetty Context Descriptor for IdP...-------------\n"

    # Ensure the webapps directory exists
    mkdir -p /opt/jetty/webapps

    # Download and place the IdP context file
    wget "https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/jetty-conf/idp.xml" -O /opt/jetty/webapps/idp.xml

    # Make the jetty user owner of important IdP directories
    echo "Setting ownership for IdP directories..."
    cd "${IDP_HOME}"
    chown -R jetty "${IDP_HOME}/logs" "${IDP_HOME}/metadata" "${IDP_HOME}/credentials" "${IDP_HOME}/conf" "${IDP_HOME}/war"

    # Restart Jetty to apply changes
    echo "Restarting Jetty to apply changes..."
    service jetty restart
    systemctl restart jetty.service
    echo "Jetty has been configured and restarted."
}



configure_apache_as_reverse_proxy(){
    echo -e "\n-------------Configuring Apache2 as a reverse proxy for Jetty...-------------\n"
    # Download and place the Apache configuration file
    local apache_conf="/etc/apache2/sites-available/${SHIB_IDP_FQDN}.conf"
    #wget "https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/apache-conf/idp.example.org.conf" -O "$apache_conf"
    cp "${SUPPORTING_FILES_PATH}/Apache2_as_front_end_of_Jetty_template.conf"  "${apache_conf}"

    # Modify the Apache configuration file
    echo "Customizing the Apache configuration..."

    sed -i "s/idp.example.org/${SHIB_IDP_FQDN}/g" "$apache_conf"
    sed -i 's|ServerAdmin admin@example.org| ServerAdmin bakursait@gmail.com |g' "$apache_conf"
    sed -i "s|/etc/ssl/certs/idp.example.org.crt|/etc/ssl/certs/${SHIB_IDP_FQDN}.crt|g" "$apache_conf"
    sed -i "s|/etc/ssl/private/idp.example.org.key|/etc/ssl/private/${SHIB_IDP_FQDN}.key|g" "$apache_conf"
    sed -i "s|#SSLCACertificateFile /etc/ssl/certs/ACME-CA.pem|SSLCACertificateFile /etc/ssl/certs/ACME-CA.pem|g" "$apache_conf"


    # Enable the Apache virtual host
    echo "Enabling the virtual host..."
    a2ensite "${SHIB_IDP_FQDN}.conf"

    # Reload Apache to apply changes
    echo "Reloading Apache2..."
    systemctl reload apache2.service

    # Verify the configuration
    echo "Checking that IdP metadata is available..."
    if curl -k -s --head "https://${SHIB_IDP_FQDN}/idp/shibboleth" | grep "200 OK" > /dev/null; then
        echo "Metadata is available on https://${SHIB_IDP_FQDN}/idp/shibboleth"
    else
        echo "Failed to verify metadata availability. Check Apache configuration."
    fi
    
}

check_idp_storage_service(){
    echo
    echo -e "\n\t-------------Checking the Shibboleth IdP Storage Service configuration...-------------\n"
    echo "We are using the default settings for Shibboleth-IdP Storage Service, please rever to the following for more inforamtion:"
    echo 'https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-shibboleth-identity-provider-storage-service'
    echo
    
    # Verify and log the current storage configuration
    echo "Current storage and encryption settings:"
    grep 'StorageService' "${IDP_HOME}/conf/idp.properties"
    grep 'encryption' "${IDP_HOME}/conf/relying-party.xml"

    # Check the status of the Shibboleth IdP
    echo "Checking the IdP status..."
    bash "${IDP_HOME}/bin/status.sh"

    # Log output for manual review
    echo "Review the output and logs to ensure proper configuration and operation."
}



# Function to update or uncomment a property in ldap.properties
update_property() {
    local property="$1"
    local value="$2"
    local file="$3"

#    # Ensure the file exists
#    if [ ! -f "$file" ]; then
#        echo "Error: File $file not found!"
#        return 1
#    fi

    # Remove all occurrences of the property (whether commented or uncommented) to avoid duplicates
    sed -i "/^[#[:space:]]*${property}[[:space:]]*=.*/d" "$file"

    # Add the updated property
    echo "$property = $value" >> "$file"
    echo "Updated: $property=$value"
}


# Function to install openLDAP on Ubuntu
install_openldap() {
    echo
    echo -e "\n\t-------------Installing openLDAP...-------------\n"
    echo
    apt update
    apt install -y slapd ldap-utils

    # Reconfigure slapd to set up the domain and admin user
    echo "Reconfiguring slapd, follow the prompts to set the domain, organization name, and password..."
    dpkg-reconfigure slapd

    # Basic configuration for DIT and adding organizational units
    echo "Setting up DIT structure..."
    ldap_setup
}

# Function to configure DIT and sample entries
ldap_setup() {
    echo
    echo -e "\n\t-------------Configure DIT and sample entries...-------------\n"
    echo "We will setup organizations, users from ${LDAP_FILES_PATH} in our LDAP system."
    # Create an LDIF file for organizational units
    echo "Creating organizational units..."

    # Load organizational units
    ldapadd -x -D "cn=admin,dc=${LDAP_DC_2}" -W -f "${LDAP_FILES_PATH}/ou-structure.ldif"

    # Create sample users
    echo "Adding sample users..."
    # Add users
    ldapadd -x -D "cn=admin,dc=${LDAP_DC_2}" -w 'akaysait1991' -f "${LDAP_FILES_PATH}/idpuser.ldif"
    ldapadd -x -D "cn=admin,dc=${LDAP_DC_2}" -w 'akaysait1991' -f "${LDAP_FILES_PATH}/alisait.ldif"
    ldapadd -x -D "cn=admin,dc=${LDAP_DC_2}" -w 'akaysait1991' -f "${LDAP_FILES_PATH}/bakursait.ldif"
    ldapadd -x -D "cn=admin,dc=${LDAP_DC_2}" -w 'akaysait1991' -f "${LDAP_FILES_PATH}/omarsait.ldif"
}


# Function to configure Shibboleth IDP for LDAP connection
configure_shibboleth_ldap() {
    echo
    echo -e "\n\t-------------Configuring Shibboleth IDP to use LDAP...-------------\n"
    echo

    # Install necessary LDAP utilities
    sudo apt install -y ldap-utils

    # Check LDAP connectivity
    echo "Checking LDAP connection..."
    ldapsearch -x -H ldap://localhost -D "cn=idpuser,ou=system,dc=${LDAP_DC_2}" -w 'idpuser123' -b "ou=people,dc=${LDAP_DC_2}" '(uid=bakursait)'

    ## Apply Solution 3 - plain LDAP ##:
    # Configure secrets.properties
    echo "Updating secrets.properties..."
    #    echo "idp.authn.LDAP.bindDNCredential=idpuser123" >> "${IDP_HOME}/credentials/secrets.properties"
    #    echo "idp.attribute.resolver.LDAP.bindDNCredential=%{idp.authn.LDAP.bindDNCredential:undefined}" >> "${IDP_HOME}/credentials/secrets.properties"
    
    update_property "idp.authn.LDAP.bindDNCredential" "idpuser123" "${SHIB_IDP_SECRETS_PROPERTIES_FILE}"
    update_property "idp.attribute.resolver.LDAP.bindDNCredential" '%{idp.authn.LDAP.bindDNCredential:undefined}' "${SHIB_IDP_SECRETS_PROPERTIES_FILE}"

    

    # Configure ldap.properties
    echo "Updating ldap.properties..."

    # Update properties in ldap.properties
    update_property "idp.authn.LDAP.authenticator" "bindSearchAuthenticator" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.ldapURL" "ldap://${SHIB_IDP_FQDN}" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.useStartTLS" "false" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.returnAttributes" "passwordExpirationTime,loginGraceRemaining" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.baseDN" "ou=people,dc=${LDAP_DC_2}" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.subtreeSearch" "false" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.bindDN" "cn=idpuser,ou=system,dc=${LDAP_DC_2}" "$LDAP_PROPERTIES_FILE"
    update_property "idp.authn.LDAP.userFilter" "(uid={user})" "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.useStartTLS" '%{idp.authn.LDAP.useStartTLS:true}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.trustCertificates" '%{idp.authn.LDAP.trustCertificates:undefined}' "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.searchFilter" "(uid=\$resolutionContext.principal)" "$LDAP_PROPERTIES_FILE"
    update_property "idp.attribute.resolver.LDAP.exportAttributes" "uid cn sn givenName mail eduPersonAffiliation" "$LDAP_PROPERTIES_FILE"
    
    echo "LDAP properties have been updated."

    # Restart Jetty to apply changes
    service jetty restart
    echo "Jetty restarted. Checking IdP status..."
    bash "${IDP_HOME}/bin/status.sh"
}



configure_persistent_nameid() {
    echo
    echo -e "\n\t-------------configure_persistent_nameid...-------------\n"
    echo
    # Enable the generation of the computed persistent-id
    # Set the source attribute to 'uid' for OpenLDAP
    saml_persistent_nameid_properties="${IDP_HOME}/conf/saml-nameid.properties"
    saml_persistent_nameid_xml="${IDP_HOME}/conf/saml-nameid.xml"
    salt_secret="${IDP_HOME}/credentials/secrets.properties"

    update_property "idp.persistentId.sourceAttribute" "uid" "${saml_persistent_nameid_properties}"
    
    
    
    # Uncomment the line to enable persistent ID generator in saml-nameid.xml
    sed -i '/<ref bean="shibboleth.SAML2PersistentGenerator" \/>/d' "${saml_persistent_nameid_xml}"
    sed -i '/<ref bean="shibboleth.SAML2TransientGenerator" \/>/a \        <ref bean="shibboleth.SAML2PersistentGenerator" />' "${saml_persistent_nameid_xml}"


    
    # Generate a salt value for persistent ID encryption and set it in secrets.properties
    local salt=$(openssl rand -base64 36)
    update_property "idp.persistentId.salt" "${salt}" "${salt_secret}"

    
    # Restart Jetty to apply the changes
    service jetty restart

    # Check IdP Status
    bash "${IDP_HOME}/bin/status.sh"
}


configure_attribute_resolver() {
    echo
    echo -e "\n\t-------------configure_attribute_resolver...-------------\n"
    echo
    # Download the sample attribute resolver
    #wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/attribute-resolver-v4-idem-sample.xml -O "${IDP_HOME}/conf/attribute-resolver.xml"
    cp "${SUPPORTING_FILES_PATH}/attribute-resolver-v5-idem-sample.xml" "${IDP_HOME}/conf/attribute-resolver.xml"

    # If using plain text LDAP, delete/comment specific directives
    sed -i '/useStartTLS="%{idp.attribute.resolver.LDAP.useStartTLS^*}"/d' "${IDP_HOME}/conf/attribute-resolver.xml"
    sed -i '/trustFile="%{idp.attribute.resolver.LDAP.trustCertificates}"/d' "${IDP_HOME}/conf/attribute-resolver.xml"

    # Set the correct owner
    chown jetty "${IDP_HOME}/conf/attribute-resolver.xml"

    # Restart Jetty to apply the changes
    #systemctl restart jetty.service
    restart_and_check_jetty

    # Check IdP status
    bash "${IDP_HOME}/bin/status.sh"
}


configure_eduPersonTargetedID() {
    apt update
    apt install xmlstarlet -y
    # Ensure the attribute resolver XML includes the necessary definitions for eduPersonTargetedID
    # Add or ensure the following entries exist in /opt/shibboleth-idp/conf/attribute-resolver.xml
    local configuration_details=$(cat <<EOF
please make sure the following script is added into '/opt/shibboleth-idp/conf/attribute-resolver.xml' file:


<!-- AttributeDefinition for eduPersonTargetedID - Computed Mode -->
<AttributeDefinition xsi:type="SAML2NameID" nameIdFormat="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent" id="eduPersonTargetedID">
    <InputDataConnector ref="computed" attributeNames="computedId" />
</AttributeDefinition>

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
    request_confirmation "$configuration_details"
    if [ $? -ne 0 ]; then
	echo -e "\nExiting configuration process... -- as you did not confirm if the value exist or not"
	#return 1
	exit 1
    fi
    echo "Proceeding with further configuration..."

    # Download custom eduPersonTargetedID properties
    echo "Create the custom eduPersonTargetedID.properties file.."
    #wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP4/attributes/custom/eduPersonTargetedID.properties -O ${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties
    cp "${SUPPORTING_FILES_PATH}/eduPersonTargetedID.properties.txt" "${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties"

    

    # Set the correct owner
    echo "Set proper owner/group with:"
    chown jetty:root "${IDP_HOME}/conf/attributes/custom/eduPersonTargetedID.properties"

    # Restart Jetty to apply changes
    #service jetty restart
    restart_and_check_jetty

    # Check IdP status
    bash "${IDP_HOME}/bin/status.sh"
}

configure_idp_logging() {

    # Insert a comment for clarity in the logback configuration
    sed -i '/^    <logger name="org.ldaptive".*/a \\n    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->' "${IDP_HOME}/conf/logback.xml"

    # Add a new logger entry specifically for LDAP authentication errors
    sed -i '/^    <!-- Logs on LDAP user authentication - ADDED BY IDEM HOWTO -->/a \ \ \ \ <logger name="org.ldaptive.auth.Authenticator" level="INFO" />' "${IDP_HOME}/conf/logback.xml"
}


secure_cookies_and_idp_data(){
    echo "Setting up security for cookies and other IdP data..."
    
    # Download the updateIDPsecrets.sh script
    echo "Downloading updateIDPsecrets.sh script..."
    #wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/bin/updateIDPsecrets.sh -O /opt/shibboleth-idp/bin/updateIDPsecrets.sh
    cp "${SUPPORTING_FILES_PATH}/updateIDPsecrets.sh" "${IDP_HOME}/bin/updateIDPsecrets.sh"
    
    
    # Give executable permissions
    echo "Setting executable permissions on the script..."
    chmod +x "${IDP_HOME}/bin/updateIDPsecrets.sh"
    
    # Create a CRON job script
    echo "Creating CRON script to run the updateIDPsecrets.sh daily..."
    cat > /etc/cron.daily/updateIDPsecrets <<EOF
#!/bin/bash
${IDP_HOME}/bin/updateIDPsecrets.sh
EOF
    
    # Give executable permissions to the CRON script
    chmod +x /etc/cron.daily/updateIDPsecrets

    # Confirm that the script is properly scheduled
    echo "Confirming the script is scheduled to run daily..."
    if sudo run-parts --test /etc/cron.daily | grep -q 'updateIDPsecrets'; then
        echo "CRON job is scheduled correctly."
    else
        echo "Error: CRON job is not set up correctly."
    fi
    
    # Optionally add properties to conf/idp.properties
    echo "Optionally adding properties to ${IDP_HOME}/conf/idp.properties..."
#    # This step assumes idp.properties is correctly formatted and ready to accept additional properties
#    echo "idp.sealer._count = 30" >> /opt/shibboleth-idp/conf/idp.properties
#    echo "idp.sealer._sync_hosts = localhost" >> /opt/shibboleth-idp/conf/idp.properties    
}

Remaining_work() {
    echo
    echo "The following sections you may want to figure out by yourself:"
    echo -e "\t1. Enrich IdP Login Page with the Institutional Logo"
    echo -e "\t   Reference: https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#enrich-idp-login-page-with-the-institutional-logo"
    echo -e "\t   Steps:"
    echo -e "\t     1.1 Look for \"placeholder-logo.png\" or \"logo.png\" at https://${SHIB_IDP_FQDN}/idp/images"
    echo -e "\t     1.2 Copy your institutional logo to: ${IDP_HOME}/edit-webapp/images/idp-logo.png"
    echo -e "\t     1.3 Add the path to the IDP Logo:"
    echo -e "\t         idp.logo = /images/idp-logo.png"
    echo -e "\t         Update this in: ${IDP_HOME}/messages/messages.properties"
    echo -e "\t     1.4 Rebuild the IdP WAR file:"
    echo -e "\t         bash ${IDP_HOME}/bin/build.sh"
    echo -e "\t     1.5 Update the IdP metadata logo path to:"
    echo -e "\t         <mdui:Logo xml:lang='en' width='80' height='80'>https://${SHIB_IDP_FQDN}/images/idp-logo.png</mdui:Logo>"
    echo

    echo -e "\t2. Connect the SP to the IdP"
    echo -e "\t   Reference: Appendix D: Connect an SP with the IdP"
    echo -e "\t   Steps:"
    echo -e "\t     2.1 Add the SP metadata configuration to metadata-providers.xml:"
    echo -e "\t         vim /opt/shibboleth-idp/conf/metadata-providers.xml"
    echo -e "\t         Add the following inside the <MetadataProviderGroup> element:"
    echo -e "\t           <MetadataProvider id=\"HTTPMetadata\""
    echo -e "\t                           xsi:type=\"FileBackedHTTPMetadataProvider\""
    echo -e "\t                           backingFile=\"%{idp.home}/metadata/sp-metadata.xml\""
    echo -e "\t                           metadataURL=\"https://sp.example.org/Shibboleth.sso/Metadata\""
    echo -e "\t                           failFastInitialization=\"false\"/>"
    echo -e "\t     2.2 Add an AttributeFilterPolicy to attribute-filter.xml:"
    echo -e "\t         wget https://registry.idem.garr.it/idem-conf/shibboleth/IDP5/conf/idem-example-arp.txt -O /opt/shibboleth-idp/conf/example-arp.txt"
    echo -e "\t         cat /opt/shibboleth-idp/conf/example-arp.txt"
    echo -e "\t         Copy and paste the content before </AttributeFilterPolicyGroup> in:"
    echo -e "\t           /opt/shibboleth-idp/conf/attribute-filter.xml"
    echo -e "\t         Update ### SP-ENTITYID ### with the actual SP entityID."
    echo -e "\t     2.3 Restart Jetty to apply changes:"
    echo -e "\t         systemctl restart jetty"
    echo
}





# Main script execution:
main(){
    update_hosts_file
    update_hostname
    install_dependencies

    #6.1: Install Apache Web Server
    apt install apache2 -y

    # Invoke the function to check the Java version
    check_java_version
    
    
    
    #6.3 Install Jetty Servlet Container:
    # Check if Jetty is already installed
    if [ ! -d "/usr/local/src/jetty-src" ]; then
	install_jetty
    else
	echo "Jetty is already installed."
    fi

    #7: # Check if Shibboleth IdP is already installed                              
    if [ ! -d "/opt/shibboleth-idp" ]; then
	install_shibboleth
	fix_installed_idp_errors
    else
	echo "Shibboleth Identity Provider is already installed."
    fi

    #6: 
    disable_directory_indexing

    # step9: # Execute main_apache_configuration_method
    main_apache_configuration_method

    # step10: Configure Jetty Context Descriptor for IdP
    configure_jetty_context

    # step11: Configure Apache2 as the front-end of Jetty
    configure_apache_as_reverse_proxy
        
    # step12: Call the function to execute the checks
    check_idp_storage_service
    
    # step13: Install OpenLDAP:
    if dpkg -l | grep -qw slapd; then
	echo
	echo "OpenLDAP is already installed..."
	echo
    else
	# step13.1: install and configure openLDAP
	install_openldap
	
	# step13.2: configure_shibboleth_ldap  
	configure_shibboleth_ldap
    fi


    # step14: Configure Shibboleth Identity Provider to release the persistent NameID
    configure_persistent_nameid


    # step15: Configure the attribute resolver (sample)
    configure_attribute_resolver
    
    
    # step16: Configure Shibboleth Identity Provider to release the eduPersonTargetedID
    configure_eduPersonTargetedID
    
    
    # step17: Configure Shibboleth IdP Logging
    configure_idp_logging


    secure_cookies_and_idp_data

    
    Remaining_work
    
}




main

