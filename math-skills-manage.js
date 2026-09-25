/* ============================================================
   JBE Academy V3.0 - Math Skills Framework Management
   Aligns perfectly with math_skills_v29 schema
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    if (typeof supabase === 'undefined') {
        alert("خطأ: لم يتم تحميل Supabase.");
        return;
    }

    // تعريف عناصر القوائم المنسدلة
    const elCurriculum = document.getElementById('curriculum_id');
    const elGrade = document.getElementById('grade_level_id');
    const elSubject = document.getElementById('subject_id');
    const tbody = document.getElementById('skills-tbody');
    const form = document.getElementById('skill-form');
    const msg = document.getElementById('form-msg');

    // 1. تحميل البيانات الأساسية للقوائم
    async function loadSelectOptions() {
        try {
            // تحميل المسارات
            const { data: curricula } = await supabase.from('curricula').select('id, title_ar').eq('is_active', true).order('sort_order');
            if (curricula) {
                curricula.forEach(c => {
                    const opt = document.createElement('option');
                    opt.value = c.id;
                    opt.textContent = c.title_ar;
                    elCurriculum.appendChild(opt);
                });
            }

            // تحميل الصفوف
            const { data: grades } = await supabase.from('grade_levels').select('id, title_ar').eq('is_active', true).order('sort_order');
            if (grades) {
                grades.forEach(g => {
                    const opt = document.createElement('option');
                    opt.value = g.id;
                    opt.textContent = g.title_ar;
                    elGrade.appendChild(opt);
                });
            }

            // تحميل مواد الرياضيات فقط
            const { data: subjects } = await supabase.from('subjects').select('id, code, name_ar').in('code', ['MATH_AR', 'MATH_EN']);
            if (subjects) {
                subjects.forEach(s => {
                    const opt = document.createElement('option');
                    opt.value = s.id;
                    opt.textContent = s.code === 'MATH_AR' ? 'الرياضيات (بالعربي)' : 'Math (English)';
                    elSubject.appendChild(opt);
                });
            }
        } catch (err) {
            console.error("Error loading options:", err);
        }
    }

    // 2. تحميل المهارات الحالية في الجدول
    async function loadSkills() {
        try {
            const { data, error } = await supabase
                .from('math_skills_v29')
                .select('*')
                .order('sort_order');

            if (error) throw error;

            tbody.innerHTML = '';
            
            if (data.length === 0) {
                tbody.innerHTML = '<tr><td colspan="4" style="text-align: center;">لا توجد مهارات مسجلة حتى الآن.</td></tr>';
                return;
            }

            data.forEach(skill => {
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td style="font-weight: bold; color: var(--primary);">${skill.skill_code}</td>
                    <td>${skill.domain_ar || skill.domain_en}</td>
                    <td>${skill.skill_ar || skill.skill_en}</td>
                    <td><span class="badge ${skill.is_active ? 'badge-success' : 'badge-danger'}">${skill.is_active ? 'نشط' : 'معطل'}</span></td>
                `;
                tbody.appendChild(tr);
            });
        } catch (err) {
            console.error("Error loading skills:", err);
            tbody.innerHTML = '<tr><td colspan="4" style="text-align: center; color: red;">حدث خطأ في تحميل البيانات.</td></tr>';
        }
    }

    // 3. إضافة مهارة جديدة لقاعدة البيانات
    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        msg.textContent = 'جاري الحفظ...';
        msg.style.color = 'var(--text-muted)';
        
        const payload = {
            curriculum_id: elCurriculum.value || null,
            grade_level_id: elGrade.value || null,
            subject_id: elSubject.value || null,
            skill_code: document.getElementById('skill_code').value,
            domain_ar: document.getElementById('domain_ar').value || null,
            domain_en: document.getElementById('domain_en').value,
            skill_ar: document.getElementById('skill_ar').value || null,
            skill_en: document.getElementById('skill_en').value,
            sort_order: parseInt(document.getElementById('sort_order').value),
            is_active: true
        };

        try {
            const { error } = await supabase.from('math_skills_v29').insert([payload]);
            if (error) throw error;

            msg.textContent = 'تم حفظ المهارة بنجاح!';
            msg.style.color = 'green';
            form.reset(); // تفريغ الحقول
            loadSkills(); // تحديث الجدول فوراً
            
            setTimeout(() => { msg.textContent = ''; }, 3000);
        } catch (err) {
            console.error("Insert Error:", err);
            msg.textContent = 'حدث خطأ أثناء الحفظ. تأكد من صحة البيانات.';
            msg.style.color = 'red';
        }
    });

    // تشغيل الدوال عند فتح الصفحة
    loadSelectOptions();
    loadSkills();
});
