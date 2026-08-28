const { createClient } = supabase;
const cfg = window.JBE_CONFIG;
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $ = (id) => document.getElementById(id);
const pct = (v) => v == null ? "—" : `${Math.round(Number(v))}%`;

async function loadDashboard() {
  const { data: { session } } = await client.auth.getSession();
  if (!session) return window.location.href = "student-login.html";

  const { data: student, error } = await client
    .from("students")
    .select(`id,student_code,full_name,full_name_en,
      curricula:current_curriculum_id(name_en),
      grade_levels:current_grade_level_id(name_en)`)
    .eq("auth_user_id", session.user.id)
    .single();

  if (error) {
    $("dashboardError").textContent = error.message;
    return;
  }

  $("studentName").textContent = student.full_name_en || student.full_name;
  $("studentCode").textContent = student.student_code || "";
  $("academicLine").textContent = `${student.curricula?.name_en || ""} • ${student.grade_levels?.name_en || ""}`;

  const [enrollmentsRes,reportsRes,skillsRes,goalsRes,notesRes] = await Promise.all([
    client.from("enrollments").select(`status,payment_status,access_enabled,courses(title_en,slug)`).eq("student_id",student.id),
    client.from("progress_reports").select("*").eq("student_id",student.id).eq("published",true).order("report_date",{ascending:false}).limit(1),
    client.from("student_skill_ratings").select(`rating,rating_label,teacher_note,skills(name_en)`).eq("student_id",student.id),
    client.from("learning_goals").select("title,description,progress_percent").eq("student_id",student.id).eq("status","active"),
    client.from("teacher_notes").select("note,note_type").eq("student_id",student.id).eq("is_parent_visible",true).order("created_at",{ascending:false}).limit(5)
  ]);

  const enrollments = enrollmentsRes.data || [];
  $("coursesList").innerHTML = enrollments.map(e => `
    <div class="list-row">
      <div><strong>${e.courses?.title_en || "Course"}</strong><span>${e.status}</span></div>
      <span class="pill ${e.payment_status==="paid"?"success":""}">${e.payment_status}</span>
    </div>`).join("") || `<p class="muted">No courses yet.</p>`;
  $("paymentStat").textContent = enrollments.some(e => e.payment_status==="paid") ? "Paid" : "Pending";

  const report = reportsRes.data?.[0];
  if (report) {
    $("attendanceStat").textContent = pct(report.attendance_percent);
    $("assessmentStat").textContent = pct(report.assessment_average);
    $("homeworkStat").textContent = pct(report.homework_completion_percent);
    $("overallProgress").textContent = pct(report.overall_progress_percent);
    $("reportPeriod").textContent = report.period_name;
    $("strengths").textContent = report.strengths || "—";
    $("improvements").textContent = report.areas_for_improvement || "—";
    $("recommendation").textContent = report.teacher_recommendation || "—";
  }

  const skills = skillsRes.data || [];
  $("skillsList").innerHTML = skills.map(s => `
    <div class="skill-row">
      <div class="skill-title"><strong>${s.skills?.name_en || "Skill"}</strong><span>${s.teacher_note || ""}</span></div>
      <div class="skill-score"><b>${s.rating}/5</b><small>${s.rating_label || ""}</small></div>
      <div class="bar"><i style="width:${s.rating*20}%"></i></div>
    </div>`).join("") || `<p class="muted">No skill ratings yet.</p>`;

  const goals = goalsRes.data || [];
  $("goalsList").innerHTML = goals.map(g => `
    <div class="goal-row"><div><strong>${g.title}</strong><span>${g.description || ""}</span></div><div class="goal-progress">${g.progress_percent}%</div></div>`).join("") || `<p class="muted">No active goals yet.</p>`;

  const notes = notesRes.data || [];
  $("teacherNotes").innerHTML = notes.map(n => `
    <div class="note-row"><span class="pill">${n.note_type}</span><p>${n.note}</p></div>`).join("") || `<p class="muted">No feedback yet.</p>`;
}

$("logoutBtn").addEventListener("click", async () => {
  await client.auth.signOut();
  window.location.href = "student-login.html";
});

loadDashboard();
