const { createClient } = supabase;
const cfg = window.JBE_CONFIG;
const client = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const form = document.getElementById("loginForm");
const message = document.getElementById("loginMessage");

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  message.textContent = "Signing in...";
  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;
  const { error } = await client.auth.signInWithPassword({ email, password });
  if (error) {
    message.textContent = error.message;
    message.className = "status-message error";
    return;
  }
  window.location.href = "student-dashboard.html";
});
