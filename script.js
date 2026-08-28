// ===== JBE Academy =====

const CONFIG = {
  whatsappBusinessLink: "https://wa.me/message/CMZT2FQE754UC1",
  whatsappNumber: "201069338883",
  instaPayLink: "https://ipn.eg/S/mohammadalgebaly/instapay/0QFtEN",
  instaPayHandle: "mohammadalgebaly@instapay",
  vodafoneCashNumber: "00201069338883",
  youtubeChannelUrl: ""
};

const whatsappFloat = document.getElementById("whatsappFloat");
const whatsappInline = document.getElementById("whatsappInline");
const courseSelect = document.getElementById("courseSelect");

if (whatsappFloat) whatsappFloat.href = CONFIG.whatsappBusinessLink;
if (whatsappInline) whatsappInline.href = CONFIG.whatsappBusinessLink;

function whatsappPrefilledLink(message) {
  return `https://wa.me/${CONFIG.whatsappNumber}?text=${encodeURIComponent(message)}`;
}

document.querySelectorAll("[data-course]").forEach(btn => {
  btn.addEventListener("click", () => {
    if (courseSelect) courseSelect.value = btn.dataset.course;
  });
});

document.querySelectorAll("[data-youtube]").forEach(link => {
  link.href = CONFIG.youtubeChannelUrl || "#youtube";
});

const enrollForm = document.getElementById("enrollForm");

if (enrollForm) {
  enrollForm.addEventListener("submit", function(e) {
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

    window.open(whatsappPrefilledLink(msg), "_blank");
  });
}

const vodafoneProofBtn = document.getElementById("vodafoneProofBtn");

if (vodafoneProofBtn) {
  const proofMessage =
    "مرحبًا، تم الدفع عبر Vodafone Cash إلى الرقم 00201069338883. أريد إرسال إثبات الدفع وتأكيد الاشتراك في JBE Academy.";

  vodafoneProofBtn.href = whatsappPrefilledLink(proofMessage);
}
