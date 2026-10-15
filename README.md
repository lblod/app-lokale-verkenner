# app-rvs

Backend of the Register van Samenwerkingsverbanden (RVS; the name will change), a slimmed-down
version of app-organization-portal for local governments, economische actoren and other
organisations.

## Change requests

Every edit of organisation data is a change request, handled by
[change-request-service](https://github.com/lblod/change-request-service) at `/change-requests`.
The service checks who may edit what (own organisation; ABB edits all), keeps the request with its
steps and versions in `http://mu.semte.ch/graphs/change-requests`, and applies it to the
organisation data in `http://mu.semte.ch/graphs/public`. A request is approved at once unless it
conflicts with a change someone made after its form was loaded; such a request waits until ABB
approves or rejects it (`POST /change-requests/:id/steps`).

The resource routes are read-only: `config/authorization/config.lisp` gives no one a write grant
on the organisation data except the service, through its scope. Its configuration (aggregates,
the ABB organisation) is `config/change-requests/change-requests.json`. The data it writes
(requests, steps, proposed versions, record states) is described in the service's README and
vocabulary; the two code lists it uses, the status of a request and the type of a step, are
loaded into the public graph by `config/migrations/2026/20261015120000-add-change-request-code-lists.ttl`.

Development, with a checkout of change-request-service next to this repository (`../change-request-service`),
which `docker-compose.dev.yml` mounts into the template image:

    docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

The identifier listens on http://localhost:88 and Virtuoso on http://localhost:8899. Log in through
mock-login (frontend-rvs, or `POST /mock/sessions`), then post change requests. The service's
`scripts/e2e-mock-login.sh` runs the whole flow against this setup.

## mu-project

Bootstrap a mu.semte.ch microservices environment in three easy steps.

## Quickstart an mu-project

> [INFO]
> This project was created by running `mu project new awesome-project-name`.  If read on GitHub under mu-semtech/mu-project then it is the template repository for a new project, use `mu project new` instead.

Setting up your environment is done in three easy steps:
1. First configure the running microservices and their names in `docker-compose.yml`
2. Then, configure how requests are dispatched in `config/dispatcher.ex`
3. Lastly, simply start the docker-compose.

### Hooking things up with docker-compose

Alter the `docker-compose.yml` file so it contains all microservices you need.  The example content should be clear, but you can find more information in the [Docker Compose documentation](https://docs.docker.com/compose/).  Don't remove the `identifier` and `db` container, they are respectively the entry-point and the database of your application.  Don't forget to link the necessary microservices to the dispatcher and the database to the microservices.

### Configure the dispatcher

Next, alter the file `config/dispatcher/dispatcher.ex` based on the example that is there by default.  Dispatch requests to the necessary microservices based on the names you used for the microservice.

### Boot up the system

Boot your microservices-enabled system using docker-compose.

    cd /path/to/mu-project
    docker-compose up

You can shut down using `docker-compose stop` and remove everything using `docker-compose rm`.
