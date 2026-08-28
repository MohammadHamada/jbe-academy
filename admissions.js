const rows=document.getElementById("rows"),msg=document.getElementById("msg");
let applications=[];

async function init(){
  const staff=await JBE.staff();
  if(!staff||!["super_admin","admin","sales"].includes(staff.role)){
    msg.textContent=JBE_I18N.t("Not authorized.");
    return;
  }
  await load();
}

function render(){
  rows.innerHTML=applications.map(a=>`<tr>
    <td><b>${a.application_code}</b></td>
    <td>${a.student_name}<br><small>${a.contact_phone||""}</small></td>
    <td>${a.curriculum||"—"}</td><td>${a.grade||"—"}</td><td>${a.subject||"—"}</td>
    <td><span class="badge">${JBE_I18N.t(a.sales_status)}</span></td>
    <td><span class="badge">${JBE_I18N.t(a.application_status)}</span></td>
    <td>${a.application_status==="converted"
      ? JBE_I18N.t("Converted")
      : `<button onclick="convertApp('${a.id}')">${JBE_I18N.t("Approve & Create Student")}</button>`}</td>
  </tr>`).join("");
  JBE_I18N.apply();
}

async function load(){
  const {data,error}=await JBE.client.rpc("staff_list_applications");
  if(error){msg.textContent=error.message;return;}
  applications=data||[];
  render();
}

async function convertApp(id){
  const q=JBE_I18N.getLanguage()==="ar"
    ?"هل تريد اعتماد هذا الطلب وإنشاء ملف الطالب؟"
    :"Approve this application and create the student profile?";
  if(!confirm(q))return;

  const {data,error}=await JBE.client.rpc("admin_convert_application_to_student",{p_application_id:id});
  if(error){alert(error.message);return;}

  alert(JBE_I18N.getLanguage()==="ar"
    ?`تم إنشاء الطالب: ${data.student_code}`
    :`Student created: ${data.student_code}`);
  await load();
}

window.convertApp=convertApp;
window.addEventListener("jbe:languagechange",render);
init();
