
const $=id=>document.getElementById(id);let data={profiles:[],offerings:[]};
async function load(){const {data:d,error}=await JBE.client.rpc("staff_teacher_approvals");if(error){$("pageMsg").textContent=error.message;return}data=d||{profiles:[],offerings:[]};render()}
function render(){
 $("profileList").innerHTML=(data.profiles||[]).map(p=>`<div class="ops-item"><div class="ops-item-main"><strong>${p.display_name}</strong><small>${p.headline_en||""} • ${p.staff_active?"Active":"Suspended"}</small></div><div class="ops-actions"><a class="ops-btn light small" href="teacher-manage.html?teacher=${p.teacher_id}">Manage</a><button class="ops-btn gold small" onclick="approveProfile('${p.teacher_id}')">Approve & Publish</button></div></div>`).join("")||`<p class="ops-muted">—</p>`;
 $("offeringList").innerHTML=(data.offerings||[]).map(o=>`<div class="ops-item"><div class="ops-item-main"><strong>${o.teacher_name} — ${o.subject}</strong><small>${o.curriculum} • ${o.grade} • ${JBE_I18N.t(o.study_mode)} • Teacher ${o.teacher_price} ${o.currency}</small></div><div class="ops-actions"><input id="price-${o.offering_id}" type="number" min="0" step="0.01" placeholder="Public price" style="width:120px"><button class="ops-btn gold small" onclick="review('${o.offering_id}','approved')">Approve</button><button class="ops-btn danger small" onclick="review('${o.offering_id}','rejected')">Reject</button></div></div>`).join("")||`<p class="ops-muted">—</p>`;
 JBE_I18N.apply();
}
window.approveProfile=async id=>{const {error}=await JBE.client.rpc("admin_set_teacher_profile_approval",{p_teacher_id:id,p_is_verified:true,p_is_public:true});if(error)alert(error.message);else load()};
window.review=async(id,decision)=>{const price=decision==="approved"?Number($(`price-${id}`).value):null;const {error}=await JBE.client.rpc("admin_review_teacher_offering",{p_offering_id:id,p_decision:decision,p_public_price:price});if(error)alert(error.message);else load()};
window.addEventListener("jbe:languagechange",render);load();
