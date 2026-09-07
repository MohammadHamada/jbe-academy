-- JBE Academy V2.6 — Read-only preflight
with required_functions(name) as (
  values
    ('admin_teacher_manager_list'),
    ('admin_teacher_manager_catalog'),
    ('admin_teacher_manager_detail'),
    ('admin_update_teacher_profile'),
    ('admin_save_teacher_scope'),
    ('admin_archive_teacher_scope'),
    ('admin_create_teacher_offering'),
    ('admin_archive_teacher_offering')
),
missing as (
  select r.name
  from required_functions r
  left join pg_proc p on p.proname=r.name
  left join pg_namespace n on n.oid=p.pronamespace and n.nspname='public'
  where p.oid is null
)
select '01_v26_functions_missing' check_name,count(*) actual_count,0 expected_count,
case when count(*)=0 then 'PASS' else 'FAIL' end status
from missing
union all
select '02_science_subject',count(*),1,
case when count(*)=1 then 'PASS' else 'FAIL' end
from public.subjects where upper(code)='SCIENCE'
union all
select '03_teacher_profiles_without_staff',count(*),0,
case when count(*)=0 then 'PASS' else 'FAIL' end
from public.teacher_profiles tp
left join public.staff s on s.id=tp.staff_id
where s.id is null
union all
select '04_active_teacher_staff_without_profile',count(*),0,
case when count(*)=0 then 'PASS' else 'CHECK' end
from public.staff s
where s.is_active=true
  and (
    s.role='teacher'
    or exists(select 1 from public.staff_roles sr where sr.staff_id=s.id and sr.role='teacher')
  )
  and not exists(select 1 from public.teacher_profiles tp where tp.staff_id=s.id)
order by check_name;
