
cat <<'EOF'

██████╗░███████╗██████╗░██╗░██████╗
██╔══██╗██╔════╝██╔══██╗██║██╔════╝
██████╔╝█████╗░░██║░░██║██║╚█████╗░
██╔══██╗██╔══╝░░██║░░██║██║░╚═══██╗
██║░░██║███████╗██████╔╝██║██████╔╝
╚═╝░░╚═╝╚══════╝╚═════╝░╚═╝╚═════╝░
           🚀 Deploying REDIS
EOF


podman run -d --name redis \
  --network quaynet \
  -p 6379:6379 \
  -e DEBUGLOG=true   \
  docker.io/library/redis:$REDIS_VERSION \
  --requirepass strongpassword 
