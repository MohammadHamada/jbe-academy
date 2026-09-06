
const $=id=>document.getElementById(id);let sessions=[];
const todayLocal=()=>{const d=new Date(),off=d.getTimezoneOffset();return new Date(d.getTime()-off*60000).toISOString().slice(0,10)}
$("dayPicker").value=todayLocal();
async function load(){
 const staff=await JBE.staff();if(!staff){$("pageMsg").textContent="Not authorized.";return}
 const {data,error}=await JBE.client.rpc("teacher_today_sessions",{p_day:$("dayPicker").value});
 if(error){$("pageMsg").textContent=error.message;return}sessions=data||[];render();
}
function render(){
 $("sessionList").innerHTML=sessions.map(s=>`<div class="ops-item"><div class="ops-item-main"><strong>${s.course_title}</strong><small>${s.group_name||""} • ${new Date(s.session_date).toLocaleString()} • ${s.student_count} ${JBE_I18N.t("Students")}</small></div><div class="ops-session-actions">${s.actual_start_at?`<span class="ops-badge ok">${JBE_I18N.t("Started")}</span>`:`<button class="ops-btn small gold" onclick="start('${s.session_id}')">${JBE_I18N.t("Start Session")}</button>`}<a class="ops-btn small" href="teacher-session.html?id=${s.session_id}">${JBE_I18N.t("Open Session")}</a></div></div>`).join("")||`<p class="ops-muted">${JBE_I18N.t("No sessions scheduled today")}</p>`;
 JBE_I18N.apply();
}
window.start=async id=>{const {error}=await JBE.client.rpc("teacher_start_session",{p_session_id:id});if(error)alert(error.message);else load()};
$("dayPicker").onchange=load;window.addEventListener("jbe:languagechange",render);load();
