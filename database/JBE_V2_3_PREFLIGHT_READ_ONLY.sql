-- ============================================================
-- JBE ACADEMY V2.3 — READ-ONLY PREFLIGHT AUDIT
-- Safe: this script does NOT change data.
-- Run after the V2.3 stabilization patch.
-- ============================================================

-- A) Required table inventory
with required(name) as (
  values
    ('students'),('guardians'),('staff'),('teacher_profiles'),
    ('teacher_teaching_scopes'),('teacher_offerings'),('applications'),
    ('courses'),('class_groups'),('class_sessions'),('enrollments'),
    ('invoices'),('invoice_items'),('payments'),('receipts'),
    ('learning_activities'),('activity_submissions')
)
select
  r.name as required_table,
  case when t.table_name is not null then 'OK' else 'MISSING' end as status
from required r
left join information_schema.tables t
  on t.table_schema='public' and t.table_name=r.name
order by r.name;

-- B) Required functions
with required(name) as (
  values
    ('resolve_my_portal'),
    ('public_teacher_directory'),
    ('public_teacher_profile'),
    ('public_submit_application'),
    ('admin_convert_application_to_student'),
    ('admin_generate_weekly_sessions'),
    ('admin_finalize_session_billing'),
    ('teacher_my_profile'),
    ('teacher_save_scope'),
    ('teacher_create_offering')
)
select
  r.name as required_function,
  case when p.proname is not null then 'OK' else 'MISSING' end as status
from required r
left join pg_proc p on p.proname=r.name
left join pg_namespace n on n.oid=p.pronamespace and n.nspname='public'
order by r.name;

-- C) Local academic structure
select
  es.code as education_system,
  c.code as curriculum,
  st.code as stage,
  st.name_en as stage_name,
  g.code as grade_code,
  g.name_en as grade_name
from public.grade_levels g
join public.curricula c on c.id=g.curriculum_id
join public.education_systems es on es.id=c.education_system_id
left join public.academic_stages st on st.id=g.stage_id
where c.code='EGYPT_NATIONAL_EN'
order by g.sort_order;

-- Expected:
-- G4-G6 -> PRIMARY
-- G7-G9 -> PREPARATORY
-- G10   -> SECONDARY

-- D) Founding teacher profile
select
  tp.slug,
  tp.display_name,
  tp.is_verified,
  tp.is_public,
  s.full_name as linked_staff,
  s.role as staff_role
from public.teacher_profiles tp
join public.staff s on s.id=tp.staff_id
where tp.slug='mr-mohammad-jebali';

-- E) Existing launch courses must be owned by Mr. Mohammad Jebali
select
  co.slug,
  co.title_en,
  co.status,
  co.is_public,
  tp.slug as teacher_slug,
  tp.display_name as teacher_name
from public.courses co
left join public.teacher_profiles tp on tp.id=co.teacher_id
where co.slug in (
  'national-grade-9-math-2026-2027',
  'national-grade-10-math-2026-2027',
  'baccalaureate-grade-11-math-2026-2027',
  'baccalaureate-grade-11-business-management-2026-2027',
  'baccalaureate-grade-12-economics-coming-soon'
)
order by co.slug;

-- F) Public vs private teacher pricing
select
  o.id,
  tp.display_name,
  su.name_en as subject,
  g.name_en as grade,
  o.teacher_price,
  o.public_price,
  o.currency,
  o.approval_status,
  o.is_public
from public.teacher_offerings o
join public.teacher_profiles tp on tp.id=o.teacher_id
join public.subjects su on su.id=o.subject_id
join public.grade_levels g on g.id=o.grade_level_id
order by o.created_at desc;

-- G) Duplicate recurring sessions check
select
  group_id,
  session_date,
  count(*) as duplicate_count
from public.class_sessions
where group_id is not null
group by group_id,session_date
having count(*) > 1;

-- Expected: 0 rows

-- H) Duplicate non-cancelled invoices for same student/session
select
  student_id,
  session_id,
  count(*) as invoice_count
from public.invoices
where session_id is not null
  and status <> 'cancelled'
group by student_id,session_id
having count(*) > 1;

-- Expected: 0 rows

-- I) Orphan applications converted without student
select
  id,
  application_code,
  application_status,
  created_student_id
from public.applications
where application_status='converted'
  and created_student_id is null;

-- Expected: 0 rows

-- J) Receipt integrity
select
  p.id as payment_id,
  p.status as payment_status,
  r.receipt_number
from public.payments p
left join public.receipts r on r.payment_id=p.id
where p.status='verified'
  and r.id is null;

-- Existing verified payments created BEFORE the receipt trigger may appear here.
-- New verified payments after V2.3 should not.

-- K) RLS status on sensitive tables
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relname in (
    'students','guardians','staff','teacher_profiles',
    'teacher_teaching_scopes','teacher_offerings',
    'applications','invoices','payments','receipts'
  )
order by c.relname;

-- L) No anon direct SELECT grants on private teacher operational tables
select
  grantee,
  table_name,
  privilege_type
from information_schema.role_table_grants
where table_schema='public'
  and table_name in (
    'teacher_profiles',
    'teacher_teaching_scopes',
    'teacher_offerings'
  )
  and grantee='anon'
  and privilege_type='SELECT';

-- Expected: 0 rows

-- M) Summary counts
select 'students' as metric,count(*)::text as value from public.students
union all
select 'applications',count(*)::text from public.applications
union all
select 'teachers',count(*)::text from public.teacher_profiles
union all
select 'courses',count(*)::text from public.courses
union all
select 'groups',count(*)::text from public.class_groups
union all
select 'sessions',count(*)::text from public.class_sessions
union all
select 'invoices',count(*)::text from public.invoices
union all
select 'payments',count(*)::text from public.payments
union all
select 'receipts',count(*)::text from public.receipts;
