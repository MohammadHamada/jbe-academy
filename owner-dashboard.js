
const $=id=>document.getElementById(id);
(async()=>{
  const role=await JBE.resolveRole();
  if(!role?.is_owner){$("pageMsg").textContent="Owner only.";return;}
  const {data,error}=await JBE.client.rpc("owner_action_center");
  if(error){$("pageMsg").textContent=error.message;return;}
  $("aNew").textContent=data.new_applications??0;
  $("aFollow").textContent=data.followups_due??0;
  $("aPayments").textContent=data.pending_payment_claims??0;
  $("aTeachers").textContent=data.pending_teacher_offerings??0;
  $("aGuardian").textContent=data.students_missing_guardian??0;
  $("aGroups").textContent=data.active_enrollments_without_group??0;
  $("aCourses").textContent=data.courses_without_teacher??0;
  $("aReceipts").textContent=data.verified_payments_without_receipt??0;
  JBE_I18N.apply();
})();
$("searchBtn").onclick=async()=>{
 const q=$("globalSearch").value.trim();
 if(q.length<2)return;
 const {data,error}=await JBE.client.rpc("owner_global_search",{p_query:q});
 if(error){$("pageMsg").textContent=error.message;return;}
 $("searchResults").innerHTML=(data||[]).map(x=>`<a class="ops-search-result" href="${x.url}"><strong>${x.title}</strong><small>${JBE_I18N.t(x.type)} • ${x.subtitle||""}</small></a>`).join("")||`<p class="ops-muted">No results.</p>`;
};
