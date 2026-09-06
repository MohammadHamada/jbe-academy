
const $=id=>document.getElementById(id);const slug=new URLSearchParams(location.search).get("slug");let d=null;
function label(en,ar){return JBE_I18N.getLanguage()==="ar"?(ar||en||""):(en||ar||"")}
function render(){
 if(!d)return;const c=d.course,t=d.teacher;
 $("courseHero").innerHTML=`<span class="ops-eyebrow">${label(c.subject_en,c.subject_ar)}</span><h1>${label(c.title_en,c.title_ar)}</h1><p>${label(c.education_system_en,c.education_system_ar)} • ${label(c.curriculum_en,c.curriculum_ar)} • ${label(c.grade_en,c.grade_ar)}</p>`;
 $("courseInfo").innerHTML=`<article class="ops-card"><h2>${JBE_I18N.t("Course Details")}</h2><p><b>${JBE_I18N.t("Price")}:</b> ${c.price??"—"} ${c.currency}</p><p><b>${JBE_I18N.t("Duration")}:</b> ${c.duration_minutes??"—"} min</p><p><b>${JBE_I18N.t("Study mode")}:</b> ${JBE_I18N.t(c.study_mode||"—")}</p><p><b>${JBE_I18N.t("Billing type")}:</b> ${JBE_I18N.t(c.billing_type||"—")}</p><a class="ops-btn gold" href="register.html?course=${encodeURIComponent(c.slug)}">${JBE_I18N.t("Register for this course")}</a></article>${t?`<article class="ops-card"><h2>${JBE_I18N.t("Teacher")}</h2><h3>${label(t.display_name,t.display_name_ar)}</h3><p>${label(t.headline_en,t.headline_ar)}</p><a class="ops-btn light" href="teacher-profile.html?slug=${encodeURIComponent(t.slug)}">${JBE_I18N.t("View Profile")}</a></article>`:""}`;
 $("groupList").innerHTML=(d.groups||[]).map(g=>`<div class="ops-item"><div class="ops-item-main"><strong>${g.name}</strong><small>${g.start_time||"—"} • ${g.duration_minutes} min • ${g.active_students}/${g.capacity??"∞"}</small></div><span class="ops-badge ${g.status==="open"?"ok":""}">${JBE_I18N.t(g.status)}</span></div>`).join("")||`<p class="ops-muted">${JBE_I18N.t("No groups published yet")}</p>`;
 JBE_I18N.apply();
}
(async()=>{if(!slug){$("msg").textContent="Missing course.";return}const {data,error}=await JBE.client.rpc("public_course_detail",{p_slug:slug});if(error||!data){$("msg").textContent=error?.message||"Course not found.";return}d=data;render()})();
window.addEventListener("jbe:languagechange",render);
