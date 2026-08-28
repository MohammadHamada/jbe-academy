const { createClient } = supabase;
const cfg = window.JBE_CONFIG;
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $ = id => document.getElementById(id);
const pct = v => v == null ? "—" : `${Math.round(Number(v))}%`;

let cached=null;

function nm(obj){
  if(!obj)return "";
  return JBE_I18N.getLanguage()==="ar"
    ? (obj.name_ar||obj.name_en||"")
    : (obj.name_en||obj.name_ar||"");
}

function courseTitle(obj){
  if(!obj)return JBE_I18N.t("Course");
  return JBE_I18N.getLanguage()==="ar"
    ? (obj.title_ar||obj.title_en||JBE_I18N.t("Course"))
    : (obj.title_en||obj.title_ar||JBE_I18N.t("Course"));
}

function render(d){
  cached=d;
  const {student,enrollments,report,skills,goals,notes}=d;

  $("studentName").textContent=
    JBE_I18N.getLanguage()==="ar"
      ? (student.full_name||student.full_name_en)
      : (student.full_name_en||student.full_name);

  $("studentCode").textContent=student.student_code||"";
  $("academicLine").textContent=`${nm(student.curricula)} • ${nm(student.grade_levels)}`;

  $("coursesList").innerHTML=enrollments.map(e=>`
    <div class="list-row">
      <div><strong>${courseTitle(e.courses)}</strong><span>${JBE_I18N.t(e.status)}</span></div>
      <span class="pill ${e.payment_status==="paid"?"success":""}">${JBE_I18N.t(e.payment_status)}</span>
    </div>`).join("") || `<p class="muted">${JBE_I18N.t("No courses yet.")}</p>`;

  $("paymentStat").textContent=
    enrollments.some(e=>e.payment_status==="paid")
      ? JBE_I18N.t("Paid")
      : JBE_I18N.t("Pending");

  if(report){
    $("attendanceStat").textContent=pct(report.attendance_percent);
    $("assessmentStat").textContent=pct(report.assessment_average);
    $("homeworkStat").textContent=pct(report.homework_completion_percent);
    $("overallProgress").textContent=pct(report.overall_progress_percent);
    $("reportPeriod").textContent=report.period_name||"—";
    $("strengths").textContent=report.strengths||"—";
    $("improvements").textContent=report.areas_for_improvement||"—";
    $("recommendation").textContent=report.teacher_recommendation||"—";
  }

  $("skillsList").innerHTML=skills.map(s=>`
    <div class="skill-row">
      <div class="skill-title"><strong>${nm(s.skills)||JBE_I18N.t("Skill")}</strong><span>${s.teacher_note||""}</span></div>
      <div class="skill-score"><b>${s.rating}/5</b><small>${JBE_I18N.t(s.rating_label||"")}</small></div>
      <div class="bar"><i style="width:${s.rating*20}%"></i></div>
    </div>`).join("") || `<p class="muted">${JBE_I18N.t("No skill ratings yet.")}</p>`;

  $("goalsList").innerHTML=goals.map(g=>`
    <div class="goal-row"><div><strong>${g.title}</strong><span>${g.description||""}</span></div><div class="goal-progress">${g.progress_percent}%</div></div>
  `).join("") || `<p class="muted">${JBE_I18N.t("No active goals yet.")}</p>`;

  $("teacherNotes").innerHTML=notes.map(n=>`
    <div class="note-row"><span class="pill">${JBE_I18N.t(n.note_type)}</span><p>${n.note}</p></div>
  `).join("") || `<p class="muted">${JBE_I18N.t("No feedback yet.")}</p>`;

  JBE_I18N.apply();
}

async function loadDashboard(){
  const {data:{session}}=await client.auth.getSession();

  if(!session){
    window.location.href="student-login.html?next=student-dashboard.html";
    return;
  }

  const {data:student,error}=await client
    .from("students")
    .select(`id,student_code,full_name,full_name_en,
      curricula:current_curriculum_id(name_en,name_ar),
      grade_levels:current_grade_level_id(name_en,name_ar)`)
    .eq("auth_user_id",session.user.id)
    .single();

  if(error){
    $("dashboardError").textContent=error.message;
    return;
  }

  const [enrollmentsRes,reportsRes,skillsRes,goalsRes,notesRes]=await Promise.all([
    client.from("enrollments").select(`status,payment_status,access_enabled,courses(title_en,title_ar,slug)`).eq("student_id",student.id),
    client.from("progress_reports").select("*").eq("student_id",student.id).eq("published",true).order("report_date",{ascending:false}).limit(1),
    client.from("student_skill_ratings").select(`rating,rating_label,teacher_note,skills(name_en,name_ar)`).eq("student_id",student.id),
    client.from("learning_goals").select("title,description,progress_percent").eq("student_id",student.id).eq("status","active"),
    client.from("teacher_notes").select("note,note_type").eq("student_id",student.id).eq("is_parent_visible",true).order("created_at",{ascending:false}).limit(5)
  ]);

  render({
    student,
    enrollments:enrollmentsRes.data||[],
    report:reportsRes.data?.[0]||null,
    skills:skillsRes.data||[],
    goals:goalsRes.data||[],
    notes:notesRes.data||[]
  });
}

$("logoutBtn").addEventListener("click",async()=>{
  await client.auth.signOut();
  window.location.href="student-login.html";
});

window.addEventListener("jbe:languagechange",()=>{if(cached)render(cached);});
loadDashboard();
