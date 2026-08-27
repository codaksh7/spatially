import { useState } from "react";
import { Outlet } from "react-router-dom";
import Sidebar from "./Sidebar";
import { LuMenu } from "react-icons/lu";
import { useAuth } from "../context/AuthContext";

export default function DashboardLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { user } = useAuth();

  return (
    <div className="dashboard-layout">
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <div className="main-content">
        <header className="topbar">
          <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            <button
              className="mobile-menu-btn"
              onClick={() => setSidebarOpen(true)}
              aria-label="Open navigation menu"
            >
              <LuMenu />
            </button>
            <span className="topbar-title" style={{ fontSize: "1.5rem", fontWeight: 800, letterSpacing: "-0.5px" }}>
              Spatial<span style={{ color: "var(--green-400)" }}>Ly</span>
            </span>
          </div>
          <div className="topbar-actions">
            <span style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "500" }}>
              {user?.nickname || user?.full_name || user?.email}
            </span>
          </div>
        </header>

        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
