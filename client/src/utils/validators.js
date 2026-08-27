const PASSWORD_REGEX = /^[a-zA-Z0-9#@$]+$/;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function validateEmail(email) {
  if (!email || !email.trim()) {
    return "Email is required";
  }
  if (!EMAIL_REGEX.test(email.trim())) {
    return "Please enter a valid email address";
  }
  return null;
}

export function validatePassword(password) {
  if (!password) {
    return "Password is required";
  }
  if (password.length < 8) {
    return "Password must be at least 8 characters long";
  }
  if (!/[A-Z]/.test(password)) {
    return "Password must contain at least one uppercase letter";
  }
  if (!/[a-z]/.test(password)) {
    return "Password must contain at least one lowercase letter";
  }
  if (!/[0-9]/.test(password)) {
    return "Password must contain at least one number";
  }
  if (!/[#@$]/.test(password)) {
    return "Password must contain at least one special character (#, @, or $)";
  }
  if (!PASSWORD_REGEX.test(password)) {
    return "Password can only contain letters, numbers, and special characters (#, @, $)";
  }
  return null;
}

export function validateName(name) {
  if (!name || !name.trim()) {
    return "Full name is required";
  }
  if (name.trim().length < 2) {
    return "Name must be at least 2 characters";
  }
  return null;
}

export function validateVolunteerId(id) {
  if (!id || !id.trim()) {
    return "Volunteer ID is required";
  }
  const formatted = id.trim().toUpperCase();
  if (!formatted.startsWith("V") || isNaN(Number(formatted.slice(1))) || formatted.length < 2) {
    return "Volunteer ID must be in format V1, V2, V3, etc.";
  }
  return null;
}

export function formatDate(dateString) {
  if (!dateString) return "";
  const date = new Date(dateString);
  return date.toLocaleDateString("en-IN", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

export function formatTime(timeString) {
  if (!timeString) return "";
  const parts = timeString.split(":");
  if (parts.length < 2) return timeString;
  const hours = parseInt(parts[0], 10);
  const minutes = parts[1];
  const ampm = hours >= 12 ? "PM" : "AM";
  const displayHours = hours % 12 || 12;
  return `${displayHours}:${minutes} ${ampm}`;
}

export function formatDateTime(dateString) {
  if (!dateString) return "";
  const date = new Date(dateString);
  return date.toLocaleString("en-IN", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function getStatusColor(status) {
  switch (status) {
    case "live": return "badge-live";
    case "upcoming": return "badge-upcoming";
    case "ended": return "badge-ended";
    case "pending": return "badge-pending";
    default: return "badge-upcoming";
  }
}

export function getMinDate() {
  const today = new Date();
  return today.toISOString().split("T")[0];
}
