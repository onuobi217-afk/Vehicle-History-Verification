;; title: maintenance-records
;; version: 1.0.0
;; summary: Append-only maintenance/service records by VIN
;; description: Stores per-VIN service entries with mileage and details. No cross-contract calls.

;; ============================================================
;; Maintenance Records (no traits, no cross-contract calls)
;; ============================================================

;; ------------------------
;; Errors
;; ------------------------
(define-constant err-invalid-vin (err u200))
(define-constant err-mileage-regression (err u201))
(define-constant err-empty-code (err u202))
(define-constant err-empty-desc (err u203))
(define-constant err-record-not-found (err u204))

(define-constant VIN-LEN u17)

;; ------------------------
;; Storage
;; ------------------------
;; Sequential per-VIN record index (starts at 0)
(define-map record-count
  { vin: (buff 17) }
  { count: uint }
)

;; Track last mileage per VIN to enforce monotonicity
(define-map last-mileage
  { vin: (buff 17) }
  { mileage: uint }
)

;; Actual record storage
(define-map records
  { vin: (buff 17), idx: uint }
  {
    mileage: uint,
    code: (string-ascii 16),
    description: (string-ascii 128),
    cost: uint,
    serviced-at: uint,
    provider: principal
  }
)

;; ------------------------
;; Helpers
;; ------------------------
(define-private (assert-vin (vin (buff 17)))
  (if (is-eq (len vin) VIN-LEN)
      (ok true)
      err-invalid-vin
  )
)

(define-private (nonempty16 (s (string-ascii 16)))
  (>= (len s) u1)
)

(define-private (nonempty128 (s (string-ascii 128)))
  (>= (len s) u1)
)

(define-private (count-for (vin (buff 17)))
  (match (map-get? record-count { vin: vin })
    entry (get count entry)
    u0
  )
)

(define-read-only (records-count (vin (buff 17)))
  (count-for vin)
)

(define-read-only (get-record (vin (buff 17)) (idx uint))
  (map-get? records { vin: vin, idx: idx })
)

(define-read-only (get-last-mileage (vin (buff 17)))
  (match (map-get? last-mileage { vin: vin })
    entry (some (get mileage entry))
    none
  )
)

;; ------------------------
;; Public entrypoints
;; ------------------------
(define-public (add-record
    (vin (buff 17))
    (mileage uint)
    (code (string-ascii 16))
    (description (string-ascii 128))
    (cost uint)
  )
  (begin
    (try! (assert-vin vin))
    (if (not (nonempty16 code)) err-empty-code
      (if (not (nonempty128 description)) err-empty-desc
        (let (
              (last (match (map-get? last-mileage { vin: vin })
                       entry (some (get mileage entry))
                       none))
             )
          (if (and (is-some last) (> (unwrap-panic last) mileage))
              err-mileage-regression
              (let (
                    (current-count (count-for vin))
                    (new-idx current-count)
                  )
                (map-set records { vin: vin, idx: new-idx }
                  {
                    mileage: mileage,
                    code: code,
                    description: description,
                    cost: cost,
                    serviced-at: u0,
                    provider: tx-sender
                  }
                )
                (map-set last-mileage { vin: vin } { mileage: mileage })
                (map-set record-count { vin: vin } { count: (+ current-count u1) })
                (ok new-idx)
              )
          )
        )
      )
    )
  )
)

;; Convenience: fetch the most recent record for a VIN
(define-read-only (get-latest (vin (buff 17)))
  (let ((cnt (count-for vin)))
    (if (> cnt u0)
        (map-get? records { vin: vin, idx: (- cnt u1) })
        none
    )
  )
)
