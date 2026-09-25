/* ============================================================
   JBE Academy V2.9.x - Progressive Smart Finder (Fully Automated)
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    // التحقق من الاتصال بقاعدة البيانات
    if (typeof supabase === 'undefined') {
        console.error("Supabase is missing!");
        return;
    }

    // تعريف الحقول المربوطة تلقائياً بملف HTML
    const elSystem = document.getElementById('sf-system');
    const elPathway = document.getElementById('sf-pathway');
    const elStage = document.getElementById('sf-stage');
    const elGrade = document.getElementById('sf-grade');
    const elSubject = document.getElementById('sf-subject');
    const elBtn = document.getElementById('sf-btn');

    if (!elSystem) return;

    // دالة تفريغ الحقول التلقائي
    const resetSelect = (el, text) => {
        el.innerHTML = `<option value="">${text}</option>`;
        el.disabled = true;
    };

    // 1. جلب أنظمة التعليم
    async function loadSystems() {
        const { data, error } = await supabase
            .from('education_systems')
            .select('id, title_ar')
            .eq('is_active', true)
            .order('sort_order');
        
        if (data) {
            data.forEach(item => {
                const opt = document.createElement('option');
                opt.value = item.id;
                opt.textContent = item.title_ar;
                elSystem.appendChild(opt);
            });
        }
    }

    // 2. جلب المسارات
    elSystem.addEventListener('change', async (e) => {
        const val = e.target.value;
        resetSelect(elPathway, 'اختر المسار...');
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!val) return;

        const { data } = await supabase.from('curricula').select('id, title_ar').eq('education_system_id', val).eq('is_active', true).order('sort_order');
        if (data && data.length > 0) {
            elPathway.disabled = false;
            data.forEach(i => {
                const opt = document.createElement('option');
                opt.value = i.id;
                opt.textContent = i.title_ar;
                elPathway.appendChild(opt);
            });
        }
    });

    // 3. جلب المراحل
    elPathway.addEventListener('change', async (e) => {
        const val = e.target.value;
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!val) return;

        const { data } = await supabase.from('academic_stages').select('id, title_ar').eq('is_active', true).order('sort_order');
        if (data && data.length > 0) {
            elStage.disabled = false;
            data.forEach(i => {
                const opt = document.createElement('option');
                opt.value = i.id;
                opt.textContent = i.title_ar;
                elStage.appendChild(opt);
            });
        }
    });

    // 4. جلب الصفوف
    elStage.addEventListener('change', async (e) => {
        const val = e.target.value;
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!val) return;

        const { data } = await supabase.from('grade_levels').select('id, title_ar').eq('stage_id', val).eq('is_active', true).order('sort_order');
        if (data && data.length > 0) {
            elGrade.disabled = false;
            data.forEach(i => {
                const opt = document.createElement('option');
                opt.value = i.id;
                opt.textContent = i.title_ar;
                elGrade.appendChild(opt);
            });
        }
    });

    // 5. جلب لغة المادة (عزل MATH_AR و MATH_EN)
    elGrade.addEventListener('change', async (e) => {
        const gradeId = e.target.value;
        const currId = elPathway.value;
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!gradeId || !currId) return;

        const { data } = await supabase
            .from('curriculum_grade_subjects')
            .select('subject_id, subjects!inner(id, code)')
            .eq('curriculum_id', currId)
            .eq('grade_level_id', gradeId)
            .eq('is_active', true)
            .in('subjects.code', ['MATH_AR', 'MATH_EN']);

        if (data && data.length > 0) {
            elSubject.disabled = false;
            data.forEach(m => {
                const opt = document.createElement('option');
                opt.value = m.subjects.id;
                opt.textContent = m.subjects.code === 'MATH_AR' ? 'الرياضيات (بالعربي)' : 'Math (English)';
                elSubject.appendChild(opt);
            });
        }
    });

    // 6. تشغيل الزر والتوجيه
    elSubject.addEventListener('change', (e) => { elBtn.disabled = !e.target.value; });

    elBtn.addEventListener('click', () => {
        window.location.href = `/courses.html?curriculum=${elPathway.value}&grade=${elGrade.value}&subject=${elSubject.value}`;
    });

    // الإقلاع التلقائي
    loadSystems();
});
