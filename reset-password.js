
const client=supabase.createClient(window.JBE_CONFIG.SUPABASE_URL,window.JBE_CONFIG.SUPABASE_ANON_KEY);
const $=id=>document.getElementById(id);
$("resetForm").onsubmit=async e=>{
 e.preventDefault();const p=$("newPassword").value;if(p!==$("confirmPassword").value){$("resetMsg").textContent="Passwords do not match.";return}
 const {error}=await client.auth.updateUser({password:p});
 if(error){$("resetMsg").textContent=error.message;return}
 $("resetMsg").textContent=JBE_I18N.t("Password updated");setTimeout(()=>location.href="student-login.html",800);
};
