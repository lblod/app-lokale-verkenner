# mu-project

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

## Sync data from OP

RVS is filled from OP's non-worship organisation data. Two `mu` commands and one manual
file move:

```sh
# in OP's project: start the store, then write data/dumps/<stamp>/
docker compose up -d triplestore project-scripts
mu script project-scripts export-to-rvs

# move data/dumps/<stamp>/ to this project's data/dumps/ (manual: separate compose networks)
mkdir -p data/dumps && cp -r <OP>/data/dumps/<stamp> data/dumps/

# in this project
docker compose up -d triplestore project-scripts
mu script project-scripts import-from-op --dump data/dumps/<stamp>
```

Prerequisites:

- the triplestore and the `project-scripts` container are running
  (`docker compose up -d triplestore project-scripts`);
- the dump folder lives inside this project, at `data/dumps/<stamp>/` — `--dump` takes that
  folder (it holds `op-rvs.nt` and `manifest.json`), and only this project is mounted in the
  script container, so a path into OP's checkout does not work;
- the dev stack mounts `config/migrations-local/` (in `docker-compose.dev.yml`), so the
  seed migrations that would duplicate the dump stay out of the way (see
  `config/project-scripts/import-from-op/README.md`);
- a read rule for `graphs/administrative-unit` exists in `config/authorization/`. Without
  it the import succeeds but the UI shows nothing.

A fresh dev database has no unit seeds and no unit-keyed mock-login accounts until a dump
is imported; only the mock-EA account exists. A developer who wants the seeds without a
dump drops the `migrations` mount from their local override.

The import is additive and one-shot. Full procedure, flags, dry-run limits and the moved
migrations: `config/project-scripts/import-from-op/README.md`.
