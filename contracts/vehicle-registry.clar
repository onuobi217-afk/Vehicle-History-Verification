;; title: vehicle-registry
;; version: 1.0.0
;; summary: Vehicle identification and ownership history registry
;; description: Manages VIN-based vehicle records and ownership without cross-contract calls.

;; ============================================================
;; Vehicle Registry (no traits, no cross-contract calls)
;; ============================================================

;; ------------------------
;; Errors
;; ------------------------
(define-constant err-unauthorized (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-found (err u102))
(define-constant err-invalid-year (err u103))
(define-constant err-invalid-vin (err u104))
(define-constant err-empty-field (err u105))

;; ------------------------
;; Types
;; ------------------------
(define-constant MAX-MAKE-LEN u32)
(define-constant MAX-MODEL-LEN u32)
(define-constant VIN-LEN u17)

(define-constant NONE-PRINCIPAL none)

;; A vehicle is stored keyed by exact VIN bytes (17 characters)
(define-map vehicles
  { vin: (buff 17) }
  {
    owner: principal,
    make: (string-ascii 32),
    model: (string-ascii 32),
    year: uint,
    created-at: uint
  }
)

;; Optional note field per VIN
(define-map notes
  { vin: (buff 17) }
  { note: (string-ascii 160) }
)

;; Counters and metadata
(define-data-var total-vehicles uint u0)

;; ------------------------
;; Helpers
;; ------------------------
(define-private (is-ascii-nonempty (s (string-ascii 32)))
  (>= (len s) u1)
)

(define-constant YEAR-MIN u1886)
(define-constant YEAR-MAX u2100)

(define-private (is-valid-year (y uint))
  (and (>= y YEAR-MIN) (<= y YEAR-MAX))
)

(define-private (assert-vin (vin (buff 17)))
  (if (is-eq (len vin) VIN-LEN)
      (ok true)
      err-invalid-vin
  )
)

(define-private (require-owner (vin (buff 17)))
  (match (map-get? vehicles { vin: vin })
    entry (if (is-eq tx-sender (get owner entry))
              (ok true)
              err-unauthorized)
    err-not-found
  )
)

;; Bring an existing entry as tuple or none
(define-read-only (get-vehicle (vin (buff 17)))
  (map-get? vehicles { vin: vin })
)

(define-read-only (is-registered (vin (buff 17)))
  (is-some (map-get? vehicles { vin: vin }))
)

(define-read-only (get-owner (vin (buff 17)))
  (match (map-get? vehicles { vin: vin })
    entry (some (get owner entry))
    none
  )
)

;; ------------------------
;; Public entrypoints
;; ------------------------
(define-public (register-vehicle
    (vin (buff 17))
    (make (string-ascii 32))
    (model (string-ascii 32))
    (year uint)
  )
  (begin
    (try! (assert-vin vin))
    (if (is-some (map-get? vehicles { vin: vin }))
        err-already-registered
        (if (not (is-ascii-nonempty make)) err-empty-field
          (if (not (is-ascii-nonempty model)) err-empty-field
            (if (not (is-valid-year year)) err-invalid-year
              (begin
                (map-set vehicles { vin: vin }
                  {
                    owner: tx-sender,
                    make: make,
                    model: model,
                    year: year,
                    created-at: u0
                  }
                )
                (var-set total-vehicles (+ (var-get total-vehicles) u1))
                (ok vin)
              )
            )
          )
        )
    )
  )
)

(define-public (update-owner (vin (buff 17)) (new-owner principal))
  (begin
    (try! (assert-vin vin))
    (try! (require-owner vin))
    (map-insert vehicles { vin: vin } ;; overwrite allowed: use map-set
      (unwrap! (map-get? vehicles { vin: vin }) err-not-found)
    )
    ;; fetch again and mutate owner
    (match (map-get? vehicles { vin: vin })
      v (begin
          (map-set vehicles { vin: vin }
            {
              owner: new-owner,
              make: (get make v),
              model: (get model v),
              year: (get year v),
              created-at: (get created-at v)
            }
          )
          (ok new-owner)
        )
      err-not-found
    )
  )
)

(define-public (set-vehicle-metadata
    (vin (buff 17))
    (make (string-ascii 32))
    (model (string-ascii 32))
    (year uint)
  )
  (begin
    (try! (assert-vin vin))
    (try! (require-owner vin))
    (if (not (is-ascii-nonempty make)) err-empty-field
      (if (not (is-ascii-nonempty model)) err-empty-field
        (if (not (is-valid-year year)) err-invalid-year
          (match (map-get? vehicles { vin: vin })
            v (begin
                (map-set vehicles { vin: vin }
                  {
                    owner: (get owner v),
                    make: make,
                    model: model,
                    year: year,
                    created-at: (get created-at v)
                  }
                )
                (ok true)
              )
            err-not-found
          )
        )
      )
    )
  )
)

(define-public (set-note (vin (buff 17)) (note (string-ascii 160)))
  (begin
    (try! (assert-vin vin))
    (try! (require-owner vin))
    (map-set notes { vin: vin } { note: note })
    (ok true)
  )
)

;; ------------------------
;; Additional read-onlys
;; ------------------------
(define-read-only (get-note (vin (buff 17)))
  (map-get? notes { vin: vin })
)

(define-read-only (total-registered)
  (var-get total-vehicles)
)
