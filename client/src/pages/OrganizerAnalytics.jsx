import { useEffect, useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { LuTrendingUp, LuDownload, LuUsers, LuRadar, LuCircleCheck, LuTriangleAlert, LuTicket } from "react-icons/lu";

export default function OrganizerAnalytics() {
  const { user } = useAuth();
  const toast = useToast();
  const [events, setEvents] = useState([]);
  const [selectedEventId, setSelectedEventId] = useState("");
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get("/api/events/organizer/mine")
      .then((data) => {
        setEvents(data.events || []);
        if (data.events && data.events.length > 0) {
          const liveEvent = data.events.find(e => e.status === "live");
          if (liveEvent) {
            setSelectedEventId(liveEvent.id);
          } else {
            const upcomingEvent = data.events.find(e => e.status === "upcoming");
            if (upcomingEvent) {
              setSelectedEventId(upcomingEvent.id);
            } else {
              const endedEvents = data.events.filter(e => e.status === "ended");
              setSelectedEventId(endedEvents.length > 0 ? endedEvents[endedEvents.length - 1].id : data.events[0].id);
            }
          }
        } else {
          setLoading(false);
        }
      })
      .catch((err) => {
        toast(err.message, "error");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (!selectedEventId) return;
    setLoading(true);
    api.get(`/api/organizer/export/${selectedEventId}?report_type=summary`)
      .then((res) => {
        setAnalytics(res.data || null);
      })
      .catch((err) => {
        toast(err.message, "error");
      })
      .finally(() => {
        setLoading(false);
      });
  }, [selectedEventId]);

  const handleExport = (type) => {
    toast(`Preparing ${type} export...`, "success");
    api.get(`/api/organizer/export/${selectedEventId}?report_type=${type}`)
      .then(res => {
        let exportData = res.data;
        if (!exportData || !Array.isArray(exportData)) {
          toast(`No data available to export for ${type}`, "error");
          return;
        }
        
        if (exportData.length === 0) {
          toast(`The ${type} report is empty.`, "success");
          return;
        }

        // Generate CSV
        const headers = Object.keys(exportData[0]).join(",");
        const rows = exportData.map(obj => {
          return Object.values(obj).map(val => {
            if (val === null || val === undefined) return '""';
            return `"${String(val).replace(/"/g, '""')}"`;
          }).join(",");
        });
        
        const csvContent = [headers, ...rows].join("\\n");
        const blob = new Blob([csvContent], { type: "text/csv;charset=utf-8;" });
        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.setAttribute("href", url);
        link.setAttribute("download", `spatially_${type}_export.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
        
        toast(`Export ${type} generated successfully!`, "success");
      })
      .catch(err => toast(err.message || "Export failed", "error"));
  };

  return (
    <div className="fade-in">
      <div className="page-header">
        <div>
          <h1>Reporting & Intel</h1>
          <p style={{ color: "var(--text-muted)", marginTop: "4px" }}>
            Operational metrics, analytics, and data exports.
          </p>
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          {events.length > 0 && (
            <select 
              className="form-select" 
              value={selectedEventId} 
              onChange={(e) => setSelectedEventId(e.target.value)}
              style={{ minWidth: "200px" }}
            >
              {events.map(ev => (
                <option key={ev.id} value={ev.id}>{ev.name} ({ev.status})</option>
              ))}
            </select>
          )}
          <button className="btn btn-secondary" onClick={() => handleExport('summary')}>
            <LuDownload size={16} /> Export Summary
          </button>
        </div>
      </div>

      {loading ? (
        <div style={{ padding: "40px", textAlign: "center" }}>
          <div className="spinner"></div>
        </div>
      ) : !analytics ? (
        <div className="empty-state">
          <div className="empty-state-icon"><LuTrendingUp /></div>
          <div className="empty-state-title">No analytics available</div>
          <div className="empty-state-text">
            Start your event to begin collecting operational data.
          </div>
        </div>
      ) : (
        <>
          <h3 style={{ marginBottom: "16px", color: "var(--text-secondary)" }}>Key Performance Indicators</h3>
          
          <div className="stats-grid" style={{ marginBottom: "24px" }}>
            <div className="stat-card">
              <div className="stat-icon info"><LuTicket /></div>
              <div>
                <div className="stat-value">{analytics.attendance?.check_in_rate || 0}%</div>
                <div className="stat-label">Check-in Rate</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  {analytics.attendance?.checked_in || 0} / {analytics.attendance?.total_tickets || 0}
                </div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon green"><LuCircleCheck /></div>
              <div>
                <div className="stat-value">{analytics.incidents?.resolution_rate || 0}%</div>
                <div className="stat-label">Incident Resolution</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  {analytics.incidents?.resolved || 0} / {analytics.incidents?.total || 0} resolved
                </div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon warning"><LuRadar /></div>
              <div>
                <div className="stat-value">{analytics.crowd?.current_total || 0}</div>
                <div className="stat-label">Active Devices Detected</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  Across {analytics.crowd?.zones_monitored || 0} monitored zones
                </div>
              </div>
            </div>
            <div className="stat-card">
              <div className="stat-icon" style={{ color: "var(--primary)" }}><LuUsers /></div>
              <div>
                <div className="stat-value">{analytics.volunteers?.active_shifts || 0}</div>
                <div className="stat-label">Active Staff Shifts</div>
                <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "4px" }}>
                  Of {analytics.volunteers?.total_shifts || 0} total shifts
                </div>
              </div>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px" }}>
            <div className="card">
              <div className="card-header">
                <h3 className="card-title">Export Compliance Reports (CSV)</h3>
              </div>
              <div style={{ padding: "16px", display: "flex", flexDirection: "column", gap: "12px" }}>
                <button className="btn btn-outline" style={{ justifyContent: "space-between" }} onClick={() => handleExport('attendance')}>
                  <span style={{ display: "flex", alignItems: "center", gap: "8px" }}><LuTicket size={16} /> Attendance & Check-ins</span>
                  <LuDownload size={14} />
                </button>
                <button className="btn btn-outline" style={{ justifyContent: "space-between" }} onClick={() => handleExport('incidents')}>
                  <span style={{ display: "flex", alignItems: "center", gap: "8px" }}><LuTriangleAlert size={16} /> Incident & Safety Logs</span>
                  <LuDownload size={14} />
                </button>
                <button className="btn btn-outline" style={{ justifyContent: "space-between" }} onClick={() => handleExport('shifts')}>
                  <span style={{ display: "flex", alignItems: "center", gap: "8px" }}><LuUsers size={16} /> Staff Shift Records</span>
                  <LuDownload size={14} />
                </button>
                <button className="btn btn-outline" style={{ justifyContent: "space-between" }} onClick={() => handleExport('tasks')}>
                  <span style={{ display: "flex", alignItems: "center", gap: "8px" }}><LuCircleCheck size={16} /> Operational Tasks</span>
                  <LuDownload size={14} />
                </button>
              </div>
            </div>
            
            <div className="card">
              <div className="card-header">
                <h3 className="card-title">Event Configuration Summary</h3>
              </div>
              <div style={{ padding: "16px" }}>
                <ul style={{ listStyle: "none", padding: 0, margin: 0, display: "flex", flexDirection: "column", gap: "16px" }}>
                  <li style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-default)", paddingBottom: "8px" }}>
                    <span style={{ color: "var(--text-muted)" }}>Spatial Zones</span>
                    <span style={{ fontWeight: "600" }}>{analytics.content?.zones || 0}</span>
                  </li>
                  <li style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-default)", paddingBottom: "8px" }}>
                    <span style={{ color: "var(--text-muted)" }}>Exhibitor Booths</span>
                    <span style={{ fontWeight: "600" }}>{analytics.content?.booths || 0}</span>
                  </li>
                  <li style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-default)", paddingBottom: "8px" }}>
                    <span style={{ color: "var(--text-muted)" }}>Scheduled Sessions</span>
                    <span style={{ fontWeight: "600" }}>{analytics.content?.sessions || 0}</span>
                  </li>
                  <li style={{ display: "flex", justifyContent: "space-between", borderBottom: "1px solid var(--border-default)", paddingBottom: "8px" }}>
                    <span style={{ color: "var(--text-muted)" }}>Total Communications Sent</span>
                    <span style={{ fontWeight: "600" }}>{analytics.communications?.total_messages || 0}</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
