import { useState, useEffect } from "react";
import { supabase } from "../utils/supabaseClient";
import { LuTriangleAlert, LuCircleCheck, LuClock, LuUser, LuMapPin, LuFilter } from "react-icons/lu";
import { formatDate, formatTime } from "../utils/validators";

export default function IncidentCommandPanel({ eventId }) {
  const [incidents, setIncidents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("all"); // 'all', 'active', 'resolved'

  const fetchIncidents = async () => {
    try {
      let query = supabase.from("operational_incidents").select("*").eq("event_id", eventId).order("created_at", { ascending: false });
      
      if (filter === "active") {
        query = query.in("status", ["reported", "acknowledged", "assigned", "in_progress"]);
      } else if (filter === "resolved") {
        query = query.in("status", ["resolved", "closed"]);
      }
      
      const { data, error } = await query;
      if (error) throw error;
      setIncidents(data || []);
    } catch (err) {
      console.error("Failed to fetch incidents", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchIncidents();

    const channel = supabase.channel(`incidents_${eventId}_${filter}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "operational_incidents", filter: `event_id=eq.${eventId}` }, fetchIncidents)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [eventId, filter]);

  const getPriorityColor = (priority) => {
    if (priority === "urgent") return "var(--error)";
    if (priority === "important") return "var(--warning)";
    return "var(--info)";
  };

  if (loading) {
    return <div className="card loading"><div className="spinner spinner-sm"></div></div>;
  }

  return (
    <div className="card" style={{ marginBottom: "28px" }}>
      <div className="section-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h3 className="section-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <LuTriangleAlert size={18} color="var(--error)" /> Incident Command
        </h3>
        <select 
          className="form-control" 
          style={{ width: "auto", padding: "4px 8px", fontSize: "0.85rem" }}
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
        >
          <option value="all">All Incidents</option>
          <option value="active">Active Only</option>
          <option value="resolved">Resolved</option>
        </select>
      </div>

      {incidents.length === 0 ? (
        <div className="empty-state" style={{ padding: "30px 10px" }}>
          <LuCircleCheck size={32} color="var(--green-400)" style={{ marginBottom: "12px" }} />
          <div className="empty-state-title" style={{ fontSize: "1rem" }}>No Incidents</div>
          <div className="empty-state-text" style={{ fontSize: "0.85rem" }}>All clear in the venue.</div>
        </div>
      ) : (
        <div style={{ overflowX: "auto" }}>
          <table className="data-table" style={{ width: "100%", fontSize: "0.85rem", textAlign: "left", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ borderBottom: "1px solid var(--border-light)", color: "var(--text-muted)" }}>
                <th style={{ padding: "12px 8px" }}>Priority</th>
                <th style={{ padding: "12px 8px" }}>Title / Category</th>
                <th style={{ padding: "12px 8px" }}>Location</th>
                <th style={{ padding: "12px 8px" }}>Status</th>
                <th style={{ padding: "12px 8px" }}>Reported</th>
              </tr>
            </thead>
            <tbody>
              {incidents.map((inc) => (
                <tr key={inc.id} style={{ borderBottom: "1px solid var(--border-light)" }}>
                  <td style={{ padding: "12px 8px" }}>
                    <span className="badge" style={{ backgroundColor: getPriorityColor(inc.priority), color: "#fff", textTransform: "uppercase", fontSize: "0.7rem" }}>
                      {inc.priority}
                    </span>
                  </td>
                  <td style={{ padding: "12px 8px", fontWeight: "500", color: "var(--text-primary)" }}>
                    <div>{inc.title}</div>
                    <div style={{ fontSize: "0.75rem", color: "var(--text-muted)", textTransform: "uppercase", marginTop: "2px" }}>{inc.category}</div>
                  </td>
                  <td style={{ padding: "12px 8px", color: "var(--text-secondary)" }}>
                    <LuMapPin size={12} style={{ marginRight: "4px" }} />
                    {inc.venue_zone_name || inc.zone_id || "Unknown"}
                  </td>
                  <td style={{ padding: "12px 8px" }}>
                    <span className={`badge ${inc.status === 'resolved' || inc.status === 'closed' ? 'bg-success' : 'bg-warning'}`}>
                      {inc.status}
                    </span>
                  </td>
                  <td style={{ padding: "12px 8px", color: "var(--text-secondary)", fontSize: "0.75rem" }}>
                    <LuClock size={12} style={{ marginRight: "4px" }} />
                    {formatTime(inc.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
