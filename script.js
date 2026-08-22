// ===== JBE Academy V1.2 =====
// Add your real details here later.

const CONFIG = {
  whatsappNumber: "201069338883",
  instaPayText: "mohammadalgebaly@instapay",
  vodafoneCashText: "00201069338883",
  youtubeChannelUrl: ""
};

const whatsappFloat = document.getElementById("whatsappFloat");
const whatsappInline = document.getElementById("whatsappInline");
const instaPayText = document.getElementById("instapayText");
const vodafoneText = document.getElementById("vodafoneText");
const courseSelect = document.getElementById("courseSelect");

instaPayText.textContent = CONFIG.instaPayText;
vodafoneText.textContent = CONFIG.vodafoneCashText;

function whatsappLink(message = "مرحبًا، أريد الاستفسار عن كورسات JBE Academy") {
  if (!CONFIG.whatsappNumber) return "#";
  return `https://wa.me/${CONFIG.whatsappNumber}?text=${encodeURIComponent(message)}`;
}

whatsappFloat.href = whatsappLink();
whatsappInline.href = whatsappLink();

document.querySelectorAll("[data-course]").forEach(btn => {
  btn.addEventListener("click", () => {
    if (courseSelect) {
      courseSelect.value = btn.dataset.course;
    }
  });
});

document.querySelectorAll("[data-youtube]").forEach(link => {
  link.href = CONFIG.youtubeChannelUrl || "#youtube";
});

document.getElementById("enrollForm").addEventListener("submit", function(e){
  e.preventDefault();

  const data = new FormData(this);
  const name = data.get("studentName");
  const phone = data.get("phone");
  const parent = data.get("parentPhone") || "غير مذكور";
  const course = data.get("course");

  const msg =
`مرحبًا، أريد التسجيل في JBE Academy.
اسم الطالب: ${name}
الكورس: ${course}
رقم الطالب: ${phone}
رقم ولي الأمر: ${parent}`;

  if (CONFIG.whatsappNumber) {
    window.open(whatsappLink(msg), "_blank");
  } else {
    document.getElementById("formNote").textContent =
      "تم تجهيز الطلب. أضف رقم WhatsApp الحقيقي داخل script.js لتفعيل الإرسال المباشر.";
  }
});

document.getElementById("langBtn").addEventListener("click", function(){
  alert("النسخة الإنجليزية الكاملة ستكون ضمن التحديث التالي.");
});


// V1.4 payment proof buttons
const vodafoneProofBtn = document.getElementById("vodafoneProofBtn");
if (vodafoneProofBtn) {
  const proofMessage = "مرحبًا، تم الدفع عبر Vodafone Cash إلى الرقم 00201069338883. أريد إرسال إثبات الدفع وتأكيد الاشتراك في JBE Academy.";
  vodafoneProofBtn.href = `https://wa.me/201069338883?text=${encodeURIComponent(proofMessage)}`;
}
