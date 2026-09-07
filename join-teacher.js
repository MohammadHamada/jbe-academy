
const form=document.getElementById("teacherApplicationForm");
const steps=[...document.querySelectorAll(".tj-step")];let currentStep=1;
const val=n=>form.elements[n]?.value?.trim?.()||"";
const checked=n=>[...form.querySelectorAll(`[name="${n}"]:checked`)].map(x=>x.value);
function renderStep(){
  steps.forEach(s=>s.classList.toggle("active",Number(s.dataset.step)===currentStep));
  document.querySelectorAll("[data-step-dot]").forEach(d=>d.classList.toggle("active",Number(d.dataset.stepDot)<=currentStep));
  document.getElementById("progressBar").style.width=`${currentStep*25}%`;
  document.getElementById("prevStep").hidden=currentStep===1;
  document.getElementById("nextStep").hidden=currentStep===4;
  document.getElementById("submitTeacher").hidden=currentStep!==4;
  if(currentStep===4) renderSummary();
  scrollTo({top:0,behavior:"smooth"});
}
function validateStep(){
  const s=steps[currentStep-1];
  const required=[...s.querySelectorAll("[required]")];
  for(const el of required){if(!el.checkValidity()){el.reportValidity();return false}}
  if(currentStep===2 && checked("subjects").length===0){
    document.getElementById("teacherAppMsg").textContent=JBE_I18N.getLanguage()==="ar"?"اختر مادة واحدة على الأقل.":"Select at least one subject.";
    document.getElementById("teacherAppMsg").className="error";return false;
  }
  document.getElementById("teacherAppMsg").textContent="";document.getElementById("teacherAppMsg").className="";
  return true;
}
function renderSummary(){
  const ar=JBE_I18N.getLanguage()==="ar";
  document.getElementById("teacherSummary").innerHTML=`
    <strong>${ar?"ملخص سريع قبل الإرسال":"Quick review before submission"}</strong>
    <p>${val("full_name")} • ${val("email")}</p>
    <p>${checked("subjects").join(" • ")||"—"}</p>
    <p>${checked("education_systems").join(" • ")||"—"}</p>
    <p>${checked("teaching_languages").join(" • ")||"—"}</p>`;
}
document.getElementById("nextStep").onclick=()=>{if(validateStep()){currentStep++;renderStep()}};
document.getElementById("prevStep").onclick=()=>{currentStep--;renderStep()};
form.onsubmit=async e=>{
  e.preventDefault();if(!validateStep())return;
  const msg=document.getElementById("teacherAppMsg");msg.textContent="Submitting...";
  const {data,error}=await JBE.client.rpc("public_submit_teacher_application",{
    p_full_name:val("full_name"),p_email:val("email"),p_phone:val("phone"),
    p_country_code:val("country_code")||"EG",p_city:val("city"),p_current_role:val("current_role"),
    p_years_experience:val("years_experience")?Number(val("years_experience")):null,
    p_headline:val("headline"),p_bio:val("bio"),p_education_systems:checked("education_systems"),
    p_subjects:checked("subjects"),p_grades:checked("grades"),p_teaching_languages:checked("teaching_languages"),
    p_study_modes:checked("study_modes"),p_qualifications:val("qualifications"),p_current_work:val("current_work"),
    p_sample_video_url:val("sample_video_url"),p_professional_url:val("professional_url"),
    p_availability_notes:val("availability_notes"),p_pricing_notes:val("pricing_notes"),p_why_jbe:val("why_jbe"),
    p_consent:form.elements.consent.checked
  });
  if(error){msg.textContent=error.message;msg.className="error";return}
  msg.className="success";
  msg.innerHTML=`<strong>${JBE_I18N.getLanguage()==="ar"?"تم استلام طلبك":"Application received"}</strong><br>${JBE_I18N.getLanguage()==="ar"?"كود الطلب":"Application code"}: ${data.application_code}<br>${JBE_I18N.getLanguage()==="ar"?"سنراجع الملف ونتواصل معك إذا كان مناسبًا للمرحلة التالية.":"We will review your profile and contact you if there is a fit for the next step."}`;
  form.querySelectorAll("input,select,textarea,button").forEach(x=>x.disabled=true);
};
renderStep();
