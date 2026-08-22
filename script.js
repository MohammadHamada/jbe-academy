const form = document.getElementById('enrollForm');
const note = document.getElementById('formNote');
form.addEventListener('submit', function(e){
  e.preventDefault();
  const data = new FormData(form);
  note.textContent = `تم استلام طلب تجريبي باسم ${data.get('studentName')} للكورس ${data.get('course')}.`;
  form.reset();
});
document.getElementById('langBtn').addEventListener('click', function(){
  alert('سنضيف النسخة الإنجليزية الكاملة بعد اعتماد النسخة العربية.');
});
