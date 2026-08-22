// ===== JBE Academy V1.1 =====
// Replace these values with your real project details.
const CONFIG = {
  whatsappNumber: "", // Example: "2010XXXXXXXX"
  instaPayText: "سيتم إضافة رابط InstaPay هنا",
  vodafoneCashText: "سيتم إضافة رقم المحفظة هنا",
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
    if (courseSelect) courseSelect.value = btn.dataset.course;
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
  alert("النسخة الإنجليزية الكاملة ستكون ضمن V1.2 بعد اعتماد المحتوى العربي.");
});
