cat <<'EOF'


██████╗░░█████╗░░██████╗████████╗░██████╗░██████╗░███████╗░██████╗
██╔══██╗██╔══██╗██╔════╝╚══██╔══╝██╔════╝░██╔══██╗██╔════╝██╔════╝
██████╔╝██║░░██║╚█████╗░░░░██║░░░██║░░██╗░██████╔╝█████╗░░╚█████╗░
██╔═══╝░██║░░██║░╚═══██╗░░░██║░░░██║░░╚██╗██╔══██╗██╔══╝░░░╚═══██╗
██║░░░░░╚█████╔╝██████╔╝░░░██║░░░╚██████╔╝██║░░██║███████╗██████╔╝
╚═╝░░░░░░╚════╝░╚═════╝░░░░╚═╝░░░░╚═════╝░╚═╝░░╚═╝╚══════╝╚═════╝░
                🚀 Deploying POSTGRES
EOF
mkdir -p $QUAY/postgres/quay
mkdir -p $QUAY/postgres/clair

setfacl -m u:26:-wx $QUAY/postgres

echo "Deploying Postgres"
sleep 3
podman run -d  -p 5432:5432 \
  --name postgresql-quay \
  --network quaynet \
  -e DEBUGLOG=true \
  -e POSTGRES_USER=quayuser \
  -e POSTGRES_DB=quaydb \
  -e POSTGRES_PASSWORD=quaypass \
  -v $QUAY/postgres:/var/lib/pgsql/data:Z \
  docker.io/library/postgres:$POSTGRES_VERSION
 
sleep 10

#podman exec -it postgresql-quay /bin/bash -c 'echo "\du+" | psql -d quaydb -U quayuser'
#sleep 5

podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quaydb -U quayuser'

podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE database quay_enterprise" | psql -d quaydb -U quayuser'
sleep 5
podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay_enterprise -U quayuser'


podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE USER clairv4user WITH PASSWORD '\'clairv4pass\''" | psql -d quaydb -U quayuser'
podman exec -it postgresql-quay /bin/bash -c 'echo "ALTER ROLE clairv4user SUPERUSER CREATEROLE CREATEDB REPLICATION BYPASSRLS" | psql -d quaydb -U quayuser'
sleep 5
podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE database clairv4db" | psql -d quaydb -U clairv4user'

 sleep 5

podman exec -it postgresql-quay /bin/bash -c 'echo "alter database clairv4db OWNER TO clairv4user" | psql -d clairv4db -U clairv4user'
podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"" | psql -d clairv4db -U clairv4user'
sleep 4

podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE database clairv4_enterprise" | psql -d clairv4db -U clairv4user'
podman exec -it postgresql-quay /bin/bash -c 'echo "alter database clairv4_enterprise OWNER TO clairv4user" | psql -d clairv4_enterprise -U clairv4user'
podman exec -it postgresql-quay /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"" | psql -d clairv4_enterprise -U clairv4user'
