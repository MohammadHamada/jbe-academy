const $ = id => document.getElementById(id);
let options = {};

function displayName(x){
  return JBE_I18N.getLanguage()==="ar"
    ? (x.name_ar || x.name_en || x.code || "")
    : (x.name_en || x.name_ar || x.code || "");
}

async function load(){
  const {data,error}=await JBE.client.rpc("public_registration_options");

  if(error){
    $("message").textContent=error.message;
    $("message").className="error";
    return;
  }

  options=data||{};

  $("system").innerHTML=(options.education_systems||[])
    .map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");

  $("subject").innerHTML=(options.subjects||[])
    .map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");

  $("teacher").innerHTML=
    `<option value="">${JBE_I18N.t("No preference")}</option>`+
    (options.teachers||[]).map(x=>`<option value="${x.id}">${x.display_name}</option>`).join("");

  refreshCurricula();
}

function refreshCurricula(){
  const systemId=$("system").value;
  const rows=(options.curricula||[]).filter(x=>x.education_system_id===systemId);

  $("curriculum").innerHTML=rows
    .map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");

  refreshStages();
}

function refreshStages(){
  const systemId=$("system").value;
  const rows=(options.stages||[]).filter(x=>x.education_system_id===systemId);

  $("stage").innerHTML=
    `<option value="">${JBE_I18N.t("Select stage")}</option>`+
    rows.map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");

  refreshGrades();
}

function refreshGrades(){
  const curriculumId=$("curriculum").value;
  const stageId=$("stage").value;
  let rows=(options.grades||[]).filter(x=>x.curriculum_id===curriculumId);

  if(stageId){
    rows=rows.filter(x=>x.stage_id===stageId);
  }

  $("grade").innerHTML=rows
    .map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");
}

$("system").onchange=refreshCurricula;
$("curriculum").onchange=refreshStages;
$("stage").onchange=refreshGrades;

$("registrationForm").onsubmit=async e=>{
  e.preventDefault();

  const f=new FormData(e.target);
  $("message").textContent=JBE_I18N.t("Submitting...");

  const {data,error}=await JBE.client.rpc("public_submit_application",{
    p_student_name:f.get("student_name"),
    p_student_name_en:f.get("student_name_en")||"",
    p_student_phone:f.get("student_phone")||"",
    p_student_email:f.get("student_email")||"",
    p_guardian_name:f.get("guardian_name")||"",
    p_guardian_phone:f.get("guardian_phone")||"",
    p_guardian_email:f.get("guardian_email")||"",
    p_relationship:f.get("relationship")||"",
    p_education_system_id:$("system").value||null,
    p_curriculum_id:$("curriculum").value||null,
    p_stage_id:$("stage").value||null,
    p_grade_level_id:$("grade").value||null,
    p_subject_id:$("subject").value||null,
    p_preferred_teacher_id:$("teacher").value||null,
    p_source:"website",
    p_notes:f.get("notes")||""
  });

  if(error){
    $("message").textContent=error.message;
    $("message").className="error";
    return;
  }

  $("message").textContent=
    JBE_I18N.getLanguage()==="ar"
      ? `تم استلام طلب التسجيل بنجاح. كود الطلب: ${data.application_code}`
      : `Registration received successfully. Your application code is ${data.application_code}.`;

  $("message").className="success";

  e.target.reset();
  await load();
};

window.addEventListener("jbe:languagechange",load);
load();
