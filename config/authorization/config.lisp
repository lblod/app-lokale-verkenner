;;;;;;;;;;;;;;;;;;;
;;; delta messenger
(in-package :delta-messenger)

;; (push (make-instance 'delta-logging-handler) *delta-handlers*) ;; enable if delta messages should be logged on terminal
(add-delta-messenger "http://delta-notifier/")
(setf *log-delta-messenger-message-bus-processing* nil) ;; set to t for extra messages for debugging delta messenger

;;;;;;;;;;;;;;;;;
;;; configuration
(in-package :client)
(setf *log-sparql-query-roundtrip* nil) ; change nil to t for logging requests to virtuoso (and the response)
(setf *backend* "http://triplestore:8890/sparql")

(in-package :server)
(setf *log-incoming-requests-p* nil) ; change nil to t for logging all incoming requests

;;;;;;;;;;;;;;;;
;;; prefix types
(in-package :type-cache)

(add-type-for-prefix "http://mu.semte.ch/sessions/" "http://mu.semte.ch/vocabularies/session/Session") ; each session URI will be handled for updates as if it had this mussession:Session type

;;;;;;;;;;;;;;;;;
;;; access rights

(in-package :acl)

;; these three reset the configuration, they are likely not necessary
(defparameter *access-specifications* nil)
(defparameter *graphs* nil)
(defparameter *rights* nil)

;; Prefixes used in the constraints below (not in the SPARQL queries)
(define-prefixes
  ;; Core
  :mu "http://mu.semte.ch/vocabularies/core/"
  :session "http://mu.semte.ch/vocabularies/session/"
  :ext "http://mu.semte.ch/vocabularies/ext/"
  ;; Custom prefix URIs here, prefix casing is ignored
  :org "http://www.w3.org/ns/org#"
  :besluit "http://data.vlaanderen.be/ns/besluit#"
  :regorg "http://www.w3.org/ns/regorg#"
  :locn "http://www.w3.org/ns/locn#"
  :schema "http://schema.org/"
  :adms "http://www.w3.org/ns/adms#"
  :generiek "https://data.vlaanderen.be/ns/generiek#"
  :rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  :oslc "http://open-services.net/ns/core#"
  :code "http://lblod.data.gift/vocabularies/organisatie/"
  :besluitvorming "https://data.vlaanderen.be/ns/besluitvorming#"
  :cr "http://lblod.data.gift/vocabularies/change-requests/")


;;;;;;;;;
;; Graphs
;;
;; These are the graph specifications known in the system.  No
;; guarantees are given as to what content is readable from a graph.  If
;; two graphs are nearly identical and have the same name, perhaps the
;; specifications can be folded too.  This could help when building
;; indexes.

;; All organisation data, the accounts of mock-login and the code lists. Read side only:
;; nobody gets a write grant on this spec, so it can stay "any type, any predicate".
(define-graph public ("http://mu.semte.ch/graphs/public")
  (_ -> _)) ; public allows ANY TYPE -> ANY PREDICATE in the direction
            ; of the arrow

;; The same graph, as the change-request service may write it: only the types of its aggregates
;; (organisations, sites, addresses, contact points, identifiers, change events with their
;; results and decisions; see config/change-requests/change-requests.json). Listing the types also
;; keeps the service's own records (cr:ChangeRequest, cr:Action, cr:ProposedVersion,
;; cr:RecordState, ...) out of this graph: sparql-parser writes a quad to every writable graph
;; whose specification matches it, and "_ -> _" would match them too.
(define-graph organisation-data ("http://mu.semte.ch/graphs/public")
  ("org:Organization" -> _)
  ("besluit:Bestuurseenheid" -> _)
  ("regorg:RegisteredOrganization" -> _)
  ("org:Site" -> _)
  ("locn:Address" -> _)
  ("schema:ContactPoint" -> _)
  ("adms:Identifier" -> _)
  ("generiek:GestructureerdeIdentificator" -> _)
  ;; what a request to register a new organisation or a veranderingsgebeurtenis applies on approval
  ("org:ChangeEvent" -> _)
  ("code:VeranderingsgebeurtenisResultaat" -> _)
  ("besluit:Besluit" -> _)
  ("besluitvorming:Beslissingsactiviteit" -> _))

;; Change requests and their versions, the history of every edit. Only the change-request
;; service reads and writes it; it decides per request who may see it. Every class the service
;; writes must be listed: sparql-parser places a quad by the type of its subject.
(define-graph change-requests ("http://mu.semte.ch/graphs/change-requests" :delta nil)
  ("cr:ChangeRequest" -> _)
  ;; the steps of a request (indiening, goedkeuring, ...)
  ("cr:Action" -> _)
  ;; the proposed state of each record a request changes
  ("cr:ProposedVersion" -> _)
  ;; the values a version started from, and the values an apply replaced
  ("cr:RecordState" -> _)
  ;; the links that pointed at a deleted record, kept by its record states
  ("rdf:Statement" -> _)
  ;; why an apply failed
  ("oslc:Error" -> _))

;; The sessions mock-login (and later the login service) writes. The change-request service
;; reads the account and the organisation of a session from it.
(define-graph sessions ("http://mu.semte.ch/graphs/sessions")
  ("session:Session" -> _))


;;;;;;;;;;;;;
;; User roles

(supply-allowed-group "public")

;; Nobody writes the organisation data directly: every edit is a change request.
;; Writes happen only through change-request-service (POST /change-requests), which sends the
;; scope below and enforces who may edit what (its policies/ folder). Reads of change requests
;; are filtered per organisation by that service, not here.
;; A direct POST, PATCH or DELETE on a resource route has no writable graph and is refused.
(grant (read)
       :to-graph public
       :for-allowed-group "public")

;; The exception: the change-request service. The scope header can only come from a service in
;; the stack: mu-identifier (1.11.0 and later) strips mu-auth-scope from what a browser sends.
(with-scope "http://services.lblod.info/change-request-service"
  (grant (read)
         :to-graph (public sessions)
         :for-allowed-group "public")
  (grant (read write)
         :to-graph (organisation-data change-requests)
         :for-allowed-group "public"))
