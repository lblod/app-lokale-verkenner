#!/usr/bin/env python3
"""Import verification gate. Run by import.sh after the insert.

Checks:
  1. queries/verify-import.rq: no worship, the RVS-25 org:Organization typing,
     the governing-body closure, and — for a real import — that every subject
     the dump brought is in the graph with at least as many triples as in the
     dump.
  2. per-class counts: the graph must match the dump's manifest
     (<dump>/manifest.json) on both triple and subject counts. A manifest whose
     counts are all zero is refused outright: it would pass on any graph.
  3. with --account-count: the foaf:OnlineAccount count in the account graph
     must be unchanged (the accounts are RVS's own, not the dump's).

Prints one line per check; exits non-zero when any check fails.
"""
import argparse
import base64
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def read_classes():
    pairs = []
    with open(os.path.join(HERE, "classes.tsv"), encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                iri, name = line.split("\t")
                pairs.append((name, iri))
    return pairs


def fetch_rows(endpoint, query, user, password):
    """Run a SELECT in one request; CSV rows without the header."""
    with open(os.path.join(HERE, "queries", "prefixes.rq"), encoding="utf-8") as handle:
        body = handle.read() + "\n" + query
    data = urllib.parse.urlencode({"query": body}).encode()
    request = urllib.request.Request(endpoint, data=data, headers={"Accept": "text/csv"})
    if user:
        request.add_header("Authorization", "Basic " +
                           base64.b64encode(f"{user}:{password}".encode()).decode())
    with urllib.request.urlopen(request, timeout=900) as response:
        text = response.read().decode("utf-8")
    return [line.strip() for line in text.splitlines()[1:] if line.strip()]


def cell_int(rows):
    """One-row CSV -> int; 0 when empty.

    Values are IRIs, names, integers and counts: none holds a comma, so a plain
    split is safe.
    """
    if not rows:
        return 0
    return int(rows[0].split(",")[-1].strip('"'))


def statements(text):
    """Split a file of SELECTs on the ';' separator lines the files use."""
    statements = []
    current = []
    for line in text.splitlines():
        if line.strip() == ";":
            statements.append("\n".join(current))
            current = []
        else:
            current.append(line)
    if current:
        statements.append("\n".join(current))
    kept = []
    for statement in statements:
        # A leading comment block is its own segment; only segments with a
        # query word are sent.
        body = [line for line in statement.splitlines()
                if line.strip() and not line.strip().startswith("#")]
        if body:
            kept.append(statement)
    return kept


def run_checks(checks, failures):
    for row in checks:
        if not row:
            continue
        name, _, count = row.partition(",")
        name = name.strip('"')
        count = int(count.strip().strip('"') or 0)
        state = "ok" if count == 0 else "FAIL"
        print(f"{name:45s} {count:8d} {state}")
        if count != 0:
            failures += 1
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", required=True)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--user", default="dba")
    parser.add_argument("--password", default="dba")
    parser.add_argument("--graph", required=True,
                        help="the graph under verification (RVS_GRAPH or the staging graph)")
    parser.add_argument("--staging", required=True,
                        help="graph holding the staged dump, the reference for the subject-set checks")
    parser.add_argument("--account-count", type=int,
                        help="foaf:OnlineAccount count the account graph must still hold")
    parser.add_argument("--account-graph", default="http://mu.semte.ch/graphs/public",
                        help="graph holding RVS's own accounts (default: graphs/public, "
                             "where RVS keeps them, not the import target)")
    args = parser.parse_args()

    with open(os.path.join(args.dump, "manifest.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    # A manifest whose counts are all zero is refused before any query: every
    # class would "pass" against an empty graph and a loaded one alike, so the
    # zeros prove nothing and the run looks verified when it is not.
    if not any(entry.get("triples") or entry.get("subjects")
               for entry in manifest["counts"].values()):
        print(f"# counts against {args.dump}/manifest.json")
        print("# manifest counts are all zero: not a usable dump manifest")
        sys.exit(1)

    graph = args.graph.strip("<>")
    staging = args.staging.strip("<>")
    # A dry run verifies the staged graph against itself, where the
    # subject-set check has nothing to compare. It is skipped with a
    # note; the per-class counts still decide that run.
    compare_subjects = staging != graph

    def substituted(file, replacements):
        """Read a query file and fill its placeholders."""
        with open(os.path.join(HERE, "queries", file), encoding="utf-8") as handle:
            text = handle.read()
        for key, value in replacements.items():
            text = text.replace(key, value)
        return text

    replacements = {
        "@GRAPH@": args.graph.strip("<>"),
        "@RVS_GRAPH@": args.graph.strip("<>"),
        "@STAGING@": staging.strip("<>"),
    }
    failures = 0

    # 1. the .rq checks, one request per statement: the store does not accept
    # several ';'-separated SELECTs in one request.
    print(f"# verify rvs: {args.graph}")
    if not compare_subjects:
        print("# staged graph compared with itself: subject-set check skipped")
    for statement in statements(substituted("verify-import.rq", replacements)):
        if not compare_subjects and "subject-triples-missing" in statement:
            continue
        checks = fetch_rows(args.endpoint, statement, args.user, args.password)
        # An empty result is a pass: the statement found nothing to report.
        failures = run_checks(checks, failures)

    # 2. per-class counts against the manifest
    print(f"# counts against {args.dump}/manifest.json")
    for name, class_iri in read_classes():
        expected = manifest["counts"].get(name, {"triples": 0, "subjects": 0})
        actual_triples = cell_int(fetch_rows(
            args.endpoint,
            f"SELECT (COUNT(*) AS ?c) WHERE {{ GRAPH <{args.graph}> "
            f"{{ ?s rdf:type <{class_iri}> }} }}",
            args.user, args.password))
        actual_subjects = cell_int(fetch_rows(
            args.endpoint,
            f"SELECT (COUNT(DISTINCT ?s) AS ?c) WHERE {{ GRAPH <{args.graph}> "
            f"{{ ?s rdf:type <{class_iri}> }} }}",
            args.user, args.password))
        ok = (actual_triples == expected["triples"] and
              actual_subjects == expected["subjects"])
        state = "ok" if ok else "FAIL"
        print(f"{name:45s} {actual_triples:6d}/"
              f"{expected['triples']:6d} triples, "
              f"{actual_subjects:6d}/{expected['subjects']:6d} subjects {state}")
        if not ok:
            failures += 1

    # 3. seeded accounts
    if args.account_count is not None:
        actual = cell_int(fetch_rows(
            args.endpoint,
            f"SELECT (COUNT(*) AS ?c) WHERE {{ GRAPH <{args.account_graph.strip('<>')}> "
            f"{{ ?s rdf:type <http://xmlns.com/foaf/0.1/OnlineAccount> }} }}",
            args.user, args.password))
        state = "ok" if actual == args.account_count else "FAIL"
        print(f"{'foaf:OnlineAccount (unchanged)':45s} "
              f"{actual:6d}/{args.account_count:6d} {state}")
        if actual != args.account_count:
            failures += 1

    if failures:
        print(f"FAILED: {failures} failed check(s)")
        sys.exit(1)
    print("passed")


if __name__ == "__main__":
    main()
