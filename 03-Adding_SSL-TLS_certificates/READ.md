# Quay Deployment POC
On this repository I had documented my learn path to use Red Hat Quay. It is separate on few segmets.  
- Creating a Certificate Authority   
- Creatting a host Certificate  
- Add SSL/TLS on Quay Registry

**1. Create Certificate Authoryty**  
Generate the root CA key  
```
$ openssl genrsa -out rootCA.key 2048
```

Generate the root CA Certificate
```
$ openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem
```
**2. Cretate host/server Certificate**  
Create host/server tls key
```
$ openssl genrsa -out ssl.key 2048
```
Create a signing request certificate
```
$ openssl req -new -key ssl.key -out ssl.csr
```
Create a configuration file openssl.cnf, specifying the server hostname, for example:
```
$ cat << EOF | tee openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = <QUAY_FQDNm>
EOF
```

Create the host/server certificate   
```
$ openssl x509 -req -in ssl.csr -CA rootCA.pem -CAkey rootCA.key \
-CAcreateserial -out ssl.cert -days 356 -extensions v3_req -extfile openssl.cnf
```

**3. Add SSL/TLS on Quay Registry**  
- Copy the certificate file and primary key file to your configuration directory, ensuring they are named ssl.cert and ssl.key respectively
```
$ cp -v ~/ssl.cert ~/ssl.key $QUAY/quay/config/
```

- Edit the config.yaml to enable the SSL/TSL and add/edit the following line:
```
PREFERRED_URL_SCHEME: https
```
Set the correct permission on ssl.key and ssl.cert
```
$ setfacl -Rm u:1001:rw- $QUAY/quay/config/ssl.cert
$ setfacl -Rm g::r-- $QUAY/quay/config/ssl.key
```
After edit, restart the quay container  
```
$ podman restart quay
```

We will need to recreate clair and add the SSL/TLS cert on the configuration  
Delete the clair container
```
podma rm clair --force
```
Now recreate the container with the following command
```
podman run -d --name clairv4 \
--network quay-net \
-p 8081:8081 -p 8088:8088 \
-e CLAIR_CONF=/clair/config.yaml \
-e CLAIR_MODE=combo \
-v $QUAY/quay/config/ssl.cert:/var/run/certs/ca.crt:Z \
-v $QUAY/clair/config:/clair:Z \
quay.io/projectquay/clair:latest
```
You could confirm the certificate by running the command
```
echo -n | openssl s_client -connect <QUAY_FQDN>:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | openssl x509 -text -noou
```
$\color{Red}\Huge{\textsf{Next Steps}}$
* **Add LDAP Server**
