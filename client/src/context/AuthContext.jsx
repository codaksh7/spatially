import { createContext, useContext, useState, useEffect, useCallback } from "react";
import { api, setAccessToken, clearAccessToken } from "../utils/api";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const tryRefresh = useCallback(async () => {
    try {
      const data = await api.post("/api/auth/refresh", null, { skipRefresh: true });
      setAccessToken(data.access_token);
      setUser(data.user);
      return true;
    } catch {
      clearAccessToken();
      setUser(null);
      return false;
    }
  }, []);

  useEffect(() => {
    tryRefresh().finally(() => setLoading(false));
  }, [tryRefresh]);

  const login = async (email, password) => {
    const data = await api.post("/api/auth/login", { email, password }, { skipRefresh: true });
    setAccessToken(data.access_token);
    setUser(data.user);
    return data.user;
  };

  const signup = async (email, password, full_name, nickname) => {
    const data = await api.post(
      "/api/auth/signup",
      { email, password, full_name, nickname },
      { skipRefresh: true }
    );
    return data;
  };

  const volunteerSignup = async (email, password, full_name, nickname, invitation_token) => {
    const data = await api.post(
      "/api/auth/volunteer-signup",
      { email, password, full_name, nickname, invitation_token },
      { skipRefresh: true }
    );
    return data;
  };

  const logout = async () => {
    try {
      await api.post("/api/auth/logout");
    } catch {
      // proceed even if server call fails
    }
    clearAccessToken();
    setUser(null);
  };

  const updateProfile = async (data) => {
    const result = await api.put("/api/auth/profile", data);
    setUser(result.user);
    return result.user;
  };

  const value = {
    user,
    loading,
    login,
    signup,
    volunteerSignup,
    logout,
    updateProfile,
    isAuthenticated: !!user,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within AuthProvider");
  }
  return context;
}
