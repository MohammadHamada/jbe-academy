
const $=id=>document.getElementById(id);
const lang=()=>JBE_I18N.getLanguage();
let catalog={},courses=[],teachers=[];

function nameOf(x){
  return lang()==="ar" ? (x.name_ar||x.name_en||x.code||"") : (x.name_en||x.name_ar||x.code||"");
}
function systemLabel(x){
  if((x.code||"").toUpperCase()==="NATIONAL"){
    return lang()==="ar"?"التعليم المصري":"Egyptian Education";
  }
  return nameOf(x);
}
function unique(arr,key,label){
  const m=new Map();
  arr.forEach(x=>{if(x[key])m.set(x[key],{id:x[key],label:label(x)})});
  return [...m.values()];
}
function fillFinder(){
  const systems=catalog.education_systems||[];
  $("homeSystem").innerHTML=systems.map(x=>`<option value="${x.id}">${systemLabel(x)}</option>`).join("");
  refreshHomeGrades();
}
function refreshHomeGrades(){
  const sid=$("homeSystem").value;
  const relatedCurr=(catalog.curricula||[]).filter(c=>c.education_system_id===sid).map(c=>c.id);
  const grades=(catalog.grades||[]).filter(g=>relatedCurr.includes(g.curriculum_id));
  $("homeGrade").innerHTML=`<option value="">${lang()==="ar"?"اختر الصف":"Choose grade"}</option>`+
    grades.map(g=>`<option value="${g.id}">${nameOf(g)}</option>`).join("");
  refreshHomeSubjects();
}
function refreshHomeSubjects(){
  const gid=$("homeGrade").value;
  const available=gid ? unique(courses.filter(c=>c.grade_level_id===gid),"subject_id",c=>lang()==="ar"?(c.subject_ar||c.subject_en):(c.subject_en||c.subject_ar)) : unique(courses,"subject_id",c=>lang()==="ar"?(c.subject_ar||c.subject_en):(c.subject_en||c.subject_ar));
  $("homeSubject").innerHTML=`<option value="">${lang()==="ar"?"اختر المادة":"Choose subject"}</option>`+
    available.map(x=>`<option value="${x.id}">${x.label}</option>`).join("");
}
function showFinderResult(){
  const sid=$("homeSystem").value,gid=$("homeGrade").value,sub=$("homeSubject").value;
  if(!gid||!sub){
    $("finderResult").hidden=false;
    $("finderResult").innerHTML=`<strong>${lang()==="ar"?"اختر الصف والمادة أولًا.":"Choose a grade and subject first."}</strong>`;
    return;
  }
  const rows=courses.filter(c=>c.education_system_id===sid&&c.grade_level_id===gid&&c.subject_id===sub);
  $("finderResult").hidden=false;
  $("finderResult").innerHTML=rows.length?`
    <div class="xp-result-grid">${rows.slice(0,3).map(c=>`
      <article class="xp-result-card">
        <strong>${lang()==="ar"?(c.title_ar||c.title_en):c.title_en}</strong>
        <small>${lang()==="ar"?(c.teacher_name_ar||c.teacher_name):(c.teacher_name||c.teacher_name_ar||"")}</small>
        <div class="xp-chips"><span class="xp-chip">${JBE_I18N.t(c.study_mode||"group")}</span>${c.price!=null?`<span class="xp-chip">${c.price} EGP</span>`:""}</div>
        <a class="xp-text-link" href="course.html?slug=${encodeURIComponent(c.slug)}">${lang()==="ar"?"عرض الكورس ←":"View course →"}</a>
      </article>`).join("")}</div>
    <div style="margin-top:14px"><a class="xp-primary" href="courses.html">${lang()==="ar"?"عرض كل الخيارات":"See all options"}</a></div>`
    :`<div><strong>${lang()==="ar"?"لا يوجد كورس منشور لهذا الاختيار حتى الآن.":"No published course for this selection yet."}</strong>
       <p style="color:#667085">${lang()==="ar"?"يمكنك إرسال طلب التسجيل وسيتواصل معك فريق القبول عند توفر الخيار المناسب.":"You can submit an inquiry and Admissions will follow up when a suitable option is available."}</p>
       <a class="xp-primary" href="register.html">${lang()==="ar"?"أرسل طلبك":"Send inquiry"}</a></div>`;
}
function teacherCard(t){
  const subjects=lang()==="ar"?t.subjects_ar:t.subjects_en;
  const grades=lang()==="ar"?t.grades_ar:t.grades_en;
  const headline=lang()==="ar"?(t.headline_ar||t.headline_en):(t.headline_en||t.headline_ar);
  return `<article class="xp-teacher-card">
    <div class="xp-teacher-photo">${t.photo_url?`<img src="${t.photo_url}" alt="${t.display_name}" loading="lazy">`:`<span class="xp-avatar">${(t.display_name||"?").split(" ").slice(-1)[0][0]||"J"}</span>`}</div>
    <div class="xp-teacher-body">
      <span class="xp-verified">✓ ${lang()==="ar"?"معلم معتمد":"Verified Teacher"}</span>
      <h3>${lang()==="ar"?(t.display_name_ar||t.display_name):(t.display_name||t.display_name_ar)}</h3>
      <p>${headline||""}</p>
      <div class="xp-chips">${(subjects||[]).slice(0,3).map(s=>`<span class="xp-chip">${s}</span>`).join("")}${(grades||[]).slice(0,2).map(g=>`<span class="xp-chip">${g}</span>`).join("")}</div>
      <a class="xp-text-link" href="teacher-profile.html?slug=${encodeURIComponent(t.slug)}">${lang()==="ar"?"عرض الملف ←":"View profile →"}</a>
    </div>
  </article>`;
}
function renderTeachers(){
  $("homeTeachers").innerHTML=teachers.length?teachers.map(teacherCard).join(""):`<p>${lang()==="ar"?"سيظهر المعلمون المعتمدون هنا.":"Verified teachers will appear here."}</p>`;
}
function renderSubjects(){
  const rows=unique(courses,"subject_id",c=>lang()==="ar"?(c.subject_ar||c.subject_en):(c.subject_en||c.subject_ar));
  const allSubjects=(catalog.subjects||[]).map(s=>({id:s.id,label:nameOf(s)}));
  const display=allSubjects.length?allSubjects:rows;
  $("homeSubjects").innerHTML=display.slice(0,8).map(s=>`
    <a class="xp-subject-card" href="courses.html">
      <b>${s.label}</b><span>${lang()==="ar"?"استكشف الصفوف والمعلمين المتاحين":"Explore available grades and teachers"} →</span>
    </a>`).join("");
}
$("homeSystem").onchange=refreshHomeGrades;
$("homeGrade").onchange=refreshHomeSubjects;
$("findProgramBtn").onclick=showFinderResult;
$("mobileToggle").onclick=()=>document.querySelector(".xp-menu").classList.toggle("open");
document.querySelectorAll("[data-audience]").forEach(btn=>btn.onclick=()=>{
  document.querySelectorAll("[data-audience]").forEach(b=>b.classList.toggle("active",b===btn));
  $("audienceStudent").hidden=btn.dataset.audience!=="student";
  $("audienceParent").hidden=btn.dataset.audience!=="parent";
});

async function boot(){
  const [catRes,courseRes,teacherRes]=await Promise.all([
    JBE.client.rpc("public_registration_options"),
    JBE.client.rpc("public_course_catalog"),
    JBE.client.rpc("public_featured_teachers")
  ]);
  if(!catRes.error) catalog=catRes.data||{};
  if(!courseRes.error) courses=courseRes.data||[];
  if(!teacherRes.error) teachers=teacherRes.data||[];
  fillFinder();renderTeachers();renderSubjects();
  JBE_I18N.apply();
}
window.addEventListener("jbe:languagechange",()=>{fillFinder();renderTeachers();renderSubjects();});
boot();
