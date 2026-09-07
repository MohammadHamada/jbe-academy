const $ = id => document.getElementById(id);

let teachers = [];
let catalog = {education_systems:[],curricula:[],stages:[],grades:[],subjects:[]};
let current = null;
let selectedTeacherId = null;

function langName(x, en="name_en", ar="name_ar"){
  if(!x) return "";
  return JBE_I18N.getLanguage()==="ar" ? (x[ar]||x[en]||x.code||"") : (x[en]||x[ar]||x.code||"");
}
function detailName(o,en,ar){
  return JBE_I18N.getLanguage()==="ar" ? (o[ar]||o[en]||"") : (o[en]||o[ar]||"");
}
function message(text,type=""){
  $("pageMsg").textContent=text||"";
  $("pageMsg").className=type;
}
async function ensureAccess(){
  const {data,error}=await JBE.client.rpc("resolve_my_portal");
  if(error) throw error;
  if(!data?.is_owner && !["super_admin","admin"].includes(data?.role)) throw new Error("Not authorized.");
}
async function loadBase(){
  try{
    await ensureAccess();

    // Load teachers FIRST so a separate catalog problem can never hide the teacher list.
    const tRes = await JBE.client.rpc("admin_teacher_manager_list");

    if(tRes.error){
      $("teacherList").innerHTML =
        `<p class="error">Teacher list error: ${tRes.error.message}</p>`;
      message(`Teacher list error: ${tRes.error.message}`,"error");
      return;
    }

    teachers = Array.isArray(tRes.data) ? tRes.data : [];
    renderTeacherList();

    // Load academic catalog independently.
    const cRes = await JBE.client.rpc("admin_teacher_manager_catalog");

    if(cRes.error){
      console.error("Teacher catalog error:", cRes.error);
      message(`Academic catalog error: ${cRes.error.message}`,"error");
      // Keep the teacher list usable even when catalog has a problem.
      return;
    }

    catalog = cRes.data || catalog;

    const requested = new URLSearchParams(location.search).get("teacher");

    if(requested && teachers.some(t=>t.teacher_id===requested)){
      await selectTeacher(requested);
    }else if(teachers.length===1){
      await selectTeacher(teachers[0].teacher_id);
    }
  }catch(err){
    console.error("Teacher Management load error:", err);
    $("teacherList").innerHTML =
      `<p class="error">Load error: ${err.message}</p>`;
    message(err.message,"error");
  }
}
function renderTeacherList(){
  const q=$("teacherSearch").value.trim().toLowerCase();
  const rows=teachers.filter(t=>!q||(t.display_name||"").toLowerCase().includes(q)||(t.display_name_ar||"").toLowerCase().includes(q)||(t.email||"").toLowerCase().includes(q));
  $("teacherList").innerHTML=rows.map(t=>`
    <button class="tm-teacher ${t.teacher_id===selectedTeacherId?"selected":""}" data-id="${t.teacher_id}">
      <strong>${t.display_name}</strong><span>${t.email||""}</span>
      <small>${t.staff_active?"Active":"Suspended"} • ${t.scope_count||0} scopes • ${t.offering_count||0} offerings${Number(t.pending_offering_count)>0?` • ${t.pending_offering_count} pending`:""}</small>
    </button>`).join("")||`<p class="ops-muted">${teachers.length ? "No teachers match this search." : "No teacher records were returned."}</p>`;
  document.querySelectorAll(".tm-teacher").forEach(btn=>btn.onclick=()=>selectTeacher(btn.dataset.id));
  JBE_I18N.apply();
}
async function selectTeacher(id){
  selectedTeacherId=id;
  history.replaceState(null,"",`teacher-manage.html?teacher=${encodeURIComponent(id)}`);
  renderTeacherList(); message("");
  const {data,error}=await JBE.client.rpc("admin_teacher_manager_detail",{p_teacher_id:id});
  if(error){message(error.message,"error");return;}
  current=data; $("emptyState").hidden=true; $("teacherWorkspace").hidden=false;
  fillProfile(); setupCatalog(); renderScopes(); renderOfferings(); renderPublication(); JBE_I18N.apply();
}
function fillProfile(){
  const p=current.profile;
  $("selectedName").textContent=p.display_name;
  $("selectedMeta").textContent=`${p.email||""} • ${p.staff_active?"Active":"Suspended"} • ${p.is_verified?"Verified":"Not verified"} • ${p.is_public?"Public":"Private"}`;
  $("displayName").value=p.display_name||""; $("displayNameAr").value=p.display_name_ar||""; $("slug").value=p.slug||"";
  $("teacherEmail").value=p.email||""; $("headlineEn").value=p.headline_en||""; $("headlineAr").value=p.headline_ar||"";
  $("bioEn").value=p.bio_en||""; $("bioAr").value=p.bio_ar||""; $("photoUrl").value=p.photo_url||"";
  $("yearsExperience").value=p.years_experience??""; $("countryCode").value=p.country_code||"EG";
  const url=`teacher-profile.html?slug=${encodeURIComponent(p.slug)}`;
  $("publicPreviewBtn").href=url; $("publicUrl").textContent=`https://jbe-academy.pages.dev/${url}`;
}
function option(rows,valueFn,labelFn,blank=false){
  return (blank?`<option value="">—</option>`:"")+rows.map(x=>`<option value="${valueFn(x)}">${labelFn(x)}</option>`).join("");
}
function setupCatalog(){
  $("scopeSystem").innerHTML=option(catalog.education_systems,x=>x.id,x=>langName(x));
  $("scopeSubject").innerHTML=option(catalog.subjects,x=>x.id,x=>langName(x));
  refreshCurricula(); refreshOfferingScopes();
}
function refreshCurricula(){
  const system=$("scopeSystem").value;
  $("scopeCurriculum").innerHTML=option(catalog.curricula.filter(x=>x.education_system_id===system),x=>x.id,x=>langName(x));
  refreshStages();
}
function refreshStages(){
  const system=$("scopeSystem").value;
  $("scopeStage").innerHTML=option(catalog.stages.filter(x=>x.education_system_id===system),x=>x.id,x=>langName(x),true);
  refreshGrades();
}
function refreshGrades(){
  const curriculum=$("scopeCurriculum").value,stage=$("scopeStage").value;
  let rows=catalog.grades.filter(x=>x.curriculum_id===curriculum);
  if(stage) rows=rows.filter(x=>x.stage_id===stage);
  $("scopeGrade").innerHTML=option(rows,x=>x.id,x=>langName(x));
}
function renderScopes(){
  const scopes=current.scopes||[];
  $("scopeList").innerHTML=scopes.map(s=>`
    <div class="ops-item">
      <div class="ops-item-main">
        <strong>${detailName(s,"subject_en","subject_ar")} — ${detailName(s,"grade_en","grade_ar")}</strong>
        <small>${detailName(s,"education_system_en","education_system_ar")} • ${detailName(s,"curriculum_en","curriculum_ar")}${detailName(s,"stage_en","stage_ar")?` • ${detailName(s,"stage_en","stage_ar")}`:""}</small>
      </div>
      <div class="ops-actions"><span class="tm-pill ${s.is_public?"public":"private"}">${s.is_public?"Public":"Private"}</span><button class="ops-btn danger small" onclick="archiveScope('${s.scope_id}')">Archive</button></div>
    </div>`).join("")||`<p class="ops-muted">No teaching scope yet.</p>`;
  refreshOfferingScopes();
}
function refreshOfferingScopes(){
  const scopes=current?.scopes||[];
  $("offeringScope").innerHTML=scopes.map(s=>`
    <option value="${s.scope_id}" data-curriculum="${s.curriculum_id}" data-grade="${s.grade_level_id}" data-subject="${s.subject_id}">
      ${detailName(s,"subject_en","subject_ar")} — ${detailName(s,"grade_en","grade_ar")} — ${detailName(s,"curriculum_en","curriculum_ar")}
    </option>`).join("");
}
function renderOfferings(){
  const rows=current.offerings||[];
  $("offeringList").innerHTML=rows.map(o=>`
    <div class="ops-item tm-offering">
      <div class="ops-item-main">
        <strong>${detailName(o,"subject_en","subject_ar")} — ${detailName(o,"grade_en","grade_ar")}</strong>
        <small>${detailName(o,"curriculum_en","curriculum_ar")} • ${JBE_I18N.t(o.study_mode)} • ${JBE_I18N.t(o.billing_type)} • Teacher: ${o.teacher_price} ${o.currency} • ${o.duration_minutes||"—"} min • capacity ${o.capacity||"—"}</small>
        <small>Status: <b>${JBE_I18N.t(o.approval_status)}</b>${o.public_price!=null?` • Public: ${o.public_price} ${o.currency}`:""}</small>
      </div>
      <div class="ops-actions tm-offering-actions">
        ${o.approval_status==="pending"?`<input id="public-${o.offering_id}" type="number" min="0" step="0.01" placeholder="Public price"><button class="ops-btn gold small" onclick="reviewOffering('${o.offering_id}','approved')">Approve</button><button class="ops-btn danger small" onclick="reviewOffering('${o.offering_id}','rejected')">Reject</button>`:""}
        <button class="ops-btn light small" onclick="archiveOffering('${o.offering_id}')">Archive</button>
      </div>
    </div>`).join("")||`<p class="ops-muted">No offerings yet.</p>`;
}
function renderPublication(){
  const p=current.profile,scopes=current.scopes||[],offerings=current.offerings||[],approved=offerings.filter(o=>o.approval_status==="approved");
  const checks=[["Active staff account",!!p.staff_active],["Teacher profile completed",!!p.display_name&&!!p.slug&&!!(p.headline_en||p.headline_ar)],["At least one teaching scope",scopes.length>0],["At least one public teaching scope",scopes.some(s=>s.is_public)],["Teacher verified",!!p.is_verified],["Teacher public",!!p.is_public],["At least one approved offering",approved.length>0]];
  $("publicationChecklist").innerHTML=checks.map(([label,ok])=>`<div class="tm-check-row ${ok?"ok":"missing"}"><span>${ok?"✓":"!"}</span><strong>${label}</strong></div>`).join("");
  $("approvePublishBtn").disabled=!p.staff_active;
}
async function reload(){
  await selectTeacher(selectedTeacherId);
  const {data}=await JBE.client.rpc("admin_teacher_manager_list"); if(data){teachers=data;renderTeacherList();}
}

$("teacherSearch").addEventListener("input",renderTeacherList);
$("scopeSystem").addEventListener("change",refreshCurricula);
$("scopeCurriculum").addEventListener("change",refreshStages);
$("scopeStage").addEventListener("change",refreshGrades);
document.querySelectorAll(".tm-tabs button").forEach(btn=>btn.onclick=()=>{document.querySelectorAll(".tm-tabs button").forEach(x=>x.classList.toggle("active",x===btn));document.querySelectorAll(".tm-tab").forEach(x=>x.hidden=true);$(`tab-${btn.dataset.tab}`).hidden=false;});

$("profileForm").onsubmit=async e=>{
  e.preventDefault(); message("Saving...");
  const {error}=await JBE.client.rpc("admin_update_teacher_profile",{p_teacher_id:selectedTeacherId,p_display_name:$("displayName").value,p_display_name_ar:$("displayNameAr").value,p_slug:$("slug").value.trim().toLowerCase(),p_headline_en:$("headlineEn").value,p_headline_ar:$("headlineAr").value,p_bio_en:$("bioEn").value,p_bio_ar:$("bioAr").value,p_photo_url:$("photoUrl").value,p_years_experience:$("yearsExperience").value?Number($("yearsExperience").value):null,p_country_code:$("countryCode").value.toUpperCase()});
  if(error){message(error.message,"error");return;} message("Profile saved.","success"); await reload();
};
$("scopeForm").onsubmit=async e=>{
  e.preventDefault(); message("Saving...");
  const {error}=await JBE.client.rpc("admin_save_teacher_scope",{p_teacher_id:selectedTeacherId,p_education_system_id:$("scopeSystem").value,p_curriculum_id:$("scopeCurriculum").value,p_stage_id:$("scopeStage").value||null,p_grade_level_id:$("scopeGrade").value,p_subject_id:$("scopeSubject").value,p_is_public:$("scopePublic").checked});
  if(error){message(error.message,"error");return;} message("Teaching scope saved.","success"); await reload();
};
$("offeringForm").onsubmit=async e=>{
  e.preventDefault(); const selected=$("offeringScope").selectedOptions[0];
  if(!selected){message("Add a teaching scope first.","error");return;} message("Saving...");
  const {error}=await JBE.client.rpc("admin_create_teacher_offering",{p_teacher_id:selectedTeacherId,p_curriculum_id:selected.dataset.curriculum,p_grade_level_id:selected.dataset.grade,p_subject_id:selected.dataset.subject,p_study_mode:$("studyMode").value,p_billing_type:$("billingType").value,p_teacher_price:Number($("teacherPrice").value||0),p_currency:$("currency").value||"EGP",p_duration_minutes:Number($("duration").value||60),p_capacity:Number($("capacity").value||1)});
  if(error){message(error.message,"error");return;} message("Offering created and sent for approval.","success"); $("teacherPrice").value=""; await reload();
};
window.archiveScope=async id=>{if(!confirm("Archive this teaching scope?"))return;const {error}=await JBE.client.rpc("admin_archive_teacher_scope",{p_scope_id:id});if(error)return message(error.message,"error");await reload();};
window.archiveOffering=async id=>{if(!confirm("Archive this offering?"))return;const {error}=await JBE.client.rpc("admin_archive_teacher_offering",{p_offering_id:id});if(error)return message(error.message,"error");await reload();};
window.reviewOffering=async(id,decision)=>{const price=decision==="approved"?Number($(`public-${id}`).value):null;if(decision==="approved"&&(!Number.isFinite(price)||price<0))return message("Enter a valid public price.","error");const {error}=await JBE.client.rpc("admin_review_teacher_offering",{p_offering_id:id,p_decision:decision,p_public_price:price});if(error)return message(error.message,"error");await reload();};
$("approvePublishBtn").onclick=async()=>{const {error}=await JBE.client.rpc("admin_set_teacher_profile_approval",{p_teacher_id:selectedTeacherId,p_is_verified:true,p_is_public:true});if(error)return message(error.message,"error");message("Teacher verified and published.","success");await reload();};
$("unpublishBtn").onclick=async()=>{const {error}=await JBE.client.rpc("admin_set_teacher_profile_approval",{p_teacher_id:selectedTeacherId,p_is_verified:!!current.profile.is_verified,p_is_public:false});if(error)return message(error.message,"error");message("Teacher unpublished.","success");await reload();};
window.addEventListener("jbe:languagechange",()=>{renderTeacherList();if(current){setupCatalog();renderScopes();renderOfferings();renderPublication();}});
loadBase();
