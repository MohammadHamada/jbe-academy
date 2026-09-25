/* ============================================================
   JBE Academy V2.9.x - Progressive Smart Finder Logic
============================================================ */

document.addEventListener('DOMContentLoaded', () => {
    // التأكد من تهيئة Supabase أولاً
    if (typeof supabase === 'undefined') {
        console.error("Supabase client is not loaded. Please ensure supabase-config.js is included.");
        return;
    }

    const elSystem = document.getElementById('sf-system');
    const elPathway = document.getElementById('sf-pathway');
    const elStage = document.getElementById('sf-stage');
    const elGrade = document.getElementById('sf-grade');
    const elSubject = document.getElementById('sf-subject');
    const elBtn = document.getElementById('sf-btn');

    if (!elSystem) return; 

    const resetSelect = (el, defaultText) => {
        el.innerHTML = `<option value="">${defaultText}</option>`;
        el.disabled = true;
    };

    async function loadSystems() {
        try {
            const { data, error } = await supabase
                .from('education_systems')
                .select('id, name_ar')
                .eq('is_active', true)
                .order('sort_order');
            
            if (!error && data) {
                data.forEach(sys => {
                    const opt = document.createElement('option');
                    opt.value = sys.id;
                    opt.textContent = sys.name_ar;
                    elSystem.appendChild(opt);
                });
            }
        } catch (err) { console.error(err); }
    }

    elSystem.addEventListener('change', async (e) => {
        const sysId = e.target.value;
        resetSelect(elPathway, 'اختر المسار...');
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!sysId) return;

        const { data } = await supabase
            .from('curricula')
            .select('id, name_ar')
            .eq('education_system_id', sysId)
            .eq('is_active', true)
            .order('sort_order');
        
        if (data && data.length > 0) {
            elPathway.disabled = false;
            data.forEach(c => {
                const opt = document.createElement('option');
                opt.value = c.id;
                opt.textContent = c.name_ar;
                elPathway.appendChild(opt);
            });
        }
    });

    elPathway.addEventListener('change', async (e) => {
        const pathId = e.target.value;
        resetSelect(elStage, 'اختر المرحلة...');
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!pathId) return;

        const { data } = await supabase
            .from('academic_stages')
            .select('id, name_ar')
            .eq('is_active', true)
            .order('sort_order');
        
        if (data && data.length > 0) {
            elStage.disabled = false;
            data.forEach(s => {
                const opt = document.createElement('option');
                opt.value = s.id;
                opt.textContent = s.name_ar;
                elStage.appendChild(opt);
            });
        }
    });

    elStage.addEventListener('change', async (e) => {
        const stageId = e.target.value;
        resetSelect(elGrade, 'اختر الصف...');
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!stageId) return;

        const { data } = await supabase
            .from('grade_levels')
            .select('id, name_ar')
            .eq('stage_id', stageId)
            .eq('is_active', true)
            .order('sort_order');
        
        if (data && data.length > 0) {
            elGrade.disabled = false;
            data.forEach(g => {
                const opt = document.createElement('option');
                opt.value = g.id;
                opt.textContent = g.name_ar;
                elGrade.appendChild(opt);
            });
        }
    });

    elGrade.addEventListener('change', async (e) => {
        const gradeId = e.target.value;
        const currId = elPathway.value;
        resetSelect(elSubject, 'اختر اللغة...');
        elBtn.disabled = true;

        if (!gradeId || !currId) return;

        const { data, error } = await supabase
            .from('curriculum_grade_subjects')
            .select(`
                subject_id,
                subjects!inner(id, code)
            `)
            .eq('curriculum_id', currId)
            .eq('grade_level_id', gradeId)
            .eq('is_active', true)
            .in('subjects.code', ['MATH_AR', 'MATH_EN']);

        if (!error && data && data.length > 0) {
            elSubject.disabled = false;
            data.forEach(m => {
                const subj = m.subjects;
                const opt = document.createElement('option');
                opt.value = subj.id;
                opt.textContent = subj.code === 'MATH_AR' ? 'الرياضيات (بالعربي)' : 'Math (English)';
                elSubject.appendChild(opt);
            });
        }
    });

    elSubject.addEventListener('change', (e) => {
        elBtn.disabled = !e.target.value;
    });

    elBtn.addEventListener('click', () => {
        const subjectId = elSubject.value;
        const gradeId = elGrade.value;
        const currId = elPathway.value;
        if(subjectId && gradeId && currId) {
            window.location.href = `/courses.html?curriculum=${currId}&grade=${gradeId}&subject=${subjectId}`;
        }
    });

    loadSystems();
});
