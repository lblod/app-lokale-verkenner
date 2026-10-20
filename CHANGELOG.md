# Changelog

## Unreleased

- [RVS-9][RVS-10] Requests to register a new organisation or a veranderingsgebeurtenis wait for ABB (statuses "Aanvullende informatie gevraagd" and "Afgehandeld", actions informatievraag, informatieantwoord, betwisting and afhandeling); edits of own data apply at once; the change-request service may write change events, their results and decisions.

### Deploy notes

- Migrations: `20261020120000-add-validation-flow-code-lists` and `20261020120001-goedgekeurd-is-the-decision` load the new concepts into the public graph (automatic).
- `config/change-requests/change-requests.json` and `config/authorization/config.lisp` changed: restart `database` (sparql-parser) and `change-requests`.
