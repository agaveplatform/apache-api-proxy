#!/bin/bash

if [[ -f "/app/config/environment.sh" ]]; then
  source /app/config/environment.sh
else
  echo "No environment config present in /app/config/environment.sh. Reading from container environment"
fi

if [[ -z "$DOCUMENT_ROOT" ]]; then
  DOCUMENT_ROOT=/var/www/html
fi

sed -i 's#%DOCUMENT_ROOT%#'$DOCUMENT_ROOT'#g' /etc/apache2/httpd.conf
sed -i 's#%DOCUMENT_ROOT%#'$DOCUMENT_ROOT'#g' /etc/apache2/conf.d/ssl.conf

sed -i 's#%HOSTNAME%#'$HOSTNAME'#g' /etc/apache2/httpd.conf
sed -i 's#%HOSTNAME%#'$HOSTNAME'#g' /etc/apache2/conf.d/ssl.conf

#################################################################
# Configure logging
#################################################################

# Enable logging to std out
if [[ -n "$LOG_TARGET_STDOUT" ]]; then
  sed -i 's#ErrorLog /var/log/apache2/error_log#ErrorLog /proc/self/fd/2#g' /etc/apache2/httpd.conf
  sed -i 's#CustomLog /var/log/apache2/access_log combined#CustomLog /proc/self/fd/1 combined#g' /etc/apache2/httpd.conf

  sed -i 's#ErrorLog /var/log/apache2/ssl_error_log#ErrorLog /proc/self/fd/2#g' /etc/apache2/conf.d/ssl.conf
  sed -i 's#TransferLog /var/log/apache2/ssl_access_log#TransferLog /proc/self/fd/1#g' /etc/apache2/conf.d/ssl.conf
  sed -i 's#CustomLog /var/log/apache2/ssl_access_log#CustomLog /proc/self/fd/1#g' /etc/apache2/conf.d/ssl.conf
fi

# Enable toggling the log level at startup
if [[ -n "$LOG_LEVEL_DEBUG" ]]; then
  LOG_LEVEL=debug
elif [[ -n "$LOG_LEVEL_WARN" ]]; then
  LOG_LEVEL=warn
elif [[ -n "$LOG_LEVEL_ERROR" ]]; then
  LOG_LEVEL=error
else
  LOG_LEVEL=info
fi

sed -i 's#%LOG_LEVEL%#'$LOG_LEVEL'#g' /etc/apache2/httpd.conf
sed -i 's#%LOG_LEVEL%#'$LOG_LEVEL'#g' /etc/apache2/conf.d/ssl.conf   

#################################################################
# Add whitelisted hostnames/ip addresses to the balancer config
#################################################################

if [[ -n "$STATUS_WHITELIST" ]]; then
  WHITELIST=( $STATUS_WHITELIST )

  for ip in "${WHITELIST[@]}"; do
    sed -i 's/#%STATUS_HOST%/Allow from '$ip'\n    #%STATUS_HOST%/g' /etc/apache2/conf.d/info.conf
  done
fi

#################################################################
# Configure newrelic login
#################################################################
#
# if [[ -n "$NEWRELIC_LICENSE_KEY" ]]; then
#   if [[ -e /var/www/html/newrelic.ini ]]; then
#     echo "New Relic file already present. Skipping config setup"
#   else
#     echo "newrelic.license='$NEWRELIC_LICENSE_KEY'" > $DOCUMENT_ROOT/newrelic.ini
#
#     if [[ -n "$NEWRELIC_APP_NAME" ]]; then
#       echo "newrelic.appname='$NEWRELIC_APP_NAME'" > $DOCUMENT_ROOT/newrelic.ini
#     fi
#   fi
# fi

#################################################################
# Configure ssl certs to use mounted files or the container defaults
#################################################################

# if [[ -e /etc/apache2/conf.d/ssl.conf.bak ]]; then
#   cp /etc/apache2/conf.d/ssl.conf.bak /etc/apache2/conf.d/ssl.conf
# else
#   cp /etc/apache2/conf.d/ssl.conf /etc/apache2/conf.d/ssl.conf.bak
# fi

if [[ -n "$SSL_CERT" ]]; then
  sed -i 's#SSLCertificateFile .*#SSLCertificateFile '$SSL_CERT'#g' /etc/apache2/conf.d/ssl.conf
fi

if [[ -n "$SSL_KEY" ]]; then
  sed -i 's#SSLCertificateKeyFile .*#SSLCertificateKeyFile '$SSL_KEY'#g' /etc/apache2/conf.d/ssl.conf
fi

if [[ -n "$SSL_CA_CHAIN" ]]; then
  sed -i 's#\#SSLCertificateChainFile .*#SSLCertificateChainFile '$SSL_CA_CHAIN'#g' /etc/apache2/conf.d/ssl.conf
fi

if [[ -n "$SSL_CA_CERT" ]]; then
  sed -i 's#\#SSLCACertificateFile .*#SSLCACertificateFile '$SSL_CA_CERT'#g' /etc/apache2/conf.d/ssl.conf
fi

#################################################################
# NTPD init
#################################################################

# start ntpd because clock skew is astoundingly real
ntpd -d -p pool.ntp.org

# finally, run the command passed into the container
exec "$@"
