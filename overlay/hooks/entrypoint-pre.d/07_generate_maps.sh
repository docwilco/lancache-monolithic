#!/bin/bash

IFS=' '
mkdir -p /data/cachedomains
echo "Bootstrapping Monolithic from ${CACHE_DOMAINS_REPO}"

export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
cd /data/cachedomains
if [[ ! -d .git ]]; then
	git clone ${CACHE_DOMAINS_REPO} .
fi

if [[ "${NOFETCH:-false}" != "true" ]]; then
	# Disable error checking whilst we attempt to get latest
	set +e
	git remote set-url origin ${CACHE_DOMAINS_REPO}
	git fetch origin || echo "Failed to update from remote, using local copy of cache_domains"
	git reset --hard origin/${CACHE_DOMAINS_BRANCH}
	# Reenable error checking
	set -e
fi

cachedomains2vcl --repo-dir . | tee -a /etc/varnish/varnish.vcl
