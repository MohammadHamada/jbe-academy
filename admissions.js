
const rows=document.getElementById("rows"),msg=document.getElementById("msg");
async function init(){
  const staff=await JBE.staff();
  if(!staff || !["super_admin","admin","sales"].includes(staff.role)){msg.textContent="Not authorized.";return;}
  await load();
}
async function load(){
  const {data,error}=await JBE.client.rpc("staff_list_applications");
  if(error){msg.textContent=error.message;return;}
  rows.innerHTML=(data||[]).map(a=>`<tr>
    <td><b>${a.application_code}</b></td><td>${a.student_name}<br><small>${a.contact_phone||""}</small></td>
    <td>${a.curriculum||"—"}</td><td>${a.grade||"—"}</td><td>${a.subject||"—"}</td>
    <td><span class="badge">${a.sales_status}</span></td><td><span class="badge">${a.application_status}</span></td>
    <td>${a.application_status==="converted"?"Converted":`<button onclick="convertApp('${a.id}')">Approve & Create Student</button>`}</td>
  </tr>`).join("");
}
async function convertApp(id){
  if(!confirm("Approve this application and create the student profile?")) return;
  const {data,error}=await JBE.client.rpc("admin_convert_application_to_student",{p_application_id:id});
  if(error){alert(error.message);return;}
  alert(`Student created: ${data.student_code}`); await load();
}
init();
