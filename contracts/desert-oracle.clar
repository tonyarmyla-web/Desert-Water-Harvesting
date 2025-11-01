;; Desert Oracle Contract
;; Soil moisture sensors, groundwater wells, vegetation surveys, and rainfall gauge data

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-input (err u203))
(define-constant err-sensor-offline (err u204))

;; Data Variables
(define-data-var reading-counter uint u0)
(define-data-var sensor-counter uint u0)
(define-data-var survey-counter uint u0)
(define-data-var oracle-active bool true)

;; Data Maps
(define-map sensor-registry
  uint
  {
    sensor-type: (string-ascii 30),
    location: {latitude: int, longitude: int},
    site-id: uint,
    operator: principal,
    installed-at: uint,
    last-calibrated: uint,
    active: bool,
    calibration-interval: uint
  }
)

(define-map soil-moisture-readings
  uint
  {
    sensor-id: uint,
    moisture-percentage: uint,
    temperature: int,
    depth: uint,
    recorded-at: uint,
    recorder: principal
  }
)

(define-map groundwater-readings
  uint
  {
    well-id: uint,
    water-level: uint,
    depth-to-water: uint,
    quality-index: uint,
    recorded-at: uint,
    recorder: principal
  }
)

(define-map rainfall-data
  uint
  {
    gauge-id: uint,
    amount: uint,
    duration: uint,
    intensity: uint,
    recorded-at: uint,
    recorder: principal
  }
)

(define-map vegetation-surveys
  uint
  {
    site-id: uint,
    surveyor: principal,
    total-coverage: uint,
    species-count: uint,
    biomass-estimate: uint,
    survey-date: uint,
    notes: (string-ascii 200)
  }
)

(define-map authorized-operators
  principal
  bool
)

(define-map sensor-maintenance-log
  {sensor-id: uint, timestamp: uint}
  {
    maintenance-type: (string-ascii 50),
    technician: principal,
    notes: (string-ascii 200)
  }
)

;; Authorization Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-authorized-operator)
  (or (is-contract-owner) (default-to false (map-get? authorized-operators tx-sender)))
)

(define-private (is-sensor-operator (sensor-id uint))
  (match (map-get? sensor-registry sensor-id)
    sensor (is-eq tx-sender (get operator sensor))
    false
  )
)

;; Read-Only Functions
(define-read-only (get-sensor (sensor-id uint))
  (map-get? sensor-registry sensor-id)
)

(define-read-only (get-soil-reading (reading-id uint))
  (map-get? soil-moisture-readings reading-id)
)

(define-read-only (get-groundwater-reading (reading-id uint))
  (map-get? groundwater-readings reading-id)
)

(define-read-only (get-rainfall-data (reading-id uint))
  (map-get? rainfall-data reading-id)
)

(define-read-only (get-vegetation-survey (survey-id uint))
  (map-get? vegetation-surveys survey-id)
)

(define-read-only (get-reading-counter)
  (var-get reading-counter)
)

(define-read-only (get-sensor-counter)
  (var-get sensor-counter)
)

(define-read-only (is-operator-authorized (operator principal))
  (default-to false (map-get? authorized-operators operator))
)

(define-read-only (is-oracle-active)
  (var-get oracle-active)
)

;; Public Functions
(define-public (register-sensor (sensor-type (string-ascii 30)) (location {latitude: int, longitude: int}) (site-id uint) (calibration-interval uint))
  (let
    (
      (new-sensor-id (+ (var-get sensor-counter) u1))
    )
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (> calibration-interval u0) err-invalid-input)
    (map-set sensor-registry new-sensor-id
      {
        sensor-type: sensor-type,
        location: location,
        site-id: site-id,
        operator: tx-sender,
        installed-at: stacks-block-height,
        last-calibrated: stacks-block-height,
        active: true,
        calibration-interval: calibration-interval
      }
    )
    (var-set sensor-counter new-sensor-id)
    (ok new-sensor-id)
  )
)

(define-public (submit-soil-moisture (sensor-id uint) (moisture-percentage uint) (temperature int) (depth uint))
  (let
    (
      (new-reading-id (+ (var-get reading-counter) u1))
      (sensor (unwrap! (map-get? sensor-registry sensor-id) err-not-found))
    )
    (asserts! (get active sensor) err-sensor-offline)
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (<= moisture-percentage u100) err-invalid-input)
    (map-set soil-moisture-readings new-reading-id
      {
        sensor-id: sensor-id,
        moisture-percentage: moisture-percentage,
        temperature: temperature,
        depth: depth,
        recorded-at: stacks-block-height,
        recorder: tx-sender
      }
    )
    (var-set reading-counter new-reading-id)
    (ok new-reading-id)
  )
)

(define-public (submit-groundwater-reading (well-id uint) (water-level uint) (depth-to-water uint) (quality-index uint))
  (let
    (
      (new-reading-id (+ (var-get reading-counter) u1))
    )
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (and (> water-level u0) (<= quality-index u100)) err-invalid-input)
    (map-set groundwater-readings new-reading-id
      {
        well-id: well-id,
        water-level: water-level,
        depth-to-water: depth-to-water,
        quality-index: quality-index,
        recorded-at: stacks-block-height,
        recorder: tx-sender
      }
    )
    (var-set reading-counter new-reading-id)
    (ok new-reading-id)
  )
)

(define-public (submit-rainfall-data (gauge-id uint) (amount uint) (duration uint) (intensity uint))
  (let
    (
      (new-reading-id (+ (var-get reading-counter) u1))
    )
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (and (> amount u0) (> duration u0)) err-invalid-input)
    (map-set rainfall-data new-reading-id
      {
        gauge-id: gauge-id,
        amount: amount,
        duration: duration,
        intensity: intensity,
        recorded-at: stacks-block-height,
        recorder: tx-sender
      }
    )
    (var-set reading-counter new-reading-id)
    (ok new-reading-id)
  )
)

(define-public (submit-vegetation-survey (site-id uint) (total-coverage uint) (species-count uint) (biomass-estimate uint) (notes (string-ascii 200)))
  (let
    (
      (new-survey-id (+ (var-get survey-counter) u1))
    )
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (and (<= total-coverage u100) (> species-count u0)) err-invalid-input)
    (map-set vegetation-surveys new-survey-id
      {
        site-id: site-id,
        surveyor: tx-sender,
        total-coverage: total-coverage,
        species-count: species-count,
        biomass-estimate: biomass-estimate,
        survey-date: stacks-block-height,
        notes: notes
      }
    )
    (var-set survey-counter new-survey-id)
    (ok new-survey-id)
  )
)

(define-public (calibrate-sensor (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensor-registry sensor-id) err-not-found))
    )
    (asserts! (or (is-contract-owner) (is-sensor-operator sensor-id)) err-unauthorized)
    (map-set sensor-registry sensor-id
      (merge sensor {last-calibrated: stacks-block-height})
    )
    (ok true)
  )
)

(define-public (log-sensor-maintenance (sensor-id uint) (maintenance-type (string-ascii 50)) (notes (string-ascii 200)))
  (begin
    (asserts! (is-authorized-operator) err-unauthorized)
    (asserts! (is-some (map-get? sensor-registry sensor-id)) err-not-found)
    (map-set sensor-maintenance-log {sensor-id: sensor-id, timestamp: stacks-block-height}
      {
        maintenance-type: maintenance-type,
        technician: tx-sender,
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (deactivate-sensor (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensor-registry sensor-id) err-not-found))
    )
    (asserts! (or (is-contract-owner) (is-sensor-operator sensor-id)) err-unauthorized)
    (map-set sensor-registry sensor-id
      (merge sensor {active: false})
    )
    (ok true)
  )
)

(define-public (reactivate-sensor (sensor-id uint))
  (let
    (
      (sensor (unwrap! (map-get? sensor-registry sensor-id) err-not-found))
    )
    (asserts! (or (is-contract-owner) (is-sensor-operator sensor-id)) err-unauthorized)
    (map-set sensor-registry sensor-id
      (merge sensor {active: true})
    )
    (ok true)
  )
)

(define-public (authorize-operator (operator principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-set authorized-operators operator true)
    (ok true)
  )
)

(define-public (revoke-operator (operator principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (map-delete authorized-operators operator)
    (ok true)
  )
)

(define-public (toggle-oracle)
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set oracle-active (not (var-get oracle-active)))
    (ok (var-get oracle-active))
  )
)

;; title: desert-oracle
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


