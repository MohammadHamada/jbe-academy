
const $=id=>document.getElementById(id);let cat={},courses=[],teachers=[];
const L=()=>JBE_I18N.getLanguage(),tx=(ar,en)=>L()==="ar"?ar:en;
const nm=x=>L()==="ar"?(x?.name_ar||x?.name_en||""):(x?.name_en||x?.name_ar||"");
const gnm=g=>L()==="ar"?(g?.local_name_ar||g?.name_ar||g?.name_en||""):(g?.local_name_en||g?.name_en||g?.name_ar||"");
function opts(el,rows,ph,label=nm){el.innerHTML=`<option value="">${ph}</option>`+rows.map(x=>`<option value="${x.id}">${label(x)}</option>`).join("")}
function currForPath(pid){return(cat.pathway_curricula||[]).filter(x=>x.pathway_id===pid).map(x=>x.curriculum_id)}
function stagesFor(pid){const cs=currForPath(pid),ids=new Set((cat.grades||[]).filter(g=>cs.includes(g.curriculum_id)).map(g=>g.stage_id));return(cat.stages||[]).filter(s=>ids.has(s.id)).sort((a,b)=>a.sort_order-b.sort_order)}
function gradesFor(pid,sid){const cs=currForPath(pid),seen=new Set();return(cat.grades||[]).filter(g=>cs.includes(g.curriculum_id)&&g.stage_id===sid).sort((a,b)=>a.sort_order-b.sort_order).filter(g=>{const k=g.code+"|"+gnm(g);if(seen.has(k))return false;seen.add(k);return true})}
function subjectsFor(pid,grade){const cs=currForPath(pid),gids=(cat.grades||[]).filter(g=>cs.includes(g.curriculum_id)&&g.code===grade.code).map(g=>g.id),sids=new Set((cat.grade_subjects||[]).filter(m=>cs.includes(m.curriculum_id)&&gids.includes(m.grade_level_id)).map(m=>m.subject_id));return(cat.subjects||[]).filter(s=>sids.has(s.id)).sort((a,b)=>a.sort_order-b.sort_order)}
function actualGradeRecords(){const pid=$("pathway").value,grade=(cat.grades||[]).find(g=>g.id===$("grade").value);if(!pid||!grade)return[];const cs=currForPath(pid);return(cat.grades||[]).filter(g=>cs.includes(g.curriculum_id)&&g.code===grade.code)}
function refreshPath(){const sid=$("system").value;opts($("pathway"),(cat.pathways||[]).filter(p=>p.education_system_id===sid),tx("اختر المسار / المنهج","Choose pathway / curriculum"));refreshStage()}
function refreshStage(){const p=$("pathway").value;opts($("stage"),p?stagesFor(p):[],tx("اختر المرحلة","Choose stage"));refreshGrade()}
function refreshGrade(){const p=$("pathway").value,s=$("stage").value;opts($("grade"),p&&s?gradesFor(p,s):[],tx("اختر الصف / السنة","Choose grade / year"),gnm);refreshSubject()}
function refreshSubject(){const p=$("pathway").value,g=(cat.grades||[]).find(x=>x.id===$("grade").value);opts($("subject"),p&&g?subjectsFor(p,g):[],tx("اختر المادة","Choose subject"));refreshChoices()}
function refreshChoices(){
  const subject=$("subject").value,grades=actualGradeRecords(),gradeIds=grades.map(x=>x.id),currIds=grades.map(x=>x.curriculum_id);
  const cs=courses.filter(c=>(!subject||c.subject_id===subject)&&(!gradeIds.length||gradeIds.includes(c.grade_level_id))&&(!currIds.length||currIds.includes(c.curriculum_id)));
  const tids=new Set(cs.map(c=>c.teacher_id).filter(Boolean));
  $("teacher").innerHTML=`<option value="">${tx("لا يوجد تفضيل","No preference")}</option>`+teachers.filter(t=>!tids.size||tids.has(t.id)).map(t=>`<option value="${t.id}">${t.display_name}</option>`).join("");
  refreshCourses();
}
function refreshCourses(){
  const subject=$("subject").value,tid=$("teacher").value,grades=actualGradeRecords(),gradeIds=grades.map(x=>x.id),currIds=grades.map(x=>x.curriculum_id);
  const cs=courses.filter(c=>(!subject||c.subject_id===subject)&&(!tid||c.teacher_id===tid)&&(!gradeIds.length||gradeIds.includes(c.grade_level_id))&&(!currIds.length||currIds.includes(c.curriculum_id)));
  $("preferredCourse").innerHTML=`<option value="">${tx("لا يوجد تفضيل","No preference")}</option>`+cs.map(c=>`<option value="${c.course_id}">${L()==="ar"?(c.title_ar||c.title_en):(c.title_en||c.title_ar)}</option>`).join("");
}
async function load(){
  const [a,b,c]=await Promise.all([JBE.client.rpc("public_academic_catalog_v28"),JBE.client.rpc("public_course_catalog"),JBE.client.rpc("public_registration_options")]);
  if(a.error||b.error||c.error){$("message").textContent=(a.error||b.error||c.error).message;return}
  cat=a.data||{};courses=b.data||[];teachers=c.data?.teachers||[];
  opts($("system"),cat.systems||[],tx("اختر نظام التعليم","Choose education system"));refreshPath();window.JBE_PAGE_I18N?.apply(document);
}
$("system").onchange=refreshPath;$("pathway").onchange=refreshStage;$("stage").onchange=refreshGrade;$("grade").onchange=refreshSubject;$("subject").onchange=refreshChoices;$("teacher").onchange=refreshCourses;
$("registrationForm").onsubmit=async e=>{
  e.preventDefault();const f=new FormData(e.target),gradeCandidates=actualGradeRecords(),course=courses.find(c=>c.course_id===$("preferredCourse").value);
  const chosenGrade=course?gradeCandidates.find(g=>g.id===course.grade_level_id):(gradeCandidates[0]||null);
  const curriculumId=course?.curriculum_id||chosenGrade?.curriculum_id||null;
  $("message").textContent=tx("جارٍ الإرسال...","Submitting...");
  const {data,error}=await JBE.client.rpc("public_submit_application_v25",{
    p_student_name:f.get("student_name"),p_student_name_en:f.get("student_name_en")||"",p_student_phone:f.get("student_phone")||"",p_student_email:f.get("student_email")||"",
    p_guardian_name:f.get("guardian_name")||"",p_guardian_phone:f.get("guardian_phone")||"",p_guardian_email:f.get("guardian_email")||"",p_relationship:f.get("relationship")||"",
    p_education_system_id:$("system").value||null,p_curriculum_id:curriculumId,p_stage_id:$("stage").value||null,p_grade_level_id:course?.grade_level_id||chosenGrade?.id||null,
    p_subject_id:$("subject").value||null,p_preferred_teacher_id:$("teacher").value||null,p_preferred_course_id:$("preferredCourse").value||null,p_source:"website",p_notes:f.get("notes")||""
  });
  if(error){$("message").textContent=error.message;$("message").className="error";return}
  $("message").textContent=tx(`تم استلام طلب التسجيل بنجاح. كود الطلب: ${data.application_code}`,`Registration received successfully. Your application code is ${data.application_code}.`);
  $("message").className="success";e.target.reset();await load();
};
window.addEventListener("jbe:languagechange",()=>load());load();
