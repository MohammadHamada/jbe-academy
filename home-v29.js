/* ============================================================
   JBE Academy - Progressive Smart Finder (V3.0 Base)
   Handles dynamic cascading dropdowns for Math-First Launch
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    // 1. تحديد عناصر DOM
    const elSystem = document.getElementById('sf-system');
    const elPathway = document.getElementById('sf-pathway');
    const elStage = document.getElementById('sf-stage');
    const elGrade = document.getElementById('sf-grade');
    const elSubject = document.getElementById('sf-subject');
    const elBtn = document.getElementById('sf-btn');

    // التحقق من وجود العناصر لتجنب أخطاء المتصفح
    if (!elSystem || !elPathway) return;

    // دالة مساعدة لإعادة ضبط وإغلاق القوائم
    const resetSelect = (el, defaultText) => {
        el.innerHTML = `<option value="">${defaultText}</option>`;
        el.disabled = true;
    };

    // 2. تحميل أنظمة التعليم (عند فتح الصفحة)
    async function loadEducationSystems() {
        try {
            const { data, error } = await supabase
                .from('education_systems')
                .select('id, name_ar, name_en')
                .eq('is_active', true)
                .order('sort_order', { ascending: true });
            
            if (error) throw error;

            if (data) {
                data.forEach(sys => {
                    const opt = document.createElement('option');
                    opt.value = sys.id;
                    opt.textContent = sys.name_ar; // العرض بالعربية
                    elSystem.appendChild(opt);
                });
            }
        } catch (err) {
            console.error('Error loading systems:', err);
        }
    }

    // 3. عند اختيار "نظام التعليم" -> تحميل "المسارات"
    elSystem.addEventListener('change', async (e) => {
        const systemId = e.target.value;
        
        resetSelect(elPathway, 'اختر المسار');
        resetSelect(elStage, 'اختر المرحلة');
        resetSelect(elGrade, 'اختر الصف');
        resetSelect(elSubject, 'اختر لغة Math');
        elBtn.disabled = true;

        if (!systemId) return;

        try {
            const { data, error } = await supabase
                .from('curricula')
                .select('id, name_ar, name_en')
                .eq('education_system_id', systemId)
                .eq('is_active', true)
                .order('sort_order', { ascending: true });

            if (error) throw error;

            if (data && data.length > 0) {
                elPathway.disabled = false;
                data.forEach(curr => {
                    const opt = document.createElement('option');
                    opt.value = curr.id;
                    opt.textContent = curr.name_ar;
                    elPathway.appendChild(opt);
                });
            }
        } catch (err) {
            console.error('Error loading pathways:', err);
        }
    });

    // 4. عند اختيار "المسار" -> تحميل "المراحل"
    elPathway.addEventListener('change', async (e) => {
        const pathwayId = e.target.value;

        resetSelect(elStage, 'اختر المرحلة');
        resetSelect(elGrade, 'اختر الصف');
        resetSelect(elSubject, 'اختر لغة Math');
        elBtn.disabled = true;

        if (!pathwayId) return;

        try {
            // جلب المراحل النشطة بشكل عام (أو يمكن ربطها بالمسار إذا تطلب الهيكل ذلك)
            const { data, error } = await supabase
                .from('academic_stages')
                .select('id, name_ar')
                .eq('is_active', true)
                .order('sort_order', { ascending: true });

            if (error) throw error;

            if (data && data.length > 0) {
                elStage.disabled = false;
                data.forEach(stage => {
                    const opt = document.createElement('option');
                    opt.value = stage.id;
                    opt.textContent = stage.name_ar;
                    elStage.appendChild(opt);
                });
            }
        } catch (err) {
            console.error('Error loading stages:', err);
        }
    });

    // 5. عند اختيار "المرحلة" -> تحميل "الصفوف"
    elStage.addEventListener('change', async (e) => {
        const stageId = e.target.value;

        resetSelect(elGrade, 'اختر الصف');
        resetSelect(elSubject, 'اختر لغة Math');
        elBtn.disabled = true;

        if (!stageId) return;

        try {
            const { data, error } = await supabase
                .from('grade_levels')
                .select('id, name_ar')
                .eq('stage_id', stageId)
                .eq('is_active', true)
                .order('sort_order', { ascending: true });

            if (error) throw error;

            if (data && data.length > 0) {
                elGrade.disabled = false;
                data.forEach(grade => {
                    const opt = document.createElement('option');
                    opt.value = grade.id;
                    opt.textContent = grade.name_ar;
                    elGrade.appendChild(opt);
                });
            }
        } catch (err) {
            console.error('Error loading grades:', err);
        }
    });

    // 6. عند اختيار "الصف" -> تحميل "لغة Math" (الربط الدقيق بـ MATH_AR و MATH_EN)
    elGrade.addEventListener('change', async (e) => {
        const gradeId = e.target.value;
        const currId = elPathway.value;

        resetSelect(elSubject, 'اختر لغة Math');
        elBtn.disabled = true;

        if (!gradeId || !currId) return;

        try {
            // جلب المواد المرتبطة بهذا المسار وهذا الصف وتكون MATH فقط
            const { data, error } = await supabase
                .from('curriculum_grade_subjects')
                .select(`
                    subject_id,
                    subjects!inner(id, code, name_ar, name_en)
                `)
                .eq('curriculum_id', currId)
                .eq('grade_level_id', gradeId)
                .eq('is_active', true)
                .in('subjects.code', ['MATH_AR', 'MATH_EN']);

            if (error) throw error;

            if (data && data.length > 0) {
                elSubject.disabled = false;
                data.forEach(mapping => {
                    const subj = mapping.subjects;
                    const opt = document.createElement('option');
                    opt.value = subj.id;
                    
                    // تخصيص النص الظاهر للعميل ليكون واضحاً جداً
                    if (subj.code === 'MATH_AR') {
                        opt.textContent = 'الرياضيات (بالعربي)';
                    } else if (subj.code === 'MATH_EN') {
                        opt.textContent = 'Math (English)';
                    } else {
                        opt.textContent = subj.name_ar;
                    }
                    
                    elSubject.appendChild(opt);
                });
            }
        } catch (err) {
            console.error('Error loading subjects:', err);
        }
    });

    // 7. تفعيل زر البحث عند اكتمال الاختيارات
    elSubject.addEventListener('change', (e) => {
        if (e.target.value) {
            elBtn.disabled = false;
        } else {
            elBtn.disabled = true;
        }
    });

    // 8. التعامل مع زر "عرض الخيارات"
    elBtn.addEventListener('click', () => {
        const subjectId = elSubject.value;
        const gradeId = elGrade.value;
        const currId = elPathway.value;
        
        if(subjectId && gradeId && currId) {
            // توجيه المستخدم إلى صفحة الكورسات مع المعاملات المطلوبة
            window.location.href = `/courses.html?curriculum=${currId}&grade=${gradeId}&subject=${subjectId}`;
        }
    });

    // بدء تشغيل المحرك
    loadEducationSystems();
});
