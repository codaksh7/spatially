import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, getStatusColor } from "../utils/validators";
import { LuCalendarDays, LuTicket, LuUsers, LuEye, LuArrowRight, LuPlus, LuMapPin, LuClock, LuTrendingUp } from "react-icons/lu";
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts";

const PIE_COLORS = ["#4A8C2A", "#5DA63A", "#738840", "#2E6B8C", "#5E735E"];

export default function OrganizerDashboard() {
  const { user } = useAuth();
  const toast = useToast();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/dashboard/organizer")
      .then(setData)
      .catch((err) => toast(err.message, "error"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="loading-screen" style={{ minHeight: "60vh" }}>
        <div className="spinner"></div>
      </div>
    );
  }

  const stats = data?.stats || {};

  const statusData = [
    { name: "Live", value: stats.live_events || 0 },
    { name: "Upcoming", value: stats.upcoming_events || 0 },
    { name: "Ended", value: stats.ended_events || 0 },
  ].filter((d) => d.value > 0);

  const registrationData = (data?.user_registrations || [])
    .map((r) => {
      const event = data?.events?.find((e) => e.id === r.event_id);
      return { name: event?.name?.slice(0, 15) || "Event", registrations: r.count };
    })
    .filter((d) => d.registrations > 0)
    .slice(0, 6);

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Organizer Dashboard</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            {user?.user_id} &middot; {user?.full_name} &middot; Full event lifecycle overview
          </p>
        </div>
        <Link to="/organizer/create-event" className="btn btn-primary">
          <LuPlus size={16} />
          Create Event
        </Link>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon green"><LuCalendarDays /></div>
          <div>
            <div className="stat-value">{stats.total_events || 0}</div>
            <div className="stat-label">Total Events</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon olive"><LuTicket /></div>
          <div>
            <div className="stat-value">{stats.total_tickets || 0}</div>
            <div className="stat-label">Total Tickets</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon info"><LuUsers /></div>
          <div>
            <div className="stat-value">{stats.total_volunteers || 0}</div>
            <div className="stat-label">Volunteers Assigned</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon warning"><LuEye /></div>
          <div>
            <div className="stat-value">{stats.total_observations || 0}</div>
            <div className="stat-label">BLE Observations</div>
          </div>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "20px", marginBottom: "32px" }}>
        {statusData.length > 0 && (
          <div className="chart-container">
            <div className="chart-title">Event Status Distribution</div>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={statusData} cx="50%" cy="50%" innerRadius={50} outerRadius={80} dataKey="value" paddingAngle={4}>
                  {statusData.map((entry, idx) => (
                    <Cell key={entry.name} fill={PIE_COLORS[idx % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{ backgroundColor: "var(--bg-elevated)", border: "1px solid var(--border-default)", borderRadius: "8px", color: "var(--text-primary)" }}
                />
              </PieChart>
            </ResponsiveContainer>
            <div style={{ display: "flex", justifyContent: "center", gap: "16px", marginTop: "8px" }}>
              {statusData.map((d, idx) => (
                <div key={d.name} style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.75rem", color: "var(--text-secondary)" }}>
                  <div style={{ width: "10px", height: "10px", borderRadius: "2px", backgroundColor: PIE_COLORS[idx % PIE_COLORS.length] }} />
                  {d.name} ({d.value})
                </div>
              ))}
            </div>
          </div>
        )}

        {registrationData.length > 0 && (
          <div className="chart-container">
            <div className="chart-title">Registrations by Event</div>
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={registrationData}>
                <XAxis dataKey="name" tick={{ fill: "var(--text-muted)", fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: "var(--text-muted)", fontSize: 11 }} axisLine={false} tickLine={false} />
                <Tooltip
                  contentStyle={{ backgroundColor: "var(--bg-elevated)", border: "1px solid var(--border-default)", borderRadius: "8px", color: "var(--text-primary)" }}
                />
                <Bar dataKey="registrations" fill="#4A8C2A" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      <div>
        <div className="section-header">
          <h3 className="section-title">Your Events</h3>
          <Link to="/organizer/events" className="btn btn-ghost btn-sm">
            Manage All <LuArrowRight size={14} />
          </Link>
        </div>
        {data?.events?.length > 0 ? (
          <div className="events-grid">
            {data.events.slice(0, 6).map((event) => (
              <div key={event.id} className="event-card">
                <div className="event-card-header">
                  <div className="event-card-title">{event.name}</div>
                  <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
                </div>
                <div className="event-card-meta">
                  <div className="event-card-meta-item">
                    <LuMapPin className="meta-icon" size={14} />
                    {event.venue || "Venue TBD"}
                  </div>
                  <div className="event-card-meta-item">
                    <LuClock className="meta-icon" size={14} />
                    {formatDate(event.event_date)}
                  </div>
                </div>
                {event.zones?.length > 0 && (
                  <div className="event-card-zones">
                    {event.zones.slice(0, 4).map((z) => <span key={z} className="zone-tag">{z}</span>)}
                    {event.zones.length > 4 && <span className="zone-tag">+{event.zones.length - 4}</span>}
                  </div>
                )}
                <div className="event-card-footer">
                  <span style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                    Capacity: {event.capacity || "Unlimited"}
                  </span>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div className="empty-state">
            <div className="empty-state-icon"><LuCalendarDays /></div>
            <div className="empty-state-title">No events created yet</div>
            <div className="empty-state-text">
              Create your first event to start managing crowd intelligence.
            </div>
            <Link to="/organizer/create-event" className="btn btn-primary" style={{ marginTop: "16px" }}>
              <LuPlus size={16} /> Create Event
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
