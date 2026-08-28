const { createClient } = supabase;
const cfg = window.JBE_CONFIG;
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $ = id => document.getElementById(id);

const params = new URLSearchParams(location.search);
const studentId = params.get("id");

let studentData = null;
let enrollments = [];

async function requireStaff() {
  const { data: { session } } = await client.auth.getSession();

  if (!session) {
    location.href = "student-login.html";
    return false;
  }

  const { data, error } = await client
    .from("staff")
    .select("id")
    .eq("auth_user_id", session.user.id)
    .single();

  if (error || !data) {
    $("pageError").textContent = "Not authorized.";
    return false;
  }

  return true;
}

function fillCourseSelect(selectId, allowEmpty = false) {
  const select = $(selectId);

  select.innerHTML =
    (allowEmpty ? `<option value="">General / No course</option>` : "") +
    enrollments.map(e =>
      `<option value="${e.course_id}">${e.course_title}</option>`
    ).join("");
}

async function loadStudent() {
  const { data, error } = await client.rpc("admin_student_detail", {
    p_student_id: studentId
  });

  if (error) throw error;

  studentData = data;
  enrollments = data.enrollments || [];

  const s = data.student;

  if (!s) throw new Error("Student not found");

  $("studentName").textContent = s.full_name_en || s.full_name;
  $("studentAcademic").textContent =
    `${s.curriculum || ""} • ${s.grade || ""}`;
  $("studentCode").textContent = s.student_code || "";
  $("studentPhone").textContent = s.phone || "—";
  $("studentStatus").textContent = s.status || "—";
  $("studentGrade").textContent = s.grade || "—";

  const guardian = data.guardians?.[0];
  $("guardianName").textContent = guardian?.full_name || "—";
  $("guardianPhone").textContent = guardian?.phone || "";

  renderEnrollments();
  renderGoals();
  renderNotes();
  renderReports();
  renderAcademicHistory();

  fillCourseSelect("attendanceCourse");
  fillCourseSelect("skillCourse");
  fillCourseSelect("goalCourse", true);
  fillCourseSelect("noteCourse", true);

  if (enrollments.length) {
    await loadSkills(enrollments[0].course_id);
  }
}

function renderEnrollments() {
  $("enrollmentsList").innerHTML = enrollments.length
    ? enrollments.map(e => `
      <div class="enrollment-row">
        <div>
          <strong>${e.course_title}</strong>
          <span>${e.status} • ${e.payment_status} • ${e.access_enabled ? "Access enabled" : "Access disabled"}</span>
        </div>

        ${
          e.payment_status !== "paid"
            ? `<button class="activate-btn" data-enrollment="${e.enrollment_id}">
                 Verify Payment & Activate
               </button>`
            : `<span class="paid-pill">Paid & Active</span>`
        }
      </div>
    `).join("")
    : `<p class="muted">No enrollments.</p>`;

  document.querySelectorAll(".activate-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      $("paymentEnrollmentId").value = btn.dataset.enrollment;
      $("paymentAmount").value = "";
      $("paymentReference").value = "";
      $("paymentMessage").textContent = "";
      $("paymentModal").classList.remove("hidden");
    });
  });
}

function renderGoals() {
  const rows = studentData.goals || [];

  $("goalsHistory").innerHTML =
    `<h3>Goal history</h3>` +
    (rows.length
      ? rows.map(g => `
        <div class="history-row">
          <strong>${g.title}</strong>
          <span>${g.status} • ${g.progress_percent}% ${g.target_date ? "• " + g.target_date : ""}</span>
        </div>
      `).join("")
      : `<p class="muted">No goals yet.</p>`);
}

function renderNotes() {
  const rows = studentData.teacher_notes || [];

  $("notesHistory").innerHTML =
    `<h3>Recent notes</h3>` +
    (rows.length
      ? rows.slice(0,8).map(n => `
        <div class="history-row">
          <strong>${n.note_type}</strong>
          <span>${n.note}</span>
        </div>
      `).join("")
      : `<p class="muted">No notes yet.</p>`);
}

function renderReports() {
  const rows = studentData.reports || [];

  $("reportsHistory").innerHTML =
    `<h3>Published reports</h3>` +
    (rows.length
      ? rows.map(r => `
        <div class="history-row">
          <strong>${r.period_name}</strong>
          <span>Overall ${r.overall_progress_percent ?? "—"}% • Assessment ${r.assessment_average ?? "—"}%</span>
        </div>
      `).join("")
      : `<p class="muted">No reports yet.</p>`);
}

function renderAcademicHistory() {
  const rows = studentData.academic_records || [];

  $("academicHistory").innerHTML = rows.length
    ? rows.map(r => `
      <div class="academic-row">
        <div><strong>${r.academic_year}</strong><span>${r.curriculum}</span></div>
        <div><strong>${r.grade}</strong><span>${r.status}</span></div>
        <div><strong>${r.final_overall_score ?? "—"}</strong><span>Final score</span></div>
      </div>
    `).join("")
    : `<p class="muted">No academic history.</p>`;
}

async function loadSkills(courseId) {
  if (!courseId) {
    $("skillSelect").innerHTML = "";
    return;
  }

  const { data, error } = await client.rpc("admin_skill_options", {
    p_course_id: courseId
  });

  if (error) throw error;

  $("skillSelect").innerHTML = (data || []).map(s =>
    `<option value="${s.skill_id}">${s.category} — ${s.skill_name}</option>`
  ).join("");
}

$("skillCourse").addEventListener("change", async e => {
  try {
    await loadSkills(e.target.value);
  } catch (err) {
    $("skillMessage").textContent = err.message;
  }
});

$("paymentForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("paymentMessage").textContent = "Verifying payment...";

  const { error } = await client.rpc("admin_verify_payment_and_activate", {
    p_enrollment_id: $("paymentEnrollmentId").value,
    p_amount: Number($("paymentAmount").value),
    p_method: $("paymentMethod").value,
    p_transaction_reference: $("paymentReference").value || null
  });

  if (error) {
    $("paymentMessage").textContent = error.message;
    return;
  }

  $("paymentMessage").textContent = "Payment verified and course activated.";

  await loadStudent();

  setTimeout(() => {
    $("paymentModal").classList.add("hidden");
  }, 700);
});

$("closePaymentModal").onclick = () =>
  $("paymentModal").classList.add("hidden");

$("attendanceForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("attendanceMessage").textContent = "Saving...";

  const f = new FormData(e.target);
  const rawDate = f.get("session_date");

  const { error } = await client.rpc("admin_record_attendance", {
    p_student_id: studentId,
    p_course_id: $("attendanceCourse").value,
    p_session_title: f.get("session_title"),
    p_session_date: new Date(rawDate).toISOString(),
    p_status: f.get("status"),
    p_minutes: Number(f.get("minutes") || 0),
    p_note: f.get("note") || ""
  });

  $("attendanceMessage").textContent =
    error ? error.message : "Attendance saved successfully.";
});

$("skillForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("skillMessage").textContent = "Saving...";

  const f = new FormData(e.target);

  const { error } = await client.rpc("admin_add_skill_rating", {
    p_student_id: studentId,
    p_course_id: $("skillCourse").value,
    p_skill_id: $("skillSelect").value,
    p_rating: Number(f.get("rating")),
    p_evidence: f.get("evidence") || "",
    p_teacher_note: f.get("teacher_note") || "",
    p_recommended_action: f.get("recommended_action") || ""
  });

  $("skillMessage").textContent =
    error ? error.message : "Skill rating saved successfully.";

  if (!error) e.target.reset();
});

$("goalForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("goalMessage").textContent = "Saving...";

  const f = new FormData(e.target);

  const { error } = await client.rpc("admin_add_learning_goal", {
    p_student_id: studentId,
    p_course_id: $("goalCourse").value || null,
    p_title: f.get("title"),
    p_description: f.get("description") || "",
    p_target_date: f.get("target_date") || null
  });

  if (error) {
    $("goalMessage").textContent = error.message;
    return;
  }

  $("goalMessage").textContent = "Learning goal added.";
  await loadStudent();
});

$("noteForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("noteMessage").textContent = "Saving...";

  const f = new FormData(e.target);

  const { error } = await client.rpc("admin_add_teacher_note", {
    p_student_id: studentId,
    p_course_id: $("noteCourse").value || null,
    p_note_type: f.get("note_type"),
    p_note: f.get("note"),
    p_parent_visible: f.get("parent_visible") === "on"
  });

  if (error) {
    $("noteMessage").textContent = error.message;
    return;
  }

  $("noteMessage").textContent = "Teacher note saved.";
  await loadStudent();
});

$("reportForm").addEventListener("submit", async e => {
  e.preventDefault();

  $("reportMessage").textContent = "Publishing...";

  const f = new FormData(e.target);

  const { error } = await client.rpc("admin_publish_progress_report", {
    p_student_id: studentId,
    p_period_name: f.get("period_name"),
    p_attendance: Number(f.get("attendance")),
    p_homework: Number(f.get("homework")),
    p_assessment: Number(f.get("assessment")),
    p_overall: Number(f.get("overall")),
    p_strengths: f.get("strengths") || "",
    p_improvements: f.get("improvements") || "",
    p_recommendation: f.get("recommendation") || ""
  });

  if (error) {
    $("reportMessage").textContent = error.message;
    return;
  }

  $("reportMessage").textContent = "Progress report published.";
  await loadStudent();
});

$("logoutBtn").onclick = async () => {
  await client.auth.signOut();
  location.href = "student-login.html";
};

(async () => {
  if (!studentId) {
    $("pageError").textContent = "Missing student ID.";
    return;
  }

  const ok = await requireStaff();
  if (!ok) return;

  try {
    await loadStudent();
  } catch (err) {
    console.error(err);
    $("pageError").textContent = err.message;
  }
})();
