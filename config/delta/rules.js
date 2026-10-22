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
];
