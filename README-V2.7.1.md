# JBE Academy V2.7.1 — PostgreSQL Syntax Fix

This release fixes the V2.7 migration error:

`syntax error at or near "current_role"`

`CURRENT_ROLE` is a PostgreSQL reserved SQL keyword.  
The database column/output field is now named:

`current_position`

The public form and RPC input can still use `p_current_role`, so the teacher application UX does not change.

## Install
Because the previous V2.7 query failed at the CREATE TABLE statement, run the corrected full migration:

`jbe_academy_v2_7_experience.sql`

Then run:

`JBE_V2_7_1_PREFLIGHT_READ_ONLY.sql`

Do not run the old V2.7 migration again.
