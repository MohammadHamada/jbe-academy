# JBE Academy V2.6 — Teacher Management

V2.6 adds a dedicated Owner/Admin Teacher Management workspace.

## Workflow
Staff Teacher
→ Profile
→ Teaching Scope
→ Courses & Pricing (Offerings)
→ Approval
→ Public Teacher Profile

## New page
`teacher-manage.html`

The Owner/Admin can:
- Select any teacher.
- Edit profile, headline, bio, photo, slug and experience.
- Assign Education System → Curriculum → Stage → Grade → Subject.
- Add Science as a supported subject.
- Create Group / Private / Hybrid / Recorded offerings.
- Set teacher price, billing model, duration and capacity.
- Approve/reject offerings and set final public price.
- Verify, publish, unpublish and preview the teacher.

## Mr. Hamadah
Because Mr. Hamadah is already linked as an active Teacher, he will appear automatically.
Select him from Teacher Management, then add his Science scopes and offerings from the UI.

## Database install
Run only:
`jbe_academy_v2_6_teacher_management.sql`

Then run:
`JBE_V2_6_PREFLIGHT_READ_ONLY.sql`

Do not rerun the old V2.5 or Master migrations.
