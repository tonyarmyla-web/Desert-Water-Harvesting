;; Land Payments Contract
;; Compensate pastoralists and land stewards for grazing reduction, revegetation commitment, and exclusion zones

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-found (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-invalid-input (err u403))
(define-constant err-insufficient-funds (err u404))
(define-constant err-already-claimed (err u405))
(define-constant err-not-eligible (err u406))

;; Data Variables
(define-data-var payment-counter uint u0)
(define-data-var steward-counter uint u0)
(define-data-var commitment-counter uint u0)
(define-data-var total-distributed uint u0)

;; Data Maps
(define-map land-stewards
  principal
  {
    steward-id: uint,
    site-id: uint,
    registered-at: uint,
    total-received: uint,
    last-payment: uint,
    active: bool
  }
)

(define-map grazing-reduction-commitments
  uint
  {
    steward: principal,
    site-id: uint,
    reduction-percentage: uint,
    duration-blocks: uint,
    start-block: uint,
    end-block: uint,
    monthly-payment: uint,
    verified: bool
  }
)

(define-map revegetation-commitments
  uint
  {
    steward: principal,
    site-id: uint,
    area: uint,
    species-target: uint,
    commitment-period: uint,
    start-block: uint,
    milestone-payment: uint,
    completed: bool
  }
)

(define-map exclusion-zones
  uint
  {
    steward: principal,
    site-id: uint,
    zone-area: uint,
    protection-level: uint,
    annual-payment: uint,
    established-at: uint,
    active: bool
  }
)

(define-map payment-records
  uint
  {
    recipient: principal,
    payment-type: (string-ascii 30),
    amount: uint,
    commitment-id: uint,
    processed-at: uint,
    processor: principal,
    notes: (string-ascii 200)
  }
)

(define-map payment-claims
  {steward: principal, commitment-id: uint, period: uint}
  bool
)

(define-map authorized-verifiers
  principal
  bool
)

(define-map steward-performance
  principal
  {
    compliance-score: uint,
    violations: uint,
    completed-commitments: uint,
    active-commitments: uint
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-verifier)
  (or (is-contract-owner) (default-to false (map-get? authorized-verifiers tx-sender)))
)

(define-private (is-registered-steward (steward principal))
  (is-some (map-get? land-stewards steward))
)

;; Read-Only Functions
(define-read-only (get-steward (steward principal))
  (map-get? land-stewards steward)
)

(define-read-only (get-grazing-commitment (commitment-id uint))
  (map-get? grazing-reduction-commitments commitment-id)
)

(define-read-only (get-revegetation-commitment (commitment-id uint))
  (map-get? revegetation-commitments commitment-id)
)

(define-read-only (get-exclusion-zone (zone-id uint))
  (map-get? exclusion-zones zone-id)
)

(define-read-only (get-payment-record (payment-id uint))
  (map-get? payment-records payment-id)
)

(define-read-only (get-steward-performance (steward principal))
  (map-get? steward-performance steward)
)

(define-read-only (has-claimed (steward principal) (commitment-id uint) (period uint))
  (default-to false (map-get? payment-claims {steward: steward, commitment-id: commitment-id, period: period}))
)

(define-read-only (get-total-distributed)
  (var-get total-distributed)
)

(define-read-only (get-payment-counter)
  (var-get payment-counter)
)

;; Public Functions
(define-public (register-steward (site-id uint))
  (let
    (
      (new-steward-id (+ (var-get steward-counter) u1))
    )
    (asserts! (not (is-registered-steward tx-sender)) err-invalid-input)
    (map-set land-stewards tx-sender
      {
        steward-id: new-steward-id,
        site-id: site-id,
        registered-at: stacks-block-height,
        total-received: u0,
        last-payment: u0,
        active: true
      }
    )
    (map-set steward-performance tx-sender
      {
        compliance-score: u100,
        violations: u0,
        completed-commitments: u0,
        active-commitments: u0
      }
    )
    (var-set steward-counter new-steward-id)
    (ok new-steward-id)
  )
)

(define-public (create-grazing-reduction (site-id uint) (reduction-percentage uint) (duration-blocks uint) (monthly-payment uint))
  (let
    (
      (new-commitment-id (+ (var-get commitment-counter) u1))
      (end-block (+ stacks-block-height duration-blocks))
    )
    (asserts! (is-registered-steward tx-sender) err-not-eligible)
    (asserts! (and (> reduction-percentage u0) (<= reduction-percentage u100)) err-invalid-input)
    (asserts! (> duration-blocks u0) err-invalid-input)
    (map-set grazing-reduction-commitments new-commitment-id
      {
        steward: tx-sender,
        site-id: site-id,
        reduction-percentage: reduction-percentage,
        duration-blocks: duration-blocks,
        start-block: stacks-block-height,
        end-block: end-block,
        monthly-payment: monthly-payment,
        verified: false
      }
    )
    (var-set commitment-counter new-commitment-id)
    (ok new-commitment-id)
  )
)

(define-public (create-revegetation-commitment (site-id uint) (area uint) (species-target uint) (commitment-period uint) (milestone-payment uint))
  (let
    (
      (new-commitment-id (+ (var-get commitment-counter) u1))
    )
    (asserts! (is-registered-steward tx-sender) err-not-eligible)
    (asserts! (and (> area u0) (> species-target u0) (> commitment-period u0)) err-invalid-input)
    (map-set revegetation-commitments new-commitment-id
      {
        steward: tx-sender,
        site-id: site-id,
        area: area,
        species-target: species-target,
        commitment-period: commitment-period,
        start-block: stacks-block-height,
        milestone-payment: milestone-payment,
        completed: false
      }
    )
    (var-set commitment-counter new-commitment-id)
    (ok new-commitment-id)
  )
)

(define-public (establish-exclusion-zone (site-id uint) (zone-area uint) (protection-level uint) (annual-payment uint))
  (let
    (
      (new-zone-id (+ (var-get commitment-counter) u1))
    )
    (asserts! (is-registered-steward tx-sender) err-not-eligible)
    (asserts! (and (> zone-area u0) (<= protection-level u10)) err-invalid-input)
    (map-set exclusion-zones new-zone-id
      {
        steward: tx-sender,
        site-id: site-id,
        zone-area: zone-area,
        protection-level: protection-level,
        annual-payment: annual-payment,
        established-at: stacks-block-height,
        active: true
      }
    )
    (var-set commitment-counter new-zone-id)
    (ok new-zone-id)
  )
)

(define-public (process-payment (recipient principal) (payment-type (string-ascii 30)) (amount uint) (commitment-id uint) (notes (string-ascii 200)))
  (let
    (
      (new-payment-id (+ (var-get payment-counter) u1))
      (steward (unwrap! (map-get? land-stewards recipient) err-not-found))
    )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (asserts! (> amount u0) err-invalid-input)
    (map-set payment-records new-payment-id
      {
        recipient: recipient,
        payment-type: payment-type,
        amount: amount,
        commitment-id: commitment-id,
        processed-at: stacks-block-height,
        processor: tx-sender,
        notes: notes
      }
    )
    (map-set land-stewards recipient
      (merge steward {
        total-received: (+ (get total-received steward) amount),
        last-payment: stacks-block-height
      })
    )
    (var-set payment-counter new-payment-id)
    (var-set total-distributed (+ (var-get total-distributed) amount))
    (ok new-payment-id)
  )
)

(define-public (claim-periodic-payment (commitment-id uint) (period uint))
  (let
    (
      (commitment (unwrap! (map-get? grazing-reduction-commitments commitment-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get steward commitment)) err-unauthorized)
    (asserts! (get verified commitment) err-not-eligible)
    (asserts! (not (has-claimed tx-sender commitment-id period)) err-already-claimed)
    (map-set payment-claims {steward: tx-sender, commitment-id: commitment-id, period: period} true)
    (ok true)
  )
)

(define-public (verify-commitment (commitment-id uint))
  (let
    (
      (commitment (unwrap! (map-get? grazing-reduction-commitments commitment-id) err-not-found))
    )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (map-set grazing-reduction-commitments commitment-id
      (merge commitment {verified: true})
    )
    (ok true)
  )
)

(define-public (complete-revegetation (commitment-id uint))
  (let
    (
      (commitment (unwrap! (map-get? revegetation-commitments commitment-id) err-not-found))
    )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (map-set revegetation-commitments commitment-id
      (merge commitment {completed: true})
    )
    (ok true)
  )
)

(define-public (update-steward-compliance (steward principal) (compliance-score uint) (violations uint))
  (let
    (
      (performance (unwrap! (map-get? steward-performance steward) err-not-found))
    )
    (asserts! (is-authorized-verifier) err-unauthorized)
    (asserts! (<= compliance-score u100) err-invalid-input)
    (map-set steward-performance steward
      (merge performance {compliance-score: compliance-score, violations: violations})
    )
    (ok true)
  )
)

(define-public (deactivate-steward (steward principal))
  (let
    (
      (steward-data (unwrap! (map-get? land-stewards steward) err-not-found))
    )
    (asserts! (is-contract-owner) err-owner-only)
    (map-set land-stewards steward
      (merge steward-data {active: false})
    )
    (ok true)
  )
)

(define-public (authorize-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

(define-public (revoke-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-delete authorized-verifiers verifier)
    (ok true)
  )
)

;; title: land-payments
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;


