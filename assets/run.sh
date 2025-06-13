#!/bin/sh
set -a

echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Start cycle at $( date '+%Y-%m-%d %H:%M:%S' )"

#######################
# Get Certificate     #
#######################

LEGO_STAGING=${LEGO_STAGING:=1}
LEGO_ARGS=${LEGO_ARGS:-}
LEGO_DNS_TIMEOUT=${LEGO_DNS_TIMEOUT:=10}
LEGO_KEY_TYPE=${LEGO_KEY_TYPE:=ec384}
ROUTEROS_SSH_PORT=${ROUTEROS_SSH_PORT:=22}

SET_ON_WEB=${SET_ON_WEB:=true}
SET_ON_API=${SET_ON_API:=true}
SET_ON_OVPN=${SET_ON_OVPN:=false}
SET_ON_HOTSPOT=${SET_ON_HOTSPOT:=false}
HOTSPOT_PROFILE_NAME=${HOTSPOT_PROFILE_NAME:-}

echo "+++ Setup +++"

# Get endpoint
echo -n "LEGO Entpoint: "
if [ "$LEGO_STAGING" == "1" ]; then
    ENDPOINT='https://acme-staging-v02.api.letsencrypt.org/directory'
    echo "staging ($ENDPOINT)"
else
    ENDPOINT='https://acme-v02.api.letsencrypt.org/directory'
    echo "production ($ENDPOINT)"
fi

LEGO_DOMAINS=${LEGO_DOMAINS:-}
LEGO_DOMAINS="$(echo -e "${LEGO_DOMAINS}" | tr -d '[:space:]')" # Remove all whitespace 
echo "LEGO domains: $LEGO_DOMAINS"
LEGO_DOMAINS=$(  ( [ -n "$LEGO_DOMAINS" ] && echo ${LEGO_DOMAINS//;/ --domains } ) )

# Print LEGO version
echo "LEGO version: $(/lego --version)"

# Fix filename if ROUTEROS_DOMAIN domain begins with wildcard-domain *.domain.tld
ROUTEROS_DOMAIN=${ROUTEROS_DOMAIN//\*/_}
CERTIFICATE="/letsencrypt/certificates/$ROUTEROS_DOMAIN.pem"
KEY="/letsencrypt/certificates/$ROUTEROS_DOMAIN.key"
ACCOUNTS="/letsencrypt/accounts"

# Stop here if no LEGO_DOMAINS were given as arguments
[ -z "$LEGO_DOMAINS" ] && echo 'Domain(s) not provided.' && exit 1

LEGO_EMAIL_ADDRESS=${LEGO_EMAIL_ADDRESS:-}

# Stop here if no email address given as arguments
[ -z "$LEGO_EMAIL_ADDRESS" ] && echo 'Email Address not provided' && exit 1 || echo "E-Mail: $LEGO_EMAIL_ADDRESS"

[ -n "$LEGO_PROVIDER" ] && echo "DNS provider: $LEGO_PROVIDER"

echo "+++ Get Certificate +++"

#Check if we had cert and keyfile
if [ ! -f $CERTIFICATE ] || [ ! -f $KEY ] || [ ! -d $ACCOUNTS ]; then
    echo "No account, certificate or keyfile found. Getting new certificates from LEGO-Client..."
    LEGO_MODE=run
else
    echo "Account, Certificate and keyfile found. Renewing certificates from LEGO-Client..."
    LEGO_MODE='renew --days 60 --no-random-sleep'
fi

if [ -n "$LEGO_PROVIDER" ]; then
    /lego --server $ENDPOINT --path /letsencrypt --accept-tos --key-type=$LEGO_KEY_TYPE --domains $LEGO_DOMAINS --email $LEGO_EMAIL_ADDRESS --pem --dns $LEGO_PROVIDER --dns-timeout $LEGO_DNS_TIMEOUT $LEGO_ARGS $LEGO_MODE 
else
    /lego --server $ENDPOINT --path /letsencrypt --accept-tos --key-type=$LEGO_KEY_TYPE --domains $LEGO_DOMAINS --email $LEGO_EMAIL_ADDRESS --pem $LEGO_ARGS $LEGO_MODE 
fi

if [ ! $? == 0 ]; then
    echo "Failed to get new certificates from LEGO-Client" && exit 1
fi

#######################
# RouterOS Precheck   #
#######################

echo "+++ RouterOS Precheck +++"

if [[ -z $ROUTEROS_USER ]] || [[ -z $ROUTEROS_HOST ]] || [[ -z $ROUTEROS_SSH_PORT ]] || [[ -z $ROUTEROS_PRIVATE_KEY ]] || [[ -z $ROUTEROS_DOMAIN ]]; then
    echo "Check the environment variables. Some information is missing." && exit 1
fi

#Check cert and keyfile
if [ ! -f $CERTIFICATE ]; then
    echo "File not found: $CERTIFICATE" && exit 1
elif [ ! -f $KEY ]; then
    echo "File not found: $KEY" && exit 1
fi

#Create alias for RouterOS command
routeros="ssh -i $ROUTEROS_PRIVATE_KEY -o StrictHostKeyChecking=no $ROUTEROS_USER@$ROUTEROS_HOST -p $ROUTEROS_SSH_PORT"

#Check connection to RouterOS
echo -n "Checking connection to RouterOS..."
$routeros /system resource print > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

################################
# RouterOS Upload Certificate  #
################################

echo "+++ RouterOS Upload Certificate +++"

# Clean up leading '_' character for wildcard domains
ROUTEROS_FILENAME=autoupload_${ROUTEROS_DOMAIN/_/}

# Remove previous certificate and delete Certificate file if the file exist on RouterOS
echo -n "Removing previous certificate and delete certificate file if the file exist on RouterOS..."
$routeros /certificate remove [find name=$ROUTEROS_FILENAME.pem_0] \; /certificate remove [find name=$ROUTEROS_FILENAME.pem_1] \; /certificate remove [find name=$ROUTEROS_FILENAME.pem_2] \; /file remove [find name="$ROUTEROS_FILENAME.pem"] > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

# Upload Certificate to RouterOS
echo -n "Uploading Certificate to RouterOS..."
scp -q -P $ROUTEROS_SSH_PORT -i "$ROUTEROS_PRIVATE_KEY" "$CERTIFICATE" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$ROUTEROS_FILENAME.pem"
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

sleep 2
# Import certificate file
echo -n "Importing certificate file..."
$routeros /certificate import file-name=$ROUTEROS_FILENAME.pem passphrase=\"\" > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

# optional remove certificate file after import
echo -n "Deleting certificate file after import..."
$routeros /file remove [find name="$ROUTEROS_FILENAME.pem"] > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

#######################
# RouterOS Upload Key #
#######################

echo "+++ RouterOS Upload Key +++"

# Delete key file if the file exist on RouterOS
echo -n "Deleting key file if the file exist on RouterOS..."
$routeros /file remove [find name="$ROUTEROS_FILENAME.key"] > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

# Upload Key to RouterOS
echo -n "Upload key to RouterOS..."
scp -q -P $ROUTEROS_SSH_PORT -i "$ROUTEROS_PRIVATE_KEY" "$KEY" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"$ROUTEROS_FILENAME.key"
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

sleep 2
# Import Key file 
echo -n "Importing key file..."
$routeros /certificate import file-name=$ROUTEROS_FILENAME.key passphrase=\"\" \ > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

# optional remove key file after import
echo -n "Deleting key file after import..."
$routeros /file remove [find name="$ROUTEROS_FILENAME.key"] > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

#######################
# RouterOS Set Cert   #
#######################

echo "+++ RouterOS Set Certificate +++"

# Set certificate to WebServer
if [ "$SET_ON_WEB" = true ]; then
echo -n "Setting certificate to Webserver..."
$routeros /ip service set [find dynamic =no and name =www-ssl] certificate=$ROUTEROS_FILENAME.pem_0 > /dev/null
[ ! $? == 0 ] && echo 'ERROR setting certificate on WebServer!' && exit 1 || echo 'DONE setting certificate on WebServer'
fi

# Set certificate to API
if [ "$SET_ON_API" = true ]; then
echo -n "Setting certificate to API..."
$routeros /ip service set [find dynamic =no and name =api-ssl] certificate=$ROUTEROS_FILENAME.pem_0 > /dev/null
[ ! $? == 0 ] && echo 'ERROR setting certificate on API!' && exit 1 || echo 'DONE setting certificate on API'
fi

# Set certificate to OpenVPN
if [ "$SET_ON_OVPN" = true ]; then
echo -n "Setting certificate to OpenVPN..."
$routeros /interface ovpn-server server set enabled=yes certificate=$ROUTEROS_FILENAME.pem_0 > /dev/null
[ ! $? == 0 ] && echo 'ERROR setting certificate on OpenVPN!' && exit 1 || echo 'DONE setting certificate on OpenVPN'
fi

# Set certificate to Hotspot
if [ "$SET_ON_HOTSPOT" = true ]; then
echo -n "Setting certificate to Hotspot..."
$routeros /ip/hotspot/profile set ssl-certificate=$ROUTEROS_FILENAME.pem_0 $HOTSPOT_PROFILE_NAME > /dev/null
[ ! $? == 0 ] && echo 'ERROR setting certificate on Hotspot!' && exit 1 || echo 'DONE setting certificate on Hotspot'
fi

echo "End cycle at $( date '+%Y-%m-%d %H:%M:%S' )"
