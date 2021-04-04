#!/bin/sh
set -a

echo "Start cycle at $( date '+%Y-%m-%d %H:%M:%S' )"

#######################
# Get Certificate     #
#######################

LEGO_STAGING=${LEGO_STAGING:-0}
LEGO_ARGS=${LEGO_ARGS:-}
LEGO_MODE=${LEGO_MODE:-renew}
LEGO_DNS_TIMEOUT=${LEGO_DNS_TIMEOUT:-10}
LEGO_KEY_TYPE=${LEGO_KEY_TYPE-ec384}

# Get endpoint
ENDPOINT='https://acme-v02.api.letsencrypt.org/directory'
if [ "$LEGO_STAGING" == "1" ]; then
    ENDPOINT='https://acme-staging-v02.api.letsencrypt.org/directory'
fi

LEGO_DOMAINS=${LEGO_DOMAINS:-}
LEGO_DOMAINS=$(  ( [ -n "$LEGO_DOMAINS" ] && echo ${LEGO_DOMAINS//;/ --domains } ) )

# Stop here if no LEGO_DOMAINS were given as arguments
[ -z "$LEGO_DOMAINS" ] && echo 'Domain(s) not provided.' && exit 1


LEGO_EMAIL_ADDRESS=${LEGO_EMAIL_ADDRESS:-}

# Stop here if no email address given as arguments
[ -z "$LEGO_EMAIL_ADDRESS" ] && echo 'Email Address not provided.' && exit 1

[ -n "$LEGO_PROVIDER" ] && echo "Using dns LEGO_PROVIDER $LEGO_PROVIDER."

if [ -n "$LEGO_PROVIDER" ]; then
    /usr/bin/lego --server $ENDPOINT --path /letsencrypt --accept-tos --key-type=$LEGO_KEY_TYPE --domains $LEGO_DOMAINS --email $LEGO_EMAIL_ADDRESS --pem --dns $LEGO_PROVIDER --dns-timeout $LEGO_DNS_TIMEOUT $LEGO_ARGS $LEGO_MODE 
else
    /usr/bin/lego --server $ENDPOINT --path /letsencrypt --accept-tos --key-type=$LEGO_KEY_TYPE --domains $LEGO_DOMAINS --email $LEGO_EMAIL_ADDRESS --pem $LEGO_ARGS $MODE 
fi
if [ ! $? == 0 ]; then
    echo "Failed to get new certificates from LEGO-Client" && exit 1
fi

#######################
# RouterOS Upload     #
#######################

if [[ -z $ROUTEROS_USER ]] || [[ -z $ROUTEROS_HOST ]] || [[ -z $ROUTEROS_SSH_PORT ]] || [[ -z $ROUTEROS_PRIVATE_KEY ]] || [[ -z $ROUTEROS_DOMAIN ]]; then
    echo "Check the enviroment variables. Some informations are missing." && exit 1
fi

CERTIFICATE="/letsencrypt/certificates/_.$ROUTEROS_DOMAIN.pem"
KEY="/letsencrypt/certificates/_.$ROUTEROS_DOMAIN.key"

#Create alias for RouterOS command
routeros="ssh -i $ROUTEROS_PRIVATE_KEY -o StrictHostKeyChecking=no $ROUTEROS_USER@$ROUTEROS_HOST -p $ROUTEROS_SSH_PORT"

#Check connection to RouterOS
echo -n "Checking connection to RouterOS..."
$routeros /system resource print > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

if [ ! -f $CERTIFICATE ] && [ ! -f $LEGO_CERT_KEY_PATH ]; then
    echo "File(s) not found:\n$CERTIFICATE\n$KEY\n" && exit 1
fi

#######################
# Create Certificate  #
#######################

# Remove previous certificate and delete Certificate file if the file exist on RouterOS
echo -n "Removing previous certificate and delete certificate file if the file exist on RouterOS..."
$routeros /certificate remove [find name=autoupload_$ROUTEROS_DOMAIN.pem_0] \; /certificate remove [find name=autoupload_$ROUTEROS_DOMAIN.pem_1] \; /certificate remove [find name=autoupload_$ROUTEROS_DOMAIN.pem_2] \; /file remove autoupload_$ROUTEROS_DOMAIN.pem > /dev/null
echo "DONE"

# Upload Certificate to RouterOS
echo -n "Uploading Certificate to RouterOS..."
scp -q -P $ROUTEROS_SSH_PORT -i "$ROUTEROS_PRIVATE_KEY" "$CERTIFICATE" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"autoupload_$ROUTEROS_DOMAIN.pem"
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

sleep 2
# Import certificate file and delete certificate file after import
echo -n "Importing certificate file and delete certificate file after import..."
$routeros /certificate import file-name=autoupload_$ROUTEROS_DOMAIN.pem passphrase=\"\" \; /file remove autoupload_$ROUTEROS_DOMAIN.pem > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

#######################
# Create Key          #
#######################

# Delete Certificate file if the file exist on RouterOS
echo -n "Deleting Certificate file if the file exist on RouterOS..."
$routeros /file remove autoupload_$KEY.key > /dev/null
echo 'DONE'

# Upload Key to RouterOS
echo -n "Upload Key to RouterOS..."
scp -q -P $ROUTEROS_SSH_PORT -i "$ROUTEROS_PRIVATE_KEY" "$KEY" "$ROUTEROS_USER"@"$ROUTEROS_HOST":"autoupload_$ROUTEROS_DOMAIN.key"
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

sleep 2
# Import Key file and delete Certificate file after import
echo -n "Importing Key file and delete Certificate file after import..."
$routeros /certificate import file-name=autoupload_$ROUTEROS_DOMAIN.key passphrase=\"\" \; /file remove autoupload_$ROUTEROS_DOMAIN.key > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

# Set certificate to Webserver
echo -n "Setting certificate to Webserver and API..."
$routeros /ip service set www-ssl certificate=autoupload_$ROUTEROS_DOMAIN.pem_0 \; /ip service set api-ssl certificate=autoupload_$ROUTEROS_DOMAIN.pem_0 > /dev/null
[ ! $? == 0 ] && echo 'ERROR!' && exit 1 || echo 'DONE'

echo "End cycle at $( date '+%Y-%m-%d %H:%M:%S' )"