
const $=id=>document.getElementById(id);
const ROLES=["admin","teacher","sales","student_affairs","finance","content","support"];
let staff=[],invites=[];

function roleOptions(selected=""){return ROLES.map(r=>`<option value="${r}" ${r===selected?"selected":""}>${JBE_I18N.t(r)}</option>`).join("")}
function checks(target,selected=[]){$(target).innerHTML=ROLES.map(r=>`<label class="ops-check"><input type="checkbox" value="${r}" ${selected.includes(r)?"checked":""}> ${JBE_I18N.t(r)}</label>`).join("")}
function selectedChecks(target){return [...$(target).querySelectorAll("input:checked")].map(x=>x.value)}

async function requireOwner(){
 const role=await JBE.resolveRole();
 if(!role?.is_owner){$("pageMsg").textContent="Owner only.";return false}
 return true;
}
async function load(){
 const [{data:s,error:se},{data:i,error:ie}]=await Promise.all([
   JBE.client.rpc("owner_list_staff"),JBE.client.rpc("owner_list_staff_invites")
 ]);
 if(se||ie){$("pageMsg").textContent=(se||ie).message;return}
 staff=s||[];invites=i||[];render();
}
function render(){
 $("staffRows").innerHTML=staff.map(s=>`<tr>
   <td><strong>${s.full_name}</strong>${s.is_owner?`<br><span class="ops-badge ok">Protected Owner</span>`:""}</td>
   <td>${s.email||"—"}</td><td>${JBE_I18N.t(s.primary_role)}</td>
   <td>${(s.roles||[]).map(r=>`<span class="ops-badge">${JBE_I18N.t(r)}</span>`).join(" ")}</td>
   <td><span class="ops-badge ${s.is_active?"ok":"warn"}">${s.is_active?JBE_I18N.t("Active"):JBE_I18N.t("Suspended")}</span></td>
   <td>${s.last_sign_in_at?new Date(s.last_sign_in_at).toLocaleString():"—"}</td>
   <td><div class="ops-actions">
    ${s.is_owner?"":`<button class="ops-btn small light" onclick="editRoles('${s.staff_id}')">${JBE_I18N.t("Edit Roles")}</button>
      <button class="ops-btn small light" onclick="editPermissions('${s.staff_id}')">Permissions</button>
      <button class="ops-btn small ${s.is_active?"danger":"gold"}" onclick="toggleStatus('${s.staff_id}',${!s.is_active})">${s.is_active?JBE_I18N.t("Suspend"):JBE_I18N.t("Reactivate")}</button>`}
    ${s.email?`<button class="ops-btn small light" onclick="resetPassword('${s.email}')">${JBE_I18N.t("Send Password Reset")}</button>`:""}
   </div></td></tr>`).join("");
 $("inviteRows").innerHTML=invites.filter(i=>i.is_active&&!i.claimed_at).map(i=>`<div class="ops-item"><div class="ops-item-main"><strong>${i.full_name}</strong><small>${i.email} • ${JBE_I18N.t(i.primary_role)} • ${JBE_I18N.t("Expires")} ${new Date(i.expires_at).toLocaleString()}</small></div><button class="ops-btn small" onclick="copyExisting('${i.token}')">${JBE_I18N.t("Copy Link")}</button></div>`).join("")||`<p class="ops-muted">—</p>`;
 JBE_I18N.apply();
}
$("invitePrimary").innerHTML=roleOptions("sales"); $("rolesPrimary").innerHTML=roleOptions(); checks("inviteRoles",["sales"]);
$("invitePrimary").onchange=()=>{const r=$("invitePrimary").value;const vals=selectedChecks("inviteRoles");if(!vals.includes(r))checks("inviteRoles",[...vals,r])}
$("openInvite").onclick=()=>{$("inviteModal").classList.remove("hidden")}; $("closeInvite").onclick=()=>{$("inviteModal").classList.add("hidden")}; $("closeRoles").onclick=()=>{$("rolesModal").classList.add("hidden")};

$("inviteForm").onsubmit=async e=>{
 e.preventDefault(); $("inviteMsg").textContent="Saving...";
 const roles=selectedChecks("inviteRoles"); const primary=$("invitePrimary").value;
 const {data,error}=await JBE.client.rpc("owner_create_staff_invite",{p_email:$("inviteEmail").value.trim(),p_full_name:$("inviteName").value.trim(),p_primary_role:primary,p_roles:roles});
 if(error){$("inviteMsg").textContent=error.message;return}
 const link=`${location.origin}/staff-setup.html?token=${data.token}`;
 $("inviteLink").value=link;$("inviteLinkBox").classList.remove("hidden");$("inviteMsg").textContent=JBE_I18N.t("Invitation created");await load();
};
$("copyInvite").onclick=()=>navigator.clipboard.writeText($("inviteLink").value);
window.copyExisting=token=>navigator.clipboard.writeText(`${location.origin}/staff-setup.html?token=${token}`);

window.editRoles=id=>{
 const s=staff.find(x=>x.staff_id===id); if(!s)return;
 $("rolesStaffId").value=id;$("rolesPrimary").innerHTML=roleOptions(s.primary_role);checks("rolesChecks",s.roles||[]);$("rolesModal").classList.remove("hidden");
};
$("saveRoles").onclick=async()=>{
 const id=$("rolesStaffId").value,primary=$("rolesPrimary").value,roles=selectedChecks("rolesChecks");
 const {error}=await JBE.client.rpc("owner_set_staff_roles",{p_staff_id:id,p_primary_role:primary,p_roles:roles});
 $("rolesMsg").textContent=error?error.message:"Saved";if(!error){await load();setTimeout(()=>$("rolesModal").classList.add("hidden"),500)}
};
window.toggleStatus=async(id,val)=>{if(!confirm(val?"Reactivate this account?":"Suspend this account?"))return;const {error}=await JBE.client.rpc("owner_set_staff_status",{p_staff_id:id,p_is_active:val});if(error)alert(error.message);else load()};
window.resetPassword=async email=>{
 const {error}=await JBE.client.auth.resetPasswordForEmail(email,{redirectTo:`${location.origin}/reset-password.html`});
 alert(error?error.message:"Password reset email sent.");
};
(async()=>{if(await requireOwner())await load()})();

$("closePerm").onclick=()=>$("permModal").classList.add("hidden");
window.editPermissions=async id=>{
 $("permStaffId").value=id;$("permMsg").textContent="Loading...";
 const {data,error}=await JBE.client.rpc("owner_staff_permissions",{p_staff_id:id});
 if(error){$("permMsg").textContent=error.message;return}
 $("permList").innerHTML=(data||[]).map(p=>`<div class="ops-item"><div class="ops-item-main"><strong>${JBE_I18N.getLanguage()==="ar"?(p.name_ar||p.name_en):p.name_en}</strong><small>${p.permission_key} • ${p.category} • ${p.effective_allowed?"Allowed":"Denied"}</small></div><select onchange="setPerm('${id}','${p.permission_key}',this.value)"><option value="default" ${p.override_value===null?"selected":""}>Default</option><option value="allow" ${p.override_value===true?"selected":""}>Allow</option><option value="deny" ${p.override_value===false?"selected":""}>Deny</option></select></div>`).join("");
 $("permMsg").textContent="";$("permModal").classList.remove("hidden");JBE_I18N.apply();
};
window.setPerm=async(id,key,val)=>{
 const allowed=val==="default"?null:val==="allow";
 const {error}=await JBE.client.rpc("owner_set_staff_permission_override",{p_staff_id:id,p_permission_key:key,p_allowed:allowed});
 $("permMsg").textContent=error?error.message:"Saved";
};
