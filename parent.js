(async()=>{
  const s=await JBE.requireSession();if(!s)return;
  const {data,error}=await JBE.client.rpc("parent_dashboard");
  const box=document.getElementById("children"),msg=document.getElementById("msg");
  if(error){msg.textContent=error.message;return;}
  const children=data.children||[];
  if(!children.length){msg.textContent=JBE_I18N.t("No child profile is linked to this parent account yet.");return;}

  function render(){
    box.innerHTML=children.map(c=>{
      const r=c.latest_report||{};
      return `<article class="card">
        <span class="eyebrow">${c.student_code||""}</span>
        <h2>${c.name}</h2>
        <p>${c.curriculum||""} • ${c.grade||""}</p>
        <p><b>${JBE_I18N.t("Attendance")}:</b> ${r.attendance??"—"}%</p>
        <p><b>${JBE_I18N.t("Homework")}:</b> ${r.homework??"—"}%</p>
        <p><b>${JBE_I18N.t("Overall progress:")}</b> ${r.overall??"—"}%</p>
        <p><b>${JBE_I18N.t("Outstanding balance:")}</b> ${c.balance??0} EGP</p>
        ${r.recommendation?`<p class="muted">${r.recommendation}</p>`:""}
      </article>`;
    }).join("");
    JBE_I18N.apply();
  }
  render();
  window.addEventListener("jbe:languagechange",render);
})();
