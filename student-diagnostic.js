/* ============================================================
   JBE Academy V3.0 - Student Diagnostic Assessment Engine
   Interacts with math_skills_v29 & student_skill_mastery_v29
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    if (typeof supabase === 'undefined') {
        alert("Supabase client is not loaded.");
        return;
    }

    const studentSelect = document.getElementById('demo-student-select');
    const skillsContainer = document.getElementById('skills-container');
    const saveBtn = document.getElementById('save-assessment-btn');

    let currentSkills = [];
    let studentMastery = [];

    // 1. جلب المهارات والتقييمات عند اختيار الطالب
    studentSelect.addEventListener('change', async (e) => {
        const studentId = e.target.value;
        if (!studentId) {
            skillsContainer.innerHTML = '<div style="text-align: center; padding: 3rem; color: var(--text-muted);">يرجى اختيار الطالب أولاً...</div>';
            saveBtn.disabled = true;
            return;
        }

        skillsContainer.innerHTML = '<div style="text-align: center; padding: 2rem;">جاري تحميل المهارات...</div>';
        saveBtn.disabled = true;

        try {
            // أ. جلب قائمة المهارات من قاعدة البيانات
            const { data: skillsData, error: skillsErr } = await supabase
                .from('math_skills_v29')
                .select('id, skill_code, domain_ar, domain_en, skill_ar, skill_en')
                .eq('is_active', true)
                .order('sort_order');

            if (skillsErr) throw skillsErr;
            currentSkills = skillsData || [];

            // ب. جلب تقييمات الطالب السابقة إن وجدت
            const { data: masteryData, error: masteryErr } = await supabase
                .from('student_skill_mastery_v29')
                .select('skill_id, mastery_level, evidence_note')
                .eq('student_id', studentId);

            if (masteryErr) throw masteryErr;
            studentMastery = masteryData || [];

            renderSkillsUI(studentId);

        } catch (error) {
            console.error("Error loading diagnostic data:", error);
            skillsContainer.innerHTML = '<div style="color: red; text-align: center;">حدث خطأ في تحميل البيانات.</div>';
        }
    });

    // 2. رسم واجهة التقييم
    function renderSkillsUI(studentId) {
        skillsContainer.innerHTML = '';

        if (currentSkills.length === 0) {
            skillsContainer.innerHTML = '<div style="text-align: center; padding: 2rem;">لا توجد مهارات مسجلة في النظام بعد. يرجى إضافتها من لوحة الإدارة.</div>';
            return;
        }

        currentSkills.forEach(skill => {
            // البحث هل تم تقييم هذا الطالب مسبقاً في هذه المهارة؟
            const existingRecord = studentMastery.find(m => m.skill_id === skill.id);
            const currentLevel = existingRecord ? existingRecord.mastery_level : 0;
            const currentNote = existingRecord && existingRecord.evidence_note ? existingRecord.evidence_note : '';

            // دالة مساعدة لتلوين القائمة المنسدلة حسب المستوى
            const getLevelClass = (lvl) => `level-${lvl}`;

            const card = document.createElement('div');
            card.className = 'skill-card';
            card.innerHTML = `
                <div class="skill-info">
                    <div style="font-size: 0.85rem; color: var(--accent); font-weight: bold;">${skill.skill_code} | ${skill.domain_ar || skill.domain_en}</div>
                    <div style="font-weight: bold; font-size: 1.1rem; color: var(--text-main); margin-top: 0.25rem;">${skill.skill_ar || skill.skill_en}</div>
                </div>
                
                <div class="skill-level">
                    <label style="font-size: 0.85rem; font-weight: bold; display: block; margin-bottom: 0.3rem;">مستوى الإتقان (0 - 4)</label>
                    <select class="level-select ${getLevelClass(currentLevel)}" data-skill-id="${skill.id}">
                        <option value="0" class="level-0" ${currentLevel === 0 ? 'selected' : ''}>0 - لم يتم التقييم</option>
                        <option value="1" class="level-1" ${currentLevel === 1 ? 'selected' : ''}>1 - بداية (Beginning)</option>
                        <option value="2" class="level-2" ${currentLevel === 2 ? 'selected' : ''}>2 - يتطور (Developing)</option>
                        <option value="3" class="level-3" ${currentLevel === 3 ? 'selected' : ''}>3 - متمكن (Secure)</option>
                        <option value="4" class="level-4" ${currentLevel === 4 ? 'selected' : ''}>4 - متقن (Mastered)</option>
                    </select>
                </div>

                <div class="skill-note">
                    <label style="font-size: 0.85rem; font-weight: bold; display: block; margin-bottom: 0.3rem;">ملاحظات المعلم / الدليل</label>
                    <input type="text" class="note-input" data-note-id="${skill.id}" placeholder="مثال: يخطئ في الإشارات السالبة..." value="${currentNote}">
                </div>
            `;
            skillsContainer.appendChild(card);
        });

        // تغيير لون القائمة عند تغيير المستوى
        document.querySelectorAll('.level-select').forEach(select => {
            select.addEventListener('change', (e) => {
                e.target.className = `level-select level-${e.target.value}`;
            });
        });

        saveBtn.disabled = false;
    }

    // 3. حفظ التقييمات في قاعدة البيانات
    saveBtn.addEventListener('click', async () => {
        const studentId = studentSelect.value;
        if (!studentId) return;

        saveBtn.textContent = 'جاري الحفظ...';
        saveBtn.disabled = true;

        const selects = document.querySelectorAll('.level-select');
        const upsertPayload = [];

        selects.forEach(select => {
            const skillId = select.getAttribute('data-skill-id');
            const level = parseInt(select.value);
            const noteInput = document.querySelector(`.note-input[data-note-id="${skillId}"]`);
            const note = noteInput.value.trim();

            // تجهيز البيانات للإرسال، لن نرسل إلا المهارات التي تم تقييمها (المستوى أكبر من 0) أو التي لها ملاحظة
            if (level > 0 || note !== '') {
                upsertPayload.push({
                    student_id: studentId,
                    skill_id: skillId,
                    mastery_level: level,
                    evidence_note: note || null,
                    last_assessed_at: new Date().toISOString(),
                    updated_at: new Date().toISOString()
                    // updated_by: يمكن إضافتها لاحقاً بربطها برقم المعلم الحالي من auth.uid()
                });
            }
        });

        if (upsertPayload.length === 0) {
            alert("لم تقم بإدخال أي تقييمات للحفظ.");
            saveBtn.textContent = 'حفظ التقييم وتحديث الخطة';
            saveBtn.disabled = false;
            return;
        }

        try {
            // استخدام Upsert لإضافة تقييم جديد أو تحديث التقييم القديم بناءً على student_id و skill_id
            const { error } = await supabase
                .from('student_skill_mastery_v29')
                .upsert(upsertPayload, { onConflict: 'student_id, skill_id' });

            if (error) throw error;

            saveBtn.textContent = 'تم الحفظ بنجاح!';
            saveBtn.style.backgroundColor = '#03543F'; // لون أخضر
            
            setTimeout(() => {
                saveBtn.textContent = 'حفظ التقييم وتحديث الخطة';
                saveBtn.style.backgroundColor = 'var(--primary)';
                saveBtn.disabled = false;
            }, 3000);

        } catch (error) {
            console.error("Error saving mastery:", error);
            alert("حدث خطأ أثناء الحفظ. الرجاء المحاولة مرة أخرى.");
            saveBtn.textContent = 'حفظ التقييم وتحديث الخطة';
            saveBtn.disabled = false;
        }
    });
});
