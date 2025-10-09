# Quay Deployment POC

On this repository I had documented my learn path to use Red Hat Quay.
* Deploy Clair security scanner
  - Deploy PostgreSQL   
  - Deploy Clair

## Add Clair security scanner to our Quay registry

**1. Deploy PostgreSQL container**
We e will need to create the directory where PostgreSQL will save the data.
Let's deplace a system variable as we did previously when deploy Quay.
```
$ QUAY=~/QUAYDATA  
$ export QUAY
```

Now let's create a directory where PostgreSQL will store the database data.  
```
$  mkdir -p $QUAY/postgres/clair
```
Now let's set the correct permission to this direcory.
```
$ setfacl -m u:26:-wx $QUAY/postgres
```
With this we are ready to deploy PostgreSQL container.
We will deploy PostgreSQL using the latest version, but in case you want to know which version are availabe, you could
check it by running:
```
$ skopeo list-tags docker://docker.io/library/postgres
```
Run the following command to deploy Postgres:
```
  $ podman run -d  -p 5433:5432 \
    --name postgresql-clairv4 \
    --network quay-net \
    -e DEBUGLOG=true \
    -e POSTGRES_USER=clairuser \
    -e POSTGRES_DB=clairdb \
    -e POSTGRES_PASSWORD=clairpass \
    -v $QUAY/postgres:/var/lib/pgsql/data:Z \
    docker.io/library/postgres:latest
```

We need to ensure that the Postgres uuid-ossp module is installed by running the following command:
```
$ podman exec -it postgresql-clairv4 /bin/bash -c \
'echo "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""| psql -d clairdb -U clairuser'
```

**2. Before deploy Clair containerr**  
Before deploy Clair, we need to edit Quay config file to add the following lilne:  
```
FEATURE_SECURITY_SCANNER: true
SECURITY_SCANNER_V4_ENDPOINT: http://<QUAY_FQDN>:8081
SECURITY_SCANNER_V4_PSK: N2k1NWRnaWRoamNp  # This Key could be change as you want.

```
You can use you prefered text editor or do it directly from the shell as shown bellow:  
```
$ cat << EOF |tee -a  $QUAY/quay/config/config.yaml
FEATURE_SECURITY_SCANNER: true
SECURITY_SCANNER_V4_ENDPOINT: http://<QUAY_FQDN>:8081
SECURITY_SCANNER_V4_PSK: N2k1NWRnaWRoamNp  # This Key could be change as you want.
EOF
```

Now restart Quay container:  
```
$ podman restart quay
```
Create a directory for your Clair configuration file:   
```
$ mkdir -p $QUAY/clair/config
```

Create the Clair configuration file:  
```
$ cat << EOF | tee $QUAY/clair/config/config.yaml
http_listen_addr: :8081
introspection_addr: :8088
log_level: debug
indexer:
  connstring: host=<QUAY_FQDN> port=5433 dbname=clairdb user=clairuser password=clairpass sslmode=disable
  scanlock_retry: 10
  layer_scan_concurrency: 5
  migrations: true
matcher:
  connstring: host=<QUAY_FQDN> port=5433 dbname=clairdb user=clairuser password=clairpass sslmode=disable
  max_conn_pool: 100
  migrations: true
  indexer_addr: clair-indexer
notifier:
  connstring: host=<QUAY_FQDN> port=5433 dbname=clairdb user=clairuser password=clairpass sslmode=disable
  delivery_interval: 1m
  poll_interval: 5m
  migrations: true
auth:
  psk:
    key: "N2k1NWRnaWRoamNp"
    iss: ["quay"]
# tracing and metrics
trace:
  name: "jaeger"
  probability: 1
  jaeger:
    agent:
      endpoint: "localhost:6831"
    service_name: "clair"
metrics:
  name: "prometheus"
EOF
```
**3. Deploy Clair Container**  

We will deploy Clair using the latest version, but in case you want to know which version are availabe, you could
check it by running:
```
$ skopeo list-tags docker://quay.io/projectquay/clair
```
Now time to Deploy Clair container by running the bellow command:
```
$ podman run -d --name clairv4 \
--network quay-net \
-p 8081:8081 -p 8088:8088 \
-e CLAIR_CONF=/clair/config.yaml \
-e CLAIR_MODE=combo \
-v $QUAY/clair/config:/clair:Z \
quay.io/projectquay/clair:latest

```
Let`s see if the Clair successfully scan our image.  
First we need to collect the image digest by running:
```
$ skopeo inspect docker://<QUAY_FQDN>/quayadm/quay:latest --tls-verify=false| awk 'NR>=2 && NR<=3'
```
The output should be something similar to the output below:
```
"Name": "<QUAY_URL>/quayadm/quay",
    "Digest": "sha256:53160e6ee9d7d19cc62fa0488fa9db3d990a4b0a252eb3157d2238d05d74ec90",
```
With the diggest collect we can run the following command to see if the image had been scanned:
```
$ curl -s -k -u "quayadm:quayadmin"  "http://<QUAY_FQDN>/api/v1/repository/quayadm/quay/manifest/sha256:53160e6ee9d7d19cc62fa0488fa9db3d990a4b0a252eb3157d2238d05d74ec90/security"| jq -r '.data.Status // .status // "unknown"'
scanned
```
As show above the image had been scanned, we also can see how many vunerabilities had been detected by running:
```
$ curl -s -k -u "quayadm:quayadmin" "http://quay01.nuc.lab/api/v1/repository/quayadm/quay/manifest/sha256:53160e6ee9d7d19cc62fa0488fa9db3d990a4b0a252eb3157d2238d05d74ec90/security" | jq |grep Severity|wc -l
511
```
On this case the image has 511 vulnerabilities. This information can be also visualized through the web UI.

$\color{Red}\Huge{\textsf{Next Steps}}$  
* **Add SSL/TLS to Quay registry**
