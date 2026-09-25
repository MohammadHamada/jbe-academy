/* ============================================================
   JBE Academy V2.9.x - Progressive Smart Finder Logic (Fixed)
   Database Columns Updated to: title_ar
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    // 1. تحقق من تحميل مكتبة Supabase
    if (typeof supabase === 'undefined') {
        console.error("خطأ: لم يتم تحميل مكتبة Supabase. تأكد من استدعاء supabase-config.js أولاً.");
        return;
    }

    // 2. مطابقة معرفات HTML (تأكد أن هذه المعرفات مطابقة لما هو مكتوب في ملف index.html لديك)
    const elSystem = document.getElementById('sf-system');
    const elPathway = document.getElementById('sf-pathway');
    const elStage = document.getElementById('sf-stage');
    const elGrade = document.getElementById('sf-grade');
    const elSubject = document.getElementById('sf-subject');
    const elBtn = document.getElementById('sf-btn');

    // إذا لم تكن هذه العناصر موجودة في الصفحة، أوقف تنفيذ الكود
    if (!elSystem) {
        console.warn("لم يتم العثور على حقول البحث المتدرج في هذه الصفحة.");
        return;
    }

    // دالة مساعدة لتفريغ وإغلاق القوائم المنسدلة
    const resetSelect = (el, defaultText) => {
        el.innerHTML = `<option value="">${defaultText}</option>`;
        el.disabled = true;
    };

    // 3. تحميل أنظمة التعليم (عند فتح الصفحة مباشرة)
    async function loadSystems() {
        try {
            const { data, error } = await supabase
                .from('education_systems')
                .select('id, title_ar') // تم التصحيح إلى title_ar بناءً على بنية قاعدة البيانات
                .eq('is_active', true)
                .order('sort_order');
            
            if (error) throw error;

            if (data && data.length > 0) {
                data.forEach(sys => {
                    const opt = document.createElement('option');
                    opt.value = sys.id;
                    opt.textContent = sys.title_ar;
                    elSystem.appendChild(opt);
                });
            } else {
                console.log("لا توجد أنظمة تعليم نشطة في قاعدة البيانات.");
            }
        } catch (err) { 
            console.error("خطأ في جلب أنظمة التعليم:", err.message); 
        }
    }

    // 4. تحميل المسارات عند اختيار نظام التعليم
    elSystem.addEventListener('change', async (e) => {
        const sysId = e.target.value;
        
        // تصفير القوائم التالية
        resetSelect(elPathway, 'اختر المسار...');
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر لغة Math...');
        elBtn.disabled = true;

        if (!sysId) return;

        try {
            const { data, error } = await supabase
                .from('curricula')
                .select('id, title_ar')
                .eq('education_system_id', sysId)
                .eq('is_active', true)
                .order('sort_order');
            
            if (error) throw error;

            if (data && data.length > 0) {
                elPathway.disabled = false;
                data.forEach(c => {
                    const opt = document.createElement('option');
                    opt.value = c.id;
                    opt.textContent = c.title_ar;
                    elPathway.appendChild(opt);
                });
            }
        } catch (err) { console.error("خطأ في جلب المسارات:", err.message); }
    });

    // 5. تحميل المراحل عند اختيار المسار
    elPathway.addEventListener('change', async (e) => {
        const pathId = e.target.value;
        
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر لغة Math...');
        elBtn.disabled = true;

        if (!pathId) return;

        try {
            const { data, error } = await supabase
                .from('academic_stages')
                .select('id, title_ar')
                .eq('is_active', true)
                .order('sort_order');
            
            if (error) throw error;

            if (data && data.length > 0) {
                elStage.disabled = false;
                data.forEach(s => {
                    const opt = document.createElement('option');
                    opt.value = s.id;
                    opt.textContent = s.title_ar;
                    elStage.appendChild(opt);
                });
            }
        } catch (err) { console.error("خطأ في جلب المراحل:", err.message); }
    });

    // 6. تحميل الصفوف عند اختيار المرحلة
    elStage.addEventListener('change', async (e) => {
        const stageId = e.target.value;
        
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر لغة Math...');
        elBtn.disabled = true;

        if (!stageId) return;

        try {
            const { data, error } = await supabase
                .from('grade_levels')
                .select('id, title_ar')
                .eq('stage_id', stageId)
                .eq('is_active', true)
                .order('sort_order');
            
            if (error) throw error;

            if (data && data.length > 0) {
                elGrade.disabled = false;
                data.forEach(g => {
                    const opt = document.createElement('option');
                    opt.value = g.id;
                    opt.textContent = g.title_ar;
                    elGrade.appendChild(opt);
                });
            }
        } catch (err) { console.error("خطأ في جلب الصفوف:", err.message); }
    });

    // 7. تحميل المادة الصحيحة (MATH_AR أو MATH_EN)
    elGrade.addEventListener('change', async (e) => {
        const gradeId = e.target.value;
        const currId = elPathway.value; // جلب رقم المسار الحالي
        
        resetSelect(elSubject, 'اختر لغة Math...');
        elBtn.disabled = true;

        if (!gradeId || !currId) return;

        try {
            const { data, error } = await supabase
                .from('curriculum_grade_subjects')
                .select(`
                    subject_id,
                    subjects!inner(id, code)
                `)
                .eq('curriculum_id', currId)
                .eq('grade_level_id', gradeId)
                .eq('is_active', true)
                .in('subjects.code', ['MATH_AR', 'MATH_EN']); // تصفية المواد لتكون رياضيات فقط

            if (error) throw error;

            if (data && data.length > 0) {
                elSubject.disabled = false;
                data.forEach(m => {
                    const subj = m.subjects;
                    const opt = document.createElement('option');
                    opt.value = subj.id;
                    
                    // تغيير النص بناءً على الكود الخاص بالمادة
                    opt.textContent = subj.code === 'MATH_AR' ? 'الرياضيات (بالعربي)' : 'Math (English)';
                    
                    elSubject.appendChild(opt);
                });
            }
        } catch (err) { console.error("خطأ في جلب المواد:", err.message); }
    });

    // 8. تفعيل زر البحث فقط عند اختيار المادة
    elSubject.addEventListener('change', (e) => {
        elBtn.disabled = !e.target.value;
    });

    // 9. تنفيذ التوجيه عند الضغط على زر البحث
    elBtn.addEventListener('click', () => {
        const subjectId = elSubject.value;
        const gradeId = elGrade.value;
        const currId = elPathway.value;
        
        if(subjectId && gradeId && currId) {
            window.location.href = `/courses.html?curriculum=${currId}&grade=${gradeId}&subject=${subjectId}`;
        }
    });

    // تشغيل الدالة الأولى لجلب أنظمة التعليم
    loadSystems();
});
