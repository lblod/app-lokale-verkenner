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
- Add the frontend, lblod/frontend-lokale-verkenner 0.0.2, to the stack
- Add an inactive flag to the municipality locations that ceased to exist through mergers, as in OP [OP-3973]
- Store the original values on the result of a change event, as in OP [OP-3950]
- Make related organisations and change events editable again as change requests: aggregates `related-organizations` and `change-event-edit` [RVS-28]
- Let the change-request service write memberships and periods of time for related organisations [RVS-28]
- Let the change-request service link another organisation from a membership, but never operate on it [RVS-28]

### Deploy notes
```
drc up -d frontend change-requests scope-of-operation kbo-data-sync project-scripts
drc restart database                                      # config.lisp: the organisation graph and the logged-in group
drc restart resource change-requests dispatcher delta-notifier   # resources model (change-requests reads it at start-up), routes, delta rule of the search index
drc restart migrations                                    # wait for "All migrations executed"
/bin/bash scripts/reset-elastic.sh                        # last: creates data/elasticsearch, builds the index, ends with "up -d"
```
To fill an environment from OP: `config/project-scripts/import-from-op/README.md`.

For the edit pages of related organisations and change events: publish or mount the new `lblod/frontend-lokale-verkenner`, publish the new `lblod/change-request-service` and recreate `change-requests` and `resource` (the aggregates in `change-requests.json`) and reload authorization (`drc restart database`, the memberships and periods of time in `config.lisp`).
