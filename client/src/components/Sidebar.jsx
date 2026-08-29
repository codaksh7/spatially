import { NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import {
  LuLayoutDashboard,
  LuCalendarDays,
  LuCalendarPlus,
  LuUsers,
  LuUser,
  LuLogOut,
  LuTicket,
  LuRadar,
  LuMail,
  LuArrowLeftRight,
} from "react-icons/lu";

const navConfig = {
  user: [
    { label: "Main", items: [
      { path: "/user/dashboard", icon: LuLayoutDashboard, text: "Dashboard" },
      { path: "/user/events", icon: LuCalendarDays, text: "Browse Events" },
      { path: "/user/my-events", icon: LuTicket, text: "My Events" },
    ]},
    { label: "Account", items: [
      { path: "/profile", icon: LuUser, text: "Profile" },
    ]},
  ],
  volunteer: [
    { label: "Main", items: [
      { path: "/volunteer/dashboard", icon: LuLayoutDashboard, text: "Dashboard" },
      { path: "/volunteer/assignments", icon: LuRadar, text: "My Assignments" },
      { path: "/volunteer/invitations", icon: LuMail, text: "Invitations" },
      { path: "/volunteer/switch-requests", icon: LuArrowLeftRight, text: "Switch Requests" },
    ]},
    { label: "Account", items: [
      { path: "/profile", icon: LuUser, text: "Profile" },
    ]},
  ],
  organizer: [
    { label: "Main", items: [
      { path: "/organizer/dashboard", icon: LuLayoutDashboard, text: "Dashboard" },
      { path: "/organizer/events", icon: LuCalendarDays, text: "Events" },
      { path: "/organizer/create-event", icon: LuCalendarPlus, text: "Create Event" },
      { path: "/organizer/invite", icon: LuUsers, text: "Invite Volunteers" },
    ]},
    { label: "Account", items: [
      { path: "/profile", icon: LuUser, text: "Profile" },
    ]},
  ],
};

export default function Sidebar({ isOpen, onClose }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  if (!user) return null;

  const sections = navConfig[user.user_type] || [];

  const handleLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <>
      <div
        className={`sidebar-overlay ${isOpen ? "open" : ""}`}
        onClick={onClose}
        role="presentation"
      />
      <aside className={`sidebar ${isOpen ? "open" : ""}`}>
        <div className="sidebar-header">
          <div className="sidebar-logo" style={{ fontSize: "1.5rem", fontWeight: 800, letterSpacing: "-0.5px" }}>
            Spatial<span style={{ color: "var(--green-400)" }}>Ly</span>
          </div>
          <div className="sidebar-user">
            <div className="sidebar-user-name">{user.full_name || user.email}</div>
            <div className="sidebar-user-id">{user.user_id}</div>
            <div className="sidebar-user-type">{user.user_type}</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {sections.map((section) => (
            <div key={section.label} className="sidebar-nav-section">
              <div className="sidebar-nav-label">{section.label}</div>
              {section.items.map((item) => (
                <NavLink
                  key={item.path}
                  to={item.path}
                  className={({ isActive }) =>
                    `sidebar-nav-item ${isActive ? "active" : ""}`
                  }
                  onClick={onClose}
                >
                  <item.icon className="nav-icon" />
                  {item.text}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button className="sidebar-nav-item" onClick={handleLogout}>
            <LuLogOut className="nav-icon" />
            Logout
          </button>
        </div>
      </aside>
    </>
  );
}
