
const client=supabase.createClient(window.JBE_CONFIG.SUPABASE_URL,window.JBE_CONFIG.SUPABASE_ANON_KEY);
const $=id=>document.getElementById(id);
const token=new URLSearchParams(location.search).get("token");
let info=null;
async function load(){
 if(!token){$("setupMsg").textContent=JBE_I18N.t("Invite is invalid or expired");return}
 const {data,error}=await client.rpc("public_staff_invite_info",{p_token:token});
 if(error||!data){$("setupMsg").textContent=error?.message||JBE_I18N.t("Invite is invalid or expired");return}
 info=data;$("setupEmail").value=info.email;
 $("inviteInfo").innerHTML=`<div class="ops-item"><div><strong>${info.full_name}</strong><small>${info.email} • ${JBE_I18N.t(info.primary_role)}</small></div></div>`;
 localStorage.setItem("jbe_staff_invite_token",token);
}
async function claim(){
 const {data,error}=await client.rpc("claim_staff_invite",{p_token:token});
 if(error){$("setupMsg").textContent=error.message;return false}
 $("setupMsg").textContent=JBE_I18N.t("Account setup completed");
 localStorage.removeItem("jbe_staff_invite_token");
 setTimeout(()=>location.href="portal.html",800);return true;
}
$("signupForm").onsubmit=async e=>{
 e.preventDefault(); if(!info)return;
 const p=$("setupPassword").value;if(p!==$("setupConfirm").value){$("setupMsg").textContent="Passwords do not match.";return}
 const {data,error}=await client.auth.signUp({email:info.email,password:p});
 if(error){$("setupMsg").textContent=error.message;return}
 if(data.session){await claim()}else{$("setupMsg").textContent="Check your email to confirm the account, then return to this invite link and sign in."}
};
$("signinClaimForm").onsubmit=async e=>{
 e.preventDefault();if(!info)return;
 const {error}=await client.auth.signInWithPassword({email:info.email,password:$("claimPassword").value});
 if(error){$("setupMsg").textContent=error.message;return}
 await claim();
};
load();
