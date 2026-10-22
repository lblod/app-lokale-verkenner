#!/bin/bash
# Rebuilds the search index from scratch: the Elasticsearch data, the index bookkeeping mu-search
# keeps in the triplestore (graph <http://mu.semte.ch/authorization>) and the two containers.
# Needed after a change of config/search/config.json and after a migration of organisation data:
# the migrations write Virtuoso directly, without deltas, so mu-search does not see them.
# Run from the repository root; it asks sudo for data/elasticsearch, which the containers own.
set -u
version=$(docker compose version)

if [ $? -eq 0 ]; then
    DRC_COMMAND="docker compose"
else
    DRC_COMMAND="docker-compose"
fi

echo "warning this will run queries on the triplestore and delete containers, you have 3 seconds to press ctrl+c"
sleep 3
eval "$DRC_COMMAND rm -fs elasticsearch search"
# Empty the data directory but keep it, owned by uid 1000: Elasticsearch 9
# (mu-search-elastic-backend 1.3.x) runs as that user, and a bind-mount source that
# "docker compose up" has to create itself belongs to root, on which it dies with
# "failed to obtain node locks".
sudo mkdir -p data/elasticsearch
sudo chown 1000 data/elasticsearch
sudo find data/elasticsearch -mindepth 1 -delete
eval "$DRC_COMMAND exec -T triplestore isql-v <<EOF2
SPARQL DELETE WHERE {   GRAPH <http://mu.semte.ch/authorization> {     ?s ?p ?o.   } };
exec('checkpoint');
exit;
EOF2"
eval "$DRC_COMMAND up -d --remove-orphans"
echo "mu-search builds the index now: follow it with '$DRC_COMMAND logs -f search'"
