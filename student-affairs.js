
const $=id=>document.getElementById(id);let students=[],unassigned=[];
async function load(){
 const [oR,iR,sR,uR]=await Promise.all([
  JBE.client.rpc("student_affairs_overview"),
  JBE.client.rpc("student_affairs_issues"),
  JBE.client.rpc("admin_list_students"),
  JBE.client.rpc("student_affairs_unassigned_enrollments")
 ]);
 const err=oR.error||iR.error||sR.error||uR.error;if(err){$("pageMsg").textContent=err.message;return}
 const o=oR.data;$("sActive").textContent=o.active_students;$("sGuardian").textContent=o.without_guardian;$("sGroup").textContent=o.active_without_group;$("sPending").textContent=o.pending_enrollments;
 $("issueList").innerHTML=(iR.data||[]).map(x=>`<div class="ops-item"><div><strong>${x.student_name}</strong><small>${x.student_code} • ${JBE_I18N.t(x.issue_type)} • ${x.details}</small></div><a class="ops-btn small" href="student-manage.html?id=${x.student_id}">${JBE_I18N.t("Open Student")}</a></div>`).join("")||`<p class="ops-muted">—</p>`;
 students=sR.data||[];unassigned=uR.data||[];renderStudents();renderUnassigned();JBE_I18N.apply();
}
function renderStudents(){const q=$("studentSearch").value.toLowerCase();$("studentList").innerHTML=students.filter(s=>!q||`${s.student_code} ${s.full_name} ${s.full_name_en||""}`.toLowerCase().includes(q)).map(s=>`<div class="ops-item"><div><strong>${s.full_name_en||s.full_name}</strong><small>${s.student_code} • ${s.curriculum} • ${s.grade}</small></div><a class="ops-btn small" href="student-manage.html?id=${s.student_id}">${JBE_I18N.t("Open Student")}</a></div>`).join("")}
function renderUnassigned(){$("unassignedList").innerHTML=unassigned.map(e=>`<div class="ops-item"><div class="ops-item-main"><strong>${e.student_name}</strong><small>${e.student_code} • ${e.course_title}</small></div><div class="ops-actions"><select id="grp-${e.enrollment_id}">${(e.groups||[]).map(g=>`<option value="${g.group_id}">${g.group_name} (${g.active_students}/${g.capacity??"∞"})</option>`).join("")}</select><button class="ops-btn small gold" ${!(e.groups||[]).length?"disabled":""} onclick="assignGroup('${e.enrollment_id}')">Assign</button></div></div>`).join("")||`<p class="ops-muted">—</p>`}
window.assignGroup=async eid=>{const gid=$(`grp-${eid}`).value;if(!gid)return;const {error}=await JBE.client.rpc("student_affairs_assign_group",{p_enrollment_id:eid,p_group_id:gid});if(error)alert(error.message);else load()};
$("studentSearch").oninput=renderStudents;window.addEventListener("jbe:languagechange",()=>{renderStudents();renderUnassigned();JBE_I18N.apply()});load();
