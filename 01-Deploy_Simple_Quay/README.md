# Quay Deployment POC

On this reposiry I had documented my learn path to use Red Hat Quay.
It is separate on few segmets.
+ **Deploy a simple Quay registry.**
  - Deploy Redis
  - Deploy PostgreSQL
  - Deploy Quay

## Deploy a simple Quay registry
On this Lab we will run Quay as a nonroot user, so we will need to do some pre-configuration.<br>

We will need to create a new container network, with this the container will communicate each other without issues.<br>
This could be achieve by runnind the command bellow:<br>
`podman network create quay-net`<br>

We will need to create a directory to storage the configuration files and container images for our Quay registry<br>
Create the repository<br>
`mkdir ~/QUAYDATA`<br>
Let's export this direcory to a system environment, so we do not need to type the full path over and over.<br>
`QUAY=~/QUAYDATA`<br>
`export $QUAY`

Once it is create let's start to deploy our containers.<br>
**1. Deploy Redis container**<br>
```
    podman run -d --name redis \
    --network quaynet \
    -p 6379:6379 \
    -e DEBUGLOG=true   \
    docker.io/library/redis:$REDIS_VERSION \
    --requirepass strongpassword 
```

**2. Deploy PostgreSQL container**<br>
First we will need to create the directory where PostgreSQL will save the data.<br>

We could achieve it by running<br>
`mkdir -p $QUAY/postgres/quay`<br>

Now let's set the correct permission to this direcory.<br>
`setfacl -m u:26:-wx $QUAY/postgres`<br>

With this we are ready to deploy PostgreSQL container.<br>
```
    podman run -d  -p 5432:5432 \
    --name postgresql-quay \
    --network quaynet \
    -e DEBUGLOG=true \
    -e POSTGRES_USER=quayuser \
    -e POSTGRES_DB=quaydb \
    -e POSTGRES_PASSWORD=quaypass \
    -v $QUAY/postgres:/var/lib/pgsql/data:Z \
    docker.io/library/postgres:$POSTGRES_VERSION
```

We need to ensure that the Postgres pg_trgm module is installed by running the following command:
```
podman exec -it postgresql-quay /bin/bash -c \
'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quaydb -U quayuser'
```
