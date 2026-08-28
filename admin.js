const { createClient } = supabase;
const cfg = window.JBE_CONFIG;
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $ = id => document.getElementById(id);
let allStudents=[], curriculumOptions=[], courseOptions=[];

async function requireStaff(){
  const {data:{session}} = await client.auth.getSession();
  if(!session){ location.href="student-login.html"; return null; }
  const {data:staff,error} = await client.from("staff").select("full_name,role,is_active").eq("auth_user_id",session.user.id).single();
  if(error || !staff?.is_active){ $("adminError").textContent="This account is not authorized as JBE Academy staff."; return null; }
  $("staffName").textContent=`${staff.full_name} • ${staff.role}`;
  return staff;
}

async function loadStats(){
  const {data,error}=await client.rpc("admin_dashboard_stats"); if(error) throw error;
  $("statStudents").textContent=data.students??0;
  $("statEnrollments").textContent=data.active_enrollments??0;
  $("statPaid").textContent=data.paid_enrollments??0;
  $("statPending").textContent=data.pending_payments??0;
  $("statCourses").textContent=data.courses??0;
}

function renderStudents(rows){
  $("studentsBody").innerHTML=rows.map(s=>`
    <tr>
      <td><b>${s.student_code||""}</b></td>
      <td><strong>${s.full_name_en||s.full_name}</strong><small>${s.phone||""}</small></td>
      <td>${s.curriculum||"—"}</td>
      <td>${s.grade||"—"}</td>
      <td>${s.active_courses??0}</td>
      <td><span class="badge ${s.payment_state==="paid"?"paid":""}">${s.payment_state||"unpaid"}</span></td>
    </tr>`).join("");
}

async function loadStudents(){
  const {data,error}=await client.rpc("admin_list_students"); if(error) throw error;
  allStudents=data||[]; renderStudents(allStudents);
}

async function loadOptions(){
  const [{data:c,error:ce},{data:co,error:coe}] = await Promise.all([
    client.rpc("admin_curriculum_options"), client.rpc("admin_course_options")
  ]);
  if(ce) throw ce; if(coe) throw coe;
  curriculumOptions=c||[]; courseOptions=co||[];
  const unique=[...new Map(curriculumOptions.map(x=>[x.curriculum_code,{code:x.curriculum_code,name:x.curriculum_name}])).values()];
  $("curriculumSelect").innerHTML=unique.map(x=>`<option value="${x.code}">${x.name}</option>`).join("");
  updateGrades();
}

function updateGrades(){
  const cur=$("curriculumSelect").value;
  const rows=curriculumOptions.filter(x=>x.curriculum_code===cur);
  $("gradeSelect").innerHTML=rows.map(x=>`<option value="${x.grade_code}">${x.grade_name}</option>`).join("");
  updateCourses();
}
function updateCourses(){
  const cur=$("curriculumSelect").value, grade=$("gradeSelect").value;
  const rows=courseOptions.filter(x=>x.curriculum_code===cur && x.grade_code===grade && x.status!=="draft");
  $("courseSelect").innerHTML=`<option value="">No course yet</option>`+rows.map(x=>`<option value="${x.slug}">${x.title_en}</option>`).join("");
}

$("studentSearch").addEventListener("input",e=>{
  const q=e.target.value.toLowerCase().trim();
  renderStudents(allStudents.filter(s=>(s.student_code||"").toLowerCase().includes(q)||(s.full_name||"").toLowerCase().includes(q)||(s.full_name_en||"").toLowerCase().includes(q)));
});
$("curriculumSelect").addEventListener("change",updateGrades);
$("gradeSelect").addEventListener("change",updateCourses);
$("openStudentForm").onclick=()=>$("studentModal").classList.remove("hidden");
$("closeStudentForm").onclick=()=>$("studentModal").classList.add("hidden");

$("studentForm").addEventListener("submit",async e=>{
  e.preventDefault(); $("formMessage").textContent="Creating student...";
  const f=new FormData(e.target);
  const {data,error}=await client.rpc("admin_create_student_bundle",{
    p_full_name:f.get("full_name"),
    p_full_name_en:f.get("full_name_en")||"",
    p_phone:f.get("phone")||"",
    p_guardian_name:f.get("guardian_name")||"",
    p_guardian_phone:f.get("guardian_phone")||"",
    p_relationship:f.get("relationship")||"",
    p_curriculum_code:f.get("curriculum_code"),
    p_grade_code:f.get("grade_code"),
    p_course_slug:f.get("course_slug")||null
  });
  if(error){ $("formMessage").textContent=error.message; return; }
  $("formMessage").textContent=`Student created: ${data.student_code}`;
  await Promise.all([loadStudents(),loadStats()]);
});

$("logoutBtn").onclick=async()=>{ await client.auth.signOut(); location.href="student-login.html"; };

(async()=>{ const staff=await requireStaff(); if(!staff) return;
  try{ await Promise.all([loadStats(),loadStudents(),loadOptions()]); }
  catch(err){ console.error(err); $("adminError").textContent=err.message; }
})();
