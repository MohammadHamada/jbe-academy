
const $=id=>document.getElementById(id);
let o={};

async function load(){
  const {data,error}=await JBE.client.rpc("public_registration_options");
  if(error){$("message").textContent=error.message;$("message").className="error";return;}
  o=data;
  $("system").innerHTML=o.education_systems.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  $("subject").innerHTML=o.subjects.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  $("teacher").innerHTML=`<option value="">No preference</option>`+(o.teachers||[]).map(x=>`<option value="${x.id}">${x.display_name}</option>`).join("");
  refreshCurricula();
}
function refreshCurricula(){
  const sid=$("system").value;
  const rows=o.curricula.filter(x=>x.education_system_id===sid);
  $("curriculum").innerHTML=rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  refreshStages();
}
function refreshStages(){
  const sid=$("system").value;
  const rows=o.stages.filter(x=>x.education_system_id===sid);
  $("stage").innerHTML=`<option value="">Select stage</option>`+rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  refreshGrades();
}
function refreshGrades(){
  const cid=$("curriculum").value, st=$("stage").value;
  let rows=o.grades.filter(x=>x.curriculum_id===cid);
  if(st) rows=rows.filter(x=>x.stage_id===st);
  $("grade").innerHTML=rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
}
$("system").onchange=refreshCurricula;
$("curriculum").onchange=refreshStages;
$("stage").onchange=refreshGrades;

$("registrationForm").onsubmit=async e=>{
  e.preventDefault();
  const f=new FormData(e.target);
  $("message").textContent="Submitting...";
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
  if(error){$("message").textContent=error.message;$("message").className="error";return;}
  $("message").textContent=`Registration received successfully. Your application code is ${data.application_code}.`;
  $("message").className="success"; e.target.reset(); await load();
};
load();
