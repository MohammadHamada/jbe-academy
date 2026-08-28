const JBE = (() => {

  const cfg = window.JBE_CONFIG;

  if (
    !cfg ||
    !cfg.SUPABASE_URL ||
    !cfg.SUPABASE_ANON_KEY ||
    cfg.SUPABASE_URL.includes("YOUR_PROJECT_REF") ||
    cfg.SUPABASE_ANON_KEY.includes("YOUR_PUBLISHABLE")
  ) {
    throw new Error(
      "JBE Academy Supabase configuration is missing or still contains placeholders."
    );
  }

  const client = supabase.createClient(
    cfg.SUPABASE_URL,
    cfg.SUPABASE_ANON_KEY
  );

  async function session() {
    const { data: { session } } = await client.auth.getSession();
    return session;
  }

  function currentPageForReturn() {
    const file = window.location.pathname.split("/").pop();

    if (!file || !file.endsWith(".html")) {
      return null;
    }

    return file;
  }

  async function requireSession() {
    const s = await session();

    if (!s) {
      const currentPage = currentPageForReturn();

      const loginUrl = currentPage
        ? `student-login.html?next=${encodeURIComponent(currentPage)}`
        : "student-login.html";

      window.location.href = loginUrl;
      return null;
    }

    return s;
  }

  async function resolveRole() {
    const s = await requireSession();
    if (!s) return null;

    const { data, error } = await client.rpc("resolve_my_portal");

    if (error) {
      throw error;
    }

    return data;
  }

  async function staff() {
    const role = await resolveRole();

    if (!role || role.account_type !== "staff") {
      return null;
    }

    const { data, error } = await client
      .from("staff")
      .select("id, full_name, role, is_active")
      .eq("auth_user_id", (await session()).user.id)
      .maybeSingle();

    if (error) {
      throw error;
    }

    return data;
  }

  async function logout() {
    await client.auth.signOut();
    window.location.href = "student-login.html";
  }

  return {
    client,
    session,
    requireSession,
    resolveRole,
    staff,
    logout
  };

})();
