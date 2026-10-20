# Changelog

## Unreleased

- `scope-of-operation` (lblod/scope-of-operation-service 0.2.0) in the stack, as in OP: the werkingsgebied of an organisation on the kerngegevens page and in the creation and change-event forms; the dispatcher already routed `/scope-of-operation`.
- Resources model in step with OP's development branch: `decisions.document-links` (uri-set, OP-3925) instead of `document-link`, `change-event-results.resulting-name` (OP-3927), the period resource named `periods-of-time` (OP-3947) with its dispatcher route.
- [RVS-9][RVS-10] Requests to register a new organisation or a veranderingsgebeurtenis wait for ABB (statuses "Aanvullende informatie gevraagd" and "Afgehandeld", actions informatievraag, informatieantwoord, betwisting and afhandeling); edits of own data apply at once; the change-request service may write change events, their results and decisions.

### Deploy notes

- Migrations: `20261020120000-add-validation-flow-code-lists` and `20261020120001-goedgekeurd-is-the-decision` load the new concepts into the public graph (automatic).
- `config/change-requests/change-requests.json` and `config/authorization/config.lisp` changed: restart `database` (sparql-parser) and `change-requests`.
