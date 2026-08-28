# JBE Academy — Master Platform V2.1

This package consolidates the decisions made so far into one expandable architecture.

## Portals
- Public Website: `index.html`
- Public Registration: `register.html`
- Public Teachers Directory: `teachers.html`
- Teacher Public Profile: `teacher-profile.html`
- Login: `student-login.html`
- Role Landing: `portal.html`
- Student Portal: `student-dashboard.html`
- Parent Portal: `parent-dashboard.html`
- Teacher Workspace: `teacher-dashboard.html`
- Admissions & Sales: `admissions-dashboard.html`
- Admin Dashboard: `admin-dashboard.html`
- Student Management: `student-manage.html`

## Database migration
Run the full file:
`jbe_academy_master_v2.sql`

Run it after the existing V1–V1.8 database setup.

## Academic structure
National:
- Primary Stage: Grade 4–6
- Preparatory Stage: Grade 7–9
- Secondary: Grade 10
- Egyptian Baccalaureate: Grade 11–12

The design also preserves International curricula (IG/IGCSE, IB, American).

## Core automation included
- Website registration goes directly to Applications.
- Admissions/Admin converts an application to a student without retyping the same data.
- Multi-teacher public profiles and teacher offerings.
- Hybrid pricing foundation.
- Groups and recurring session generator.
- Fixed-session vs hourly billing rules.
- Invoices, invoice items, payment claims and automatic receipt records.
- Parent dashboard foundation.
- Teacher workspace separated from financial/admin clutter.
- Sales/Admissions workspace separated from Admin.
- Notifications and audit-log tables ready for integrations.

## Important external integrations
The following cannot be safely automated from a public browser-only site without provider/API credentials:
- Confirming InstaPay/Vodafone Cash transfers automatically.
- Sending WhatsApp messages through the official WhatsApp Business API.
- Server-side creation/invitation of Auth users with Supabase Admin API.
- Card/payment-gateway webhooks.

The database is structured so these can be added later through secure server/Edge Functions without redesigning the platform.

## GitHub upload
Upload all web files to the repository root. Do NOT publish SQL as an executable browser asset if you prefer a clean public repo; keeping it in `/database/` is recommended.

Cloudflare Pages should redeploy automatically after the commit.


## V2.1 Teacher Ownership
- Mr. Mohammad Jebali is seeded as the founding verified teacher.
- Existing launch courses are explicitly linked to his teacher profile.
- Every future teacher gets an independent `teacher_profiles` row.
- Every teacher selects their own Education System, Curriculum, Stage, Grade and Subject through `teacher-settings.html`.
- Teacher pricing proposals are stored per teacher offering and require Admin approval before public publication.
- Public teacher pages read only that teacher's scopes and approved offerings.
- Archiving a teaching scope does not delete historic courses or student records.
- Adding National Grades 4–6 (Primary) and 7–9 (Preparatory) to the platform does not automatically assign them to every teacher.
