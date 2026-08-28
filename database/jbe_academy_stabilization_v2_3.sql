-- ============================================================
-- JBE ACADEMY V2.3 — STABILIZATION PATCH
-- Run AFTER JBE Teacher Ownership V2.1.
--
-- Goals:
-- 1) Universal role resolver (Staff > Student > Parent)
-- 2) Keep teacher earning private; expose only approved public price
-- 3) Prevent public table leakage of staff/teacher internal IDs
-- 4) Make recurring session generation idempotent
-- 5) Make session billing finalization idempotent
-- 6) Harden automatic receipt generation
-- ============================================================

begin;

-- ============================================================
-- 1) UNIVERSAL ROLE RESOLVER
-- ============================================================

create or replace function public.resolve_my_portal()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then
    return jsonb_build_object(
      'authenticated', false,
      'account_type', null,
      'role', null,
      'destination', null
    );
  end if;

  -- STAFF ALWAYS WINS.
  -- This is essential because the founding Admin account may also be linked
  -- to the demo student record.
  select s.role
  into v_role
  from public.staff s
  where s.auth_user_id = v_uid
    and s.is_active = true
  limit 1;

  if v_role is not null then
    return jsonb_build_object(
      'authenticated', true,
      'account_type', 'staff',
      'role', v_role,
      'destination',
        case v_role
          when 'super_admin' then 'portal.html'
          when 'admin' then 'portal.html'
          when 'teacher' then 'teacher-dashboard.html'
          when 'sales' then 'admissions-dashboard.html'
          else 'portal.html'
        end
    );
  end if;

  if exists(
    select 1
    from public.students st
    where st.auth_user_id = v_uid
  ) then
    return jsonb_build_object(
      'authenticated', true,
      'account_type', 'student',
      'role', 'student',
      'destination', 'student-dashboard.html'
    );
  end if;

  if exists(
    select 1
    from public.guardians g
    where g.auth_user_id = v_uid
  ) then
    return jsonb_build_object(
      'authenticated', true,
      'account_type', 'parent',
      'role', 'parent',
      'destination', 'parent-dashboard.html'
    );
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'account_type', 'unlinked',
    'role', null,
    'destination', null
  );
end;
$$;

revoke all on function public.resolve_my_portal() from public;
grant execute on function public.resolve_my_portal() to authenticated;

-- ============================================================
-- 2) TEACHER PRICING PRIVACY
-- teacher_price = teacher's own commercial amount (private)
-- public_price  = final price shown to visitors after Admin approval
-- ============================================================

alter table public.teacher_offerings
  add column if not exists public_price numeric(12,2),
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by_staff_id uuid references public.staff(id);

create or replace function public.admin_review_teacher_offering(
  p_offering_id uuid,
  p_decision text,
  p_public_price numeric
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_staff_id uuid;
begin
  if not public.has_staff_role(array['super_admin','admin']) then
    raise exception 'not authorized';
  end if;

  if p_decision not in ('approved','rejected') then
    raise exception 'Decision must be approved or rejected';
  end if;

  if p_decision = 'approved' and (p_public_price is null or p_public_price < 0) then
    raise exception 'A valid public price is required for approval';
  end if;

  select id into v_staff_id
  from public.staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;

  update public.teacher_offerings
  set approval_status = p_decision,
      is_public = (p_decision = 'approved'),
      public_price = case
        when p_decision = 'approved' then p_public_price
        else null
      end,
      reviewed_at = now(),
      reviewed_by_staff_id = v_staff_id
  where id = p_offering_id;

  return found;
end;
$$;

revoke all on function public.admin_review_teacher_offering(uuid,text,numeric) from public;
grant execute on function public.admin_review_teacher_offering(uuid,text,numeric)
to authenticated;

-- ============================================================
-- 3) PUBLIC TEACHER DIRECTORY / PROFILE
-- SECURITY-DEFINER RPCs expose only intended public fields.
-- No direct anon SELECT on teacher operational tables.
-- ============================================================

create or replace function public.public_teacher_directory()
returns table(
  slug text,
  display_name text,
  display_name_ar text,
  headline_en text,
  headline_ar text,
  bio_en text,
  bio_ar text,
  photo_url text,
  rating_average numeric,
  rating_count int
)
language sql
stable
security definer
set search_path = public
as $$
  select
    tp.slug,
    tp.display_name,
    tp.display_name_ar,
    tp.headline_en,
    tp.headline_ar,
    tp.bio_en,
    tp.bio_ar,
    tp.photo_url,
    tp.rating_average,
    tp.rating_count
  from public.teacher_profiles tp
  where tp.is_public = true
    and tp.is_verified = true
  order by tp.display_name;
$$;

revoke all on function public.public_teacher_directory() from public;
grant execute on function public.public_teacher_directory() to anon, authenticated;

create or replace function public.public_teacher_profile(p_slug text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'profile', jsonb_build_object(
      'slug', tp.slug,
      'display_name', tp.display_name,
      'display_name_ar', tp.display_name_ar,
      'headline_en', tp.headline_en,
      'headline_ar', tp.headline_ar,
      'bio_en', tp.bio_en,
      'bio_ar', tp.bio_ar,
      'photo_url', tp.photo_url,
      'rating_average', tp.rating_average,
      'rating_count', tp.rating_count
    ),

    'teaching_scope', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'education_system', es.name_en,
          'curriculum', c.name_en,
          'stage', st.name_en,
          'grade', g.name_en,
          'subject', su.name_en
        )
        order by es.name_en, c.name_en, g.sort_order, su.name_en
      )
      from public.teacher_teaching_scopes ts
      join public.education_systems es on es.id = ts.education_system_id
      join public.curricula c on c.id = ts.curriculum_id
      left join public.academic_stages st on st.id = ts.stage_id
      join public.grade_levels g on g.id = ts.grade_level_id
      join public.subjects su on su.id = ts.subject_id
      where ts.teacher_id = tp.id
        and ts.is_active = true
        and ts.is_public = true
    ), '[]'::jsonb),

    'offerings', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', o.id,
          'curriculum', c.name_en,
          'grade', g.name_en,
          'subject', su.name_en,
          'study_mode', o.study_mode,
          'billing_type', o.billing_type,
          'price', o.public_price,
          'currency', o.currency,
          'duration_minutes', o.duration_minutes,
          'capacity', o.capacity
        )
        order by c.name_en, g.sort_order, su.name_en
      )
      from public.teacher_offerings o
      join public.curricula c on c.id = o.curriculum_id
      join public.grade_levels g on g.id = o.grade_level_id
      join public.subjects su on su.id = o.subject_id
      where o.teacher_id = tp.id
        and o.approval_status = 'approved'
        and o.is_public = true
        and o.public_price is not null
    ), '[]'::jsonb)
  )
  from public.teacher_profiles tp
  where tp.slug = p_slug
    and tp.is_public = true
    and tp.is_verified = true;
$$;

revoke all on function public.public_teacher_profile(text) from public;
grant execute on function public.public_teacher_profile(text) to anon, authenticated;

-- Remove direct public-table policies that expose internal UUIDs/private pricing.
drop policy if exists "public_read_verified_teachers" on public.teacher_profiles;
drop policy if exists "public_read_approved_offerings" on public.teacher_offerings;
drop policy if exists "public_read_teacher_scopes" on public.teacher_teaching_scopes;

revoke select on public.teacher_profiles from anon;
revoke select on public.teacher_offerings from anon;
revoke select on public.teacher_teaching_scopes from anon;

-- ============================================================
-- 4) IDEMPOTENT RECURRING SESSION GENERATION
-- Avoid duplicate sessions when the same date range is generated again.
-- ============================================================

create or replace function public.admin_generate_weekly_sessions(
  p_group_id uuid,
  p_start_date date,
  p_end_date date
)
returns int
language plpgsql
security definer
set search_path = public
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

  if p_end_date < p_start_date then
    raise exception 'end date must be on or after start date';
  end if;

  select *
  into g
  from public.class_groups
  where id = p_group_id;

  if g.id is null then
    raise exception 'group not found';
  end if;

  if g.recurring_weekday is null or g.recurring_start_time is null then
    raise exception 'group recurring schedule is incomplete';
  end if;

  d := p_start_date;

  while d <= p_end_date loop
    if extract(dow from d)::int = g.recurring_weekday then
      v_session_ts :=
        (d::text || ' ' || g.recurring_start_time::text)::timestamp
        at time zone g.timezone;

      if not exists(
        select 1
        from public.class_sessions cs
        where cs.group_id = g.id
          and cs.session_date = v_session_ts
      ) then
        insert into public.class_sessions(
          course_id,
          group_id,
          title,
          session_date,
          session_type,
          planned_duration_minutes
        )
        values(
          g.course_id,
          g.id,
          g.name || ' - ' || to_char(d,'YYYY-MM-DD'),
          v_session_ts,
          'live',
          g.default_duration_minutes
        );

        v_count := v_count + 1;
      end if;
    end if;

    d := d + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.admin_generate_weekly_sessions(uuid,date,date) from public;
grant execute on function public.admin_generate_weekly_sessions(uuid,date,date)
to authenticated;

-- ============================================================
-- 5) IDEMPOTENT SESSION BILLING
-- A finalized session must not generate charges twice.
-- ============================================================

alter table public.invoices
  add column if not exists session_id uuid references public.class_sessions(id) on delete set null;

create index if not exists idx_invoices_session_student
on public.invoices(session_id, student_id);

create or replace function public.admin_finalize_session_billing(
  p_session_id uuid,
  p_actual_start timestamptz,
  p_actual_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_minutes int;
  v_course public.courses%rowtype;
  v_group_id uuid;
  v_already_finalized boolean;
  r record;
  v_amount numeric(12,2);
  v_invoice_id uuid;
  v_invoice_no text;
  v_created int := 0;
begin
  if not public.has_staff_role(array['super_admin','admin','teacher']) then
    raise exception 'not authorized';
  end if;

  if p_actual_end <= p_actual_start then
    raise exception 'end time must be after start time';
  end if;

  select
    cs.group_id,
    cs.billing_finalized
  into
    v_group_id,
    v_already_finalized
  from public.class_sessions cs
  where cs.id = p_session_id;

  if not found then
    raise exception 'session not found';
  end if;

  if v_already_finalized = true then
    return jsonb_build_object(
      'success', true,
      'already_finalized', true,
      'charge_created', false
    );
  end if;

  select co.*
  into v_course
  from public.class_sessions cs
  join public.courses co on co.id = cs.course_id
  where cs.id = p_session_id;

  v_minutes :=
    ceil(extract(epoch from (p_actual_end - p_actual_start)) / 60.0);

  update public.class_sessions
  set actual_start_at = p_actual_start,
      actual_end_at = p_actual_end,
      actual_duration_minutes = v_minutes
  where id = p_session_id;

  -- Monthly / Term / Package are billed outside individual sessions.
  if v_course.billing_type in ('monthly','term','package') then
    update public.class_sessions
    set billing_finalized = true
    where id = p_session_id;

    return jsonb_build_object(
      'success', true,
      'minutes', v_minutes,
      'billing_type', v_course.billing_type,
      'charge_created', false,
      'invoices_created', 0
    );
  end if;

  for r in
    select e.id as enrollment_id, e.student_id
    from public.enrollments e
    left join public.group_members gm on gm.enrollment_id = e.id
    where e.status = 'active'
      and (
        (v_group_id is not null and gm.group_id = v_group_id)
        or
        (v_group_id is null and e.course_id = v_course.id)
      )
  loop
    -- Skip if this student already has an invoice for this session.
    if exists(
      select 1
      from public.invoices i
      where i.session_id = p_session_id
        and i.student_id = r.student_id
        and i.status <> 'cancelled'
    ) then
      continue;
    end if;

    if v_course.billing_type = 'hourly' then
      v_amount :=
        round(
          coalesce(v_course.public_price, v_course.price_egp, 0)
          * v_minutes / 60.0,
          2
        );
    else
      -- FIXED SESSION:
      -- actual overrun does NOT increase the price.
      v_amount :=
        coalesce(v_course.public_price, v_course.price_egp, 0);
    end if;

    v_invoice_no :=
      'JBE-INV-' ||
      to_char(now(),'YYYY') ||
      '-' ||
      lpad(nextval('public.invoice_number_seq')::text, 6, '0');

    insert into public.invoices(
      invoice_number,
      student_id,
      enrollment_id,
      session_id,
      status,
      currency,
      total_amount,
      due_date
    )
    values(
      v_invoice_no,
      r.student_id,
      r.enrollment_id,
      p_session_id,
      'due',
      'EGP',
      v_amount,
      current_date
    )
    returning id into v_invoice_id;

    insert into public.invoice_items(
      invoice_id,
      session_id,
      description,
      quantity,
      unit_price,
      amount
    )
    values(
      v_invoice_id,
      p_session_id,
      case
        when v_course.billing_type = 'hourly'
          then 'Hourly session - ' || v_minutes || ' minutes'
        else 'Fixed session'
      end,
      case
        when v_course.billing_type = 'hourly'
          then v_minutes / 60.0
        else 1
      end,
      case
        when v_course.billing_type = 'hourly'
          then coalesce(v_course.public_price, v_course.price_egp, 0)
        else v_amount
      end,
      v_amount
    );

    v_created := v_created + 1;
  end loop;

  update public.class_sessions
  set billing_finalized = true
  where id = p_session_id;

  return jsonb_build_object(
    'success', true,
    'already_finalized', false,
    'minutes', v_minutes,
    'billing_type', v_course.billing_type,
    'charge_created', (v_created > 0),
    'invoices_created', v_created
  );
end;
$$;

revoke all on function public.admin_finalize_session_billing(uuid,timestamptz,timestamptz)
from public;

grant execute on function public.admin_finalize_session_billing(uuid,timestamptz,timestamptz)
to authenticated;

-- ============================================================
-- 6) HARDEN AUTO RECEIPT TRIGGER
-- ============================================================

create or replace function public.jbe_auto_receipt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_should_issue boolean := false;
  v_receipt text;
begin
  if tg_op = 'INSERT' then
    v_should_issue := (new.status = 'verified');
  elsif tg_op = 'UPDATE' then
    v_should_issue :=
      (new.status = 'verified' and old.status is distinct from new.status);
  end if;

  if v_should_issue then
    v_receipt :=
      'JBE-RCP-' ||
      to_char(now(),'YYYY') ||
      '-' ||
      lpad(nextval('public.receipt_number_seq')::text, 6, '0');

    insert into public.receipts(
      receipt_number,
      payment_id,
      student_id,
      invoice_id,
      amount,
      currency
    )
    values(
      v_receipt,
      new.id,
      new.student_id,
      new.invoice_id,
      new.amount,
      new.currency
    )
    on conflict(payment_id) do nothing;

    if new.invoice_id is not null then
      update public.invoices i
      set amount_paid = (
            select coalesce(sum(p.amount),0)
            from public.payments p
            where p.invoice_id = i.id
              and p.status = 'verified'
          ),
          status = case
            when (
              select coalesce(sum(p.amount),0)
              from public.payments p
              where p.invoice_id = i.id
                and p.status = 'verified'
            ) >= i.total_amount then 'paid'
            when (
              select coalesce(sum(p.amount),0)
              from public.payments p
              where p.invoice_id = i.id
                and p.status = 'verified'
            ) > 0 then 'partial'
            else 'due'
          end
      where i.id = new.invoice_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_jbe_auto_receipt on public.payments;

create trigger trg_jbe_auto_receipt
after insert or update of status on public.payments
for each row
execute function public.jbe_auto_receipt();

-- ============================================================
-- 7) BASIC INDEXES
-- ============================================================

create index if not exists idx_guardians_auth_user_id
on public.guardians(auth_user_id);

create index if not exists idx_teacher_profiles_staff_id
on public.teacher_profiles(staff_id);

create index if not exists idx_teacher_offerings_status
on public.teacher_offerings(teacher_id, approval_status, is_public);

commit;

select 'JBE Academy V2.3 stabilization patch loaded' as result;
