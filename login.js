const { createClient } = supabase;

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

const client = createClient(
  cfg.SUPABASE_URL,
  cfg.SUPABASE_ANON_KEY
);

const form = document.getElementById("loginForm");
const message = document.getElementById("loginMessage");

function safeNextPage() {
  const params = new URLSearchParams(window.location.search);
  const next = params.get("next");

  if (!next) return null;

  if (
    next.startsWith("http://") ||
    next.startsWith("https://") ||
    next.startsWith("//") ||
    !/^[a-zA-Z0-9._-]+\.html$/.test(next)
  ) {
    return null;
  }

  return next;
}

function nextPageAllowed(next, role) {
  if (!next) return false;

  const adminPages = [
    "portal.html",
    "owner-dashboard.html",
    "admin-dashboard.html",
    "student-manage.html",
    "student-affairs.html",
    "finance-dashboard.html",
    "groups.html",
    "teacher-dashboard.html",
    "teacher-workspace.html",
    "teacher-session.html",
    "teacher-settings.html",
    "admissions-dashboard.html",
    "sales-crm.html",
    "staff-management.html",
    "audit-log.html",
    "teacher-approvals.html"
  ];

  const teacherPages = [
    "portal.html",
    "teacher-dashboard.html",
    "teacher-workspace.html",
    "teacher-session.html",
    "teacher-settings.html"
  ];

  const salesPages = [
    "portal.html",
    "admissions-dashboard.html",
    "sales-crm.html"
  ];

  const studentAffairsPages = [
    "portal.html",
    "student-affairs.html",
    "student-manage.html",
    "groups.html",
    "sales-crm.html"
  ];

  const financePages = [
    "portal.html",
    "finance-dashboard.html"
  ];

  if (["super_admin", "admin"].includes(role)) {
    return adminPages.includes(next);
  }

  if (role === "teacher") {
    return teacherPages.includes(next);
  }

  if (role === "sales") {
    return salesPages.includes(next);
  }

  if (role === "student_affairs") {
    return studentAffairsPages.includes(next);
  }

  if (role === "finance") {
    return financePages.includes(next);
  }

  if (role === "student") {
    return next === "student-dashboard.html";
  }

  if (role === "parent") {
    return next === "parent-dashboard.html";
  }

  return false;
}

async function resolveDestination() {
  const { data, error } = await client.rpc("resolve_my_portal");

  if (error) {
    console.error("Role resolver error:", error);
    throw new Error(
      "Could not determine the account role. Please contact JBE Academy."
    );
  }

  if (!data?.authenticated || !data?.destination) {
    return null;
  }

  const next = safeNextPage();

  if (nextPageAllowed(next, data.role)) {
    return next;
  }

  return data.destination;
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();

  message.textContent = JBE_I18N.t("Signing in...");
  message.className = "status-message";

  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;

  const { error } = await client.auth.signInWithPassword({
    email,
    password
  });

  if (error) {
    message.textContent = error.message;
    message.className = "status-message error";
    return;
  }

  try {
    message.textContent = (JBE_I18N.getLanguage()==="ar" ? "تم تسجيل الدخول. جارٍ فتح مساحة العمل..." : "Signed in. Opening your workspace...");

    const destination = await resolveDestination();

    if (!destination) {
      await client.auth.signOut();

      message.textContent =
        (JBE_I18N.getLanguage()==="ar" ? "بيانات الدخول صحيحة، لكن الحساب غير مرتبط بدور داخل JBE Academy حتى الآن." : "This login is valid, but it is not linked to a JBE Academy role yet.");

      message.className = "status-message error";
      return;
    }

    window.location.href = destination;
  } catch (err) {
    message.textContent = err.message;
    message.className = "status-message error";
  }
});

(async () => {
  const { data: { session } } = await client.auth.getSession();

  if (!session) return;

  try {
    message.textContent = (JBE_I18N.getLanguage()==="ar" ? "تم العثور على جلسة نشطة. جارٍ فتح مساحة العمل..." : "Active session found. Opening your workspace...");

    const destination = await resolveDestination();

    if (destination) {
      window.location.href = destination;
    }
  } catch (err) {
    message.textContent = err.message;
    message.className = "status-message error";
  }
})();
