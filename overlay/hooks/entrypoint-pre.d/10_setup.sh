#!/bin/bash
set -e

# Handle CACHE_MEM_SIZE deprecation
if [[ ! -z "${CACHE_MEM_SIZE}" ]]; then
    CACHE_INDEX_SIZE=${CACHE_MEM_SIZE}
fi

# Preprocess UPSTREAM_DNS to allow for multiple resolvers using the same syntax as lancache-dns
UPSTREAM_DNS="$(echo -n "${UPSTREAM_DNS}" | sed 's/[;]/ /g')"

echo "worker_processes ${NGINX_WORKER_PROCESSES};" > /etc/nginx/workers.conf
sed -i "s/^user .*/user ${WEBUSER};/" /etc/nginx/nginx.conf
sed -i "s/UPSTREAM_DNS/${UPSTREAM_DNS}/"    /etc/nginx/stream-available/10_sni.conf
