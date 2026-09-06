
const $=id=>document.getElementById(id);let courses=[];
const lang=()=>JBE_I18N.getLanguage();
const choose=(r,en,ar)=>lang()==="ar"?(r[ar]||r[en]||""):(r[en]||r[ar]||"");
function unique(arr,key,label){const m=new Map();arr.forEach(x=>{if(x[key])m.set(x[key],{id:x[key],label:label(x)})});return [...m.values()].sort((a,b)=>a.label.localeCompare(b.label))}
function fillFilters(){
 const current={s:$("fSystem").value,g:$("fGrade").value,u:$("fSubject").value,t:$("fTeacher").value};
 const opts=(id,rows,all)=>{$(id).innerHTML=`<option value="">${JBE_I18N.t(all)}</option>`+rows.map(x=>`<option value="${x.id}">${x.label}</option>`).join("")};
 opts("fSystem",unique(courses,"education_system_id",x=>choose(x,"education_system_en","education_system_ar")),"All systems");
 opts("fGrade",unique(courses,"grade_level_id",x=>choose(x,"grade_en","grade_ar")),"All grades");
 opts("fSubject",unique(courses,"subject_id",x=>choose(x,"subject_en","subject_ar")),"All subjects");
 opts("fTeacher",unique(courses,"teacher_id",x=>lang()==="ar"?(x.teacher_name_ar||x.teacher_name):(x.teacher_name||x.teacher_name_ar)),"All teachers");
 $("fSystem").value=current.s;$("fGrade").value=current.g;$("fSubject").value=current.u;$("fTeacher").value=current.t;
}
function render(){
 const q=$("fSearch").value.toLowerCase().trim(),s=$("fSystem").value,g=$("fGrade").value,u=$("fSubject").value,t=$("fTeacher").value;
 const rows=courses.filter(x=>(!s||x.education_system_id===s)&&(!g||x.grade_level_id===g)&&(!u||x.subject_id===u)&&(!t||x.teacher_id===t)&&(!q||`${x.title_en} ${x.title_ar||""} ${x.teacher_name||""}`.toLowerCase().includes(q)));
 $("courseGrid").innerHTML=rows.map(x=>`<article class="ops-card"><span class="ops-badge">${choose(x,"subject_en","subject_ar")}</span><h2>${lang()==="ar"?(x.title_ar||x.title_en):x.title_en}</h2><p class="ops-muted">${choose(x,"education_system_en","education_system_ar")} • ${choose(x,"grade_en","grade_ar")}</p><p>${lang()==="ar"?(x.teacher_name_ar||x.teacher_name||""):(x.teacher_name||x.teacher_name_ar||"")}</p><p><b>${JBE_I18N.t("Price")}:</b> ${x.price??"—"} EGP</p><p><b>${JBE_I18N.t("Study mode")}:</b> ${JBE_I18N.t(x.study_mode||"—")}</p><a class="ops-btn gold" href="course.html?slug=${encodeURIComponent(x.slug)}">${JBE_I18N.t("View Course")}</a></article>`).join("")||`<p class="ops-muted">${JBE_I18N.t("No matching courses")}</p>`;
 JBE_I18N.apply();
}
["fSystem","fGrade","fSubject","fTeacher"].forEach(id=>$(id).onchange=render);$("fSearch").oninput=render;
(async()=>{const {data,error}=await JBE.client.rpc("public_course_catalog");if(error){$("msg").textContent=error.message;return}courses=data||[];fillFilters();render()})();
window.addEventListener("jbe:languagechange",()=>{fillFilters();render()});
