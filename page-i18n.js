window.JBE_PAGE_I18N = (() => {
  function lang(){ return window.JBE_I18N?.getLanguage?.() || "ar"; }

  function apply(root=document){
    const current=lang();
    document.documentElement.lang=current;
    document.documentElement.dir=current==="ar"?"rtl":"ltr";

    root.querySelectorAll("[data-ar][data-en]").forEach(el=>{
      const value=current==="ar"?el.dataset.ar:el.dataset.en;
      if(el.matches("input,textarea")) el.placeholder=value;
      else el.textContent=value;
    });

    root.querySelectorAll("[data-placeholder-ar][data-placeholder-en]").forEach(el=>{
      el.placeholder=current==="ar"?el.dataset.placeholderAr:el.dataset.placeholderEn;
    });
  }

  document.addEventListener("DOMContentLoaded",()=>apply(document));
  window.addEventListener("jbe:languagechange",()=>apply(document));
  return {apply,lang};
})();
