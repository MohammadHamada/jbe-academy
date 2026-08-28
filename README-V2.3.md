# JBE Academy V2.3 — Stabilized Architecture

This is the stabilization release. It is intentionally focused on correctness before adding more features.

## Do NOT rerun old V2.1 mega SQL just to fix V2.3
If `JBE Teacher Ownership V2.1 loaded` already succeeded, run only:

1. `database/jbe_academy_stabilization_v2_3.sql`
2. `database/JBE_V2_3_PREFLIGHT_READ_ONLY.sql`

The second script is read-only.

## Then upload/replace the website files
Upload the full package to GitHub after the SQL patch succeeds.

Important corrected files:
- `login.js`
- `portal.js`
- `portal.html`
- `teachers.html`
- `style.css`
- `script.js`

The package also preserves all Admin, Student, Parent, Teacher and Admissions files.

## Required test order
1. `/student-login.html` — Admin account must route as Staff, not demo Student.
2. `/teacher-settings.html` — Mr. Mohammad Jebali teacher profile.
3. `/teachers.html` — public directory.
4. `/teacher-profile.html?slug=mr-mohammad-jebali`
5. `/register.html` — test application.
6. `/admissions-dashboard.html` — application appears.
7. Convert one test application to Student.
8. `/admin-dashboard.html`
9. Existing Student Dashboard.
10. Parent Portal only after a guardian Auth account is explicitly linked.

## Core rule
Database is rich; every role sees only the minimum information needed for its job.
