## Creating Directories 
sudo rm -rf ~/QUAYDEPLOYMENT
mkdir -p ~/QUAYDEPLOYMENT
sleep 5
export QUAY=~/QUAYDEPLOYMENT
mkdir -p $QUAY/quay/config/extra_ca_certs
mkdir -p $QUAY/quay/storage

## Creating podman network "quaynet"
podman network create quaynet

## Export username, hostname and IP Address
export USER=$(whoami)
export FQDN=$(hostname -f)
## To be used on TLS Certs
export IP=$(ip a |grep -A 3 -Ew "(wl.*)|(en.*)"|grep -Ew "inet"|cut -d " " -f 6|cut -d "/" -f 1)
export wild_card=$(echo $FQDN|cut -d "." -f2-)

## List Container Images version
# --- Quay Version ---
echo "Available Quay versions:"
skopeo list-tags docker://quay.io/projectquay/quay | jq -r '.Tags[]' | grep -E '^(v?3\.[0-9]+(\.[0-9]+)?)$' | grep -Ev '-' | sort -V 
echo
read -rp "Please select Quay version: " QUAY_VERSION

if [ -z "$QUAY_VERSION" ]; then
  echo "❌ No version selected, aborting."
  exit 1
fi
export QUAY_VERSION

# --- PostgreSQL Version ---
echo
echo "Available Postgres versions:"
skopeo list-tags docker://docker.io/library/postgres | jq -r '.Tags[]' | grep -E '^[0-9]+\.[0-9]+' | grep -Ev '-' | sort -V
read -rp "Please select Postgres version: " POSTGRES_VERSION
if [ -z "$POSTGRES_VERSION" ]; then
  echo "❌ No version selected, aborting."
  exit 1
fi
export POSTGRES_VERSION

# --- Redis Version ---
echo
echo "Available Redis versions:"
skopeo list-tags docker://docker.io/library/redis | jq -r '.Tags[]' | grep -E '^[0-9]+\.[0-9]+' | grep -Ev '-' | sort -V 
read -rp "Please select Redis version: " REDIS_VERSION
if [ -z "$REDIS_VERSION" ]; then
  echo "❌ No version selected, aborting."
  exit 1
fi
export REDIS_VERSION

# --- Clair Version ---
echo
echo "Available Clair versions:"
skopeo list-tags docker://quay.io/projectquay/clair | jq -r '.Tags[]' | grep -E '^[0-9]+\.[0-9]+' | grep -Ev '\-rc' | sort -V 
read -rp "Please select Clair version: " CLAIR_VERSION
if [ -z "$CLAIR_VERSION" ]; then
  echo "❌ No version selected, aborting."
  exit 1
fi
export CLAIR_VERSION

echo
echo "✅ Selected versions:"
echo "   Quay:      $QUAY_VERSION"
echo "   Postgres:  $POSTGRES_VERSION"
echo "   Redis:     $REDIS_VERSION"
echo "   Clair:     $CLAIR_VERSION"


sh ./containers/redis.sh
sh ./containers/postgres.sh
sh ./containers/quay.sh
