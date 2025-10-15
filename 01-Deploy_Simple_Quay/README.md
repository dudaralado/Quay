# Quay Deployment POC

On this repository I had documented my learn path to use Red Hat Quay.
It is separate on few segmets.
+ **Deploy a simple Quay registry.**
  - Deploy Redis
  - Deploy PostgreSQL
  - Deploy Quay

## Deploy a simple Quay registry
On this Lab we will run Quay as a nonroot user, so we will need to do some pre-configuration.

We need to configure the firewall to accept access to few ports.
```
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=5433/tcp
sudo firewall-cmd --permanent --add-port=6379/tcp
sudo firewall-cmd --reload

```

We will need to create a new container network, with this the container will communicate each other without issues.  
This could be achieve by runnind the command bellow:  
```
$ podman network create quay-net
``````

We will need to create a directory to storage the configuration files and container images for our Quay registry  
Create the directory  
```
$ mkdir ~/QUAYDATA
```
Let's export this direcory to a system environment, so we do not need to type the full path over and over.  
```
$ QUAY=~/QUAYDATA  
$ export QUAY
```

Once it is create let's start to deploy our containers.  
**1. Deploy Redis container**  
We will deploy Redis using the latest version, but in case you want to know which version are availabe, you could
check it by running:  
```
$ skopeo list-tags docker://docker.io/library/redis  
```
Run the following command to deploy Redis:  
```
  $ podman run -d --name redis \
    --network quay-net \
    -p 6379:6379 \
    -e DEBUGLOG=true   \
    docker.io/library/redis:latest \
    --requirepass strongpassword 
```

**2. Deploy PostgreSQL container**  
First we will need to create the directory where PostgreSQL will save the data.  

We could achieve it by running  
```
$ mkdir -p $QUAY/postgres/quay  
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
  $ podman run -d  -p 5432:5432 \
    --name postgresql-quay \
    --network quay-net \
    -e DEBUGLOG=true \
    -e POSTGRES_USER=quayuser \
    -e POSTGRES_DB=quaydb \
    -e POSTGRES_PASSWORD=quaypass \
    -v $QUAY/postgres:/var/lib/pgsql/data:Z \
    docker.io/library/postgres:latest
```

We need to ensure that the Postgres pg_trgm module is installed by running the following command:
```
$ podman exec -it postgresql-quay /bin/bash -c \
'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quaydb -U quayuser'
```
**3. Deploy Quay container**  
We need to create two directories before deploy Quay.
* **Storage** which will store the container's images  
* **Config** which will storage the Quay configuration files

Let's create the required file by running the commands bellow:  
```
$ mkdir -p $QUAY/quay/config  
$ mkdir -p $QUAY/quay/storage  
```
Now let's set the correct permission to this direcory.   
```
$ setfacl -Rm u:1001:-wx $QUAY/quay/storage
$ setfacl -Rm g:1001:-wx $QUAY/quay/storage
$ setfacl -Rm g:$USER:-wx $QUAY/quay/storage
$ setfacl -Rm u:$USER:-wx $QUAY/quay/storage
```

Now that we have the directories we need to have a Quay configuration file, lest create on using `cat` command  
```
$ cat << EOF |tee $QUAY/quay/config/config.yaml
BUILDLOGS_REDIS:
    host: <Host IP OR FQDN>  # Here you will place the IP Addres of you host or the hostname with the Fully Qualified Domain Name
    password: strongpassword
    port: 6379
BROWSER_API_CALLS_XHR_ONLY: false
CREATE_NAMESPACE_ON_PUSH: true
DATABASE_SECRET_KEY: a8c2744b-7004-4af2-bcee-e417e7bdd235
DB_URI: postgresql://quayuser:quaypass@<Host IP OR FQDN>:5432/quaydb # Here you will place the IP Addres of you host or the hostname with the Fully Qualified Domain Name
DISTRIBUTED_STORAGE_CONFIG:
    default:
        - LocalStorage
        - storage_path: /datastorage/registry
DISTRIBUTED_STORAGE_DEFAULT_LOCATIONS: []
DISTRIBUTED_STORAGE_PREFERENCE:
    - default
FEATURE_MAILING: false
FEATURE_USER_INITIALIZE: true
PERMANENTLY_DELETE_TAGS: true
PREFERRED_URL_SCHEME: http
QUOTA_TOTAL_DELAY_SECONDS: 1800
REGISTRY_TITLE: Project Quay
REGISTRY_TITLE_SHORT: Project Quay
REPO_MIRROR_INTERVAL: 30
REPO_MIRROR_TLS_VERIFY: true
RESET_CHILD_MANIFEST_EXPIRATION: true
SEARCH_MAX_RESULT_PAGE_COUNT: 10
SEARCH_RESULTS_PER_PAGE: 10
SECRET_KEY: e9bd34f4-900c-436a-979e-7530e5d74ac8
SERVER_HOSTNAME: <Host IP OR FQDN>  # Here you will place the IP Addres of you host or the hostname with the Fully Qualified Domain Name
SETUP_COMPLETE: true
USER_EVENTS_REDIS:
    host: <Host IP OR FQDN>  # Here you will place the IP Addres of you host or the hostname with the Fully Qualified Domain Name
    password: strongpassword
    port: 6379
SUPER_USERS:
  - quayadmin
TAG_EXPIRATION_OPTIONS:
  - 1s
  - 1d
  - 1w
  - 2w
  - 4w
EOF
```

We will deploy Quay using the latest version, but in case you want to know which version are availabe, you could
check it by running: 
```
$ skopeo list-tags docker://quay.io/projectquay/quay  
```
Now time to Deploy Quay container  by running the bellow command:  
```
$ podman run -d -p 80:8080 -p 443:8443 -p 9091:9091 \
   --name=quay \
   --network quay-net \
   -e DEBUGLOG=true \
   -v $QUAY/quay/config:/conf/stack:Z \
   -v $QUAY/quay/storage:/datastorage:Z \
   quay.io/projectquay/quay:latest
```

$\color{Red}\small{\textbf{You may face the issue below}}$
> Error: rootlessport cannot expose privileged port 80, you can add 'net.ipv4.ip_unprivileged_port_start=80' to /etc/sysctl.conf (currently 1024), or choose a larger port number (>= 1024): listen tcp 0.0.0.0:80: bind: permission denied

To fix it run the command:   
```
$ sudo sh -c 'echo "net.ipv4.ip_unprivileged_port_start=80" >> /etc/sysctl.conf'
$ sudo sysctl -p
```
Then start the quay pod:  
```
$ podman start quay
```
Let's create our first user via CLI and test some push and pull against the Quay image registry.

To cretae the user we could run the following command:
_Note that you will need to ajdut the command to align with you Quay URL ($host_FQDN)_  
`curl -X POST -k  http://$host_FQDN/api/v1/user/initialize --header 'Content-Type: application/json' --data '{ "username": "quayadm", "password": "quayadmin", "email": "quayadm@'$host_FQDN'", "access_token": true}'
`

Time to login to our Registry.  
```
$ podman login -u quayadm -p quayadmin <QUAY_FQDN> --tls-verify=false
```

Now lets tag and push an image to Quay registry.  
We should have some images previously pulled from internet, lets list it:
```
$ podman images
REPOSITORY                  TAG         IMAGE ID      CREATED      SIZE
docker.io/library/redis     latest      3bd8c109f88b  5 days ago   140 MB
docker.io/library/postgres  latest      194f5f2a900a  13 days ago  463 MB
quay.io/projectquay/quay    latest      a4c452279ee3  2 years ago  1.49 GB
```
Lets tag and push the quay images which has the tag latest
```
$ podman tag quay.io/projectquay/quay:latest <QUAY_FQDN>/quayadm/quay:latest
$ podman push --tls-verify=false <QUAY_FQDN>/quayadm/quay:latest
```
To make sure our image has been pushed successfully, we can check it using `skopeo` commane
```
 skopeo list-tags docker://<QUAY_FQDN>/quayadm/quay --tls-verify=false
{
    "Repository": "quay01.nuc.lab/quayadm/quay",
    "Tags": [
        "latest"
    ]
}
```
Now we have Quay registry up running !!!  

$\color{Red}\Huge{\textsf{Next Steps}}$
* **Add Clair to the Quay registry, for image vulnarability scanner.**  
vulnerability scanner detects security weaknesses like known software vulnerabilities (CVEs), misconfigurations, and embedded secrets within container images, often by scanning the base image, application dependencies, and infrastructure-as-code files
