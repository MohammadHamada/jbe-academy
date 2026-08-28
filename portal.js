
const JBE = (() => {
  const client = supabase.createClient(window.JBE_CONFIG.SUPABASE_URL, window.JBE_CONFIG.SUPABASE_ANON_KEY);

  async function session(){ return (await client.auth.getSession()).data.session; }

  async function requireSession(){
    const s = await session();
    if(!s){ location.href="student-login.html"; return null; }
    return s;
  }

  async function staff(){
    const s = await requireSession(); if(!s) return null;
    const {data,error}=await client.from("staff").select("id,full_name,role,is_active").eq("auth_user_id",s.user.id).maybeSingle();
    if(error) throw error;
    return data;
  }

  async function logout(){
    await client.auth.signOut(); location.href="student-login.html";
  }

  return {client,session,requireSession,staff,logout};
})();
