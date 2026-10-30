# Changelog
## Unreleased
- Set up mock-login [RVS-39]
- Add change-request-service 0.2.0: every edit of organisation data is a change request [RVS-28]
- New organisations and change events wait for validation by ABB; edits apply at once [RVS-9] [RVS-10]
- Configure per aggregate the fields it may change and the classifications it registers [RVS-37]
- Add scope-of-operation, kbo-data-sync and mu-search with Elasticsearch, as in OP [RVS-37]
- Move the organisation data from the public graph to graphs/administrative-unit, readable only when logged in [RVS-37]
- Sync the resources model with OP: document-links, resulting-name, periods-of-time with dates [OP-3925] [OP-3927] [OP-3947]
- Migrations: status labels of the validation flow, earlier requests set to afgehandeld, a second ABB mock account [RVS-37]
- Add the import-from-op mu-script; the seed migrations move to config/dev-migrations [RVS-40]
- Add mock-login accounts for the organisations an OP import brings in [RVS-40]

### Deploy notes
```
drc up -d change-requests scope-of-operation kbo-data-sync project-scripts
drc restart database                                      # config.lisp: the organisation graph and the logged-in group
drc restart resource dispatcher delta-notifier            # resources model, routes, delta rule of the search index
drc restart migrations                                    # wait for "All migrations executed"
/bin/bash scripts/reset-elastic.sh                        # last: creates data/elasticsearch, builds the index, ends with "up -d"
```
To fill an environment from OP: `config/project-scripts/import-from-op/README.md`.
