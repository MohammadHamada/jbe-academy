const $=id=>document.getElementById(id);let rows=[],catalog=null;
const L=()=>JBE_I18N.getLanguage();const n=(en,ar)=>L()==="ar"?(ar||en):(en||ar);
async function load(){
  const [r1,r2]=await Promise.all([JBE.client.rpc("admin_academic_catalog_v28"),JBE.client.rpc("public_academic_catalog_v28")]);
  if(r1.error){$("acMsg").textContent=r1.error.message;return}
  if(r2.error){$("acMsg").textContent=r2.error.message;return}
  rows=r1.data||[];catalog=r2.data||{};fillSystems();render();
}
function fillSystems(){
  $("acSystem").innerHTML=`<option value="">${L()==="ar"?"كل الأنظمة":"All systems"}</option>`+(catalog.systems||[]).map(x=>`<option value="${x.code}">${n(x.name_en,x.name_ar)}</option>`).join("");
  fillPathways();
}
function fillPathways(){
  const sys=$("acSystem").value,sid=catalog.systems?.find(s=>s.code===sys)?.id;
  const data=(catalog.pathways||[]).filter(p=>!sys||p.education_system_id===sid);
  $("acPathway").innerHTML=`<option value="">${L()==="ar"?"كل المسارات":"All pathways"}</option>`+data.map(x=>`<option value="${x.id}">${n(x.name_en,x.name_ar)}</option>`).join("");
  fillGrades();
}
function fillGrades(){
  const sys=$("acSystem").value,p=$("acPathway").value,map=new Map();
  rows.filter(r=>(!sys||r.system_code===sys)&&(!p||r.pathway_id===p)).forEach(r=>map.set(r.grade_level_id,{id:r.grade_level_id,en:r.grade_en,ar:r.grade_ar}));
  $("acGrade").innerHTML=`<option value="">${L()==="ar"?"كل الصفوف":"All grades"}</option>`+[...map.values()].map(x=>`<option value="${x.id}">${n(x.en,x.ar)}</option>`).join("");
}
function render(){
  const sys=$("acSystem").value,p=$("acPathway").value,g=$("acGrade").value,q=$("acSearch").value.toLowerCase().trim();
  const data=rows.filter(r=>(!sys||r.system_code===sys)&&(!p||r.pathway_id===p)&&(!g||r.grade_level_id===g)&&(!q||`${r.subject_en} ${r.subject_ar||""} ${r.grade_en} ${r.pathway_en||""}`.toLowerCase().includes(q)));
  $("acList").innerHTML=data.map(r=>`<div class="ac-row"><div><strong>${n(r.subject_en,r.subject_ar)}</strong><small>${n(r.grade_en,r.grade_ar)} • ${n(r.pathway_en,r.pathway_ar)}</small></div><div><small>${n(r.curriculum_en,r.curriculum_ar)}</small></div><label class="ac-toggle"><input id="pub-${r.mapping_id}" type="checkbox" ${r.is_public?"checked":""}> Public</label><div class="ops-actions"><label class="ac-toggle"><input id="feat-${r.mapping_id}" type="checkbox" ${r.is_featured?"checked":""} ${!r.is_public?"disabled":""}> Featured</label><button class="ops-btn gold small" onclick="saveRow('${r.mapping_id}')">Save</button></div></div>`).join("")||`<p class="ops-muted">${L()==="ar"?"لا توجد نتائج.":"No results."}</p>`;
  document.querySelectorAll('[id^="pub-"]').forEach(el=>el.onchange=()=>{const id=el.id.replace("pub-",""),f=$(`feat-${id}`);f.disabled=!el.checked;if(!el.checked)f.checked=false});
}
window.saveRow=async id=>{
  const {error}=await JBE.client.rpc("admin_set_grade_subject_visibility_v28",{p_mapping_id:id,p_is_public:$(`pub-${id}`).checked,p_is_featured:$(`feat-${id}`).checked});
  if(error){$("acMsg").textContent=error.message;return}
  $("acMsg").textContent=L()==="ar"?"تم الحفظ.":"Saved.";await load();
};
$("acSystem").onchange=()=>{fillPathways();render()};$("acPathway").onchange=()=>{fillGrades();render()};$("acGrade").onchange=render;$("acSearch").oninput=render;
window.addEventListener("jbe:languagechange",()=>{fillSystems();render()});load();
