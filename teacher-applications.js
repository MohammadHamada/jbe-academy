
const $=id=>document.getElementById(id);let rows=[];
function chip(s){return `<span class="ta-chip">${s}</span>`}
function render(){
 const q=$("taSearch").value.toLowerCase().trim(),st=$("taStatus").value;
 const data=rows.filter(x=>(!st||x.status===st)&&(!q||`${x.full_name} ${x.email} ${(x.subjects||[]).join(" ")}`.toLowerCase().includes(q)));
 $("teacherApplications").innerHTML=data.map(a=>`<article class="ta-card">
  <div class="ta-head"><div><h2>${a.full_name}</h2><span class="ta-meta">${a.application_code} • ${a.email}${a.phone?` • ${a.phone}`:""}</span></div><span class="ops-badge">${JBE_I18N.t(a.status)}</span></div>
  <div class="ta-chips">${(a.subjects||[]).map(chip).join("")}${(a.education_systems||[]).map(chip).join("")}${(a.teaching_languages||[]).map(chip).join("")}</div>
  <div class="ta-details"><div><b>Experience</b><br>${a.years_experience??"—"} years<br>${a.current_position||""}</div><div><b>Study modes</b><br>${(a.study_modes||[]).join(" • ")||"—"}</div></div>
  ${a.headline?`<p><b>${a.headline}</b></p>`:""}${a.bio?`<p>${a.bio}</p>`:""}
  ${a.qualifications?`<details><summary>Qualifications</summary><p>${a.qualifications}</p></details>`:""}
  ${a.sample_video_url?`<p><a class="ops-btn light small" href="${a.sample_video_url}" target="_blank">Open sample video</a></p>`:""}
  <textarea id="note-${a.id}" placeholder="Reviewer notes">${a.reviewer_notes||""}</textarea>
  <div class="ta-actions">
    <button class="ops-btn light small" onclick="review('${a.id}','under_review')">Under review</button>
    <button class="ops-btn light small" onclick="review('${a.id}','shortlisted')">Shortlist</button>
    <button class="ops-btn light small" onclick="review('${a.id}','interview')">Interview</button>
    <button class="ops-btn gold small" onclick="review('${a.id}','approved')">Approve</button>
    <button class="ops-btn danger small" onclick="review('${a.id}','rejected')">Reject</button>
    ${a.status==="approved"?`<a class="ops-btn gold small" href="staff-management.html">Invite via Team & Access</a>`:""}
  </div></article>`).join("")||`<p class="ops-muted">No applications.</p>`;
 JBE_I18N.apply();
}
async function load(){const {data,error}=await JBE.client.rpc("admin_teacher_applications");if(error){$("taMsg").textContent=error.message;return}rows=data||[];render()}
window.review=async(id,status)=>{const {error}=await JBE.client.rpc("admin_review_teacher_application",{p_application_id:id,p_status:status,p_reviewer_notes:$(`note-${id}`).value});if(error){alert(error.message);return}await load()};
$("taSearch").oninput=render;$("taStatus").onchange=render;load();
