
const $=id=>document.getElementById(id);
let options={},courses=[];

function displayName(x){
  return JBE_I18N.getLanguage()==="ar"
    ? (x.name_ar||x.name_en||x.code||"")
    : (x.name_en||x.name_ar||x.code||"");
}
function courseName(x){
  return JBE_I18N.getLanguage()==="ar"
    ? (x.title_ar||x.title_en||"")
    : (x.title_en||x.title_ar||"");
}
async function load(){
 const [or,cr]=await Promise.all([
   JBE.client.rpc("public_registration_options"),
   JBE.client.rpc("public_course_catalog")
 ]);
 if(or.error||cr.error){$("message").textContent=(or.error||cr.error).message;return}
 options=or.data||{};courses=cr.data||[];
 $("system").innerHTML=(options.education_systems||[]).map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");
 $("subject").innerHTML=(options.subjects||[]).map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");
 $("teacher").innerHTML=`<option value="">${JBE_I18N.t("No preference")}</option>`+(options.teachers||[]).map(x=>`<option value="${x.id}">${x.display_name}</option>`).join("");
 refreshCurricula();
 const slug=new URLSearchParams(location.search).get("course");
 if(slug){
   const c=courses.find(x=>x.slug===slug);
   if(c){
     $("system").value=c.education_system_id;refreshCurricula();
     $("curriculum").value=c.curriculum_id;refreshStages();
     if(c.stage_id)$("stage").value=c.stage_id;refreshGrades();
     $("grade").value=c.grade_level_id;$("subject").value=c.subject_id;
     if(c.teacher_id)$("teacher").value=c.teacher_id;
     refreshCourses();$("preferredCourse").value=c.course_id;
   }
 }
}
function refreshCurricula(){
 const sid=$("system").value,rows=(options.curricula||[]).filter(x=>x.education_system_id===sid);
 $("curriculum").innerHTML=rows.map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");refreshStages();
}
function refreshStages(){
 const sid=$("system").value,rows=(options.stages||[]).filter(x=>x.education_system_id===sid);
 $("stage").innerHTML=`<option value="">${JBE_I18N.t("Select stage")}</option>`+rows.map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");refreshGrades();
}
function refreshGrades(){
 const cid=$("curriculum").value,st=$("stage").value;let rows=(options.grades||[]).filter(x=>x.curriculum_id===cid);if(st)rows=rows.filter(x=>x.stage_id===st);
 $("grade").innerHTML=rows.map(x=>`<option value="${x.id}">${displayName(x)}</option>`).join("");refreshCourses();
}
function refreshCourses(){
 const cid=$("curriculum").value,gid=$("grade").value,sid=$("subject").value,tid=$("teacher").value;
 const rows=courses.filter(x=>(!cid||x.curriculum_id===cid)&&(!gid||x.grade_level_id===gid)&&(!sid||x.subject_id===sid)&&(!tid||x.teacher_id===tid));
 $("preferredCourse").innerHTML=`<option value="">${JBE_I18N.t("No preference")}</option>`+rows.map(x=>`<option value="${x.course_id}">${courseName(x)}</option>`).join("");
}
$("system").onchange=refreshCurricula;$("curriculum").onchange=refreshStages;$("stage").onchange=refreshGrades;
$("grade").onchange=refreshCourses;$("subject").onchange=refreshCourses;$("teacher").onchange=refreshCourses;
$("registrationForm").onsubmit=async e=>{
 e.preventDefault();const f=new FormData(e.target);$("message").textContent=JBE_I18N.t("Submitting...");
 const {data,error}=await JBE.client.rpc("public_submit_application_v25",{
  p_student_name:f.get("student_name"),p_student_name_en:f.get("student_name_en")||"",p_student_phone:f.get("student_phone")||"",p_student_email:f.get("student_email")||"",
  p_guardian_name:f.get("guardian_name")||"",p_guardian_phone:f.get("guardian_phone")||"",p_guardian_email:f.get("guardian_email")||"",p_relationship:f.get("relationship")||"",
  p_education_system_id:$("system").value||null,p_curriculum_id:$("curriculum").value||null,p_stage_id:$("stage").value||null,p_grade_level_id:$("grade").value||null,
  p_subject_id:$("subject").value||null,p_preferred_teacher_id:$("teacher").value||null,p_preferred_course_id:$("preferredCourse").value||null,p_source:"website",p_notes:f.get("notes")||""
 });
 if(error){$("message").textContent=error.message;$("message").className="error";return}
 $("message").textContent=JBE_I18N.getLanguage()==="ar"?`تم استلام طلب التسجيل بنجاح. كود الطلب: ${data.application_code}`:`Registration received successfully. Your application code is ${data.application_code}.`;
 $("message").className="success";e.target.reset();await load();
};
window.addEventListener("jbe:languagechange",()=>{load()});load();
