
const $=id=>document.getElementById(id);
async function load(){const role=await JBE.resolveRole();if(!role?.is_owner){$("pageMsg").textContent="Owner only.";return}const {data,error}=await JBE.client.rpc("owner_audit_log",{p_limit:150});if(error){$("pageMsg").textContent=error.message;return}$("auditRows").innerHTML=(data||[]).map(r=>`<tr><td>${new Date(r.created_at).toLocaleString()}</td><td>${r.actor_email||"system"}</td><td>${r.action}</td><td>${r.entity_type}<br><small>${r.entity_id||""}</small></td><td><code>${JSON.stringify(r.details||{})}</code></td></tr>`).join("");JBE_I18N.apply()}
$("refreshAudit").onclick=load;load();
