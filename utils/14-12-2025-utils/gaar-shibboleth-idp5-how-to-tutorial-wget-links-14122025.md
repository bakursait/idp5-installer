# [Install Jetty Servlet Container](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#install-jetty-servlet-container):
  - 2. Download and Extract Jetty: [wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.3/jetty-home-12.1.3.tar.gz](wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.3/jetty-home-12.1.3.tar.gz)
  
  - 5. Create your custom Jetty configuration that overrides the default one and will survive upgrades [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-start.ini -O /opt/jetty/start.ini][wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-start.ini -O /opt/jetty/start.ini]
  
  - 2. Download and Extract Jetty: [wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.3/jetty-home-12.1.3.tar.gz](wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/12.1.3/jetty-home-12.1.3.tar.gz)
  
  - 11. Install & configure LogBack for all Jetty logging 
    - [wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-requestlog.xml" -O /opt/jetty/etc/jetty-requestlog.xml][wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-requestlog.xml" -O /opt/jetty/etc/jetty-requestlog.xml]
    - [wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-logging.properties" -O /opt/jetty/resources/jetty-logging.properties][wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/jetty-logging.properties" -O /opt/jetty/resources/jetty-logging.properties]
  

# [Install Shibboleth Identity Provider](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#install-shibboleth-identity-provider):
  - 2. Download the Shibboleth Identity Provider v5.x.y (replace '5.x.y' with the latest version found on the Shibboleth download site): 
    - [wget http://shibboleth.net/downloads/identity-provider/5.x.y/shibboleth-identity-provider-5.x.y.tar.gz](wget http://shibboleth.net/downloads/identity-provider/5.x.y/shibboleth-identity-provider-5.x.y.tar.gz)

  - 3. Validate the package downloaded: 
    - [wget https://shibboleth.net/downloads/identity-provider/5.x.y/shibboleth-identity-provider-5.x.y.tar.gz.asc](wget https://shibboleth.net/downloads/identity-provider/5.x.y/shibboleth-identity-provider-5.x.y.tar.gz.asc)
    - [wget https://shibboleth.net/downloads/PGP_KEYS](wget https://shibboleth.net/downloads/PGP_KEYS)
    

# [Configure Apache Web Server](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-apache-web-server):
  - 2. Put SSL credentials in the right place: 
    - [wget -O /etc/ssl/certs/GEANT_TLS_RSA_1.pem https://crt.sh/?d=16099180997](wget -O /etc/ssl/certs/GEANT_TLS_RSA_1.pem https://crt.sh/?d=16099180997)


# [Configure Jetty Context Descriptor for IdP](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-jetty-context-descriptor-for-idp):
  - 2. Configure the Jetty Context Descriptor: 
    - [wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.xml" -O /opt/jetty/webapps/idp.xml](wget "https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.xml" -O /opt/jetty/webapps/idp.xml)

# [Configure Apache2 as the front-end of Jetty](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-apache2-as-the-front-end-of-jetty):
  - 2. Create the Virtualhost file: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.example.org.conf -O /etc/apache2/sites-available/$(hostname -f).conf](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idp.example.org.conf -O /etc/apache2/sites-available/$(hostname -f).conf)



# [Configure Shibboleth Identity Provider Storage Service](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-shibboleth-identity-provider-storage-service):

## [Strategy B - JDBC Storage Service - using a database](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#strategy-b---jdbc-storage-service---using-a-database)
  - 5. Create StorageRecords table on the storagerecords database: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/shib-sr-db.sql -O /root/shib-sr-db.sql](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/shib-sr-db.sql -O /root/shib-sr-db.sql)


# [Configure Shibboleth Identity Provider Storage Service](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-shibboleth-identity-provider-storage-service):

## [Strategy B - Stored mode - using a database](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#strategy-b---jdbc-storage-service---using-a-database)
  - 7. Create `shibpid` table on `shibboleth` database: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/shib-pid-db.sql -O /root/shib-pid-db.sql](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/shib-pid-db.sql -O /root/shib-pid-db.sql)



# [Configure the attribute resolver (sample)](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-the-attribute-resolver-sample):
  - 2. Download the sample attribute resolver provided by IDEM GARR AAI Federation Operators (OpenLDAP / Active Directory compliant): 
    - [wget https://conf.idem.garr.it/idem-attribute-resolver-shib-v5.xml -O /opt/shibboleth-idp/conf/attribute-resolver.xml](wget https://conf.idem.garr.it/idem-attribute-resolver-shib-v5.xml -O /opt/shibboleth-idp/conf/attribute-resolver.xml)


# [Configure Shibboleth Identity Provider to release the eduPersonTargetedID](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#configure-shibboleth-identity-provider-to-release-the-edupersontargetedid):

## [Strategy A - Computed mode - using the computed persistent NameID - Recommended](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#strategy-a---computed-mode---using-the-computed-persistent-nameid---recommended)
  - 3. Create the custom `eduPersonTargetedID.properties` file: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties)


## [Strategy B - Stored mode - using the persistent NameID database](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#strategy-b---stored-mode---using-the-persistent-nameid-database)
  - 3. Create the custom `eduPersonTargetedID.properties` file: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/eduPersonTargetedID.properties -O /opt/shibboleth-idp/conf/attributes/custom/eduPersonTargetedID.properties)



# [Secure cookies and other IDP data](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#secure-cookies-and-other-idp-data):
  - 1. Download `updateIDPsecrets.sh` into the right location:: 
    - [wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/updateIDPsecrets.sh -O /opt/shibboleth-idp/bin/updateIDPsecrets.sh](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/updateIDPsecrets.sh -O /opt/shibboleth-idp/bin/updateIDPsecrets.sh)




# [Appendix D: Connect an SP with the IdP](https://github.com/ConsortiumGARR/idem-tutorials/blob/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/Debian-Ubuntu/HOWTO-Install-and-Configure-a-Shibboleth-IdP-v5.x-on-Debian-Ubuntu-Linux-with-Apache-%2B-Jetty.md#appendix-d-connect-an-sp-with-the-idp):
  - 2. Adding an `AttributeFilterPolicy` on the `conf/attribute-filter.xml` file: 
    - [  wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idem-example-arp.txt -O /opt/shibboleth-idp/conf/example-arp.txt](wget https://github.com/ConsortiumGARR/idem-tutorials/raw/master/idem-fedops/HOWTO-Shibboleth/Identity%20Provider/utils/idem-example-arp.txt -O /opt/shibboleth-idp/conf/example-arp.txt)
