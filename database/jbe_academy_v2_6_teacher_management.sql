-- ============================================================
-- JBE ACADEMY V2.6 — OWNER TEACHER MANAGEMENT
-- Incremental migration. Run AFTER V2.5.
--
-- Adds:
-- - Science subject if missing.
-- - Owner/Admin teacher manager RPCs.
-- - Profile editing for any teacher.
-- - Teaching-scope management for any teacher.
-- - Offering/course-proposal management for any teacher.
-- - Owner/Admin publication controls.
--
-- This does NOT recreate the database and does NOT change the
-- protected Owner account.
-- ============================================================

begin;

-- ------------------------------------------------------------
-- 0) SCIENCE SUBJECT
-- ------------------------------------------------------------
insert into public.subjects(code,name_en,name_ar,is_active)
select 'SCIENCE','Science','العلوم',true
where not exists (
  select 1 from public.subjects where upper(code)='SCIENCE'
);

-- ------------------------------------------------------------
-- 1) OWNER/ADMIN TEACHER LIST
-- ------------------------------------------------------------
create or replace function public.admin_teacher_manager_list()
returns table(
  teacher_id uuid,
  staff_id uuid,
  auth_user_id uuid,
  email text,
  display_name text,
  display_name_ar text,
  slug text,
  headline_en text,
  headline_ar text,
  is_verified boolean,
  is_public boolean,
  staff_active boolean,
  scope_count bigint,
  offering_count bigint,
  pending_offering_count bigint
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  return query
  select
    tp.id,
    s.id,
    s.auth_user_id,
    u.email::text,
    tp.display_name,
    tp.display_name_ar,
    tp.slug,
    tp.headline_en,
    tp.headline_ar,
    tp.is_verified,
    tp.is_public,
    s.is_active,
    (select count(*) from public.teacher_teaching_scopes ts
      where ts.teacher_id=tp.id and ts.is_active=true),
    (select count(*) from public.teacher_offerings o
      where o.teacher_id=tp.id and o.approval_status <> 'archived'),
    (select count(*) from public.teacher_offerings o
      where o.teacher_id=tp.id and o.approval_status='pending')
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  left join auth.users u on u.id=s.auth_user_id
  order by lower(tp.display_name),tp.created_at;
end;
$$;

-- ------------------------------------------------------------
-- 2) TEACHER MANAGER CATALOG
-- ------------------------------------------------------------
create or replace function public.admin_teacher_manager_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'education_systems',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.education_systems
      where is_active=true
    ),'[]'::jsonb),

    'curricula',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'education_system_id',education_system_id,
        'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.curricula
      where is_active=true
    ),'[]'::jsonb),

    'stages',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'education_system_id',education_system_id,
        'code',code,'name_en',name_en,'name_ar',name_ar,'sort_order',sort_order
      ) order by sort_order)
      from public.academic_stages
      where is_active=true
    ),'[]'::jsonb),

    'grades',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'curriculum_id',curriculum_id,'stage_id',stage_id,
        'code',code,'name_en',name_en,'name_ar',name_ar,'sort_order',sort_order
      ) order by sort_order)
      from public.grade_levels
      where is_active=true
    ),'[]'::jsonb),

    'subjects',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.subjects
      where is_active=true
    ),'[]'::jsonb)
  );
end;
$$;

-- ------------------------------------------------------------
-- 3) ONE TEACHER DETAIL
-- ------------------------------------------------------------
create or replace function public.admin_teacher_manager_detail(p_teacher_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  if not exists(select 1 from public.teacher_profiles where id=p_teacher_id) then
    raise exception 'teacher not found';
  end if;

  return jsonb_build_object(
    'profile',(
      select jsonb_build_object(
        'teacher_id',tp.id,
        'staff_id',tp.staff_id,
        'email',u.email,
        'display_name',tp.display_name,
        'display_name_ar',tp.display_name_ar,
        'slug',tp.slug,
        'headline_en',tp.headline_en,
        'headline_ar',tp.headline_ar,
        'bio_en',tp.bio_en,
        'bio_ar',tp.bio_ar,
        'photo_url',tp.photo_url,
        'years_experience',tp.years_experience,
        'country_code',tp.country_code,
        'is_verified',tp.is_verified,
        'is_public',tp.is_public,
        'staff_active',s.is_active
      )
      from public.teacher_profiles tp
      join public.staff s on s.id=tp.staff_id
      left join auth.users u on u.id=s.auth_user_id
      where tp.id=p_teacher_id
    ),

    'scopes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'scope_id',ts.id,
        'education_system_id',ts.education_system_id,
        'education_system_en',es.name_en,
        'education_system_ar',es.name_ar,
        'curriculum_id',ts.curriculum_id,
        'curriculum_en',c.name_en,
        'curriculum_ar',c.name_ar,
        'stage_id',ts.stage_id,
        'stage_en',st.name_en,
        'stage_ar',st.name_ar,
        'grade_level_id',ts.grade_level_id,
        'grade_en',g.name_en,
        'grade_ar',g.name_ar,
        'subject_id',ts.subject_id,
        'subject_en',su.name_en,
        'subject_ar',su.name_ar,
        'is_active',ts.is_active,
        'is_public',ts.is_public
      ) order by es.name_en,g.sort_order,su.name_en)
      from public.teacher_teaching_scopes ts
      join public.education_systems es on es.id=ts.education_system_id
      join public.curricula c on c.id=ts.curriculum_id
      left join public.academic_stages st on st.id=ts.stage_id
      join public.grade_levels g on g.id=ts.grade_level_id
      join public.subjects su on su.id=ts.subject_id
      where ts.teacher_id=p_teacher_id
        and ts.is_active=true
    ),'[]'::jsonb),

    'offerings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'offering_id',o.id,
        'curriculum_id',o.curriculum_id,
        'curriculum_en',c.name_en,
        'curriculum_ar',c.name_ar,
        'grade_level_id',o.grade_level_id,
        'grade_en',g.name_en,
        'grade_ar',g.name_ar,
        'subject_id',o.subject_id,
        'subject_en',su.name_en,
        'subject_ar',su.name_ar,
        'study_mode',o.study_mode,
        'billing_type',o.billing_type,
        'teacher_price',o.teacher_price,
        'public_price',o.public_price,
        'currency',o.currency,
        'duration_minutes',o.duration_minutes,
        'capacity',o.capacity,
        'approval_status',o.approval_status,
        'is_public',o.is_public,
        'created_at',o.created_at
      ) order by o.created_at desc)
      from public.teacher_offerings o
      join public.curricula c on c.id=o.curriculum_id
      join public.grade_levels g on g.id=o.grade_level_id
      join public.subjects su on su.id=o.subject_id
      where o.teacher_id=p_teacher_id
        and o.approval_status <> 'archived'
    ),'[]'::jsonb)
  );
end;
$$;

-- ------------------------------------------------------------
-- 4) EDIT TEACHER PROFILE
-- ------------------------------------------------------------
create or replace function public.admin_update_teacher_profile(
  p_teacher_id uuid,
  p_display_name text,
  p_display_name_ar text,
  p_slug text,
  p_headline_en text,
  p_headline_ar text,
  p_bio_en text,
  p_bio_ar text,
  p_photo_url text,
  p_years_experience int,
  p_country_code text
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  if coalesce(trim(p_display_name),'')='' then
    raise exception 'display name is required';
  end if;

  if coalesce(trim(p_slug),'')='' then
    raise exception 'slug is required';
  end if;

  if p_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'slug must use lowercase letters, numbers and hyphens only';
  end if;

  if exists(
    select 1 from public.teacher_profiles
    where slug=p_slug and id<>p_teacher_id
  ) then
    raise exception 'slug is already in use';
  end if;

  update public.teacher_profiles
  set
    display_name=trim(p_display_name),
    display_name_ar=nullif(trim(p_display_name_ar),''),
    slug=trim(p_slug),
    headline_en=nullif(trim(p_headline_en),''),
    headline_ar=nullif(trim(p_headline_ar),''),
    bio_en=nullif(trim(p_bio_en),''),
    bio_ar=nullif(trim(p_bio_ar),''),
    photo_url=nullif(trim(p_photo_url),''),
    years_experience=p_years_experience,
    country_code=coalesce(nullif(trim(p_country_code),''),'EG'),
    updated_at=now()
  where id=p_teacher_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'teacher_profile_update','teacher_profile',p_teacher_id::text,
      jsonb_build_object('display_name',p_display_name,'slug',p_slug)
    );
  end if;

  return found;
end;
$$;

-- ------------------------------------------------------------
-- 5) SAVE SCOPE FOR SELECTED TEACHER
-- ------------------------------------------------------------
create or replace function public.admin_save_teacher_scope(
  p_teacher_id uuid,
  p_education_system_id uuid,
  p_curriculum_id uuid,
  p_stage_id uuid,
  p_grade_level_id uuid,
  p_subject_id uuid,
  p_is_public boolean default false
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  if not exists(select 1 from public.teacher_profiles where id=p_teacher_id) then
    raise exception 'teacher not found';
  end if;

  if not exists(
    select 1
    from public.curricula c
    join public.grade_levels g on g.curriculum_id=c.id
    where c.id=p_curriculum_id
      and c.education_system_id=p_education_system_id
      and g.id=p_grade_level_id
      and (p_stage_id is null or g.stage_id=p_stage_id)
  ) then
    raise exception 'invalid academic hierarchy';
  end if;

  if not exists(select 1 from public.subjects where id=p_subject_id and is_active=true) then
    raise exception 'invalid subject';
  end if;

  insert into public.teacher_teaching_scopes(
    teacher_id,education_system_id,curriculum_id,stage_id,grade_level_id,subject_id,
    is_active,is_public
  )
  values(
    p_teacher_id,p_education_system_id,p_curriculum_id,p_stage_id,p_grade_level_id,p_subject_id,
    true,p_is_public
  )
  on conflict(teacher_id,curriculum_id,grade_level_id,subject_id)
  do update set
    education_system_id=excluded.education_system_id,
    stage_id=excluded.stage_id,
    is_active=true,
    is_public=excluded.is_public
  returning id into v_id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'teacher_scope_save','teacher_profile',p_teacher_id::text,
    jsonb_build_object(
      'scope_id',v_id,'curriculum_id',p_curriculum_id,
      'grade_level_id',p_grade_level_id,'subject_id',p_subject_id,
      'public',p_is_public
    )
  );

  return v_id;
end;
$$;

create or replace function public.admin_archive_teacher_scope(p_scope_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if not public.has_permission('teachers.manage') then
    raise exception 'not authorized';
  end if;

  select teacher_id into v_teacher_id
  from public.teacher_teaching_scopes
  where id=p_scope_id;

  update public.teacher_teaching_scopes
  set is_active=false,is_public=false
  where id=p_scope_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'teacher_scope_archive','teacher_scope',p_scope_id::text,
      jsonb_build_object('teacher_id',v_teacher_id)
    );
  end if;

  return found;
end;
$$;

-- ------------------------------------------------------------
-- 6) CREATE OFFERING FOR SELECTED TEACHER
-- ------------------------------------------------------------
create or replace function public.admin_create_teacher_offering(
  p_teacher_id uuid,
  p_curriculum_id uuid,
  p_grade_level_id uuid,
  p_subject_id uuid,
  p_study_mode text,
  p_billing_type text,
  p_teacher_price numeric,
  p_currency text,
  p_duration_minutes int,
  p_capacity int
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
begin
  if not (
    public.has_permission('teachers.manage')
    or public.has_permission('courses.manage')
  ) then
    raise exception 'not authorized';
  end if;

  if p_teacher_price is null or p_teacher_price < 0 then
    raise exception 'teacher price cannot be negative';
  end if;

  if p_study_mode not in ('group','private','recorded','hybrid') then
    raise exception 'invalid study mode';
  end if;

  if p_billing_type not in ('fixed_session','hourly','monthly','term','package') then
    raise exception 'invalid billing type';
  end if;

  if not exists(
    select 1 from public.teacher_teaching_scopes ts
    where ts.teacher_id=p_teacher_id
      and ts.curriculum_id=p_curriculum_id
      and ts.grade_level_id=p_grade_level_id
      and ts.subject_id=p_subject_id
      and ts.is_active=true
  ) then
    raise exception 'add this teaching scope first';
  end if;

  insert into public.teacher_offerings(
    teacher_id,curriculum_id,grade_level_id,subject_id,
    study_mode,billing_type,teacher_price,currency,duration_minutes,capacity,
    approval_status,is_public
  )
  values(
    p_teacher_id,p_curriculum_id,p_grade_level_id,p_subject_id,
    p_study_mode,p_billing_type,p_teacher_price,
    coalesce(nullif(trim(p_currency),''),'EGP'),
    p_duration_minutes,p_capacity,'pending',false
  )
  returning id into v_id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'teacher_offering_create','teacher_offering',v_id::text,
    jsonb_build_object('teacher_id',p_teacher_id,'teacher_price',p_teacher_price)
  );

  return v_id;
end;
$$;

create or replace function public.admin_archive_teacher_offering(p_offering_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('teachers.manage')
    or public.has_permission('courses.manage')
  ) then
    raise exception 'not authorized';
  end if;

  update public.teacher_offerings
  set approval_status='archived',is_public=false
  where id=p_offering_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'teacher_offering_archive','teacher_offering',p_offering_id::text,'{}'::jsonb
    );
  end if;

  return found;
end;
$$;

-- ------------------------------------------------------------
-- 7) GRANTS
-- ------------------------------------------------------------
grant execute on function public.admin_teacher_manager_list() to authenticated;
grant execute on function public.admin_teacher_manager_catalog() to authenticated;
grant execute on function public.admin_teacher_manager_detail(uuid) to authenticated;
grant execute on function public.admin_update_teacher_profile(
  uuid,text,text,text,text,text,text,text,text,int,text
) to authenticated;
grant execute on function public.admin_save_teacher_scope(
  uuid,uuid,uuid,uuid,uuid,uuid,boolean
) to authenticated;
grant execute on function public.admin_archive_teacher_scope(uuid) to authenticated;
grant execute on function public.admin_create_teacher_offering(
  uuid,uuid,uuid,uuid,text,text,numeric,text,int,int
) to authenticated;
grant execute on function public.admin_archive_teacher_offering(uuid) to authenticated;

commit;

-- ============================================================
-- VERIFICATION
-- ============================================================
select
  'JBE Academy V2.6 teacher management loaded' as status,
  (select count(*) from public.subjects where upper(code)='SCIENCE') as science_subjects,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'admin_%teacher%') as teacher_admin_functions;
