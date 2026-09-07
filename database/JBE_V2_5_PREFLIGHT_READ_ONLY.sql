
-- JBE ACADEMY V2.5 — READ ONLY PREFLIGHT
-- Run AFTER jbe_academy_v2_5_operations_access.sql

-- 1. Protected owner
select
  po.owner_email,
  s.full_name,
  s.role,
  s.is_active,
  case when po.owner_email='mr.mhammadahmad2@gmail.com' and s.role='super_admin' and s.is_active
       then 'OK' else 'CHECK' end as status
from public.platform_ownership po
join public.staff s on s.id=po.owner_staff_id
where po.id=1;

-- 2. No other primary super admins
select id,full_name,role
from public.staff
where role='super_admin'
  and id<>(select owner_staff_id from public.platform_ownership where id=1);
-- Expected: 0 rows

-- 3. No other super_admin multi-role assignments
select s.full_name,sr.role
from public.staff_roles sr
join public.staff s on s.id=sr.staff_id
where sr.role='super_admin'
  and sr.staff_id<>(select owner_staff_id from public.platform_ownership where id=1);
-- Expected: 0 rows

-- 4. Owner teacher profile
select tp.slug,tp.display_name,s.full_name as linked_staff,s.role
from public.teacher_profiles tp
join public.staff s on s.id=tp.staff_id
where tp.slug='mr-mohammad-jebali';

-- 5. Role / permission counts
select role,count(*) permission_count
from public.role_permissions
group by role
order by role;

-- 6. Required V2.5 functions
with required(name) as (
 values
 ('has_permission'),('owner_list_staff'),('owner_create_staff_invite'),
 ('claim_staff_invite'),('owner_action_center'),('owner_global_search'),
 ('public_course_catalog'),('public_course_detail'),('public_submit_application_v25'),
 ('teacher_today_sessions'),('teacher_session_detail'),('teacher_start_session'),
 ('teacher_record_session_attendance'),('teacher_add_homework'),('teacher_end_session'),
 ('finance_overview'),('finance_pending_claims'),('finance_verify_claim'),
 ('student_affairs_overview'),('student_affairs_unassigned_enrollments'),
 ('student_affairs_assign_group'),('staff_groups_list'),('staff_create_group'),
 ('staff_teacher_approvals'),('admin_set_teacher_profile_approval')
)
select r.name,
       case when p.proname is null then 'MISSING' else 'OK' end status
from required r
left join pg_proc p on p.proname=r.name
left join pg_namespace n on n.oid=p.pronamespace and n.nspname='public'
order by r.name;

-- 7. Existing verified payments should now have receipts after the V2.5 backfill
select p.id,p.amount,p.currency,p.verified_at
from public.payments p
where p.status='verified'
  and not exists(select 1 from public.receipts r where r.payment_id=p.id);
-- Expected: 0 rows

-- 8. Data quality summary
select 'students_missing_guardian' metric,count(*) value
from public.students s
where s.status='active'
and not exists(select 1 from public.student_guardians sg where sg.student_id=s.id)
union all
select 'active_enrollments_without_group',count(*)
from public.enrollments where status='active' and group_id is null
union all
select 'courses_without_teacher',count(*)
from public.courses where status in ('open','active') and teacher_id is null
union all
select 'pending_payment_claims',count(*)
from public.payment_claims where status='pending'
union all
select 'pending_teacher_offerings',count(*)
from public.teacher_offerings where approval_status='pending';

-- 9. Local academic structure stays intact
select c.code curriculum,st.code stage,g.code grade,g.name_en,g.name_ar
from public.grade_levels g
join public.curricula c on c.id=g.curriculum_id
left join public.academic_stages st on st.id=g.stage_id
where c.code='EGYPT_NATIONAL_EN'
order by g.sort_order;

-- 10. Public catalog
select slug,title_en,status,is_public,approval_status,teacher_id
from public.courses
order by title_en;
