
-- ============================================================
-- JBE ACADEMY V2.5
-- OPERATIONS + ACCESS CONTROL + COURSE DISCOVERY + STAFF TOOLS
--
-- Run AFTER:
--   V2.1 Teacher Ownership
--   V2.3 Stabilization
--
-- This is an incremental migration. Do NOT rerun older master SQL.
-- ============================================================

begin;

-- ============================================================
-- 0) STAFF ROLE COMPATIBILITY
-- Keep the legacy primary role while adding multi-role support.
-- ============================================================

alter table public.staff
  drop constraint if exists staff_role_check;

alter table public.staff
  add constraint staff_role_check
  check (
    role in (
      'super_admin',
      'admin',
      'teacher',
      'sales',
      'student_affairs',
      'finance',
      'content',
      'support'
    )
  );

-- ============================================================
-- 1) OWNER + ROLE / PERMISSION MODEL
-- ============================================================

create table if not exists public.platform_ownership (
  id smallint primary key default 1 check (id = 1),
  owner_staff_id uuid not null unique references public.staff(id),
  owner_email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.staff_roles (
  staff_id uuid not null references public.staff(id) on delete cascade,
  role text not null,
  granted_by_staff_id uuid references public.staff(id),
  granted_at timestamptz not null default now(),
  primary key (staff_id, role),
  check (
    role in (
      'super_admin',
      'admin',
      'teacher',
      'sales',
      'student_affairs',
      'finance',
      'content',
      'support'
    )
  )
);

create table if not exists public.app_permissions (
  permission_key text primary key,
  name_en text not null,
  name_ar text,
  category text not null,
  is_sensitive boolean not null default false
);

create table if not exists public.role_permissions (
  role text not null,
  permission_key text not null references public.app_permissions(permission_key) on delete cascade,
  primary key (role, permission_key)
);

create table if not exists public.staff_permission_overrides (
  staff_id uuid not null references public.staff(id) on delete cascade,
  permission_key text not null references public.app_permissions(permission_key) on delete cascade,
  allowed boolean not null,
  granted_by_staff_id uuid references public.staff(id),
  updated_at timestamptz not null default now(),
  primary key (staff_id, permission_key)
);

create table if not exists public.staff_scopes (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete cascade,
  scope_type text not null check (
    scope_type in (
      'education_system',
      'curriculum',
      'stage',
      'grade',
      'subject',
      'teacher',
      'country',
      'branch'
    )
  ),
  scope_id uuid,
  scope_value text,
  created_by_staff_id uuid references public.staff(id),
  created_at timestamptz not null default now(),
  check (scope_id is not null or nullif(scope_value,'') is not null)
);

create index if not exists idx_staff_roles_staff on public.staff_roles(staff_id);
create index if not exists idx_staff_scopes_staff on public.staff_scopes(staff_id);

-- Team invitations allow the owner to onboard a staff member without exposing a service_role key.
create table if not exists public.staff_invites (
  id uuid primary key default gen_random_uuid(),
  token uuid not null unique default gen_random_uuid(),
  email text not null,
  full_name text not null,
  primary_role text not null,
  roles text[] not null,
  created_by_staff_id uuid not null references public.staff(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  claimed_at timestamptz,
  is_active boolean not null default true
);

create index if not exists idx_staff_invites_email on public.staff_invites(lower(email));
create index if not exists idx_staff_invites_token on public.staff_invites(token);

-- ============================================================
-- 2) PERMISSION CATALOG
-- ============================================================

insert into public.app_permissions(permission_key,name_en,name_ar,category,is_sensitive)
values
  ('admin.dashboard','View admin operations dashboard','عرض لوحة الإدارة','admin',false),
  ('analytics.view','View operational analytics','عرض التحليلات التشغيلية','admin',false),
  ('audit.view','View audit log','عرض سجل العمليات','security',true),

  ('team.view','View staff directory','عرض فريق العمل','security',true),
  ('team.manage','Manage staff accounts and roles','إدارة فريق العمل والصلاحيات','security',true),

  ('applications.view','View applications and leads','عرض طلبات التسجيل والعملاء المحتملين','sales',false),
  ('applications.edit','Update sales status and follow-up','تحديث حالة العميل والمتابعة','sales',false),
  ('applications.convert','Convert approved application to student','تحويل الطلب إلى طالب','sales',true),

  ('students.view','View full student records','عرض ملفات الطلاب الكاملة','students',true),
  ('students.manage','Create and manage students','إنشاء وإدارة الطلاب','students',true),

  ('finance.view','View invoices and payments','عرض الفواتير والمدفوعات','finance',true),
  ('finance.verify','Verify payments and activate access','تأكيد المدفوعات وتفعيل الوصول','finance',true),

  ('teachers.view','View teacher operations','عرض عمليات المعلمين','teachers',false),
  ('teachers.manage','Manage teachers and teaching scopes','إدارة المعلمين ومجالات التدريس','teachers',true),
  ('courses.manage','Manage courses and public catalog','إدارة الكورسات والفهرس العام','courses',true),
  ('courses.approve','Approve teacher offerings and prices','اعتماد عروض وأسعار المعلمين','courses',true),

  ('groups.manage','Create groups and schedules','إدارة المجموعات والجداول','academic',true),
  ('teacher.workspace','Use teacher daily workspace','استخدام مساحة عمل المعلم','academic',false),
  ('academic.assess','Record attendance, skills and learning notes','تسجيل الحضور والمهارات والملاحظات','academic',true),
  ('reports.manage','Create and publish progress reports','إنشاء ونشر تقارير التقدم','academic',true),

  ('content.manage','Manage public and learning content','إدارة المحتوى العام والتعليمي','content',true),
  ('support.view','View support requests','عرض طلبات الدعم','support',false),
  ('settings.manage','Manage platform settings','إدارة إعدادات المنصة','security',true),
  ('exports.data','Export platform data','تصدير بيانات المنصة','security',true)
on conflict(permission_key) do update
set
  name_en=excluded.name_en,
  name_ar=excluded.name_ar,
  category=excluded.category,
  is_sensitive=excluded.is_sensitive;

-- Reset role templates so this migration is deterministic.
delete from public.role_permissions
where role in ('super_admin','admin','teacher','sales','student_affairs','finance','content','support');

-- Super admin template. The protected owner also bypasses permission checks.
insert into public.role_permissions(role,permission_key)
select 'super_admin', permission_key from public.app_permissions
on conflict do nothing;

-- Operational admin: broad operation rights, but NOT team ownership.
insert into public.role_permissions(role,permission_key)
select 'admin', permission_key
from unnest(array[
  'admin.dashboard','analytics.view','audit.view',
  'applications.view','applications.edit','applications.convert',
  'students.view','students.manage',
  'finance.view','finance.verify',
  'teachers.view','teachers.manage',
  'courses.manage','courses.approve',
  'groups.manage','teacher.workspace','academic.assess','reports.manage',
  'content.manage','support.view'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'teacher', permission_key
from unnest(array[
  'teacher.workspace','academic.assess','reports.manage','teachers.view'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'sales', permission_key
from unnest(array[
  'applications.view','applications.edit','applications.convert'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'student_affairs', permission_key
from unnest(array[
  'applications.view','applications.convert',
  'students.view','students.manage',
  'groups.manage','reports.manage'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'finance', permission_key
from unnest(array[
  'finance.view','finance.verify'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'content', permission_key
from unnest(array[
  'content.manage','courses.manage','teachers.view'
]::text[]) as t(permission_key)
on conflict do nothing;

insert into public.role_permissions(role,permission_key)
select 'support', permission_key
from unnest(array[
  'support.view'
]::text[]) as t(permission_key)
on conflict do nothing;

-- ============================================================
-- 3) CURRENT STAFF / OWNER HELPERS
-- ============================================================

create or replace function public.current_staff_id()
returns uuid
language sql
stable
security definer
set search_path=public
as $$
  select s.id
  from public.staff s
  where s.auth_user_id=auth.uid()
    and s.is_active=true
  limit 1;
$$;

create or replace function public.is_platform_owner()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.platform_ownership po
    join public.staff s on s.id=po.owner_staff_id
    where s.auth_user_id=auth.uid()
      and s.is_active=true
  );
$$;

create or replace function public.has_permission(p_permission text)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_staff_id uuid;
  v_override boolean;
begin
  if public.is_platform_owner() then
    return true;
  end if;

  select id into v_staff_id
  from public.staff
  where auth_user_id=auth.uid()
    and is_active=true
  limit 1;

  if v_staff_id is null then
    return false;
  end if;

  select allowed into v_override
  from public.staff_permission_overrides
  where staff_id=v_staff_id
    and permission_key=p_permission;

  if found then
    return v_override;
  end if;

  return exists(
    select 1
    from public.staff_roles sr
    join public.role_permissions rp on rp.role=sr.role
    where sr.staff_id=v_staff_id
      and rp.permission_key=p_permission
  );
end;
$$;

-- Make legacy has_staff_role multi-role aware.
create or replace function public.has_staff_role(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select
    public.is_platform_owner()
    or exists(
      select 1
      from public.staff s
      left join public.staff_roles sr on sr.staff_id=s.id
      where s.auth_user_id=auth.uid()
        and s.is_active=true
        and (
          s.role=any(p_roles)
          or sr.role=any(p_roles)
        )
    );
$$;

-- Legacy compatibility only. Do not use this function as the authorization
-- boundary for new sensitive functions.
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists(
    select 1
    from public.staff
    where auth_user_id=auth.uid()
      and is_active=true
  );
$$;

grant execute on function public.current_staff_id() to authenticated;
grant execute on function public.is_platform_owner() to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.has_staff_role(text[]) to authenticated;
grant execute on function public.is_staff() to authenticated;

-- ============================================================
-- 4) PROTECTED OWNER SEED
-- The currently designated owner is Mohammad Jebali.
-- ============================================================

do $$
declare
  v_auth_id uuid;
  v_staff_id uuid;
begin
  select id into v_auth_id
  from auth.users
  where lower(email)=lower('mr.mhammadahmad2@gmail.com')
  limit 1;

  if v_auth_id is null then
    raise notice 'Owner Auth user mr.mhammadahmad2@gmail.com was not found. Create/sign in this Auth account, then rerun V2.5.';
  else
    select id into v_staff_id
    from public.staff
    where auth_user_id=v_auth_id
    limit 1;

    if v_staff_id is null then
      insert into public.staff(auth_user_id,full_name,role,is_active)
      values(v_auth_id,'Mohammad Jebali','super_admin',true)
      returning id into v_staff_id;
    else
      update public.staff
      set full_name='Mohammad Jebali',
          role='super_admin',
          is_active=true
      where id=v_staff_id;
    end if;

    -- Only the protected owner remains primary super_admin.
    update public.staff
    set role='admin'
    where role='super_admin'
      and id<>v_staff_id;

    delete from public.staff_roles
    where role='super_admin'
      and staff_id<>v_staff_id;

    insert into public.staff_roles(staff_id,role,granted_by_staff_id)
    values
      (v_staff_id,'super_admin',v_staff_id),
      (v_staff_id,'admin',v_staff_id),
      (v_staff_id,'teacher',v_staff_id)
    on conflict do nothing;

    insert into public.platform_ownership(id,owner_staff_id,owner_email)
    values(1,v_staff_id,'mr.mhammadahmad2@gmail.com')
    on conflict(id) do update
    set owner_staff_id=excluded.owner_staff_id,
        owner_email=excluded.owner_email,
        updated_at=now();

    -- Keep Mr. Mohammad Jebali's public teacher identity attached to the owner account.
    update public.teacher_profiles
    set staff_id=v_staff_id,
        updated_at=now()
    where slug='mr-mohammad-jebali'
      and staff_id is distinct from v_staff_id;
  end if;
end $$;

-- Seed every active legacy staff member's primary role into staff_roles.
insert into public.staff_roles(staff_id,role)
select id,role
from public.staff
where is_active=true
on conflict do nothing;

-- ============================================================
-- 5) OWNER TEAM MANAGEMENT
-- ============================================================

create or replace function public.owner_list_staff()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'staff_id',s.id,
        'full_name',s.full_name,
        'primary_role',s.role,
        'is_active',s.is_active,
        'email',u.email,
        'last_sign_in_at',u.last_sign_in_at,
        'is_owner',(po.owner_staff_id=s.id),
        'roles',coalesce((
          select jsonb_agg(sr.role order by sr.role)
          from public.staff_roles sr
          where sr.staff_id=s.id
        ),'[]'::jsonb)
      )
      order by (po.owner_staff_id=s.id) desc, s.full_name
    )
    from public.staff s
    left join auth.users u on u.id=s.auth_user_id
    left join public.platform_ownership po on po.id=1
  ),'[]'::jsonb);
end;
$$;

create or replace function public.owner_create_staff_invite(
  p_email text,
  p_full_name text,
  p_primary_role text,
  p_roles text[]
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
  v_token uuid;
  v_roles text[];
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  if nullif(trim(p_email),'') is null or nullif(trim(p_full_name),'') is null then
    raise exception 'email and full name are required';
  end if;

  if lower(trim(p_email))=lower('mr.mhammadahmad2@gmail.com') then
    raise exception 'protected owner email cannot be invited as staff';
  end if;

  if p_primary_role not in ('admin','teacher','sales','student_affairs','finance','content','support') then
    raise exception 'invalid primary role';
  end if;

  v_roles := coalesce(p_roles,array[p_primary_role]::text[]);

  if not (p_primary_role=any(v_roles)) then
    v_roles := array_append(v_roles,p_primary_role);
  end if;

  if exists(
    select 1
    from unnest(v_roles) as t(role_name)
    where role_name not in ('admin','teacher','sales','student_affairs','finance','content','support')
  ) then
    raise exception 'invalid role in roles list';
  end if;

  v_owner := public.current_staff_id();
  v_token := gen_random_uuid();

  -- Invalidate previous unclaimed invites for the same email.
  update public.staff_invites
  set is_active=false
  where lower(email)=lower(trim(p_email))
    and claimed_at is null
    and is_active=true;

  insert into public.staff_invites(
    token,email,full_name,primary_role,roles,created_by_staff_id
  )
  values(
    v_token,lower(trim(p_email)),trim(p_full_name),p_primary_role,v_roles,v_owner
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'staff_invite_created','staff_invite',v_token::text,
    jsonb_build_object('email',lower(trim(p_email)),'roles',v_roles)
  );

  return jsonb_build_object(
    'token',v_token,
    'email',lower(trim(p_email)),
    'expires_at',now()+interval '7 days'
  );
end;
$$;

create or replace function public.owner_list_staff_invites()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id',i.id,
        'token',i.token,
        'email',i.email,
        'full_name',i.full_name,
        'primary_role',i.primary_role,
        'roles',i.roles,
        'created_at',i.created_at,
        'expires_at',i.expires_at,
        'claimed_at',i.claimed_at,
        'is_active',i.is_active
      )
      order by i.created_at desc
    )
    from public.staff_invites i
  ),'[]'::jsonb);
end;
$$;

create or replace function public.public_staff_invite_info(p_token uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_inv public.staff_invites%rowtype;
begin
  select * into v_inv
  from public.staff_invites
  where token=p_token
    and is_active=true
    and claimed_at is null
    and expires_at>now();

  if v_inv.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'email',v_inv.email,
    'full_name',v_inv.full_name,
    'primary_role',v_inv.primary_role,
    'expires_at',v_inv.expires_at
  );
end;
$$;

create or replace function public.claim_staff_invite(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_inv public.staff_invites%rowtype;
  v_email text;
  v_staff_id uuid;
  r text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_inv
  from public.staff_invites
  where token=p_token
    and is_active=true
    and claimed_at is null
    and expires_at>now()
  for update;

  if v_inv.id is null then
    raise exception 'invite is invalid or expired';
  end if;

  select lower(email) into v_email
  from auth.users
  where id=auth.uid();

  if v_email is null or v_email<>lower(v_inv.email) then
    raise exception 'authenticated email does not match invite';
  end if;

  select id into v_staff_id
  from public.staff
  where auth_user_id=auth.uid()
  limit 1;

  if v_staff_id is null then
    insert into public.staff(auth_user_id,full_name,role,is_active)
    values(auth.uid(),v_inv.full_name,v_inv.primary_role,true)
    returning id into v_staff_id;
  else
    update public.staff
    set full_name=v_inv.full_name,
        role=v_inv.primary_role,
        is_active=true
    where id=v_staff_id;
  end if;

  delete from public.staff_roles
  where staff_id=v_staff_id
    and role<>'super_admin';

  foreach r in array v_inv.roles loop
    insert into public.staff_roles(staff_id,role,granted_by_staff_id)
    values(v_staff_id,r,v_inv.created_by_staff_id)
    on conflict do nothing;
  end loop;

  if 'teacher'=any(v_inv.roles) and not exists(
    select 1 from public.teacher_profiles where staff_id=v_staff_id
  ) then
    insert into public.teacher_profiles(
      staff_id,slug,display_name,display_name_ar,
      headline_en,headline_ar,is_verified,is_public
    )
    values(
      v_staff_id,
      'teacher-'||substr(replace(v_staff_id::text,'-',''),1,12),
      v_inv.full_name,
      v_inv.full_name,
      'JBE Academy Teacher',
      'معلم في JBE Academy',
      false,
      false
    );
  end if;

  update public.staff_invites
  set claimed_at=now(),
      is_active=false
  where id=v_inv.id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'staff_invite_claimed','staff',v_staff_id::text,
    jsonb_build_object('email',v_email,'roles',v_inv.roles)
  );

  return jsonb_build_object(
    'success',true,
    'staff_id',v_staff_id,
    'primary_role',v_inv.primary_role,
    'roles',v_inv.roles
  );
end;
$$;

create or replace function public.owner_set_staff_roles(
  p_staff_id uuid,
  p_primary_role text,
  p_roles text[]
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner_staff uuid;
  v_roles text[];
  r text;
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  select owner_staff_id into v_owner_staff
  from public.platform_ownership
  where id=1;

  if p_staff_id=v_owner_staff then
    raise exception 'protected owner roles cannot be changed here';
  end if;

  if p_primary_role not in ('admin','teacher','sales','student_affairs','finance','content','support') then
    raise exception 'invalid primary role';
  end if;

  v_roles := coalesce(p_roles,array[p_primary_role]::text[]);

  if not (p_primary_role=any(v_roles)) then
    v_roles := array_append(v_roles,p_primary_role);
  end if;

  if exists(
    select 1 from unnest(v_roles) as t(role_name)
    where role_name not in ('admin','teacher','sales','student_affairs','finance','content','support')
  ) then
    raise exception 'invalid role';
  end if;

  update public.staff
  set role=p_primary_role
  where id=p_staff_id;

  if not found then
    raise exception 'staff member not found';
  end if;

  delete from public.staff_roles where staff_id=p_staff_id;

  foreach r in array v_roles loop
    insert into public.staff_roles(staff_id,role,granted_by_staff_id)
    values(p_staff_id,r,public.current_staff_id())
    on conflict do nothing;
  end loop;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'staff_roles_changed','staff',p_staff_id::text,
    jsonb_build_object('primary_role',p_primary_role,'roles',v_roles)
  );

  return true;
end;
$$;


create or replace function public.owner_staff_permissions(p_staff_id uuid)
returns table(
  permission_key text,
  name_en text,
  name_ar text,
  category text,
  role_allowed boolean,
  override_value boolean,
  effective_allowed boolean
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  return query
  select
    p.permission_key,
    p.name_en,
    p.name_ar,
    p.category,
    exists(
      select 1
      from public.staff_roles sr
      join public.role_permissions rp on rp.role=sr.role
      where sr.staff_id=p_staff_id
        and rp.permission_key=p.permission_key
    ) as role_allowed,
    o.allowed as override_value,
    coalesce(
      o.allowed,
      exists(
        select 1
        from public.staff_roles sr
        join public.role_permissions rp on rp.role=sr.role
        where sr.staff_id=p_staff_id
          and rp.permission_key=p.permission_key
      )
    ) as effective_allowed
  from public.app_permissions p
  left join public.staff_permission_overrides o
    on o.staff_id=p_staff_id and o.permission_key=p.permission_key
  order by p.category,p.permission_key;
end;
$$;

create or replace function public.owner_set_staff_permission_override(
  p_staff_id uuid,
  p_permission_key text,
  p_allowed boolean
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner_staff uuid;
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  select owner_staff_id into v_owner_staff
  from public.platform_ownership
  where id=1;

  if p_staff_id=v_owner_staff then
    raise exception 'protected owner permissions cannot be restricted';
  end if;

  if not exists(select 1 from public.app_permissions where permission_key=p_permission_key) then
    raise exception 'unknown permission';
  end if;

  if p_allowed is null then
    delete from public.staff_permission_overrides
    where staff_id=p_staff_id
      and permission_key=p_permission_key;
  else
    insert into public.staff_permission_overrides(
      staff_id,permission_key,allowed,granted_by_staff_id,updated_at
    )
    values(
      p_staff_id,p_permission_key,p_allowed,public.current_staff_id(),now()
    )
    on conflict(staff_id,permission_key) do update
    set allowed=excluded.allowed,
        granted_by_staff_id=excluded.granted_by_staff_id,
        updated_at=now();
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'staff_permission_override','staff',p_staff_id::text,
    jsonb_build_object('permission',p_permission_key,'allowed',p_allowed)
  );

  return true;
end;
$$;

create or replace function public.owner_set_staff_status(
  p_staff_id uuid,
  p_is_active boolean
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner_staff uuid;
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  select owner_staff_id into v_owner_staff
  from public.platform_ownership
  where id=1;

  if p_staff_id=v_owner_staff and p_is_active=false then
    raise exception 'protected owner cannot be suspended';
  end if;

  update public.staff
  set is_active=p_is_active
  where id=p_staff_id;

  if not found then
    raise exception 'staff member not found';
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),
    case when p_is_active then 'staff_reactivated' else 'staff_suspended' end,
    'staff',p_staff_id::text,
    jsonb_build_object('is_active',p_is_active)
  );

  return true;
end;
$$;

grant execute on function public.owner_list_staff() to authenticated;
grant execute on function public.owner_create_staff_invite(text,text,text,text[]) to authenticated;
grant execute on function public.owner_list_staff_invites() to authenticated;
grant execute on function public.public_staff_invite_info(uuid) to anon,authenticated;
grant execute on function public.claim_staff_invite(uuid) to authenticated;
grant execute on function public.owner_set_staff_roles(uuid,text,text[]) to authenticated;
grant execute on function public.owner_staff_permissions(uuid) to authenticated;
grant execute on function public.owner_set_staff_permission_override(uuid,text,boolean) to authenticated;
grant execute on function public.owner_set_staff_status(uuid,boolean) to authenticated;

-- ============================================================
-- 6) AUTH / PORTAL ROUTING
-- ============================================================

create or replace function public.resolve_my_portal()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then
    return jsonb_build_object(
      'authenticated',false,
      'account_type',null,
      'role',null,
      'destination',null
    );
  end if;

  if public.is_platform_owner() then
    return jsonb_build_object(
      'authenticated',true,
      'account_type','staff',
      'role','super_admin',
      'is_owner',true,
      'destination','owner-dashboard.html'
    );
  end if;

  select s.role into v_role
  from public.staff s
  where s.auth_user_id=v_uid
    and s.is_active=true
  limit 1;

  if v_role is not null then
    return jsonb_build_object(
      'authenticated',true,
      'account_type','staff',
      'role',v_role,
      'is_owner',false,
      'destination',
        case v_role
          when 'admin' then 'admin-dashboard.html'
          when 'teacher' then 'teacher-workspace.html'
          when 'sales' then 'sales-crm.html'
          when 'student_affairs' then 'student-affairs.html'
          when 'finance' then 'finance-dashboard.html'
          else 'portal.html'
        end
    );
  end if;

  if exists(select 1 from public.students where auth_user_id=v_uid) then
    return jsonb_build_object(
      'authenticated',true,'account_type','student','role','student',
      'is_owner',false,'destination','student-dashboard.html'
    );
  end if;

  if exists(select 1 from public.guardians where auth_user_id=v_uid) then
    return jsonb_build_object(
      'authenticated',true,'account_type','parent','role','parent',
      'is_owner',false,'destination','parent-dashboard.html'
    );
  end if;

  return jsonb_build_object(
    'authenticated',true,'account_type','unlinked','role',null,
    'is_owner',false,'destination',null
  );
end;
$$;

revoke all on function public.resolve_my_portal() from public;
grant execute on function public.resolve_my_portal() to authenticated;

-- ============================================================
-- 7) TEACHER / STUDENT ACCESS HELPERS
-- ============================================================

create or replace function public.can_manage_student_course(
  p_student_id uuid,
  p_course_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if public.has_permission('students.manage') then
    return true;
  end if;

  if not public.has_permission('academic.assess') then
    return false;
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
    and s.is_active=true
  limit 1;

  if v_teacher_id is null then
    return false;
  end if;

  return exists(
    select 1
    from public.enrollments e
    join public.courses co on co.id=e.course_id
    left join public.class_groups cg on cg.id=e.group_id
    where e.student_id=p_student_id
      and e.course_id=p_course_id
      and (
        co.teacher_id=v_teacher_id
        or cg.teacher_id=v_teacher_id
      )
  );
end;
$$;

create or replace function public.can_manage_student(p_student_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if public.has_permission('students.manage') then
    return true;
  end if;

  if not public.has_permission('academic.assess') then
    return false;
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
    and s.is_active=true
  limit 1;

  if v_teacher_id is null then
    return false;
  end if;

  return exists(
    select 1
    from public.enrollments e
    join public.courses co on co.id=e.course_id
    left join public.class_groups cg on cg.id=e.group_id
    where e.student_id=p_student_id
      and (
        co.teacher_id=v_teacher_id
        or cg.teacher_id=v_teacher_id
      )
  );
end;
$$;

create or replace function public.can_manage_session(p_session_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if public.has_permission('groups.manage') then
    return true;
  end if;

  if not public.has_permission('teacher.workspace') then
    return false;
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
    and s.is_active=true
  limit 1;

  if v_teacher_id is null then
    return false;
  end if;

  return exists(
    select 1
    from public.class_sessions cs
    join public.courses co on co.id=cs.course_id
    left join public.class_groups cg on cg.id=cs.group_id
    where cs.id=p_session_id
      and (
        co.teacher_id=v_teacher_id
        or cg.teacher_id=v_teacher_id
      )
  );
end;
$$;

grant execute on function public.can_manage_student_course(uuid,uuid) to authenticated;
grant execute on function public.can_manage_student(uuid) to authenticated;
grant execute on function public.can_manage_session(uuid) to authenticated;

-- ============================================================
-- 8) HARDEN LEGACY ADMIN FUNCTIONS WITH PERMISSIONS
-- ============================================================

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('admin.dashboard') then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'students',(select count(*) from public.students where status='active'),
    'active_enrollments',(select count(*) from public.enrollments where status='active'),
    'paid_enrollments',(select count(*) from public.enrollments where payment_status='paid'),
    'pending_payments',(select count(*) from public.enrollments where payment_status in ('unpaid','pending_verification','partial')),
    'courses',(select count(*) from public.courses where status in ('open','active'))
  );
end;
$$;

create or replace function public.admin_list_students()
returns table(
  student_id uuid, student_code text, full_name text, full_name_en text,
  phone text, status text, curriculum text, grade text,
  active_courses bigint, payment_state text
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('students.view') then
    raise exception 'not authorized';
  end if;

  return query
  select
    s.id,s.student_code,s.full_name,s.full_name_en,s.phone,s.status,
    c.name_en,g.name_en,
    count(distinct e.id) filter (where e.status='active'),
    case when bool_or(e.payment_status='paid') then 'paid'
         when bool_or(e.payment_status='pending_verification') then 'pending_verification'
         else coalesce(max(e.payment_status),'unpaid') end
  from public.students s
  left join public.curricula c on c.id=s.current_curriculum_id
  left join public.grade_levels g on g.id=s.current_grade_level_id
  left join public.enrollments e on e.student_id=s.id
  group by s.id,c.name_en,g.name_en
  order by s.created_at desc;
end;
$$;

create or replace function public.admin_curriculum_options()
returns table(curriculum_code text,curriculum_name text,grade_code text,grade_name text)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('students.manage')
    or public.has_permission('courses.manage')
    or public.has_permission('teachers.manage')
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select c.code,c.name_en,g.code,g.name_en
  from public.curricula c
  join public.grade_levels g on g.curriculum_id=c.id
  where c.is_active=true and g.is_active=true
  order by c.code,g.sort_order;
end;
$$;

create or replace function public.admin_course_options()
returns table(course_id uuid,slug text,title_en text,curriculum_code text,grade_code text,status text)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('students.manage')
    or public.has_permission('courses.manage')
    or public.has_permission('groups.manage')
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select co.id,co.slug,co.title_en,c.code,g.code,co.status
  from public.courses co
  join public.curricula c on c.id=co.curriculum_id
  join public.grade_levels g on g.id=co.grade_level_id
  where co.status in ('draft','open','active')
  order by c.code,g.sort_order,co.title_en;
end;
$$;

create or replace function public.admin_create_student_bundle(
  p_full_name text,p_full_name_en text,p_phone text,
  p_guardian_name text,p_guardian_phone text,p_relationship text,
  p_curriculum_code text,p_grade_code text,p_course_slug text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_student_id uuid; v_guardian_id uuid; v_es_id uuid; v_curriculum_id uuid;
  v_grade_id uuid; v_year_id uuid; v_course_id uuid; v_student_code text;
begin
  if not public.has_permission('students.manage') then
    raise exception 'not authorized';
  end if;

  select c.education_system_id,c.id into v_es_id,v_curriculum_id
  from public.curricula c where c.code=p_curriculum_code;

  select g.id into v_grade_id
  from public.grade_levels g
  where g.curriculum_id=v_curriculum_id and g.code=p_grade_code;

  select id into v_year_id
  from public.academic_years
  where is_current=true
  order by start_date desc nulls last limit 1;

  if v_curriculum_id is null or v_grade_id is null or v_year_id is null then
    raise exception 'invalid curriculum/grade/current academic year';
  end if;

  v_student_code := 'JBE-'||to_char(now(),'YY')||'-'||lpad(nextval('public.student_code_seq')::text,5,'0');

  insert into public.students(
    student_code,full_name,full_name_en,phone,
    current_education_system_id,current_curriculum_id,current_grade_level_id,status
  ) values(
    v_student_code,p_full_name,nullif(p_full_name_en,''),nullif(p_phone,''),
    v_es_id,v_curriculum_id,v_grade_id,'active'
  ) returning id into v_student_id;

  if nullif(p_guardian_name,'') is not null and nullif(p_guardian_phone,'') is not null then
    select id into v_guardian_id from public.guardians where phone=p_guardian_phone limit 1;
    if v_guardian_id is null then
      insert into public.guardians(full_name,phone,relationship)
      values(p_guardian_name,p_guardian_phone,nullif(p_relationship,''))
      returning id into v_guardian_id;
    end if;
    insert into public.student_guardians(student_id,guardian_id,is_primary,receives_reports)
    values(v_student_id,v_guardian_id,true,true)
    on conflict do nothing;
  end if;

  insert into public.student_academic_records(
    student_id,academic_year_id,education_system_id,curriculum_id,grade_level_id,status
  ) values(v_student_id,v_year_id,v_es_id,v_curriculum_id,v_grade_id,'active');

  if nullif(p_course_slug,'') is not null then
    select id into v_course_id from public.courses where slug=p_course_slug limit 1;
    if v_course_id is null then raise exception 'invalid course slug'; end if;
    insert into public.enrollments(student_id,course_id,status,payment_status,access_enabled)
    values(v_student_id,v_course_id,'pending','unpaid',false);
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'student_created','student',v_student_id::text,
    jsonb_build_object('student_code',v_student_code)
  );

  return jsonb_build_object('student_id',v_student_id,'student_code',v_student_code);
end;
$$;

-- V1.8 detail: Student Affairs/Admin only. Teachers use the scoped teacher workspace.
create or replace function public.admin_student_detail(p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_result jsonb;
begin
  if not public.has_permission('students.view') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'student',
      (
        select jsonb_build_object(
          'id', s.id,
          'student_code', s.student_code,
          'full_name', s.full_name,
          'full_name_en', s.full_name_en,
          'phone', s.phone,
          'email', s.email,
          'city', s.city,
          'status', s.status,
          'joined_at', s.joined_at,
          'curriculum', c.name_en,
          'curriculum_code', c.code,
          'grade', g.name_en,
          'grade_code', g.code
        )
        from public.students s
        left join public.curricula c on c.id=s.current_curriculum_id
        left join public.grade_levels g on g.id=s.current_grade_level_id
        where s.id=p_student_id
      ),
    'guardians',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',gu.id,'full_name',gu.full_name,'phone',gu.phone,'email',gu.email,
          'relationship',gu.relationship,'is_primary',sg.is_primary,'receives_reports',sg.receives_reports
        ))
        from public.student_guardians sg
        join public.guardians gu on gu.id=sg.guardian_id
        where sg.student_id=p_student_id
      ),'[]'::jsonb),
    'enrollments',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'enrollment_id',e.id,'course_id',co.id,'course_title',co.title_en,'course_slug',co.slug,
          'status',e.status,'payment_status',e.payment_status,'access_enabled',e.access_enabled,'enrolled_at',e.enrolled_at
        ) order by e.enrolled_at desc)
        from public.enrollments e
        join public.courses co on co.id=e.course_id
        where e.student_id=p_student_id
      ),'[]'::jsonb),
    'academic_records',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'academic_year',ay.name,'curriculum',c.name_en,'grade',g.name_en,'status',ar.status,
          'final_overall_score',ar.final_overall_score,'teacher_summary',ar.teacher_summary
        ) order by ay.start_date desc nulls last)
        from public.student_academic_records ar
        join public.academic_years ay on ay.id=ar.academic_year_id
        join public.curricula c on c.id=ar.curriculum_id
        join public.grade_levels g on g.id=ar.grade_level_id
        where ar.student_id=p_student_id
      ),'[]'::jsonb),
    'goals',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',lg.id,'title',lg.title,'description',lg.description,'target_date',lg.target_date,
          'status',lg.status,'progress_percent',lg.progress_percent
        ) order by lg.created_at desc)
        from public.learning_goals lg
        where lg.student_id=p_student_id
      ),'[]'::jsonb),
    'teacher_notes',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',tn.id,'note_type',tn.note_type,'note',tn.note,
          'is_parent_visible',tn.is_parent_visible,'created_at',tn.created_at
        ) order by tn.created_at desc)
        from public.teacher_notes tn
        where tn.student_id=p_student_id
      ),'[]'::jsonb),
    'reports',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',pr.id,'period_name',pr.period_name,'report_date',pr.report_date,
          'attendance_percent',pr.attendance_percent,'homework_completion_percent',pr.homework_completion_percent,
          'assessment_average',pr.assessment_average,'overall_progress_percent',pr.overall_progress_percent,
          'strengths',pr.strengths,'areas_for_improvement',pr.areas_for_improvement,
          'teacher_recommendation',pr.teacher_recommendation,'published',pr.published
        ) order by pr.report_date desc)
        from public.progress_reports pr
        where pr.student_id=p_student_id
      ),'[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function public.admin_verify_payment_and_activate(
  p_enrollment_id uuid,
  p_amount numeric,
  p_method text,
  p_transaction_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_student_id uuid;
  v_course_id uuid;
begin
  if not public.has_permission('finance.verify') then
    raise exception 'not authorized';
  end if;

  if p_method not in ('instapay','vodafone_cash','bank_transfer','card','cash','other') then
    raise exception 'invalid payment method';
  end if;

  select student_id,course_id
  into v_student_id,v_course_id
  from public.enrollments
  where id=p_enrollment_id;

  if v_student_id is null then
    raise exception 'enrollment not found';
  end if;

  insert into public.payments(
    student_id,enrollment_id,amount,currency,method,transaction_reference,
    status,paid_at,verified_at,notes
  )
  values(
    v_student_id,p_enrollment_id,p_amount,'EGP',p_method,
    nullif(p_transaction_reference,''),'verified',now(),now(),
    'Verified from JBE Finance/Admin'
  );

  update public.enrollments
  set status='active',
      payment_status='paid',
      access_enabled=true
  where id=p_enrollment_id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'payment_verified','enrollment',p_enrollment_id::text,
    jsonb_build_object('amount',p_amount,'method',p_method,'reference',p_transaction_reference)
  );

  return jsonb_build_object('success',true,'student_id',v_student_id,'course_id',v_course_id);
end;
$$;

create or replace function public.admin_skill_options(p_course_id uuid)
returns table(skill_id uuid,category text,skill_name text,skill_code text)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('academic.assess')
    or public.has_permission('students.manage')
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select sk.id,sc.name_en,sk.name_en,sk.code
  from public.courses co
  join public.skill_categories sc on sc.subject_id=co.subject_id
  join public.skills sk on sk.skill_category_id=sc.id
  where co.id=p_course_id
  order by sc.sort_order,sk.sort_order;
end;
$$;

create or replace function public.admin_add_skill_rating(
  p_student_id uuid,p_course_id uuid,p_skill_id uuid,p_rating int,
  p_evidence text,p_teacher_note text,p_recommended_action text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_year_id uuid;
  v_id uuid;
  v_label text;
begin
  if not public.can_manage_student_course(p_student_id,p_course_id) then
    raise exception 'not authorized';
  end if;

  if p_rating<1 or p_rating>5 then
    raise exception 'rating must be between 1 and 5';
  end if;

  select id into v_year_id from public.academic_years
  where is_current=true order by start_date desc nulls last limit 1;

  v_label := case p_rating
    when 1 then 'beginning'
    when 2 then 'developing'
    when 3 then 'secure'
    when 4 then 'strong'
    when 5 then 'advanced'
  end;

  insert into public.student_skill_ratings(
    student_id,academic_year_id,course_id,skill_id,rating,rating_label,
    evidence,teacher_note,recommended_action,assessed_at
  )
  values(
    p_student_id,v_year_id,p_course_id,p_skill_id,p_rating,v_label,
    nullif(p_evidence,''),nullif(p_teacher_note,''),nullif(p_recommended_action,''),current_date
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.admin_add_learning_goal(
  p_student_id uuid,p_course_id uuid,p_title text,p_description text,p_target_date date
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_year_id uuid;
  v_id uuid;
begin
  if p_course_id is not null then
    if not public.can_manage_student_course(p_student_id,p_course_id) then
      raise exception 'not authorized';
    end if;
  elsif not public.can_manage_student(p_student_id) then
    raise exception 'not authorized';
  end if;

  select id into v_year_id from public.academic_years
  where is_current=true order by start_date desc nulls last limit 1;

  insert into public.learning_goals(
    student_id,academic_year_id,course_id,title,description,target_date,status,progress_percent
  )
  values(
    p_student_id,v_year_id,p_course_id,p_title,nullif(p_description,''),p_target_date,'active',0
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.admin_add_teacher_note(
  p_student_id uuid,p_course_id uuid,p_note_type text,p_note text,p_parent_visible boolean
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
begin
  if p_course_id is not null then
    if not public.can_manage_student_course(p_student_id,p_course_id) then
      raise exception 'not authorized';
    end if;
  elsif not public.can_manage_student(p_student_id) then
    raise exception 'not authorized';
  end if;

  if p_note_type not in ('general','academic','behavior','attendance','parent_followup','strength','concern') then
    raise exception 'invalid note type';
  end if;

  insert into public.teacher_notes(student_id,course_id,note_type,note,is_parent_visible)
  values(p_student_id,p_course_id,p_note_type,p_note,p_parent_visible)
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.admin_record_attendance(
  p_student_id uuid,p_course_id uuid,p_session_title text,p_session_date timestamptz,
  p_status text,p_minutes int,p_note text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_session_id uuid;
  v_attendance_id uuid;
begin
  if not public.can_manage_student_course(p_student_id,p_course_id) then
    raise exception 'not authorized';
  end if;

  if p_status not in ('present','late','absent','excused') then
    raise exception 'invalid attendance status';
  end if;

  select id into v_session_id
  from public.class_sessions
  where course_id=p_course_id
    and title=p_session_title
    and session_date=p_session_date
  limit 1;

  if v_session_id is null then
    insert into public.class_sessions(course_id,title,session_date,session_type)
    values(p_course_id,p_session_title,p_session_date,'live')
    returning id into v_session_id;
  end if;

  insert into public.attendance(session_id,student_id,status,minutes_attended,note)
  values(v_session_id,p_student_id,p_status,p_minutes,nullif(p_note,''))
  on conflict(session_id,student_id)
  do update set
    status=excluded.status,
    minutes_attended=excluded.minutes_attended,
    note=excluded.note
  returning id into v_attendance_id;

  return v_attendance_id;
end;
$$;

create or replace function public.admin_publish_progress_report(
  p_student_id uuid,p_period_name text,p_attendance numeric,p_homework numeric,
  p_assessment numeric,p_overall numeric,p_strengths text,p_improvements text,p_recommendation text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_year_id uuid;
  v_id uuid;
begin
  if not (
    public.has_permission('students.manage')
    or (public.has_permission('reports.manage') and public.can_manage_student(p_student_id))
  ) then
    raise exception 'not authorized';
  end if;

  select id into v_year_id from public.academic_years
  where is_current=true order by start_date desc nulls last limit 1;

  insert into public.progress_reports(
    student_id,academic_year_id,period_name,report_date,
    attendance_percent,homework_completion_percent,assessment_average,overall_progress_percent,
    strengths,areas_for_improvement,teacher_recommendation,published
  )
  values(
    p_student_id,v_year_id,p_period_name,current_date,
    p_attendance,p_homework,p_assessment,p_overall,
    nullif(p_strengths,''),nullif(p_improvements,''),nullif(p_recommendation,''),true
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Course preference is used by both Sales conversion and public course registration.
alter table public.applications
  add column if not exists preferred_course_id uuid references public.courses(id);

-- ============================================================
-- 9) SALES / APPLICATION SECURITY
-- ============================================================

create or replace function public.staff_list_applications()
returns table(
  id uuid,application_code text,created_at timestamptz,student_name text,
  contact_phone text,curriculum text,grade text,subject text,
  sales_status text,application_status text,next_follow_up_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('applications.view') then
    raise exception 'not authorized';
  end if;

  return query
  select
    a.id,a.application_code,a.created_at,a.student_name,
    coalesce(a.student_phone,a.guardian_phone),
    c.name_en,g.name_en,su.name_en,
    a.sales_status,a.application_status,a.next_follow_up_at
  from public.applications a
  left join public.curricula c on c.id=a.curriculum_id
  left join public.grade_levels g on g.id=a.grade_level_id
  left join public.subjects su on su.id=a.subject_id
  order by a.created_at desc;
end;
$$;

create or replace function public.staff_update_application_status(
  p_application_id uuid,
  p_sales_status text,
  p_application_status text,
  p_sales_notes text,
  p_next_follow_up_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('applications.edit') then
    raise exception 'not authorized';
  end if;

  update public.applications
  set sales_status=coalesce(p_sales_status,sales_status),
      application_status=coalesce(p_application_status,application_status),
      sales_notes=case when p_sales_notes is null then sales_notes else nullif(p_sales_notes,'') end,
      next_follow_up_at=p_next_follow_up_at,
      last_contact_at=case
        when p_sales_status in ('contacted','follow_up','trial','won','lost') then now()
        else last_contact_at
      end,
      updated_at=now()
  where id=p_application_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'application_updated','application',p_application_id::text,
      jsonb_build_object(
        'sales_status',p_sales_status,
        'application_status',p_application_status,
        'next_follow_up_at',p_next_follow_up_at
      )
    );
  end if;

  return found;
end;
$$;

create or replace function public.admin_convert_application_to_student(
  p_application_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  a public.applications%rowtype;
  v_student_id uuid;
  v_guardian_id uuid;
  v_year_id uuid;
  v_student_code text;
begin
  if not public.has_permission('applications.convert') then
    raise exception 'not authorized';
  end if;

  select * into a
  from public.applications
  where id=p_application_id
  for update;

  if a.id is null then
    raise exception 'application not found';
  end if;

  if a.created_student_id is not null then
    return jsonb_build_object('student_id',a.created_student_id,'already_converted',true);
  end if;

  select id into v_year_id
  from public.academic_years
  where is_current=true
  order by start_date desc nulls last limit 1;

  v_student_code := 'JBE-'||to_char(now(),'YY')||'-'||lpad(nextval('public.student_code_seq')::text,5,'0');

  insert into public.students(
    student_code,full_name,full_name_en,phone,email,
    current_education_system_id,current_curriculum_id,current_grade_level_id,status
  )
  values(
    v_student_code,a.student_name,a.student_name_en,a.student_phone,a.student_email,
    a.education_system_id,a.curriculum_id,a.grade_level_id,'active'
  )
  returning id into v_student_id;

  if a.guardian_name is not null and a.guardian_phone is not null then
    select id into v_guardian_id
    from public.guardians
    where phone=a.guardian_phone
    order by created_at limit 1;

    if v_guardian_id is null then
      insert into public.guardians(full_name,phone,email,relationship)
      values(a.guardian_name,a.guardian_phone,a.guardian_email,a.relationship)
      returning id into v_guardian_id;
    end if;

    insert into public.student_guardians(student_id,guardian_id,is_primary,receives_reports)
    values(v_student_id,v_guardian_id,true,true)
    on conflict do nothing;
  end if;

  if v_year_id is not null and a.curriculum_id is not null and a.grade_level_id is not null and a.education_system_id is not null then
    insert into public.student_academic_records(
      student_id,academic_year_id,education_system_id,curriculum_id,grade_level_id,status
    )
    values(v_student_id,v_year_id,a.education_system_id,a.curriculum_id,a.grade_level_id,'active')
    on conflict(student_id,academic_year_id) do nothing;
  end if;

  if a.preferred_course_id is not null then
    insert into public.enrollments(student_id,course_id,status,payment_status,access_enabled)
    values(v_student_id,a.preferred_course_id,'pending','unpaid',false);
  end if;

  update public.applications
  set created_student_id=v_student_id,
      application_status='converted',
      sales_status='won',
      converted_at=now(),
      updated_at=now()
  where id=a.id;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'application_converted','student',v_student_id::text,
    jsonb_build_object('application_id',a.id,'student_code',v_student_code)
  );

  return jsonb_build_object('success',true,'student_id',v_student_id,'student_code',v_student_code);
end;
$$;

-- ============================================================
-- 10) COURSE DISCOVERY + COURSE-BASED REGISTRATION
-- ============================================================

create or replace function public.public_course_catalog()
returns table(
  course_id uuid,
  slug text,
  title_en text,
  title_ar text,
  education_system_id uuid,
  education_system_en text,
  education_system_ar text,
  curriculum_id uuid,
  curriculum_en text,
  curriculum_ar text,
  stage_id uuid,
  stage_en text,
  stage_ar text,
  grade_level_id uuid,
  grade_en text,
  grade_ar text,
  subject_id uuid,
  subject_en text,
  subject_ar text,
  teacher_id uuid,
  teacher_slug text,
  teacher_name text,
  teacher_name_ar text,
  study_mode text,
  billing_type text,
  session_duration_minutes int,
  price numeric
)
language sql
stable
security definer
set search_path=public
as $$
  select
    co.id,
    co.slug,
    co.title_en,
    co.title_ar,
    es.id,
    es.name_en,
    es.name_ar,
    c.id,
    c.name_en,
    c.name_ar,
    st.id,
    st.name_en,
    st.name_ar,
    g.id,
    g.name_en,
    g.name_ar,
    su.id,
    su.name_en,
    su.name_ar,
    tp.id,
    tp.slug,
    tp.display_name,
    tp.display_name_ar,
    co.study_mode,
    co.billing_type,
    co.session_duration_minutes,
    coalesce(co.public_price,co.price_egp)
  from public.courses co
  join public.curricula c on c.id=co.curriculum_id
  join public.education_systems es on es.id=c.education_system_id
  join public.grade_levels g on g.id=co.grade_level_id
  left join public.academic_stages st on st.id=g.stage_id
  join public.subjects su on su.id=co.subject_id
  left join public.teacher_profiles tp on tp.id=co.teacher_id
  where co.is_public=true
    and co.status in ('open','active')
    and co.approval_status='approved'
  order by es.name_en,g.sort_order,su.name_en,co.title_en;
$$;

create or replace function public.public_course_detail(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'course',jsonb_build_object(
      'id',co.id,
      'slug',co.slug,
      'title_en',co.title_en,
      'title_ar',co.title_ar,
      'study_mode',co.study_mode,
      'billing_type',co.billing_type,
      'duration_minutes',co.session_duration_minutes,
      'price',coalesce(co.public_price,co.price_egp),
      'currency','EGP',
      'education_system_en',es.name_en,
      'education_system_ar',es.name_ar,
      'curriculum_en',c.name_en,
      'curriculum_ar',c.name_ar,
      'stage_en',st.name_en,
      'stage_ar',st.name_ar,
      'grade_en',g.name_en,
      'grade_ar',g.name_ar,
      'subject_en',su.name_en,
      'subject_ar',su.name_ar
    ),
    'teacher',case when tp.id is null then null else jsonb_build_object(
      'slug',tp.slug,
      'display_name',tp.display_name,
      'display_name_ar',tp.display_name_ar,
      'headline_en',tp.headline_en,
      'headline_ar',tp.headline_ar,
      'photo_url',tp.photo_url
    ) end,
    'groups',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',cg.id,
        'code',cg.code,
        'name',cg.name,
        'capacity',cg.capacity,
        'weekday',cg.recurring_weekday,
        'start_time',cg.recurring_start_time,
        'duration_minutes',cg.default_duration_minutes,
        'timezone',cg.timezone,
        'status',cg.status,
        'active_students',(
          select count(*)
          from public.group_members gm
          where gm.group_id=cg.id and gm.status='active'
        )
      ) order by cg.name)
      from public.class_groups cg
      where cg.course_id=co.id
        and cg.status in ('open','active')
    ),'[]'::jsonb)
  )
  from public.courses co
  join public.curricula c on c.id=co.curriculum_id
  join public.education_systems es on es.id=c.education_system_id
  join public.grade_levels g on g.id=co.grade_level_id
  left join public.academic_stages st on st.id=g.stage_id
  join public.subjects su on su.id=co.subject_id
  left join public.teacher_profiles tp on tp.id=co.teacher_id
  where co.slug=p_slug
    and co.is_public=true
    and co.status in ('open','active')
    and co.approval_status='approved';
$$;

create or replace function public.public_submit_application_v25(
  p_student_name text,
  p_student_name_en text,
  p_student_phone text,
  p_student_email text,
  p_guardian_name text,
  p_guardian_phone text,
  p_guardian_email text,
  p_relationship text,
  p_education_system_id uuid,
  p_curriculum_id uuid,
  p_stage_id uuid,
  p_grade_level_id uuid,
  p_subject_id uuid,
  p_preferred_teacher_id uuid,
  p_preferred_course_id uuid,
  p_source text,
  p_notes text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_code text;
begin
  if coalesce(trim(p_student_name),'')='' then
    raise exception 'student name is required';
  end if;

  if coalesce(trim(p_student_phone),'')='' and coalesce(trim(p_guardian_phone),'')='' then
    raise exception 'a contact phone is required';
  end if;

  if p_preferred_course_id is not null and not exists(
    select 1 from public.courses
    where id=p_preferred_course_id
      and is_public=true
      and status in ('open','active')
  ) then
    raise exception 'invalid preferred course';
  end if;

  v_code := 'JBE-APP-'||to_char(now(),'YY')||'-'||lpad(nextval('public.application_code_seq')::text,5,'0');

  insert into public.applications(
    application_code,student_name,student_name_en,student_phone,student_email,
    guardian_name,guardian_phone,guardian_email,relationship,
    education_system_id,curriculum_id,stage_id,grade_level_id,subject_id,
    preferred_teacher_id,preferred_course_id,source,notes
  )
  values(
    v_code,p_student_name,nullif(p_student_name_en,''),nullif(p_student_phone,''),nullif(p_student_email,''),
    nullif(p_guardian_name,''),nullif(p_guardian_phone,''),nullif(p_guardian_email,''),nullif(p_relationship,''),
    p_education_system_id,p_curriculum_id,p_stage_id,p_grade_level_id,p_subject_id,
    p_preferred_teacher_id,p_preferred_course_id,coalesce(nullif(p_source,''),'website'),nullif(p_notes,'')
  )
  returning id into v_id;

  return jsonb_build_object('success',true,'application_id',v_id,'application_code',v_code);
end;
$$;

grant execute on function public.public_course_catalog() to anon,authenticated;
grant execute on function public.public_course_detail(text) to anon,authenticated;
grant execute on function public.public_submit_application_v25(
  text,text,text,text,text,text,text,text,uuid,uuid,uuid,uuid,uuid,uuid,uuid,text,text
) to anon,authenticated;


create or replace function public.staff_teacher_approvals()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('teachers.manage')
    or public.has_permission('courses.approve')
  ) then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'profiles',coalesce((
      select jsonb_agg(jsonb_build_object(
        'teacher_id',tp.id,
        'display_name',tp.display_name,
        'display_name_ar',tp.display_name_ar,
        'headline_en',tp.headline_en,
        'is_verified',tp.is_verified,
        'is_public',tp.is_public,
        'staff_active',s.is_active
      ) order by tp.created_at desc)
      from public.teacher_profiles tp
      join public.staff s on s.id=tp.staff_id
      where tp.is_verified=false or tp.is_public=false
    ),'[]'::jsonb),
    'offerings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'offering_id',o.id,
        'teacher_name',tp.display_name,
        'curriculum',c.name_en,
        'grade',g.name_en,
        'subject',su.name_en,
        'study_mode',o.study_mode,
        'billing_type',o.billing_type,
        'teacher_price',o.teacher_price,
        'public_price',o.public_price,
        'currency',o.currency,
        'duration_minutes',o.duration_minutes,
        'capacity',o.capacity,
        'approval_status',o.approval_status
      ) order by o.created_at desc)
      from public.teacher_offerings o
      join public.teacher_profiles tp on tp.id=o.teacher_id
      join public.curricula c on c.id=o.curriculum_id
      join public.grade_levels g on g.id=o.grade_level_id
      join public.subjects su on su.id=o.subject_id
      where o.approval_status='pending'
    ),'[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_set_teacher_profile_approval(
  p_teacher_id uuid,
  p_is_verified boolean,
  p_is_public boolean
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

  update public.teacher_profiles
  set is_verified=p_is_verified,
      is_public=p_is_public,
      updated_at=now()
  where id=p_teacher_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'teacher_profile_approval','teacher_profile',p_teacher_id::text,
      jsonb_build_object('verified',p_is_verified,'public',p_is_public)
    );
  end if;

  return found;
end;
$$;

create or replace function public.admin_review_teacher_offering(
  p_offering_id uuid,
  p_decision text,
  p_public_price numeric
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_staff_id uuid;
begin
  if not public.has_permission('courses.approve') then
    raise exception 'not authorized';
  end if;

  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  if p_decision='approved' and (p_public_price is null or p_public_price<0) then
    raise exception 'A valid public price is required for approval';
  end if;

  v_staff_id:=public.current_staff_id();

  update public.teacher_offerings
  set approval_status=p_decision,
      is_public=(p_decision='approved'),
      public_price=case when p_decision='approved' then p_public_price else null end,
      reviewed_at=now(),
      reviewed_by_staff_id=v_staff_id
  where id=p_offering_id;

  if found then
    insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
    values(
      auth.uid(),'teacher_offering_review','teacher_offering',p_offering_id::text,
      jsonb_build_object('decision',p_decision,'public_price',p_public_price)
    );
  end if;

  return found;
end;
$$;

grant execute on function public.staff_teacher_approvals() to authenticated;
grant execute on function public.admin_set_teacher_profile_approval(uuid,boolean,boolean) to authenticated;
grant execute on function public.admin_review_teacher_offering(uuid,text,numeric) to authenticated;

-- ============================================================
-- 11) TEACHER DAILY WORKSPACE
-- ============================================================

create or replace function public.teacher_today_sessions(p_day date default current_date)
returns table(
  session_id uuid,
  session_title text,
  session_date timestamptz,
  actual_start_at timestamptz,
  actual_end_at timestamptz,
  planned_duration_minutes int,
  actual_duration_minutes int,
  billing_finalized boolean,
  group_name text,
  course_title text,
  student_count bigint
)
language plpgsql
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if not public.has_permission('teacher.workspace') then
    raise exception 'not authorized';
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
    and s.is_active=true
  limit 1;

  if v_teacher_id is null and not public.has_permission('groups.manage') then
    raise exception 'teacher profile not linked';
  end if;

  return query
  select
    cs.id,
    cs.title,
    cs.session_date,
    cs.actual_start_at,
    cs.actual_end_at,
    cs.planned_duration_minutes,
    cs.actual_duration_minutes,
    cs.billing_finalized,
    cg.name,
    co.title_en,
    (
      select count(*)
      from public.enrollments e
      left join public.group_members gm on gm.enrollment_id=e.id
      where e.status='active'
        and (
          (cs.group_id is not null and gm.group_id=cs.group_id and gm.status='active')
          or
          (cs.group_id is null and e.course_id=cs.course_id)
        )
    )
  from public.class_sessions cs
  join public.courses co on co.id=cs.course_id
  left join public.class_groups cg on cg.id=cs.group_id
  where (cs.session_date at time zone coalesce(cg.timezone,'Africa/Cairo'))::date=p_day
    and (
      public.has_permission('groups.manage')
      or co.teacher_id=v_teacher_id
      or cg.teacher_id=v_teacher_id
    )
  order by cs.session_date;
end;
$$;

create or replace function public.teacher_session_detail(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  v_result jsonb;
begin
  if not public.can_manage_session(p_session_id) then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'session',jsonb_build_object(
      'id',cs.id,
      'title',cs.title,
      'session_date',cs.session_date,
      'actual_start_at',cs.actual_start_at,
      'actual_end_at',cs.actual_end_at,
      'planned_duration_minutes',cs.planned_duration_minutes,
      'actual_duration_minutes',cs.actual_duration_minutes,
      'billing_finalized',cs.billing_finalized,
      'group_id',cs.group_id,
      'group_name',cg.name,
      'course_id',co.id,
      'course_title',co.title_en
    ),
    'students',coalesce((
      select jsonb_agg(jsonb_build_object(
        'student_id',s.id,
        'student_code',s.student_code,
        'full_name',s.full_name,
        'full_name_en',s.full_name_en,
        'phone',s.phone
      ) order by coalesce(s.full_name_en,s.full_name))
      from public.enrollments e
      join public.students s on s.id=e.student_id
      left join public.group_members gm on gm.enrollment_id=e.id
      where e.status='active'
        and (
          (cs.group_id is not null and gm.group_id=cs.group_id and gm.status='active')
          or
          (cs.group_id is null and e.course_id=cs.course_id)
        )
    ),'[]'::jsonb),
    'activities',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',la.id,'activity_type',la.activity_type,'title',la.title,
        'description',la.description,'due_at',la.due_at,'resource_url',la.resource_url,
        'is_published',la.is_published
      ) order by la.created_at desc)
      from public.learning_activities la
      where la.session_id=cs.id
    ),'[]'::jsonb)
  )
  into v_result
  from public.class_sessions cs
  join public.courses co on co.id=cs.course_id
  left join public.class_groups cg on cg.id=cs.group_id
  where cs.id=p_session_id;

  return v_result;
end;
$$;

create or replace function public.teacher_start_session(p_session_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path=public
as $$
declare
  v_started timestamptz;
begin
  if not public.can_manage_session(p_session_id) then
    raise exception 'not authorized';
  end if;

  update public.class_sessions
  set actual_start_at=coalesce(actual_start_at,now())
  where id=p_session_id
  returning actual_start_at into v_started;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'session_started','class_session',p_session_id::text,null);

  return v_started;
end;
$$;

create or replace function public.teacher_record_session_attendance(
  p_session_id uuid,
  p_student_id uuid,
  p_status text,
  p_minutes int,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_course_id uuid;
  v_title text;
  v_date timestamptz;
begin
  if not public.can_manage_session(p_session_id) then
    raise exception 'not authorized';
  end if;

  if not exists(
    select 1
    from public.class_sessions cs
    join public.enrollments e on e.course_id=cs.course_id and e.student_id=p_student_id
    left join public.group_members gm on gm.enrollment_id=e.id
    where cs.id=p_session_id
      and e.status='active'
      and (
        cs.group_id is null
        or (gm.group_id=cs.group_id and gm.status='active')
      )
  ) then
    raise exception 'student is not in this session roster';
  end if;

  select course_id,title,session_date
  into v_course_id,v_title,v_date
  from public.class_sessions
  where id=p_session_id;

  return public.admin_record_attendance(
    p_student_id,v_course_id,v_title,v_date,p_status,p_minutes,p_note
  );
end;
$$;

create or replace function public.teacher_add_homework(
  p_session_id uuid,
  p_title text,
  p_description text,
  p_due_at timestamptz,
  p_resource_url text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_course_id uuid;
  v_group_id uuid;
  v_id uuid;
begin
  if not public.can_manage_session(p_session_id) then
    raise exception 'not authorized';
  end if;

  select course_id,group_id
  into v_course_id,v_group_id
  from public.class_sessions
  where id=p_session_id;

  insert into public.learning_activities(
    course_id,group_id,session_id,activity_type,title,description,
    resource_url,due_at,is_published,created_by_staff_id
  )
  values(
    v_course_id,v_group_id,p_session_id,'homework',p_title,
    nullif(p_description,''),nullif(p_resource_url,''),p_due_at,true,public.current_staff_id()
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Direct execute of the underlying billing finalizer is no longer needed by browser users.
revoke execute on function public.admin_finalize_session_billing(uuid,timestamptz,timestamptz)
from authenticated;

create or replace function public.teacher_end_session(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_started timestamptz;
  v_result jsonb;
begin
  if not public.can_manage_session(p_session_id) then
    raise exception 'not authorized';
  end if;

  select actual_start_at into v_started
  from public.class_sessions
  where id=p_session_id;

  if v_started is null then
    v_started := now();
    update public.class_sessions
    set actual_start_at=v_started
    where id=p_session_id;
  end if;

  v_result := public.admin_finalize_session_billing(
    p_session_id,v_started,now()
  );

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'session_ended','class_session',p_session_id::text,v_result);

  return v_result;
end;
$$;

grant execute on function public.teacher_today_sessions(date) to authenticated;
grant execute on function public.teacher_session_detail(uuid) to authenticated;
grant execute on function public.teacher_start_session(uuid) to authenticated;
grant execute on function public.teacher_record_session_attendance(uuid,uuid,text,int,text) to authenticated;
grant execute on function public.teacher_add_homework(uuid,text,text,timestamptz,text) to authenticated;
grant execute on function public.teacher_end_session(uuid) to authenticated;


create or replace function public.parent_dashboard()
returns jsonb
language sql
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'children',coalesce(jsonb_agg(child_data),'[]'::jsonb)
  )
  from (
    select jsonb_build_object(
      'student_id',s.id,
      'student_code',s.student_code,
      'name_ar',s.full_name,
      'name_en',s.full_name_en,
      'curriculum_en',c.name_en,
      'curriculum_ar',c.name_ar,
      'grade_en',gl.name_en,
      'grade_ar',gl.name_ar,
      'latest_report',(
        select jsonb_build_object(
          'period_name',pr.period_name,
          'attendance',pr.attendance_percent,
          'homework',pr.homework_completion_percent,
          'assessment',pr.assessment_average,
          'overall',pr.overall_progress_percent,
          'strengths',pr.strengths,
          'improvement',pr.areas_for_improvement,
          'recommendation',pr.teacher_recommendation
        )
        from public.progress_reports pr
        where pr.student_id=s.id and pr.published=true
        order by pr.report_date desc
        limit 1
      ),
      'balance',(
        select coalesce(sum(i.total_amount-i.amount_paid),0)
        from public.invoices i
        where i.student_id=s.id and i.status in ('due','partial')
      )
    ) child_data
    from public.guardians g
    join public.student_guardians sg on sg.guardian_id=g.id
    join public.students s on s.id=sg.student_id
    left join public.curricula c on c.id=s.current_curriculum_id
    left join public.grade_levels gl on gl.id=s.current_grade_level_id
    where g.auth_user_id=auth.uid()
  ) q;
$$;

grant execute on function public.parent_dashboard() to authenticated;

-- ============================================================
-- 12) FINANCE WORKSPACE
-- ============================================================

create or replace function public.finance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('finance.view') then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'pending_claims',(select count(*) from public.payment_claims where status='pending'),
    'due_invoices',(select count(*) from public.invoices where status in ('due','partial')),
    'outstanding_amount',(select coalesce(sum(total_amount-amount_paid),0) from public.invoices where status in ('due','partial')),
    'verified_payments',(select count(*) from public.payments where status='verified'),
    'receipts',(select count(*) from public.receipts)
  );
end;
$$;

create or replace function public.finance_pending_claims()
returns table(
  claim_id uuid,
  student_id uuid,
  student_code text,
  student_name text,
  invoice_id uuid,
  invoice_number text,
  enrollment_id uuid,
  amount numeric,
  currency text,
  method text,
  transaction_reference text,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('finance.view') then
    raise exception 'not authorized';
  end if;

  return query
  select
    pc.id,s.id,s.student_code,coalesce(s.full_name_en,s.full_name),
    i.id,i.invoice_number,i.enrollment_id,
    pc.amount,pc.currency,pc.method,pc.transaction_reference,pc.submitted_at
  from public.payment_claims pc
  join public.students s on s.id=pc.student_id
  left join public.invoices i on i.id=pc.invoice_id
  where pc.status='pending'
  order by pc.submitted_at;
end;
$$;

create or replace function public.finance_verify_claim(p_claim_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_claim public.payment_claims%rowtype;
  v_invoice public.invoices%rowtype;
  v_payment_id uuid;
  v_method text;
begin
  if not public.has_permission('finance.verify') then
    raise exception 'not authorized';
  end if;

  select * into v_claim
  from public.payment_claims
  where id=p_claim_id
    and status='pending'
  for update;

  if v_claim.id is null then
    raise exception 'payment claim not found or already reviewed';
  end if;

  if v_claim.invoice_id is not null then
    select * into v_invoice
    from public.invoices
    where id=v_claim.invoice_id;
  end if;

  v_method := case
    when v_claim.method in ('instapay','vodafone_cash','bank_transfer','card','cash','other')
      then v_claim.method
    else 'other'
  end;

  insert into public.payments(
    student_id,enrollment_id,invoice_id,amount,currency,method,
    transaction_reference,status,paid_at,verified_at,notes
  )
  values(
    v_claim.student_id,v_invoice.enrollment_id,v_claim.invoice_id,
    v_claim.amount,v_claim.currency,v_method,
    v_claim.transaction_reference,'verified',now(),now(),
    'Verified from submitted payment claim'
  )
  returning id into v_payment_id;

  update public.payment_claims
  set status='verified',
      reviewed_at=now(),
      reviewed_by_staff_id=public.current_staff_id()
  where id=v_claim.id;

  if v_invoice.enrollment_id is not null then
    update public.enrollments e
    set payment_status=case
          when (select status from public.invoices where id=v_invoice.id)='paid' then 'paid'
          else e.payment_status
        end,
        access_enabled=case
          when (select status from public.invoices where id=v_invoice.id)='paid' then true
          else e.access_enabled
        end,
        status=case
          when (select status from public.invoices where id=v_invoice.id)='paid' then 'active'
          else e.status
        end
    where e.id=v_invoice.enrollment_id;
  end if;

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'payment_claim_verified','payment_claim',v_claim.id::text,
    jsonb_build_object('payment_id',v_payment_id,'amount',v_claim.amount)
  );

  return jsonb_build_object('success',true,'payment_id',v_payment_id);
end;
$$;

grant execute on function public.finance_overview() to authenticated;
grant execute on function public.finance_pending_claims() to authenticated;
grant execute on function public.finance_verify_claim(uuid) to authenticated;

-- Backfill receipts for verified payments created before the automatic receipt trigger existed.
insert into public.receipts(
  receipt_number,payment_id,student_id,invoice_id,amount,currency
)
select
  'JBE-RCP-'||to_char(coalesce(p.verified_at,p.paid_at,now()),'YYYY')||'-'||
    lpad(nextval('public.receipt_number_seq')::text,6,'0'),
  p.id,p.student_id,p.invoice_id,p.amount,p.currency
from public.payments p
where p.status='verified'
  and not exists(select 1 from public.receipts r where r.payment_id=p.id)
on conflict(payment_id) do nothing;

-- ============================================================
-- 13) STUDENT AFFAIRS / DATA QUALITY
-- ============================================================

create or replace function public.student_affairs_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('students.view') then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'active_students',(select count(*) from public.students where status='active'),
    'without_guardian',(
      select count(*)
      from public.students s
      where s.status='active'
        and not exists(select 1 from public.student_guardians sg where sg.student_id=s.id)
    ),
    'active_without_group',(
      select count(*)
      from public.enrollments e
      where e.status='active'
        and e.group_id is null
    ),
    'pending_enrollments',(select count(*) from public.enrollments where status='pending')
  );
end;
$$;

create or replace function public.student_affairs_issues()
returns table(
  issue_type text,
  student_id uuid,
  student_code text,
  student_name text,
  details text
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('students.view') then
    raise exception 'not authorized';
  end if;

  return query
  select
    'missing_guardian',s.id,s.student_code,coalesce(s.full_name_en,s.full_name),
    'No guardian is linked'
  from public.students s
  where s.status='active'
    and not exists(select 1 from public.student_guardians sg where sg.student_id=s.id)

  union all

  select
    'active_enrollment_without_group',s.id,s.student_code,coalesce(s.full_name_en,s.full_name),
    co.title_en
  from public.enrollments e
  join public.students s on s.id=e.student_id
  join public.courses co on co.id=e.course_id
  where e.status='active'
    and e.group_id is null;
end;
$$;

grant execute on function public.student_affairs_overview() to authenticated;
grant execute on function public.student_affairs_issues() to authenticated;

create or replace function public.student_affairs_unassigned_enrollments()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.has_permission('students.manage') then
    raise exception 'not authorized';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'enrollment_id',e.id,
      'student_id',s.id,
      'student_code',s.student_code,
      'student_name',coalesce(s.full_name_en,s.full_name),
      'course_id',co.id,
      'course_title',co.title_en,
      'groups',coalesce((
        select jsonb_agg(jsonb_build_object(
          'group_id',cg.id,
          'group_name',cg.name,
          'capacity',cg.capacity,
          'active_students',(
            select count(*) from public.group_members gm
            where gm.group_id=cg.id and gm.status='active'
          )
        ) order by cg.name)
        from public.class_groups cg
        where cg.course_id=co.id
          and cg.status in ('open','active')
      ),'[]'::jsonb)
    ) order by s.student_code)
    from public.enrollments e
    join public.students s on s.id=e.student_id
    join public.courses co on co.id=e.course_id
    where e.group_id is null
      and e.status in ('pending','active')
  ),'[]'::jsonb);
end;
$$;

create or replace function public.student_affairs_assign_group(
  p_enrollment_id uuid,
  p_group_id uuid
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_course_id uuid;
  v_group_course uuid;
  v_capacity int;
  v_count int;
begin
  if not public.has_permission('students.manage') then
    raise exception 'not authorized';
  end if;

  select course_id into v_course_id
  from public.enrollments
  where id=p_enrollment_id;

  select course_id,capacity into v_group_course,v_capacity
  from public.class_groups
  where id=p_group_id
    and status in ('open','active');

  if v_course_id is null or v_group_course is null then
    raise exception 'enrollment or group not found';
  end if;

  if v_course_id<>v_group_course then
    raise exception 'group belongs to a different course';
  end if;

  select count(*) into v_count
  from public.group_members
  where group_id=p_group_id
    and status='active';

  if v_capacity is not null and v_count>=v_capacity then
    raise exception 'group is full';
  end if;

  update public.enrollments
  set group_id=p_group_id
  where id=p_enrollment_id;

  insert into public.group_members(group_id,enrollment_id,status)
  values(p_group_id,p_enrollment_id,'active')
  on conflict(enrollment_id) do update
  set group_id=excluded.group_id,
      status='active';

  insert into public.audit_log(actor_user_id,action,entity_type,entity_id,details)
  values(
    auth.uid(),'enrollment_group_assigned','enrollment',p_enrollment_id::text,
    jsonb_build_object('group_id',p_group_id)
  );

  return true;
end;
$$;

grant execute on function public.student_affairs_unassigned_enrollments() to authenticated;
grant execute on function public.student_affairs_assign_group(uuid,uuid) to authenticated;

-- ============================================================
-- 14) GROUP MANAGEMENT
-- ============================================================

create sequence if not exists public.group_code_seq start 1001;

create or replace function public.staff_teacher_options()
returns table(teacher_id uuid,display_name text)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_permission('groups.manage') then
    raise exception 'not authorized';
  end if;

  return query
  select tp.id,tp.display_name
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.is_active=true
  order by tp.display_name;
end;
$$;

create or replace function public.staff_groups_list()
returns table(
  group_id uuid,
  group_code text,
  group_name text,
  course_id uuid,
  course_title text,
  teacher_id uuid,
  teacher_name text,
  capacity int,
  recurring_weekday int,
  recurring_start_time time,
  default_duration_minutes int,
  timezone text,
  status text,
  active_students bigint
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not (
    public.has_permission('groups.manage')
    or public.has_permission('teacher.workspace')
  ) then
    raise exception 'not authorized';
  end if;

  return query
  select
    cg.id,cg.code,cg.name,co.id,co.title_en,tp.id,tp.display_name,
    cg.capacity,cg.recurring_weekday,cg.recurring_start_time,
    cg.default_duration_minutes,cg.timezone,cg.status,
    (
      select count(*)
      from public.group_members gm
      where gm.group_id=cg.id and gm.status='active'
    )
  from public.class_groups cg
  join public.courses co on co.id=cg.course_id
  left join public.teacher_profiles tp on tp.id=coalesce(cg.teacher_id,co.teacher_id)
  where
    public.has_permission('groups.manage')
    or exists(
      select 1
      from public.teacher_profiles mytp
      join public.staff mys on mys.id=mytp.staff_id
      where mys.auth_user_id=auth.uid()
        and mytp.id=coalesce(cg.teacher_id,co.teacher_id)
    )
  order by cg.created_at desc;
end;
$$;

create or replace function public.staff_create_group(
  p_course_id uuid,
  p_teacher_id uuid,
  p_name text,
  p_capacity int,
  p_weekday int,
  p_start_time time,
  p_duration_minutes int,
  p_timezone text
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_code text;
begin
  if not public.has_permission('groups.manage') then
    raise exception 'not authorized';
  end if;

  if p_weekday<0 or p_weekday>6 then
    raise exception 'weekday must be 0 to 6';
  end if;

  v_code := 'JBE-GRP-'||to_char(now(),'YY')||'-'||lpad(nextval('public.group_code_seq')::text,5,'0');

  insert into public.class_groups(
    course_id,teacher_id,code,name,capacity,timezone,
    recurring_weekday,recurring_start_time,default_duration_minutes,status
  )
  values(
    p_course_id,p_teacher_id,v_code,p_name,p_capacity,
    coalesce(nullif(p_timezone,''),'Africa/Cairo'),
    p_weekday,p_start_time,coalesce(p_duration_minutes,60),'open'
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.admin_generate_weekly_sessions(
  p_group_id uuid,
  p_start_date date,
  p_end_date date
)
returns int
language plpgsql
security definer
set search_path=public
as $$
declare
  g public.class_groups%rowtype;
  d date;
  v_count int := 0;
  v_session_ts timestamptz;
begin
  if not public.has_permission('groups.manage') then
    raise exception 'not authorized';
  end if;

  if p_end_date<p_start_date then
    raise exception 'end date must be on or after start date';
  end if;

  select * into g from public.class_groups where id=p_group_id;

  if g.id is null then raise exception 'group not found'; end if;
  if g.recurring_weekday is null or g.recurring_start_time is null then
    raise exception 'group recurring schedule is incomplete';
  end if;

  d:=p_start_date;

  while d<=p_end_date loop
    if extract(dow from d)::int=g.recurring_weekday then
      v_session_ts := (d::text||' '||g.recurring_start_time::text)::timestamp at time zone g.timezone;

      if not exists(
        select 1 from public.class_sessions
        where group_id=g.id and session_date=v_session_ts
      ) then
        insert into public.class_sessions(
          course_id,group_id,title,session_date,session_type,planned_duration_minutes
        )
        values(
          g.course_id,g.id,g.name||' - '||to_char(d,'YYYY-MM-DD'),
          v_session_ts,'live',g.default_duration_minutes
        );
        v_count:=v_count+1;
      end if;
    end if;
    d:=d+1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.staff_teacher_options() to authenticated;
grant execute on function public.staff_groups_list() to authenticated;
grant execute on function public.staff_create_group(uuid,uuid,text,int,int,time,int,text) to authenticated;
grant execute on function public.admin_generate_weekly_sessions(uuid,date,date) to authenticated;

-- ============================================================
-- 15) OWNER ACTION CENTER / SEARCH / AUDIT
-- ============================================================

create or replace function public.owner_action_center()
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  return jsonb_build_object(
    'new_applications',(select count(*) from public.applications where application_status in ('pending','under_review')),
    'followups_due',(select count(*) from public.applications where next_follow_up_at is not null and next_follow_up_at<=now() and sales_status not in ('won','lost')),
    'pending_payment_claims',(select count(*) from public.payment_claims where status='pending'),
    'pending_teacher_offerings',(select count(*) from public.teacher_offerings where approval_status='pending'),
    'students_missing_guardian',(
      select count(*)
      from public.students s
      where s.status='active'
        and not exists(select 1 from public.student_guardians sg where sg.student_id=s.id)
    ),
    'active_enrollments_without_group',(select count(*) from public.enrollments where status='active' and group_id is null),
    'courses_without_teacher',(select count(*) from public.courses where status in ('open','active') and teacher_id is null),
    'verified_payments_without_receipt',(
      select count(*)
      from public.payments p
      where p.status='verified'
        and not exists(select 1 from public.receipts r where r.payment_id=p.id)
    )
  );
end;
$$;

create or replace function public.owner_global_search(p_query text)
returns jsonb
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  q text := '%'||lower(trim(p_query))||'%';
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  if length(trim(p_query))<2 then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(x order by x->>'type',x->>'title')
    from (
      select jsonb_build_object(
        'type','student','id',s.id,'title',coalesce(s.full_name_en,s.full_name),
        'subtitle',coalesce(s.student_code,'')||' • '||coalesce(s.phone,''),
        'url','student-manage.html?id='||s.id::text
      ) x
      from public.students s
      where lower(coalesce(s.full_name,'')) like q
         or lower(coalesce(s.full_name_en,'')) like q
         or lower(coalesce(s.student_code,'')) like q
         or lower(coalesce(s.phone,'')) like q

      union all

      select jsonb_build_object(
        'type','application','id',a.id,'title',a.student_name,
        'subtitle',coalesce(a.application_code,'')||' • '||coalesce(a.student_phone,a.guardian_phone,''),
        'url','sales-crm.html'
      )
      from public.applications a
      where lower(coalesce(a.student_name,'')) like q
         or lower(coalesce(a.application_code,'')) like q
         or lower(coalesce(a.student_phone,'')) like q
         or lower(coalesce(a.guardian_phone,'')) like q

      union all

      select jsonb_build_object(
        'type','guardian','id',g.id,'title',g.full_name,
        'subtitle',coalesce(g.phone,''),
        'url','student-affairs.html'
      )
      from public.guardians g
      where lower(coalesce(g.full_name,'')) like q
         or lower(coalesce(g.phone,'')) like q
    ) s
  ),'[]'::jsonb);
end;
$$;

create or replace function public.owner_audit_log(p_limit int default 100)
returns table(
  created_at timestamptz,
  actor_email text,
  action text,
  entity_type text,
  entity_id text,
  details jsonb
)
language plpgsql
stable
security definer
set search_path=public
as $$
begin
  if not public.is_platform_owner() then
    raise exception 'owner only';
  end if;

  return query
  select
    al.created_at,
    u.email,
    al.action,
    al.entity_type,
    al.entity_id,
    al.details
  from public.audit_log al
  left join auth.users u on u.id=al.actor_user_id
  order by al.created_at desc
  limit greatest(1,least(coalesce(p_limit,100),500));
end;
$$;

grant execute on function public.owner_action_center() to authenticated;
grant execute on function public.owner_global_search(text) to authenticated;
grant execute on function public.owner_audit_log(int) to authenticated;

-- ============================================================
-- 16) RLS ON NEW ACCESS TABLES
-- Direct browser access is intentionally blocked; RPCs are the interface.
-- ============================================================

alter table public.platform_ownership enable row level security;
alter table public.staff_roles enable row level security;
alter table public.app_permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.staff_permission_overrides enable row level security;
alter table public.staff_scopes enable row level security;
alter table public.staff_invites enable row level security;

-- Owner may read permission catalog directly for UI if needed.
drop policy if exists owner_read_permissions on public.app_permissions;
create policy owner_read_permissions
on public.app_permissions
for select to authenticated
using(public.is_platform_owner());

grant select on public.app_permissions to authenticated;

commit;

select 'JBE Academy V2.5 operations + access control loaded' as result;
