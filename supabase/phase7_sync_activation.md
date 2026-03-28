# Phase 7 - Supabase Sync Activation

## Remote schema decision

- Remote tables are `transactions`, `transaction_lines`, `order_modifiers`, `payments`.
- Remote primary keys are UUIDs, not local integers.
- Local integer IDs are kept only as informational snapshot columns where needed:
  - `transactions.shift_local_id`
  - `transactions.user_local_id`
  - `transactions.cancelled_by_local_id`
  - `transaction_lines.product_local_id`
- Remote relations are UUID-based:
  - `transaction_lines.transaction_uuid -> transactions.uuid`
  - `order_modifiers.transaction_line_uuid -> transaction_lines.uuid`
  - `payments.transaction_uuid -> transactions.uuid`
- `transactions.status` is restricted to `paid|cancelled` remotely so OPEN orders can never become remote truth.

## Why this design

- It preserves the local-first rule: Drift stays authoritative and Supabase only mirrors finalized sales graphs.
- It prevents local SQLite integer PKs from becoming remote relational truth.
- It keeps graph upserts deterministic and idempotent because the UUID graph is stable across retries.
- It allows the client to send only the finalized snapshot fields needed for reporting and audit.

## Remote overwrite safety

- `transactions` has a trigger that rejects OPEN snapshots.
- The same trigger prevents stale `updated_at` payloads from overwriting newer remote snapshots.
- When `updated_at` is equal, `kitchen_printed` and `receipt_printed` are merged with logical OR so duplicate syncs stay monotonic.
- `synced_at` is server-managed.

## RLS posture

- No delete policies are granted.
- No broad select policy is granted.
- Client access is limited to insert/update for the four sync tables.
- Child-table insert/update checks use `security definer` helpers so the app does not need read access just to satisfy FK-style policy checks.

## Current security level

- Acceptable for a first local-first mirror where the anon/publishable key is the only client credential.
- Not tenant-safe and not device-safe: any client holding the anon key can still attempt writes allowed by policy.
- Stronger hardening requires one of:
  - real user auth with per-user/per-device claims in RLS
  - device auth with device-scoped policies
  - edge function mediation that verifies device identity and writes with stronger server-side controls

## Manual setup

- Run [phase7_sync_activation.sql](/Users/nacho/Desktop/EPOS/supabase/phase7_sync_activation.sql) in the target Supabase SQL editor.
- Inject runtime values with `--dart-define` or an equivalent secrets mechanism.
- Do not commit publishable/anon values into source files.
