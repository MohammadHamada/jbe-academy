
-- ============================================================
-- JBE ACADEMY MASTER PLATFORM V2
-- Multi-role / Multi-teacher / Registration / Billing / Groups
-- Sessions / Parent / Sales / Automation foundation
-- Designed to run AFTER the existing V1–V1.8 schema.
-- Idempotent where practical.
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- A) ROLE MODEL
-- ============================================================

-- Expand staff roles from V1.7.
alter table if exists public.staff
  drop constraint if exists staff_role_check;

alter table if exists public.staff
  add constraint staff_role_check
  check (role in ('super_admin','admin','teacher','sales'));

create or replace function public.has_staff_role(p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.staff s
    where s.auth_user_id = auth.uid()
      and s.is_active = true
      and s.role = any(p_roles)
  );
$$;

grant execute on function public.has_staff_role(text[]) to authenticated;

-- ============================================================
-- B) ACADEMIC STRUCTURE
-- Education System -> Curriculum -> Stage -> Grade
-- ============================================================

create table if not exists public.academic_stages (
  id uuid primary key default gen_random_uuid(),
  education_system_id uuid not null references public.education_systems(id) on delete cascade,
  code text not null,
  name_en text not null,
  name_ar text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  unique(education_system_id, code)
);

alter table public.grade_levels
  add column if not exists stage_id uuid references public.academic_stages(id);

-- National stages requested for JBE Academy.
insert into public.academic_stages(education_system_id,code,name_en,name_ar,sort_order)
select id,'PRIMARY','Primary Stage','المرحلة الابتدائية',10
from public.education_systems where code='NATIONAL'
on conflict(education_system_id,code) do update
set name_en=excluded.name_en,name_ar=excluded.name_ar,sort_order=excluded.sort_order;

insert into public.academic_stages(education_system_id,code,name_en,name_ar,sort_order)
select id,'PREPARATORY','Preparatory Stage','المرحلة الإعدادية',20
from public.education_systems where code='NATIONAL'
on conflict(education_system_id,code) do update
set name_en=excluded.name_en,name_ar=excluded.name_ar,sort_order=excluded.sort_order;

insert into public.academic_stages(education_system_id,code,name_en,name_ar,sort_order)
select id,'SECONDARY','Secondary Stage','المرحلة الثانوية',30
from public.education_systems where code='NATIONAL'
on conflict(education_system_id,code) do update
set name_en=excluded.name_en,name_ar=excluded.name_ar,sort_order=excluded.sort_order;

insert into public.academic_stages(education_system_id,code,name_en,name_ar,sort_order)
select id,'BACCALAUREATE','Egyptian Baccalaureate','البكالوريا المصرية',40
from public.education_systems where code='NATIONAL'
on conflict(education_system_id,code) do update
set name_en=excluded.name_en,name_ar=excluded.name_ar,sort_order=excluded.sort_order;

-- Add local Grades 4-8 if missing, and ensure Grade 9 belongs to Preparatory.
do $$
declare
  v_curr uuid;
  v_primary uuid;
  v_prep uuid;
  v_secondary uuid;
begin
  select id into v_curr from public.curricula where code='EGYPT_NATIONAL_EN';
  if v_curr is not null then
    select id into v_primary from public.academic_stages
      where education_system_id=(select education_system_id from public.curricula where id=v_curr)
        and code='PRIMARY';
    select id into v_prep from public.academic_stages
      where education_system_id=(select education_system_id from public.curricula where id=v_curr)
        and code='PREPARATORY';
    select id into v_secondary from public.academic_stages
      where education_system_id=(select education_system_id from public.curricula where id=v_curr)
        and code='SECONDARY';

    insert into public.grade_levels(curriculum_id,stage_id,grade_number,code,name_en,name_ar,sort_order,is_active)
    values
      (v_curr,v_primary,4,'G4','Grade 4','الصف الرابع',4,true),
      (v_curr,v_primary,5,'G5','Grade 5','الصف الخامس',5,true),
      (v_curr,v_primary,6,'G6','Grade 6','الصف السادس',6,true),
      (v_curr,v_prep,7,'G7','Grade 7','الصف السابع / الأول الإعدادي',7,true),
      (v_curr,v_prep,8,'G8','Grade 8','الصف الثامن / الثاني الإعدادي',8,true)
    on conflict(curriculum_id,code) do update
      set stage_id=excluded.stage_id,
          grade_number=excluded.grade_number,
          name_en=excluded.name_en,
          name_ar=excluded.name_ar,
          sort_order=excluded.sort_order,
          is_active=true;

    update public.grade_levels set stage_id=v_prep
    where curriculum_id=v_curr and code='G9';

    update public.grade_levels set stage_id=v_secondary
    where curriculum_id=v_curr and code='G10';
  end if;
end $$;

-- ============================================================
-- C) TEACHERS & PUBLIC TEACHER PROFILES
-- ============================================================

create table if not exists public.teacher_profiles (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null unique references public.staff(id) on delete cascade,
  slug text not null unique,
  display_name text not null,
  display_name_ar text,
  headline_en text,
  headline_ar text,
  bio_en text,
  bio_ar text,
  photo_url text,
  years_experience int,
  country_code text default 'EG',
  is_verified boolean not null default false,
  is_public boolean not null default false,
  rating_average numeric(3,2),
  rating_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.teacher_offerings (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teacher_profiles(id) on delete cascade,
  curriculum_id uuid not null references public.curricula(id),
  grade_level_id uuid not null references public.grade_levels(id),
  subject_id uuid not null references public.subjects(id),
  study_mode text not null default 'group'
    check(study_mode in ('group','private','recorded','hybrid')),
  billing_type text not null default 'fixed_session'
    check(billing_type in ('fixed_session','hourly','monthly','term','package')),
  teacher_price numeric(12,2) not null default 0,
  currency text not null default 'EGP',
  duration_minutes int,
  capacity int,
  approval_status text not null default 'draft'
    check(approval_status in ('draft','pending','approved','rejected','archived')),
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.pricing_policies (
  id uuid primary key default gen_random_uuid(),
  curriculum_id uuid references public.curricula(id),
  grade_level_id uuid references public.grade_levels(id),
  subject_id uuid references public.subjects(id),
  study_mode text,
  minimum_price numeric(12,2),
  recommended_price numeric(12,2),
  maximum_price numeric(12,2),
  currency text not null default 'EGP',
  platform_fee_percent numeric(5,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.courses
  add column if not exists teacher_id uuid references public.teacher_profiles(id),
  add column if not exists approval_status text default 'approved',
  add column if not exists study_mode text default 'group',
  add column if not exists billing_type text default 'fixed_session',
  add column if not exists teacher_price numeric(12,2),
  add column if not exists public_price numeric(12,2),
  add column if not exists session_duration_minutes int;

-- ============================================================
-- D) PUBLIC APPLICATIONS / ADMISSIONS / SALES
-- ============================================================

create sequence if not exists public.application_code_seq start 1001;

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  application_code text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  student_name text not null,
  student_name_en text,
  student_phone text,
  student_email text,
  date_of_birth date,

  guardian_name text,
  guardian_phone text,
  guardian_email text,
  relationship text,

  education_system_id uuid references public.education_systems(id),
  curriculum_id uuid references public.curricula(id),
  stage_id uuid references public.academic_stages(id),
  grade_level_id uuid references public.grade_levels(id),
  subject_id uuid references public.subjects(id),
  preferred_teacher_id uuid references public.teacher_profiles(id),
  preferred_offering_id uuid references public.teacher_offerings(id),

  source text default 'website',
  preferred_contact text default 'whatsapp',
  notes text,

  sales_status text not null default 'new'
    check(sales_status in ('new','contacted','follow_up','trial','won','lost')),
  application_status text not null default 'pending'
    check(application_status in ('pending','under_review','approved','rejected','converted')),

  assigned_sales_staff_id uuid references public.staff(id),
  next_follow_up_at timestamptz,
  last_contact_at timestamptz,
  sales_notes text,

  created_student_id uuid references public.students(id),
  converted_at timestamptz
);

create index if not exists idx_applications_status
  on public.applications(application_status,sales_status,created_at desc);

create or replace function public.public_registration_options()
returns jsonb
language sql
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'education_systems',
      coalesce((
        select jsonb_agg(jsonb_build_object('id',id,'code',code,'name_en',name_en,'name_ar',name_ar) order by name_en)
        from public.education_systems
      ),'[]'::jsonb),
    'curricula',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',c.id,'education_system_id',c.education_system_id,'code',c.code,'name_en',c.name_en,'name_ar',c.name_ar
        ) order by c.name_en)
        from public.curricula c where c.is_active=true
      ),'[]'::jsonb),
    'stages',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',s.id,'education_system_id',s.education_system_id,'code',s.code,'name_en',s.name_en,'name_ar',s.name_ar
        ) order by s.sort_order)
        from public.academic_stages s where s.is_active=true
      ),'[]'::jsonb),
    'grades',
      coalesce((
        select jsonb_agg(jsonb_build_object(
          'id',g.id,'curriculum_id',g.curriculum_id,'stage_id',g.stage_id,'code',g.code,'name_en',g.name_en,'name_ar',g.name_ar,'sort_order',g.sort_order
        ) order by g.sort_order)
        from public.grade_levels g where g.is_active=true
      ),'[]'::jsonb),
    'subjects',
      coalesce((
        select jsonb_agg(jsonb_build_object('id',id,'code',code,'name_en',name_en,'name_ar',name_ar) order by name_en)
        from public.subjects where is_active=true
      ),'[]'::jsonb),
    'teachers',
      coalesce((
        select jsonb_agg(jsonb_build_object('id',id,'slug',slug,'display_name',display_name,'headline_en',headline_en,'photo_url',photo_url))
        from public.teacher_profiles where is_public=true and is_verified=true
      ),'[]'::jsonb)
  );
$$;

grant execute on function public.public_registration_options() to anon, authenticated;

create or replace function public.public_submit_application(
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

  v_code := 'JBE-APP-' || to_char(now(),'YY') || '-' ||
            lpad(nextval('public.application_code_seq')::text,5,'0');

  insert into public.applications(
    application_code,student_name,student_name_en,student_phone,student_email,
    guardian_name,guardian_phone,guardian_email,relationship,
    education_system_id,curriculum_id,stage_id,grade_level_id,subject_id,
    preferred_teacher_id,source,notes
  ) values(
    v_code,p_student_name,nullif(p_student_name_en,''),nullif(p_student_phone,''),nullif(p_student_email,''),
    nullif(p_guardian_name,''),nullif(p_guardian_phone,''),nullif(p_guardian_email,''),nullif(p_relationship,''),
    p_education_system_id,p_curriculum_id,p_stage_id,p_grade_level_id,p_subject_id,
    p_preferred_teacher_id,coalesce(nullif(p_source,''),'website'),nullif(p_notes,'')
  )
  returning id into v_id;

  return jsonb_build_object('success',true,'application_id',v_id,'application_code',v_code);
end;
$$;

grant execute on function public.public_submit_application(
  text,text,text,text,text,text,text,text,uuid,uuid,uuid,uuid,uuid,uuid,text,text
) to anon,authenticated;

-- ============================================================
-- E) GROUPS, SCHEDULING & SESSION BILLING
-- ============================================================

create table if not exists public.class_groups (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  teacher_id uuid references public.teacher_profiles(id),
  code text not null unique,
  name text not null,
  capacity int,
  timezone text not null default 'Africa/Cairo',
  recurring_weekday int check(recurring_weekday between 0 and 6),
  recurring_start_time time,
  default_duration_minutes int not null default 60,
  status text not null default 'active'
    check(status in ('draft','open','active','completed','archived')),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.class_groups(id) on delete cascade,
  enrollment_id uuid not null unique references public.enrollments(id) on delete cascade,
  joined_at timestamptz not null default now(),
  status text not null default 'active'
    check(status in ('active','paused','completed','left')),
  primary key(group_id,enrollment_id)
);

alter table public.class_sessions
  add column if not exists group_id uuid references public.class_groups(id),
  add column if not exists planned_duration_minutes int,
  add column if not exists actual_start_at timestamptz,
  add column if not exists actual_end_at timestamptz,
  add column if not exists actual_duration_minutes int,
  add column if not exists billing_finalized boolean not null default false;

alter table public.enrollments
  add column if not exists group_id uuid references public.class_groups(id);

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
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  select * into g from public.class_groups where id=p_group_id;
  if g.id is null then raise exception 'group not found'; end if;
  if g.recurring_weekday is null or g.recurring_start_time is null then
    raise exception 'group recurring schedule is incomplete';
  end if;

  d := p_start_date;
  while d <= p_end_date loop
    if extract(dow from d)::int = g.recurring_weekday then
      v_session_ts := (d::text || ' ' || g.recurring_start_time::text)::timestamp
                      at time zone g.timezone;

      insert into public.class_sessions(
        course_id,group_id,title,session_date,session_type,planned_duration_minutes
      )
      values(
        g.course_id,g.id,g.name || ' - ' || to_char(d,'YYYY-MM-DD'),
        v_session_ts,'live',g.default_duration_minutes
      )
      on conflict do nothing;

      v_count := v_count + 1;
    end if;
    d := d + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.admin_generate_weekly_sessions(uuid,date,date) to authenticated;

-- ============================================================
-- F) LEARNING ACTIVITIES / HOMEWORK / QUIZZES
-- ============================================================

create table if not exists public.learning_activities (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  group_id uuid references public.class_groups(id) on delete cascade,
  session_id uuid references public.class_sessions(id) on delete set null,
  activity_type text not null
    check(activity_type in ('lesson','homework','quiz','exam','project','resource')),
  title text not null,
  description text,
  resource_url text,
  due_at timestamptz,
  max_score numeric(8,2),
  is_published boolean not null default false,
  created_by_staff_id uuid references public.staff(id),
  created_at timestamptz not null default now()
);

create table if not exists public.activity_submissions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.learning_activities(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  submission_url text,
  submission_text text,
  submitted_at timestamptz,
  status text not null default 'not_started'
    check(status in ('not_started','submitted','late','reviewed','missing')),
  score numeric(8,2),
  feedback text,
  reviewed_at timestamptz,
  unique(activity_id,student_id)
);

-- ============================================================
-- G) BILLING / INVOICES / PAYMENT CLAIMS / RECEIPTS
-- ============================================================

create sequence if not exists public.invoice_number_seq start 1001;
create sequence if not exists public.receipt_number_seq start 1001;

create table if not exists public.billing_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  billing_type text not null
    check(billing_type in ('fixed_session','hourly','monthly','term','package')),
  amount numeric(12,2) not null,
  currency text not null default 'EGP',
  included_sessions int,
  included_minutes int,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  student_id uuid not null references public.students(id) on delete cascade,
  enrollment_id uuid references public.enrollments(id) on delete set null,
  status text not null default 'due'
    check(status in ('draft','due','partial','paid','cancelled','refunded')),
  currency text not null default 'EGP',
  total_amount numeric(12,2) not null default 0,
  amount_paid numeric(12,2) not null default 0,
  due_date date,
  issued_at timestamptz not null default now(),
  notes text
);

create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  session_id uuid references public.class_sessions(id) on delete set null,
  description text not null,
  quantity numeric(10,2) not null default 1,
  unit_price numeric(12,2) not null default 0,
  amount numeric(12,2) not null default 0
);

alter table public.payments
  add column if not exists invoice_id uuid references public.invoices(id) on delete set null;

create table if not exists public.payment_claims (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid references public.invoices(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  amount numeric(12,2) not null,
  currency text not null default 'EGP',
  method text not null,
  transaction_reference text,
  proof_url text,
  status text not null default 'pending'
    check(status in ('pending','verified','rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by_staff_id uuid references public.staff(id)
);

create table if not exists public.receipts (
  id uuid primary key default gen_random_uuid(),
  receipt_number text not null unique,
  payment_id uuid not null unique references public.payments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  amount numeric(12,2) not null,
  currency text not null default 'EGP',
  issued_at timestamptz not null default now()
);

create or replace function public.jbe_auto_receipt()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_receipt text;
begin
  if new.status='verified' and (tg_op='INSERT' or old.status is distinct from new.status) then
    v_receipt := 'JBE-RCP-' || to_char(now(),'YYYY') || '-' ||
                 lpad(nextval('public.receipt_number_seq')::text,6,'0');

    insert into public.receipts(
      receipt_number,payment_id,student_id,invoice_id,amount,currency
    )
    values(v_receipt,new.id,new.student_id,new.invoice_id,new.amount,new.currency)
    on conflict(payment_id) do nothing;

    if new.invoice_id is not null then
      update public.invoices i
      set amount_paid = (
            select coalesce(sum(p.amount),0)
            from public.payments p
            where p.invoice_id=i.id and p.status='verified'
          ),
          status = case
            when (
              select coalesce(sum(p.amount),0)
              from public.payments p
              where p.invoice_id=i.id and p.status='verified'
            ) >= i.total_amount then 'paid'
            when (
              select coalesce(sum(p.amount),0)
              from public.payments p
              where p.invoice_id=i.id and p.status='verified'
            ) > 0 then 'partial'
            else 'due'
          end
      where i.id=new.invoice_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_jbe_auto_receipt on public.payments;
create trigger trg_jbe_auto_receipt
after insert or update of status on public.payments
for each row execute function public.jbe_auto_receipt();

-- Fixed session vs hourly billing.
create or replace function public.admin_finalize_session_billing(
  p_session_id uuid,
  p_actual_start timestamptz,
  p_actual_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_minutes int;
  v_course public.courses%rowtype;
  v_group_id uuid;
  r record;
  v_amount numeric(12,2);
  v_invoice_id uuid;
  v_invoice_no text;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  if p_actual_end <= p_actual_start then
    raise exception 'end time must be after start time';
  end if;

  v_minutes := ceil(extract(epoch from (p_actual_end-p_actual_start))/60.0);

  select co.*,cs.group_id
  into v_course,v_group_id
  from public.class_sessions cs
  join public.courses co on co.id=cs.course_id
  where cs.id=p_session_id;

  if v_course.id is null then raise exception 'session not found'; end if;

  update public.class_sessions
  set actual_start_at=p_actual_start,
      actual_end_at=p_actual_end,
      actual_duration_minutes=v_minutes,
      billing_finalized=true
  where id=p_session_id;

  -- Monthly/term/package: session creates no new charge.
  if v_course.billing_type in ('monthly','term','package') then
    return jsonb_build_object('minutes',v_minutes,'billing_type',v_course.billing_type,'charge_created',false);
  end if;

  for r in
    select e.id enrollment_id,e.student_id
    from public.enrollments e
    left join public.group_members gm on gm.enrollment_id=e.id
    where e.status='active'
      and (
        (v_group_id is not null and gm.group_id=v_group_id)
        or (v_group_id is null and e.course_id=v_course.id)
      )
  loop
    if v_course.billing_type='hourly' then
      v_amount := round(coalesce(v_course.public_price,v_course.price_egp,0) * v_minutes / 60.0,2);
    else
      -- fixed_session: price never increases because the class ran longer.
      v_amount := coalesce(v_course.public_price,v_course.price_egp,0);
    end if;

    v_invoice_no := 'JBE-INV-' || to_char(now(),'YYYY') || '-' ||
                    lpad(nextval('public.invoice_number_seq')::text,6,'0');

    insert into public.invoices(
      invoice_number,student_id,enrollment_id,status,currency,total_amount,due_date
    )
    values(v_invoice_no,r.student_id,r.enrollment_id,'due','EGP',v_amount,current_date)
    returning id into v_invoice_id;

    insert into public.invoice_items(
      invoice_id,session_id,description,quantity,unit_price,amount
    )
    values(
      v_invoice_id,p_session_id,
      case when v_course.billing_type='hourly'
        then 'Hourly session - ' || v_minutes || ' minutes'
        else 'Fixed session'
      end,
      case when v_course.billing_type='hourly' then v_minutes/60.0 else 1 end,
      case when v_course.billing_type='hourly'
        then coalesce(v_course.public_price,v_course.price_egp,0)
        else v_amount
      end,
      v_amount
    );
  end loop;

  return jsonb_build_object(
    'minutes',v_minutes,
    'billing_type',v_course.billing_type,
    'charge_created',true
  );
end;
$$;

grant execute on function public.admin_finalize_session_billing(uuid,timestamptz,timestamptz)
to authenticated;

-- ============================================================
-- H) PARENT ACCOUNTS
-- ============================================================

alter table public.guardians
  add column if not exists auth_user_id uuid unique;

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
      'name',coalesce(s.full_name_en,s.full_name),
      'grade',gl.name_en,
      'curriculum',c.name_en,
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
-- I) ADMIN / SALES APPLICATION OPERATIONS
-- ============================================================

create or replace function public.staff_list_applications()
returns table(
  id uuid,
  application_code text,
  created_at timestamptz,
  student_name text,
  contact_phone text,
  curriculum text,
  grade text,
  subject text,
  sales_status text,
  application_status text,
  next_follow_up_at timestamptz
)
language sql
security definer
set search_path=public
as $$
  select
    a.id,a.application_code,a.created_at,a.student_name,
    coalesce(a.student_phone,a.guardian_phone),
    c.name_en,g.name_en,su.name_en,
    a.sales_status,a.application_status,a.next_follow_up_at
  from public.applications a
  left join public.curricula c on c.id=a.curriculum_id
  left join public.grade_levels g on g.id=a.grade_level_id
  left join public.subjects su on su.id=a.subject_id
  where public.has_staff_role(array['super_admin','admin','sales'])
  order by a.created_at desc;
$$;

grant execute on function public.staff_list_applications() to authenticated;

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
  if not public.has_staff_role(array['super_admin','admin','sales']) then
    raise exception 'not authorized';
  end if;

  update public.applications
  set sales_status=coalesce(p_sales_status,sales_status),
      application_status=coalesce(p_application_status,application_status),
      sales_notes=coalesce(nullif(p_sales_notes,''),sales_notes),
      next_follow_up_at=p_next_follow_up_at,
      last_contact_at=case when p_sales_status in ('contacted','follow_up','trial','won','lost') then now() else last_contact_at end,
      updated_at=now()
  where id=p_application_id;

  return found;
end;
$$;

grant execute on function public.staff_update_application_status(uuid,text,text,text,timestamptz)
to authenticated;

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
  if not public.has_staff_role(array['super_admin','admin']) then
    raise exception 'not authorized';
  end if;

  select * into a from public.applications where id=p_application_id for update;
  if a.id is null then raise exception 'application not found'; end if;

  if a.created_student_id is not null then
    return jsonb_build_object('student_id',a.created_student_id,'already_converted',true);
  end if;

  select id into v_year_id
  from public.academic_years
  where is_current=true
  order by start_date desc nulls last limit 1;

  v_student_code := 'JBE-' || to_char(now(),'YY') || '-' ||
                    lpad(nextval('public.student_code_seq')::text,5,'0');

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

  update public.applications
  set created_student_id=v_student_id,
      application_status='converted',
      sales_status='won',
      converted_at=now(),
      updated_at=now()
  where id=a.id;

  return jsonb_build_object(
    'success',true,
    'student_id',v_student_id,
    'student_code',v_student_code
  );
end;
$$;

grant execute on function public.admin_convert_application_to_student(uuid)
to authenticated;

-- ============================================================
-- J) NOTIFICATIONS + AUDIT
-- ============================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid,
  student_id uuid references public.students(id) on delete cascade,
  guardian_id uuid references public.guardians(id) on delete cascade,
  staff_id uuid references public.staff(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  action_url text,
  is_read boolean not null default false,
  scheduled_for timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigserial primary key,
  actor_user_id uuid,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- K) RLS BASELINE
-- Security: public users use RPCs, not direct table reads.
-- ============================================================

alter table public.academic_stages enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.teacher_offerings enable row level security;
alter table public.pricing_policies enable row level security;
alter table public.applications enable row level security;
alter table public.class_groups enable row level security;
alter table public.group_members enable row level security;
alter table public.learning_activities enable row level security;
alter table public.activity_submissions enable row level security;
alter table public.billing_plans enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.payment_claims enable row level security;
alter table public.receipts enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log enable row level security;

-- Public teacher discovery.
drop policy if exists "public_read_verified_teachers" on public.teacher_profiles;
create policy "public_read_verified_teachers"
on public.teacher_profiles for select
to anon,authenticated
using(is_public=true and is_verified=true);

drop policy if exists "public_read_approved_offerings" on public.teacher_offerings;
create policy "public_read_approved_offerings"
on public.teacher_offerings for select
to anon,authenticated
using(is_public=true and approval_status='approved');

-- Staff can see core operational data through direct select where useful.
drop policy if exists "staff_read_applications" on public.applications;
create policy "staff_read_applications"
on public.applications for select to authenticated
using(public.has_staff_role(array['super_admin','admin','sales']));

drop policy if exists "staff_manage_groups" on public.class_groups;
create policy "staff_manage_groups"
on public.class_groups for all to authenticated
using(public.has_staff_role(array['super_admin','admin','teacher']))
with check(public.has_staff_role(array['super_admin','admin','teacher']));

drop policy if exists "staff_manage_activities" on public.learning_activities;
create policy "staff_manage_activities"
on public.learning_activities for all to authenticated
using(public.has_staff_role(array['super_admin','admin','teacher']))
with check(public.has_staff_role(array['super_admin','admin','teacher']));

-- Guardian sees own invoices/receipts only.
drop policy if exists "guardian_read_invoices" on public.invoices;
create policy "guardian_read_invoices"
on public.invoices for select to authenticated
using(exists(
  select 1
  from public.guardians g
  join public.student_guardians sg on sg.guardian_id=g.id
  where g.auth_user_id=auth.uid()
    and sg.student_id=invoices.student_id
));

drop policy if exists "guardian_read_receipts" on public.receipts;
create policy "guardian_read_receipts"
on public.receipts for select to authenticated
using(exists(
  select 1
  from public.guardians g
  join public.student_guardians sg on sg.guardian_id=g.id
  where g.auth_user_id=auth.uid()
    and sg.student_id=receipts.student_id
));

-- ============================================================
-- L) INDEXES
-- ============================================================

create index if not exists idx_teacher_offerings_teacher on public.teacher_offerings(teacher_id);
create index if not exists idx_groups_course on public.class_groups(course_id);
create index if not exists idx_group_members_group on public.group_members(group_id);
create index if not exists idx_learning_activities_group on public.learning_activities(group_id);
create index if not exists idx_invoices_student_status on public.invoices(student_id,status);
create index if not exists idx_payment_claims_status on public.payment_claims(status,submitted_at desc);
create index if not exists idx_notifications_recipient on public.notifications(recipient_user_id,is_read);

-- ============================================================
-- END MASTER V2 MIGRATION
-- ============================================================

select 'JBE Academy Master V2 base migration loaded' as result;


-- ============================================================
-- M) TEACHER OWNERSHIP & SELF-SERVICE — V2.1
-- Every teacher owns independent curricula/grades/subjects/courses/pricing.
-- Existing JBE courses are explicitly attached to Mr. Mohammad Jebali.
-- ============================================================

create table if not exists public.teacher_teaching_scopes (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teacher_profiles(id) on delete cascade,
  education_system_id uuid not null references public.education_systems(id),
  curriculum_id uuid not null references public.curricula(id),
  stage_id uuid references public.academic_stages(id),
  grade_level_id uuid not null references public.grade_levels(id),
  subject_id uuid not null references public.subjects(id),
  is_active boolean not null default true,
  is_public boolean not null default false,
  created_at timestamptz not null default now(),
  unique(teacher_id,curriculum_id,grade_level_id,subject_id)
);

create index if not exists idx_teacher_scopes_teacher
on public.teacher_teaching_scopes(teacher_id,is_active);

-- ------------------------------------------------------------
-- Seed the founding teacher profile.
-- We intentionally find the existing staff row instead of hard-coding Auth IDs.
-- ------------------------------------------------------------
do $$
declare
  v_staff_id uuid;
  v_teacher_id uuid;
begin
  select id into v_staff_id
  from public.staff
  where lower(full_name) in (
    lower('Mr. Mohammad Jebali'),
    lower('Mohammad Jebali'),
    lower('Mr. Jebali')
  )
  order by created_at
  limit 1;

  if v_staff_id is null then
    select id into v_staff_id
    from public.staff
    where role in ('super_admin','admin')
    order by created_at
    limit 1;
  end if;

  if v_staff_id is not null then
    insert into public.teacher_profiles(
      staff_id,slug,display_name,display_name_ar,
      headline_en,headline_ar,bio_en,bio_ar,
      photo_url,country_code,is_verified,is_public
    )
    values(
      v_staff_id,
      'mr-mohammad-jebali',
      'Mr. Mohammad Jebali',
      'مستر محمد جبالي',
      'Mathematics & Business Management Teacher',
      'مدرس رياضيات وإدارة أعمال',
      'JBE Academy founding teacher. Mathematics and Business Management with structured academic follow-up, skills tracking, homework and progress reporting.',
      'المعلم المؤسس لـ JBE Academy. تدريس الرياضيات وإدارة الأعمال مع متابعة أكاديمية منظمة للواجبات والمهارات والتقدم.',
      'teacher.png',
      'EG',
      true,
      true
    )
    on conflict(staff_id) do update
    set slug='mr-mohammad-jebali',
        display_name='Mr. Mohammad Jebali',
        display_name_ar='مستر محمد جبالي',
        headline_en='Mathematics & Business Management Teacher',
        headline_ar='مدرس رياضيات وإدارة أعمال',
        photo_url='teacher.png',
        is_verified=true,
        is_public=true,
        updated_at=now();

    select id into v_teacher_id
    from public.teacher_profiles
    where staff_id=v_staff_id;

    -- All courses that already formed the original JBE Academy launch
    -- belong explicitly to Mr. Mohammad Jebali.
    update public.courses
    set teacher_id=v_teacher_id
    where slug in (
      'national-grade-9-math-2026-2027',
      'national-grade-10-math-2026-2027',
      'baccalaureate-grade-11-math-2026-2027',
      'baccalaureate-grade-11-business-management-2026-2027',
      'baccalaureate-grade-12-economics-coming-soon'
    );

    -- Preserve his CURRENT active teaching scope from the original site/courses.
    insert into public.teacher_teaching_scopes(
      teacher_id,education_system_id,curriculum_id,stage_id,grade_level_id,subject_id,
      is_active,is_public
    )
    select distinct
      v_teacher_id,
      c.education_system_id,
      co.curriculum_id,
      gl.stage_id,
      co.grade_level_id,
      co.subject_id,
      true,
      co.is_public
    from public.courses co
    join public.curricula c on c.id=co.curriculum_id
    join public.grade_levels gl on gl.id=co.grade_level_id
    where co.teacher_id=v_teacher_id
    on conflict(teacher_id,curriculum_id,grade_level_id,subject_id)
    do update set
      is_active=true,
      is_public=excluded.is_public;
  end if;
end $$;

-- ------------------------------------------------------------
-- Teacher catalog: systems -> curricula -> stages -> grades -> subjects
-- ------------------------------------------------------------
create or replace function public.teacher_catalog()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  return jsonb_build_object(
    'education_systems',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.education_systems
    ),'[]'::jsonb),

    'curricula',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'education_system_id',education_system_id,
        'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.curricula where is_active=true
    ),'[]'::jsonb),

    'stages',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'education_system_id',education_system_id,
        'code',code,'name_en',name_en,'name_ar',name_ar,'sort_order',sort_order
      ) order by sort_order)
      from public.academic_stages where is_active=true
    ),'[]'::jsonb),

    'grades',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'curriculum_id',curriculum_id,'stage_id',stage_id,
        'code',code,'name_en',name_en,'name_ar',name_ar,'sort_order',sort_order
      ) order by sort_order)
      from public.grade_levels where is_active=true
    ),'[]'::jsonb),

    'subjects',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',id,'code',code,'name_en',name_en,'name_ar',name_ar
      ) order by name_en)
      from public.subjects where is_active=true
    ),'[]'::jsonb)
  );
end;
$$;

grant execute on function public.teacher_catalog() to authenticated;

-- ------------------------------------------------------------
-- Resolve the teacher profile belonging to the logged-in staff account.
-- Admin/Super Admin can also own a teacher profile.
-- ------------------------------------------------------------
create or replace function public.teacher_my_profile()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
  limit 1;

  if v_teacher_id is null then
    return jsonb_build_object(
      'profile',null,
      'scopes','[]'::jsonb,
      'offerings','[]'::jsonb
    );
  end if;

  return jsonb_build_object(
    'profile',(
      select jsonb_build_object(
        'id',tp.id,
        'slug',tp.slug,
        'display_name',tp.display_name,
        'display_name_ar',tp.display_name_ar,
        'headline_en',tp.headline_en,
        'headline_ar',tp.headline_ar,
        'bio_en',tp.bio_en,
        'bio_ar',tp.bio_ar,
        'photo_url',tp.photo_url,
        'is_verified',tp.is_verified,
        'is_public',tp.is_public
      )
      from public.teacher_profiles tp where tp.id=v_teacher_id
    ),
    'scopes',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',ts.id,
        'education_system_id',ts.education_system_id,
        'education_system',es.name_en,
        'curriculum_id',ts.curriculum_id,
        'curriculum',c.name_en,
        'stage_id',ts.stage_id,
        'stage',st.name_en,
        'grade_level_id',ts.grade_level_id,
        'grade',g.name_en,
        'subject_id',ts.subject_id,
        'subject',su.name_en,
        'is_active',ts.is_active,
        'is_public',ts.is_public
      ) order by es.name_en,c.name_en,g.sort_order,su.name_en)
      from public.teacher_teaching_scopes ts
      join public.education_systems es on es.id=ts.education_system_id
      join public.curricula c on c.id=ts.curriculum_id
      left join public.academic_stages st on st.id=ts.stage_id
      join public.grade_levels g on g.id=ts.grade_level_id
      join public.subjects su on su.id=ts.subject_id
      where ts.teacher_id=v_teacher_id
    ),'[]'::jsonb),
    'offerings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,
        'curriculum',c.name_en,
        'grade',g.name_en,
        'subject',su.name_en,
        'study_mode',o.study_mode,
        'billing_type',o.billing_type,
        'teacher_price',o.teacher_price,
        'currency',o.currency,
        'duration_minutes',o.duration_minutes,
        'capacity',o.capacity,
        'approval_status',o.approval_status,
        'is_public',o.is_public
      ) order by o.created_at desc)
      from public.teacher_offerings o
      join public.curricula c on c.id=o.curriculum_id
      join public.grade_levels g on g.id=o.grade_level_id
      join public.subjects su on su.id=o.subject_id
      where o.teacher_id=v_teacher_id
    ),'[]'::jsonb)
  );
end;
$$;

grant execute on function public.teacher_my_profile() to authenticated;

-- ------------------------------------------------------------
-- Teacher adds/removes the systems, curricula, grades and subjects taught.
-- New scope is private until teacher chooses to request/publish it.
-- ------------------------------------------------------------
create or replace function public.teacher_save_scope(
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
  v_teacher_id uuid;
  v_id uuid;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
  limit 1;

  if v_teacher_id is null then
    raise exception 'No teacher profile is linked to this account';
  end if;

  -- Validate hierarchy so a grade from another curriculum cannot be mixed in.
  if not exists(
    select 1
    from public.curricula c
    join public.grade_levels g on g.curriculum_id=c.id
    where c.id=p_curriculum_id
      and c.education_system_id=p_education_system_id
      and g.id=p_grade_level_id
      and (p_stage_id is null or g.stage_id=p_stage_id)
  ) then
    raise exception 'Invalid academic hierarchy';
  end if;

  insert into public.teacher_teaching_scopes(
    teacher_id,education_system_id,curriculum_id,stage_id,grade_level_id,subject_id,
    is_active,is_public
  )
  values(
    v_teacher_id,p_education_system_id,p_curriculum_id,p_stage_id,p_grade_level_id,p_subject_id,
    true,p_is_public
  )
  on conflict(teacher_id,curriculum_id,grade_level_id,subject_id)
  do update set
    education_system_id=excluded.education_system_id,
    stage_id=excluded.stage_id,
    is_active=true,
    is_public=excluded.is_public
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.teacher_save_scope(uuid,uuid,uuid,uuid,uuid,boolean)
to authenticated;

create or replace function public.teacher_archive_scope(p_scope_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_teacher_id uuid;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
  limit 1;

  update public.teacher_teaching_scopes
  set is_active=false,is_public=false
  where id=p_scope_id and teacher_id=v_teacher_id;

  return found;
end;
$$;

grant execute on function public.teacher_archive_scope(uuid) to authenticated;

-- ------------------------------------------------------------
-- Teacher proposes an offering and chooses their own price.
-- It does NOT become public automatically; Admin approval is required.
-- ------------------------------------------------------------
create or replace function public.teacher_create_offering(
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
  v_teacher_id uuid;
  v_id uuid;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  if p_teacher_price < 0 then
    raise exception 'Price cannot be negative';
  end if;

  if p_study_mode not in ('group','private','recorded','hybrid') then
    raise exception 'Invalid study mode';
  end if;

  if p_billing_type not in ('fixed_session','hourly','monthly','term','package') then
    raise exception 'Invalid billing type';
  end if;

  select tp.id into v_teacher_id
  from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where s.auth_user_id=auth.uid()
  limit 1;

  if v_teacher_id is null then
    raise exception 'No teacher profile is linked to this account';
  end if;

  if not exists(
    select 1
    from public.teacher_teaching_scopes ts
    where ts.teacher_id=v_teacher_id
      and ts.curriculum_id=p_curriculum_id
      and ts.grade_level_id=p_grade_level_id
      and ts.subject_id=p_subject_id
      and ts.is_active=true
  ) then
    raise exception 'Add this curriculum/grade/subject to your teaching scope first';
  end if;

  insert into public.teacher_offerings(
    teacher_id,curriculum_id,grade_level_id,subject_id,
    study_mode,billing_type,teacher_price,currency,duration_minutes,capacity,
    approval_status,is_public
  )
  values(
    v_teacher_id,p_curriculum_id,p_grade_level_id,p_subject_id,
    p_study_mode,p_billing_type,p_teacher_price,coalesce(nullif(p_currency,''),'EGP'),
    p_duration_minutes,p_capacity,
    'pending',false
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.teacher_create_offering(
  uuid,uuid,uuid,text,text,numeric,text,int,int
) to authenticated;

-- ------------------------------------------------------------
-- Admin approves/rejects a teacher offering.
-- Public price can differ from teacher earning; this keeps platform fee private.
-- ------------------------------------------------------------
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
begin
  if not public.has_staff_role(array['super_admin','admin']) then
    raise exception 'not authorized';
  end if;

  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  update public.teacher_offerings
  set approval_status=p_decision,
      is_public=(p_decision='approved')
  where id=p_offering_id;

  -- Public price is applied later when Admin creates the actual course/group.
  -- It is deliberately not stored on the public teacher scope.
  return found;
end;
$$;

grant execute on function public.admin_review_teacher_offering(uuid,text,numeric)
to authenticated;

-- ------------------------------------------------------------
-- Public teacher profile with ONLY that teacher's own scope and offerings.
-- This prevents future teachers from being mixed together.
-- ------------------------------------------------------------
create or replace function public.public_teacher_profile(p_slug text)
returns jsonb
language sql
security definer
set search_path=public
as $$
  select jsonb_build_object(
    'profile',jsonb_build_object(
      'id',tp.id,
      'slug',tp.slug,
      'display_name',tp.display_name,
      'display_name_ar',tp.display_name_ar,
      'headline_en',tp.headline_en,
      'headline_ar',tp.headline_ar,
      'bio_en',tp.bio_en,
      'bio_ar',tp.bio_ar,
      'photo_url',tp.photo_url,
      'rating_average',tp.rating_average,
      'rating_count',tp.rating_count
    ),
    'teaching_scope',coalesce((
      select jsonb_agg(jsonb_build_object(
        'education_system',es.name_en,
        'curriculum',c.name_en,
        'stage',st.name_en,
        'grade',g.name_en,
        'subject',su.name_en
      ) order by es.name_en,c.name_en,g.sort_order,su.name_en)
      from public.teacher_teaching_scopes ts
      join public.education_systems es on es.id=ts.education_system_id
      join public.curricula c on c.id=ts.curriculum_id
      left join public.academic_stages st on st.id=ts.stage_id
      join public.grade_levels g on g.id=ts.grade_level_id
      join public.subjects su on su.id=ts.subject_id
      where ts.teacher_id=tp.id
        and ts.is_active=true
        and ts.is_public=true
    ),'[]'::jsonb),
    'offerings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',o.id,
        'curriculum',c.name_en,
        'grade',g.name_en,
        'subject',su.name_en,
        'study_mode',o.study_mode,
        'billing_type',o.billing_type,
        'price',o.teacher_price,
        'currency',o.currency,
        'duration_minutes',o.duration_minutes,
        'capacity',o.capacity
      ) order by c.name_en,g.sort_order,su.name_en)
      from public.teacher_offerings o
      join public.curricula c on c.id=o.curriculum_id
      join public.grade_levels g on g.id=o.grade_level_id
      join public.subjects su on su.id=o.subject_id
      where o.teacher_id=tp.id
        and o.approval_status='approved'
        and o.is_public=true
    ),'[]'::jsonb)
  )
  from public.teacher_profiles tp
  where tp.slug=p_slug
    and tp.is_public=true
    and tp.is_verified=true;
$$;

grant execute on function public.public_teacher_profile(text) to anon,authenticated;

-- RLS for scope.
alter table public.teacher_teaching_scopes enable row level security;

drop policy if exists "public_read_teacher_scopes" on public.teacher_teaching_scopes;
create policy "public_read_teacher_scopes"
on public.teacher_teaching_scopes for select
to anon,authenticated
using(is_active=true and is_public=true);

drop policy if exists "teacher_read_own_scopes" on public.teacher_teaching_scopes;
create policy "teacher_read_own_scopes"
on public.teacher_teaching_scopes for select
to authenticated
using(exists(
  select 1 from public.teacher_profiles tp
  join public.staff s on s.id=tp.staff_id
  where tp.id=teacher_teaching_scopes.teacher_id
    and s.auth_user_id=auth.uid()
));

select 'JBE Teacher Ownership V2.1 loaded' as result;

