# Changelog

## Unreleased

- `scope-of-operation` (lblod/scope-of-operation-service 0.2.0) in the stack, as in OP: the werkingsgebied of an organisation in the creation and change-event forms; the dispatcher already routed `/scope-of-operation`. It writes composed locations with mu-auth-sudo and is reachable without login: the exception is documented in `config/authorization/config.lisp`.
- Resources model in step with OP's development branch: `decisions.document-links` (uri-set, OP-3925) instead of `document-link`, `change-event-results.resulting-name` (OP-3927), the period resource named `periods-of-time` (OP-3947) with its dispatcher route, its start and end as dates (`xsd:date`), as in OP.
- [RVS-9][RVS-10] Requests to register a new organisation or a veranderingsgebeurtenis wait for ABB (statuses "Informatie gevraagd" and "Afgehandeld", actions informatievraag, informatieantwoord, betwisting and afhandeling); edits of own data apply at once; the change-request service may write change events, their results and decisions.
- [RVS-37] Change-request configuration: per aggregate the fields it may change (`writable`: the kerngegevens no longer change the werkingsgebied, the juridische vorm or the bijkomende kwalificaties, a vestiging only the sites), what the service registers (`registration`: the classifications by resource type, the oprichting, the classifications without a KBO number), the oprichting carries its result (`new-organisation` operates on `change-event-results`), the OCMW may request a ziekenhuisvereniging ("Wie beheert").
- Migrations: the status labels as the screens show them and the goedkeuring as a decision, the requests applied before the validation flow are "Afgehandeld", a second ABB mock account.

### Deploy notes

The first deploy of the change requests. In this order:

1. Publish `lblod/change-request-service:0.2.0`, the first release with the validation flow, from the service's master once its PR #2 is merged; `docker-compose.yml` pins it.
2. `docker compose pull change-requests scope-of-operation`, then `docker compose up -d change-requests scope-of-operation` (two new services).
3. `docker compose restart database`: `config/authorization/config.lisp` (the graph the service writes, by type, and the change-requests graph).
4. `docker compose restart resource dispatcher`: the resources model (`change-events.json`, read by `domain.lisp`; `auth.json` roles; `document-links`, `resulting-name`, `periods-of-time`) and the routes `/change-requests` and `/periods-of-time`.
5. `docker compose restart migrations` and wait until `docker compose logs migrations` shows these executed: `20261015120000-add-change-request-code-lists`, `20261020120000-add-validation-flow-code-lists`, `20261020120001-goedgekeurd-is-the-decision`, `20261021120000-validation-flow-labels`, `20261021120001-requests-applied-before-the-validation-flow`, `20261021120002-add-second-abb-mock-account`.
6. `docker compose restart change-requests`: it reads `config/change-requests/change-requests.json` and the resources model at start-up, and checks them; `docker compose logs change-requests` names the aggregates it loaded, or why it did not start.
7. Check: `GET /change-requests/permissions` without a session answers 401; logged in, `GET /change-requests` answers 200.
