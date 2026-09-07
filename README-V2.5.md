# JBE Academy V2.5 — Operations & Access Control

This release converts the platform from a collection of dashboards into a role-based operating system.

## Protected owner
Current protected owner:
- Mohammad Jebali
- mr.mhammadahmad2@gmail.com

Only the protected owner can manage staff access. Other users cannot suspend, downgrade or assign the owner.

## New workspaces
- `owner-dashboard.html` — Action Center, global search and control links.
- `staff-management.html` — team invitations, roles, permission overrides, suspension and password reset.
- `staff-setup.html` — secure invite-based staff account setup without exposing a service-role key.
- `reset-password.html` — secure password update.
- `sales-crm.html` — admissions and lead follow-up.
- `student-affairs.html` — student data quality and group assignment.
- `finance-dashboard.html` — payment claims, invoices and payment verification.
- `groups.html` — groups and recurring session generation.
- `teacher-workspace.html` — today's sessions.
- `teacher-session.html` — attendance, homework, start/end session.
- `teacher-approvals.html` — approve teacher profiles and public prices.
- `audit-log.html` — owner audit trail.
- `courses.html` — customer course discovery.
- `course.html` — public course details.

## Access model
Identity -> Roles -> Permissions -> Optional Overrides -> Scope-ready architecture.

Primary roles:
- Owner / Super Admin
- Admin
- Teacher
- Sales
- Student Affairs
- Finance
- Content
- Support

Staff may hold multiple roles. Owner may also set individual permission overrides.

## Password security
The owner never sees staff passwords.
The owner can send a secure Supabase password-reset email.
New staff can be onboarded with an invitation link and choose their own password.

## Multi-teacher model
Every teacher remains independent:
Teacher -> Teaching Scope -> Offerings -> Course -> Group -> Session.
A new teacher does not inherit Mr. Mohammad Jebali's grades, subjects, prices or students.

## Billing rule preserved
- Fixed Session: class overrun does not increase the charge.
- Hourly: actual minutes are used.
- Monthly / Term / Package: no per-session invoice is generated.

## Deployment sequence
1. In Supabase SQL Editor run:
   `database/jbe_academy_v2_5_operations_access.sql`
2. Confirm result:
   `JBE Academy V2.5 operations + access control loaded`
3. Run:
   `database/JBE_V2_5_PREFLIGHT_READ_ONLY.sql`
4. Review the results.
5. Only then upload the full web package to GitHub.
6. Wait for Cloudflare deployment.
7. Test Owner -> Staff -> Sales -> Student Affairs -> Finance -> Teacher -> Public Courses.

Do NOT rerun the old V2.1 master SQL.

## Important secure-backend limitation
The static site does not use a service-role key.
Force-revoking all Supabase Auth sessions and automatic external WhatsApp/payment-gateway webhooks should be added later via Supabase Edge Functions or another secure server environment.
