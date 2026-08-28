const $=id=>document.getElementById(id);
let catalog={},mine={profile:null,scopes:[],offerings:[]};

async function boot(){
  const staff=await JBE.staff();
  if(!staff || !["teacher","admin","super_admin"].includes(staff.role)){
    $("pageMsg").textContent="Not authorized.";
    $("pageMsg").className="error";
    return;
  }

  const [{data:c,error:ce},{data:m,error:me}] = await Promise.all([
    JBE.client.rpc("teacher_catalog"),
    JBE.client.rpc("teacher_my_profile")
  ]);

  if(ce||me){
    $("pageMsg").textContent=(ce||me).message;
    $("pageMsg").className="error";
    return;
  }

  catalog=c; mine=m;
  if(!mine.profile){
    $("pageMsg").textContent="This staff account does not yet have a Teacher Profile. Ask JBE Admin to create/approve it.";
    $("pageMsg").className="error";
    return;
  }

  $("teacherName").textContent=mine.profile.display_name;
  loadSystems();
  renderMine();
}

function loadSystems(){
  $("system").innerHTML=(catalog.education_systems||[]).map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  loadCurricula();
}

function loadCurricula(){
  const systemId=$("system").value;
  const rows=(catalog.curricula||[]).filter(x=>x.education_system_id===systemId);
  $("curriculum").innerHTML=rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  loadStages();
}

function loadStages(){
  const systemId=$("system").value;
  const rows=(catalog.stages||[]).filter(x=>x.education_system_id===systemId);
  $("stage").innerHTML=`<option value="">No stage / curriculum-defined</option>`+
    rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
  loadGrades();
}

function loadGrades(){
  const curriculumId=$("curriculum").value;
  const stageId=$("stage").value;
  let rows=(catalog.grades||[]).filter(x=>x.curriculum_id===curriculumId);
  if(stageId) rows=rows.filter(x=>x.stage_id===stageId);
  $("grade").innerHTML=rows.map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");

  $("subject").innerHTML=(catalog.subjects||[]).map(x=>`<option value="${x.id}">${x.name_en}</option>`).join("");
}

function renderMine(){
  const scopes=(mine.scopes||[]).filter(x=>x.is_active);

  $("scopeRows").innerHTML=scopes.length ? scopes.map(x=>`
    <tr>
      <td>${x.education_system}</td>
      <td>${x.curriculum}</td>
      <td>${x.stage||"—"}</td>
      <td>${x.grade}</td>
      <td>${x.subject}</td>
      <td>${x.is_public?"Yes":"No"}</td>
      <td><button onclick="archiveScope('${x.id}')">Archive</button></td>
    </tr>`).join("") : `<tr><td colspan="7">No teaching scope yet.</td></tr>`;

  $("scopeSelect").innerHTML=scopes.map(x=>
    `<option value="${x.id}" data-curriculum="${x.curriculum_id}" data-grade="${x.grade_level_id}" data-subject="${x.subject_id}">
      ${x.curriculum} • ${x.grade} • ${x.subject}
    </option>`
  ).join("");

  $("offeringRows").innerHTML=(mine.offerings||[]).length ? mine.offerings.map(x=>`
    <tr>
      <td>${x.curriculum}</td><td>${x.grade}</td><td>${x.subject}</td>
      <td>${x.study_mode}</td><td>${x.billing_type}</td>
      <td>${x.teacher_price} ${x.currency}</td>
      <td><span class="badge ${x.approval_status==="approved"?"ok":""}">${x.approval_status}</span></td>
    </tr>`).join("") : `<tr><td colspan="7">No offerings yet.</td></tr>`;
}

async function reloadMine(){
  const {data,error}=await JBE.client.rpc("teacher_my_profile");
  if(error) throw error;
  mine=data; renderMine();
}

$("system").onchange=loadCurricula;
$("curriculum").onchange=loadStages;
$("stage").onchange=loadGrades;

$("scopeForm").onsubmit=async e=>{
  e.preventDefault(); $("scopeMsg").textContent="Saving...";
  const {error}=await JBE.client.rpc("teacher_save_scope",{
    p_education_system_id:$("system").value,
    p_curriculum_id:$("curriculum").value,
    p_stage_id:$("stage").value||null,
    p_grade_level_id:$("grade").value,
    p_subject_id:$("subject").value,
    p_is_public:$("scopePublic").checked
  });
  if(error){$("scopeMsg").textContent=error.message;$("scopeMsg").className="error";return;}
  $("scopeMsg").textContent="Teaching scope saved.";$("scopeMsg").className="success";
  await reloadMine();
};

async function archiveScope(id){
  if(!confirm("Archive this teaching scope? Existing historic courses will not be deleted.")) return;
  const {error}=await JBE.client.rpc("teacher_archive_scope",{p_scope_id:id});
  if(error){alert(error.message);return;}
  await reloadMine();
}
window.archiveScope=archiveScope;

$("offeringForm").onsubmit=async e=>{
  e.preventDefault(); $("offeringMsg").textContent="Submitting...";
  const option=$("scopeSelect").selectedOptions[0];
  if(!option){$("offeringMsg").textContent="Add a teaching scope first.";return;}
  const {error}=await JBE.client.rpc("teacher_create_offering",{
    p_curriculum_id:option.dataset.curriculum,
    p_grade_level_id:option.dataset.grade,
    p_subject_id:option.dataset.subject,
    p_study_mode:$("studyMode").value,
    p_billing_type:$("billingType").value,
    p_teacher_price:Number($("teacherPrice").value),
    p_currency:$("currency").value,
    p_duration_minutes:Number($("duration").value)||null,
    p_capacity:Number($("capacity").value)||null
  });
  if(error){$("offeringMsg").textContent=error.message;$("offeringMsg").className="error";return;}
  $("offeringMsg").textContent="Offering submitted for Admin approval.";$("offeringMsg").className="success";
  e.target.reset();
  await reloadMine();
};

boot();
