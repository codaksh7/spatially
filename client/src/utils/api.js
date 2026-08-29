import { supabase } from "./supabaseClient";

const API_BASE = import.meta.env.VITE_API_URL || "http://localhost:8000";

async function request(method, path, body = null, options = {}) {
  const url = `${API_BASE}${path}`;
  const headers = {
    "Content-Type": "application/json",
    ...options.headers,
  };

  const { data: { session } } = await supabase.auth.getSession();
  if (session?.access_token) {
    headers["Authorization"] = `Bearer ${session.access_token}`;
  }

  const config = {
    method,
    headers,
    credentials: "omit", // Don't send cookies since we use Bearer
  };

  if (body && method !== "GET") {
    config.body = JSON.stringify(body);
  }

  const response = await fetch(url, config);

  if (!response.ok) {
    let errMessage = "An error occurred";
    try {
      const errData = await response.json();
      errMessage = errData.detail || errMessage;
    } catch {
      // Ignore JSON parse errors for non-JSON responses
    }
    throw new Error(errMessage);
  }

  return response.json();
}

export const api = {
  get: (path, options) => request("GET", path, null, options),
  post: (path, body, options) => request("POST", path, body, options),
  put: (path, body, options) => request("PUT", path, body, options),
  delete: (path, options) => request("DELETE", path, null, options),
};
