# Vehicle-History-Verification

Comprehensive vehicle history tracking to help prevent odometer fraud and title washing. This Clarinet project defines smart contracts in Clarity that allow registering vehicles and recording service/maintenance history on-chain.

Note: This initial main branch contains only project initialization files and documentation. All contract development happens on the development branch.

## Overview

The system is designed around two core contracts (no cross-contract calls):

- vehicle-registry: Manages unique vehicle records (VIN), basic metadata, and ownership assertions via principal addresses.
- maintenance-records: Appends immutable service records per vehicle (by VIN) with mileage, service codes, cost, and timestamp.

These contracts are intentionally decoupled, following the requirement to avoid cross-contract calls or traits. Each contract validates its inputs independently.

## Data Model

- Vehicle (vehicle-registry)
  - vin: (buff 17) – normalized VIN as bytes (17 chars)
  - owner: principal – owner principal
  - make: (string-ascii 32)
  - model: (string-ascii 32)
  - year: uint

- ServiceRecord (maintenance-records)
  - vin: (buff 17)
  - mileage: uint
  - code: (string-ascii 16) – maintenance or DTC code (e.g., OBD-II)
  - description: (string-ascii 128)
  - cost: uint (nominal units)
  - serviced-at: uint (block-height snapshot)
  - provider: principal (submitter)

## Core Functions (summary)

vehicle-registry
- register-vehicle: Register a new VIN with metadata and owner
- update-owner: Change recorded owner (only current owner)
- set-vehicle-metadata: Update make/model/year (only owner)
- get-vehicle: Read-only get vehicle by VIN
- is-registered: Read-only boolean check

maintenance-records
- add-record: Append a new maintenance record for a VIN
- records-count: Read-only count of records for a VIN
- get-record: Read-only fetch by VIN and index
- last-mileage: Read-only fetch last recorded mileage for VIN

## Development

- Check contracts: clarinet check
- Create a new contract scaffold (on development branch): clarinet contract new <name>

## Branching Strategy

- main: initialization files and documentation only.
- development: active development, contracts and tests live here. Pull requests target main.

## Build & Test

- Syntax and type checking: clarinet check
- You can add tests in the tests directory using JS/TS with Clarinet test harness.

## Security Notes

- No cross-contract calls per requirements.
- Input normalization is performed for VINs (expected length: 17). Callers should pre-validate VIN strings.

## License

MIT (or your preferred license).