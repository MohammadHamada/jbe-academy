const $=id=>document.getElementById(id);
const L=()=>window.JBE_I18N?.getLanguage?.()||"ar";
let catalog={systems:[],pathways:[],pathway_curricula:[],curricula:[],stages:[],grades:[],grade_subjects:[],subjects:[]};
let teachers=[],courses=[],featuredSubjects=[];

function tx(ar,en){return L()==="ar"?ar:en}
function nm(x){return L()==="ar"?(x?.name_ar||x?.name_en||""):(x?.name_en||x?.name_ar||"")}
function gradeNm(g){return L()==="ar"?(g?.local_name_ar||g?.name_ar||g?.name_en||""):(g?.local_name_en||g?.name_en||g?.name_ar||"")}
function setOptions(el,rows,placeholder,labelFn=nm){el.innerHTML=`<option value="">${placeholder}</option>`+rows.map(x=>`<option value="${x.id}">${labelFn(x)}</option>`).join("")}
function curriculaForPathway(pid){return catalog.pathway_curricula.filter(x=>x.pathway_id===pid).map(x=>x.curriculum_id)}
function stagesForPathway(pid){
  const cids=curriculaForPathway(pid);
  const sids=new Set(catalog.grades.filter(g=>cids.includes(g.curriculum_id)).map(g=>g.stage_id).filter(Boolean));
  return catalog.stages.filter(s=>sids.has(s.id)).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
}
function gradesFor(pid,stageId){
  const cids=curriculaForPathway(pid),seen=new Set();
  return catalog.grades.filter(g=>cids.includes(g.curriculum_id)&&(!stageId||g.stage_id===stageId))
    .sort((a,b)=>(a.sort_order||0)-(b.sort_order||0))
    .filter(g=>{const key=(g.code||"")+"|"+gradeNm(g);if(seen.has(key))return false;seen.add(key);return true});
}
function subjectsFor(pid,grade){
  if(!grade)return[];
  const cids=curriculaForPathway(pid);
  const gradeIds=catalog.grades.filter(g=>cids.includes(g.curriculum_id)&&((g.code&&g.code===grade.code)||g.id===grade.id)).map(g=>g.id);
  const sids=new Set(catalog.grade_subjects.filter(m=>cids.includes(m.curriculum_id)&&gradeIds.includes(m.grade_level_id)).map(m=>m.subject_id));
  return catalog.subjects.filter(s=>sids.has(s.id)).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
}
function show(el,yes=true){el.hidden=!yes}
function clearDownstream(from){
  const items={pathway:$("pathwayStep"),stage:$("stageStep"),grade:$("gradeStep"),subject:$("subjectStep"),submit:$("finderSubmit")};
  const order=["pathway","stage","grade","subject","submit"],i=order.indexOf(from);
  order.slice(i).forEach(k=>show(items[k],false));
  $("finderResults").hidden=true;
}
function updateProgress(){
  let n=1;if($("finderPathway").value)n=2;if($("finderStage").value)n=3;if($("finderGrade").value)n=4;if($("finderSubject").value)n=5;
  $("finderProgress").style.width=`${n*20}%`;
}
function renderContext(p){
  if(!p){$("finderContext").hidden=true;return}
  $("finderContext").hidden=false;
  $("finderContext").innerHTML=`<strong>${nm(p)}</strong><span>${L()==="ar"?(p.description_ar||p.description_en||""):(p.description_en||p.description_ar||"")}</span>`;
}
function initFinder(){
  setOptions($("finderSystem"),catalog.systems,tx("اختر نظام التعليم","Choose education system"));
  clearDownstream("pathway");updateProgress();$("finderContext").hidden=true;
}
$("finderSystem").addEventListener("change",()=>{
  const sid=$("finderSystem").value;clearDownstream("pathway");$("finderContext").hidden=true;
  if(!sid){updateProgress();return}
  const rows=catalog.pathways.filter(p=>p.education_system_id===sid).sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));
  setOptions($("finderPathway"),rows,tx("اختر المسار / المنهج","Choose pathway / curriculum"));
  show($("pathwayStep"),true);updateProgress();
});
$("finderPathway").addEventListener("change",()=>{
  const pid=$("finderPathway").value;clearDownstream("stage");
  const p=catalog.pathways.find(x=>x.id===pid);renderContext(p);
  if(!pid){updateProgress();return}
  setOptions($("finderStage"),stagesForPathway(pid),tx("اختر المرحلة","Choose stage"));
  show($("stageStep"),true);updateProgress();
});
$("finderStage").addEventListener("change",()=>{
  const pid=$("finderPathway").value,sid=$("finderStage").value;clearDownstream("grade");
  if(!sid){updateProgress();return}
  setOptions($("finderGrade"),gradesFor(pid,sid),tx("اختر الصف / السنة","Choose grade / year"),gradeNm);
  show($("gradeStep"),true);updateProgress();
});
$("finderGrade").addEventListener("change",()=>{
  const pid=$("finderPathway").value,gid=$("finderGrade").value;clearDownstream("subject");
  if(!gid){updateProgress();return}
  const grade=catalog.grades.find(g=>g.id===gid);
  setOptions($("finderSubject"),subjectsFor(pid,grade),tx("اختر المادة","Choose subject"));
  show($("subjectStep"),true);updateProgress();
});
$("finderSubject").addEventListener("change",()=>{show($("finderSubmit"),!!$("finderSubject").value);updateProgress()});

function courseMatches(c,pid,grade,subjectId){
  const cids=curriculaForPathway(pid);if(!cids.includes(c.curriculum_id)||c.subject_id!==subjectId)return false;
  const cg=catalog.grades.find(g=>g.id===c.grade_level_id);return !!cg&&!!grade&&(cg.code===grade.code||cg.id===grade.id);
}
function courseCard(c){
  const title=L()==="ar"?(c.title_ar||c.title_en):(c.title_en||c.title_ar);
  const teacher=L()==="ar"?(c.teacher_name_ar||c.teacher_name||""):(c.teacher_name||c.teacher_name_ar||"");
  const subject=L()==="ar"?(c.subject_ar||c.subject_en||""):(c.subject_en||c.subject_ar||"");
  return `<article class="v28-program-card"><div class="v28-program-top"><span>${JBE_I18N.t(c.study_mode||"group")}</span>${c.price!=null?`<b>${c.price} ${c.currency||"EGP"}</b>`:""}</div><h3>${title||""}</h3><p>${teacher}</p><div class="v28-chips">${c.grade_name?`<span>${c.grade_name}</span>`:""}${subject?`<span>${subject}</span>`:""}</div><a href="course.html?slug=${encodeURIComponent(c.slug)}">${tx("عرض الكورس ←","View course →")}</a></article>`;
}
$("finderSubmit").addEventListener("click",()=>{
  const pid=$("finderPathway").value,grade=catalog.grades.find(g=>g.id===$("finderGrade").value),subjectId=$("finderSubject").value,subject=catalog.subjects.find(s=>s.id===subjectId);
  const rows=courses.filter(c=>courseMatches(c,pid,grade,subjectId));
  $("finderResults").hidden=false;
  $("finderResults").innerHTML=rows.length?`<div class="v28-results-head"><div><strong>${gradeNm(grade)} • ${nm(subject)}</strong><span>${tx("الخيارات المنشورة حاليًا","Currently published options")}</span></div></div><div class="v28-result-grid">${rows.slice(0,6).map(courseCard).join("")}</div>`:`<div class="v28-empty"><strong>${tx("لا يوجد كورس منشور لهذا الاختيار حتى الآن.","No published course is available for this selection yet.")}</strong><p>${tx("يمكنك إرسال طلب تسجيل، وسيتابع فريق القبول معك عند توفر المعلم أو الكورس المناسب.","You can submit an inquiry and Admissions will follow up when a suitable teacher or course becomes available.")}</p><a class="v28-primary" href="register.html">${tx("أرسل طلبك","Send inquiry")}</a></div>`;
});

function teacherCard(t){
  const subjects=L()==="ar"?t.subjects_ar:t.subjects_en,grades=L()==="ar"?t.grades_ar:t.grades_en;
  const display=L()==="ar"?(t.display_name_ar||t.display_name):(t.display_name||t.display_name_ar);
  const headline=L()==="ar"?(t.headline_ar||t.headline_en):(t.headline_en||t.headline_ar);
  const initials=(display||"J").split(" ").filter(Boolean).map(x=>x[0]).slice(0,2).join("");
  return `<article class="v28-teacher-card"><div class="v28-teacher-photo">${t.photo_url?`<img src="${t.photo_url}" alt="${display}" loading="lazy">`:`<span>${initials}</span>`}</div><div class="v28-teacher-body"><small class="v28-verified">✓ ${tx("معلم معتمد","Verified Teacher")}</small><h3>${display}</h3><p>${headline||""}</p><div class="v28-chips">${(subjects||[]).slice(0,3).map(x=>`<span>${x}</span>`).join("")}${(grades||[]).slice(0,2).map(x=>`<span>${x}</span>`).join("")}</div><a href="teacher-profile.html?slug=${encodeURIComponent(t.slug)}">${tx("عرض الملف ←","View profile →")}</a></div></article>`;
}
function renderTeachers(){$("v28Teachers").innerHTML=teachers.length?teachers.slice(0,6).map(teacherCard).join(""):`<div class="v28-empty"><strong>${tx("سيظهر المعلمون المعتمدون هنا.","Verified teachers will appear here.")}</strong></div>`}
function renderPrograms(){$("v28Programs").innerHTML=courses.length?courses.slice(0,6).map(courseCard).join(""):`<div class="v28-empty"><strong>${tx("سيتم نشر البرامج المتاحة هنا.","Available programs will be published here.")}</strong></div>`}
function subjectIcon(k){return({calculator:"∑",science:"⚗",language:"A",business:"▦",economics:"↗",computer:"⌘",globe:"◎",art:"✦",book:"▤"})[k]||"•"}
function renderSubjects(){
  $("v28Subjects").innerHTML=featuredSubjects.length?featuredSubjects.map(s=>`<a class="v28-subject-card" href="#finder"><span class="v28-subject-icon">${subjectIcon(s.icon_key)}</span><b>${L()==="ar"?(s.name_ar||s.name_en):s.name_en}</b><small>${L()==="ar"?`${s.active_grades} صفوف متاحة`:`Available in ${s.active_grades} grades`}</small><em>${tx("ابدأ الاختيار ←","Start exploring →")}</em></a>`).join(""):`<div class="v28-empty"><strong>${tx("لم يحدد المسؤول مواد مميزة للصفحة الرئيسية بعد.","No featured homepage subjects have been selected yet.")}</strong></div>`;
}
document.querySelectorAll("[data-audience]").forEach(btn=>btn.addEventListener("click",()=>{document.querySelectorAll("[data-audience]").forEach(b=>b.classList.toggle("active",b===btn));$("studentPreview").hidden=btn.dataset.audience!=="student";$("parentPreview").hidden=btn.dataset.audience!=="parent"}));
$("v28MobileMenu").addEventListener("click",()=>document.querySelector(".v28-menu").classList.toggle("open"));

async function boot(){
  const [a,b,c,d]=await Promise.all([
    JBE.client.rpc("public_academic_catalog_v28"),
    JBE.client.rpc("public_featured_teachers"),
    JBE.client.rpc("public_course_catalog"),
    JBE.client.rpc("public_featured_subjects_v28")
  ]);
  if(!a.error)catalog=a.data||catalog;else console.error(a.error);
  if(!b.error)teachers=b.data||[];else console.error(b.error);
  if(!c.error)courses=c.data||[];else console.error(c.error);
  if(!d.error)featuredSubjects=d.data||[];else console.error(d.error);
  initFinder();renderTeachers();renderPrograms();renderSubjects();window.JBE_PAGE_I18N?.apply(document);
}
window.addEventListener("jbe:languagechange",()=>{initFinder();renderTeachers();renderPrograms();renderSubjects();window.JBE_PAGE_I18N?.apply(document)});
boot();
