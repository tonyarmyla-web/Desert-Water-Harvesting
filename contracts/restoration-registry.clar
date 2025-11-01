;; Restoration Registry Contract
;; Document soil crust recovery, water catch basin locations, native shrub distribution, and degradation levels

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-unauthorized (err u104))

;; Data Variables
(define-data-var site-counter uint u0)
(define-data-var basin-counter uint u0)
(define-data-var observation-counter uint u0)

;; Data Maps
(define-map restoration-sites
  uint
  {
    owner: principal,
    location: {latitude: int, longitude: int},
    area: uint,
    degradation-level: uint,
    site-type: (string-ascii 50),
    registered-at: uint,
    last-updated: uint,
    active: bool
  }
)

(define-map water-basins
  uint
  {
    site-id: uint,
    basin-type: (string-ascii 30),
    capacity: uint,
    depth: uint,
    installed-at: uint,
    operational: bool
  }
)

(define-map soil-crust-observations
  uint
  {
    site-id: uint,
    observer: principal,
    recovery-stage: uint,
    coverage-percentage: uint,
    crust-thickness: uint,
    recorded-at: uint,
    notes: (string-ascii 200)
  }
)

(define-map native-shrub-distribution
  uint
  {
    site-id: uint,
    species: (string-ascii 50),
    count: uint,
    density-per-hectare: uint,
    health-index: uint,
    recorded-at: uint
  }
)

(define-map site-managers
  {site-id: uint, manager: principal}
  bool
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-site-owner (site-id uint))
  (match (map-get? restoration-sites site-id)
    site (is-eq tx-sender (get owner site))
    false
  )
)

(define-private (is-site-manager (site-id uint))
  (default-to false (map-get? site-managers {site-id: site-id, manager: tx-sender}))
)

(define-private (can-manage-site (site-id uint))
  (or (is-site-owner site-id) (is-site-manager site-id))
)

;; Read-Only Functions
(define-read-only (get-site (site-id uint))
  (map-get? restoration-sites site-id)
)

(define-read-only (get-basin (basin-id uint))
  (map-get? water-basins basin-id)
)

(define-read-only (get-observation (obs-id uint))
  (map-get? soil-crust-observations obs-id)
)

(define-read-only (get-shrub-data (record-id uint))
  (map-get? native-shrub-distribution record-id)
)

(define-read-only (get-site-counter)
  (var-get site-counter)
)

(define-read-only (get-basin-counter)
  (var-get basin-counter)
)

(define-read-only (get-observation-counter)
  (var-get observation-counter)
)

;; Public Functions
(define-public (register-site (location {latitude: int, longitude: int}) (area uint) (degradation-level uint) (site-type (string-ascii 50)))
  (let
    (
      (new-site-id (+ (var-get site-counter) u1))
    )
    (asserts! (and (> area u0) (<= degradation-level u10)) err-invalid-input)
    (map-set restoration-sites new-site-id
      {
        owner: tx-sender,
        location: location,
        area: area,
        degradation-level: degradation-level,
        site-type: site-type,
        registered-at: stacks-block-height,
        last-updated: stacks-block-height,
        active: true
      }
    )
    (var-set site-counter new-site-id)
    (ok new-site-id)
  )
)

(define-public (add-water-basin (site-id uint) (basin-type (string-ascii 30)) (capacity uint) (depth uint))
  (let
    (
      (new-basin-id (+ (var-get basin-counter) u1))
    )
    (asserts! (can-manage-site site-id) err-unauthorized)
    (asserts! (is-some (map-get? restoration-sites site-id)) err-not-found)
    (asserts! (and (> capacity u0) (> depth u0)) err-invalid-input)
    (map-set water-basins new-basin-id
      {
        site-id: site-id,
        basin-type: basin-type,
        capacity: capacity,
        depth: depth,
        installed-at: stacks-block-height,
        operational: true
      }
    )
    (var-set basin-counter new-basin-id)
    (ok new-basin-id)
  )
)

(define-public (record-soil-observation (site-id uint) (recovery-stage uint) (coverage-percentage uint) (crust-thickness uint) (notes (string-ascii 200)))
  (let
    (
      (new-obs-id (+ (var-get observation-counter) u1))
    )
    (asserts! (is-some (map-get? restoration-sites site-id)) err-not-found)
    (asserts! (and (<= recovery-stage u10) (<= coverage-percentage u100)) err-invalid-input)
    (map-set soil-crust-observations new-obs-id
      {
        site-id: site-id,
        observer: tx-sender,
        recovery-stage: recovery-stage,
        coverage-percentage: coverage-percentage,
        crust-thickness: crust-thickness,
        recorded-at: stacks-block-height,
        notes: notes
      }
    )
    (var-set observation-counter new-obs-id)
    (ok new-obs-id)
  )
)

(define-public (record-shrub-distribution (site-id uint) (species (string-ascii 50)) (count uint) (density-per-hectare uint) (health-index uint))
  (let
    (
      (record-id (+ (var-get observation-counter) u1))
    )
    (asserts! (is-some (map-get? restoration-sites site-id)) err-not-found)
    (asserts! (and (> count u0) (<= health-index u10)) err-invalid-input)
    (map-set native-shrub-distribution record-id
      {
        site-id: site-id,
        species: species,
        count: count,
        density-per-hectare: density-per-hectare,
        health-index: health-index,
        recorded-at: stacks-block-height
      }
    )
    (ok record-id)
  )
)

(define-public (update-degradation-level (site-id uint) (new-level uint))
  (let
    (
      (site (unwrap! (map-get? restoration-sites site-id) err-not-found))
    )
    (asserts! (can-manage-site site-id) err-unauthorized)
    (asserts! (<= new-level u10) err-invalid-input)
    (map-set restoration-sites site-id
      (merge site {degradation-level: new-level, last-updated: stacks-block-height})
    )
    (ok true)
  )
)

(define-public (add-site-manager (site-id uint) (manager principal))
  (begin
    (asserts! (is-site-owner site-id) err-unauthorized)
    (asserts! (is-some (map-get? restoration-sites site-id)) err-not-found)
    (map-set site-managers {site-id: site-id, manager: manager} true)
    (ok true)
  )
)

(define-public (remove-site-manager (site-id uint) (manager principal))
  (begin
    (asserts! (is-site-owner site-id) err-unauthorized)
    (map-delete site-managers {site-id: site-id, manager: manager})
    (ok true)
  )
)

(define-public (deactivate-site (site-id uint))
  (let
    (
      (site (unwrap! (map-get? restoration-sites site-id) err-not-found))
    )
    (asserts! (is-site-owner site-id) err-unauthorized)
    (map-set restoration-sites site-id
      (merge site {active: false, last-updated: stacks-block-height})
    )
    (ok true)
  )
)

(define-public (reactivate-site (site-id uint))
  (let
    (
      (site (unwrap! (map-get? restoration-sites site-id) err-not-found))
    )
    (asserts! (is-site-owner site-id) err-unauthorized)
    (map-set restoration-sites site-id
      (merge site {active: true, last-updated: stacks-block-height})
    )
    (ok true)
  )
)

;; title: restoration-registry
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


