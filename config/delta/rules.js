export default [
  {
    match: {
      subject: {},
    },
    callback: {
      url: "http://resource/.mu/delta",
      method: "POST",
    },
    options: {
      resourceFormat: "v0.0.1",
      gracePeriod: 1000,
      foldEffectiveChanges: true,
      ignoreFromSelf: true,
    },
  },
  {
    // mu-search: the organisation index follows the organisation data (as in OP, which also
    // leaves the public graph out: a renamed code list or location does not update the index)
    match: {
      graph: {
        type: "uri",
        value: "http://mu.semte.ch/graphs/administrative-unit",
      },
    },
    callback: {
      url: "http://search/update",
      method: "POST",
    },
    options: {
      resourceFormat: "v0.0.1",
      gracePeriod: 10000,
      ignoreFromSelf: true,
    },
  },
  {
    // The delta producer's jobs: the controller starts the next task of a job when its task
    // reports a new status (as in OP).
    match: {
      predicate: {
        type: "uri",
        value: "http://www.w3.org/ns/adms#status",
      },
    },
    callback: {
      url: "http://jobs-controller/delta",
      method: "POST",
    },
    options: {
      resourceFormat: "v0.0.1",
      gracePeriod: 1000,
      ignoreFromSelf: true,
      optOutMuScopeIds: [
        "http://redpencil.data.gift/id/concept/muScope/deltas/initialSync",
      ],
    },
  },
  {
    // The delta producer: every change goes to the publication-graph-maintainer, which keeps
    // the publication graph and the delta files in step with it (the export config decides what
    // it copies). As in OP the rule matches every graph: the maintainer also has to see the
    // tasks of the jobs graph, or it never starts the initial sync. The initial sync and the
    // maintainer's own writes are left out by mu scope, as in OP.
    match: {},
    callback: {
      url: "http://delta-producer-publication-graph-maintainer/delta",
      method: "POST",
    },
    options: {
      resourceFormat: "v0.0.1",
      gracePeriod: 1000,
      ignoreFromSelf: true,
      optOutMuScopeIds: [
        "http://redpencil.data.gift/id/concept/muScope/deltas/initialSync",
        "http://redpencil.data.gift/id/concept/muScope/deltas/publicationGraphMaintenance",
      ],
    },
  },
  {
    // The dump-file-publisher picks up the dump-creation and initial-sync jobs once they are
    // scheduled (as in OP).
    match: {
      predicate: {
        type: "uri",
        value: "http://www.w3.org/ns/adms#status",
      },
      object: {
        type: "uri",
        value: "http://redpencil.data.gift/id/concept/JobStatus/scheduled",
      },
    },
    callback: {
      url: "http://delta-producer-dump-file-publisher/delta",
      method: "POST",
    },
    options: {
      resourceFormat: "v0.0.1",
      gracePeriod: 1000,
      ignoreFromSelf: true,
      optOutMuScopeIds: [
        "http://redpencil.data.gift/id/concept/muScope/deltas/initialSync",
      ],
    },
  },
];
