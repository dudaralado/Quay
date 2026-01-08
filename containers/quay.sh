cat <<'EOF'
   __   __
  /  \ /  \     ______   _    _     __   __   __
 / /\ / /\ \   /  __  \ | |  | |   /  \  \ \ / /
/ /  / /  \ \  | |  | | | |  | |  / /\ \  \   /
\ \  \ \  / /  | |__| | | |__| | / ____ \  | |
 \ \/ \ \/ /   \_  ___/  \____/ /_/    \_\ |_|
  \__/ \__/      \ \__
                  \___\ by Red Hat
           
           🚀 Deploying QUAY
EOF

cp  ~/Quay/configs/config.yaml  $QUAY/quay/config

SERVER=$(hostname --fqdn)

sed "s/\$FQDN/$SERVER/g" ~/Quay/configs/config.yaml > "$QUAY/quay/config/config.yaml"

sudo setfacl -Rm u:1001:-wx $QUAY/quay/storage
sudo setfacl -Rm g:1001:-wx $QUAY/quay/storage
sudo setfacl -Rm g:$USER:-wx $QUAY/quay/storage
sudo setfacl -Rm u:$USER:-wx $QUAY/quay/storage


podman run -d -p 80:8080 -p 443:8443 -p 9091:9091 \
   --name=quay \
   --network quaynet \
   -e DEBUGLOG=true \
   -v $QUAY/quay/config:/conf/stack:Z \
   -v $QUAY/quay/storage:/datastorage:Z \
   quay.io/projectquay/quay:$QUAY_VERSION

## Creating quayadm user (Not working properly yet)
#echo "Creating a quayadm user"
#sleep 5
#curl -X POST -k "https://$IP/api/v1/user/initialize" \
#            --header 'Content-Type: application/json' \
#            --data '{ "username": "quayadm", "password": "quayadmin", "email": "quayadm@quay.lab", "access_token": true }' 
#
#echo "username = quayadm"
#echo "password = quayadmin"
