import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, formatTime, getStatusColor } from "../utils/validators";
import { LuArrowLeft, LuMapPin, LuClock, LuUsers, LuTicket, LuCircleCheck, LuActivity, LuPencil, LuCalendarDays } from "react-icons/lu";
import EventCountdown from "../components/EventCountdown";

export default function EventDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const toast = useToast();

  const [event, setEvent] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get(`/api/events/${id}`)
      .then((data) => setEvent(data.event))
      .catch((err) => {
        toast(err.message, "error");
        navigate("/organizer/events");
      })
      .finally(() => setLoading(false));
  }, [id, navigate, toast]);

  const handleStatusChange = async (newStatus) => {
    try {
      await api.put(`/api/events/${id}`, { status: newStatus });
      setEvent((prev) => ({ ...prev, status: newStatus }));
      toast(`Event marked as ${newStatus}`, "success");
    } catch (err) {
      toast(err.message, "error");
    }
  };

  if (loading) {
    return <div className="loading-screen" style={{ minHeight: "60vh" }}><div className="spinner spinner-lg"></div></div>;
  }

  if (!event) return null;

  return (
    <div className="fade-in event-detail-page">
      <button
        className="btn btn-ghost"
        style={{ marginBottom: "20px", padding: "8px 12px" }}
        onClick={() => navigate("/organizer/events")}
      >
        <LuArrowLeft /> Back to Events
      </button>

      {/* CREATIVE HEADER & COUNTDOWN SECTION */}
      <div className="card" style={{ marginBottom: "28px", borderTop: "4px solid var(--green-500)", position: "relative", overflow: "hidden" }}>
        <div style={{ position: "absolute", right: "-50px", top: "-50px", width: "200px", height: "200px", borderRadius: "50%", background: "radial-gradient(circle, var(--green-900) 0%, transparent 70%)", opacity: 0.5, pointerEvents: "none" }}></div>

        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "20px", position: "relative", zIndex: 1 }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "8px" }}>
              <h1 style={{ fontSize: "2rem", fontWeight: "700", color: "var(--text-primary)" }}>{event.name}</h1>
              <span className={`badge ${getStatusColor(event.status)}`} style={{ fontSize: "0.85rem", padding: "6px 12px" }}>
                {event.status}
              </span>
            </div>
            <p style={{ color: "var(--text-secondary)", fontSize: "1.1rem", maxWidth: "600px", lineHeight: "1.6" }}>
              {event.description || "No description provided for this event."}
            </p>
          </div>

          <div style={{ textAlign: "right" }}>
            {event.status === "upcoming" ? (
              <div style={{ background: "var(--bg-primary)", padding: "16px 24px", borderRadius: "var(--radius-lg)", border: "1px solid var(--border-light)", boxShadow: "var(--shadow-md)" }}>
                <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "8px", fontWeight: "600" }}>
                  Time Until Event
                </div>
                <EventCountdown
                  eventDate={event.event_date}
                  startTime={event.start_time}
                  onComplete={() => handleStatusChange("live")}
                />
              </div>
            ) : event.status === "live" ? (
              <div style={{ background: "rgba(58, 114, 32, 0.1)", border: "1px solid var(--green-800)", padding: "16px 24px", borderRadius: "var(--radius-lg)" }}>
                <div className="pulse-animation" style={{ display: "flex", alignItems: "center", gap: "8px", color: "var(--green-400)", fontWeight: "600", fontSize: "1.2rem" }}>
                  <LuActivity size={24} /> EVENT IS LIVE
                </div>
              </div>
            ) : (
              <div style={{ background: "var(--bg-primary)", padding: "16px 24px", borderRadius: "var(--radius-lg)", border: "1px solid var(--border-light)" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "8px", color: "var(--text-muted)", fontWeight: "600" }}>
                  <LuCalendarDays size={20} /> EVENT CONCLUDED
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "24px", marginBottom: "28px" }}>

        {/* DETAILS CARD */}
        <div className="card">
          <div className="section-header">
            <h3 className="section-title">Event Information</h3>
            <button className="btn btn-sm btn-ghost"><LuPencil size={14} /> Edit</button>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            <div style={{ display: "flex", alignItems: "flex-start", gap: "12px" }}>
              <div style={{ background: "var(--bg-tertiary)", padding: "10px", borderRadius: "var(--radius-md)", color: "var(--green-400)" }}>
                <LuMapPin size={20} />
              </div>
              <div>
                <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "500", textTransform: "uppercase" }}>Venue</div>
                <div style={{ fontWeight: "500" }}>{event.venue}</div>
                {event.location_address && <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "4px" }}>{event.location_address}</div>}
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "flex-start", gap: "12px" }}>
              <div style={{ background: "var(--bg-tertiary)", padding: "10px", borderRadius: "var(--radius-md)", color: "var(--green-400)" }}>
                <LuClock size={20} />
              </div>
              <div>
                <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "500", textTransform: "uppercase" }}>Date & Time</div>
                <div style={{ fontWeight: "500" }}>{formatDate(event.event_date)}</div>
                <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)", marginTop: "4px" }}>
                  {event.start_time ? formatTime(event.start_time) : "TBD"} {event.end_time ? `- ${formatTime(event.end_time)}` : ""}
                </div>
              </div>
            </div>
          </div>

          {event.zones?.length > 0 && (
            <div style={{ marginTop: "24px", paddingTop: "20px", borderTop: "1px solid var(--border-default)" }}>
              <div style={{ fontSize: "0.8rem", color: "var(--text-muted)", fontWeight: "500", textTransform: "uppercase", marginBottom: "12px" }}>Configured Zones</div>
              <div className="event-card-zones">
                {event.zones.map(z => <span key={z} className="zone-tag">{z}</span>)}
              </div>
            </div>
          )}
        </div>

        {/* METRICS CARD */}
        <div className="card">
          <div className="section-header">
            <h3 className="section-title">Live Metrics</h3>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>

            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", background: "var(--bg-primary)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-light)" }}>
              <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                <LuUsers size={24} color="var(--info)" />
                <div>
                  <div style={{ fontSize: "0.85rem", color: "var(--text-secondary)" }}>Assigned Volunteers</div>
                  <div style={{ fontSize: "1.4rem", fontWeight: "700" }}>{event.volunteer_count || 0}</div>
                </div>
              </div>
              <button className="btn btn-sm btn-secondary" onClick={() => navigate("/organizer/volunteers")}>Manage</button>
            </div>

            <div style={{ display: "flex", gap: "16px" }}>
              <div style={{ flex: 1, background: "var(--bg-primary)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-light)" }}>
                <LuTicket size={20} color="var(--warning)" style={{ marginBottom: "8px" }} />
                <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>Tickets Issued</div>
                <div style={{ fontSize: "1.2rem", fontWeight: "700" }}>{event.ticket_count || 0}</div>
              </div>

              <div style={{ flex: 1, background: "var(--bg-primary)", padding: "16px", borderRadius: "var(--radius-md)", border: "1px solid var(--border-light)" }}>
                <LuCircleCheck size={20} color="var(--green-400)" style={{ marginBottom: "8px" }} />
                <div style={{ fontSize: "0.8rem", color: "var(--text-secondary)" }}>Checked In</div>
                <div style={{ fontSize: "1.2rem", fontWeight: "700" }}>{event.checkin_count || 0}</div>
              </div>
            </div>

            {event.capacity > 0 && (
              <div style={{ marginTop: "8px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.8rem", marginBottom: "6px" }}>
                  <span color="var(--text-secondary)">Venue Capacity</span>
                  <span><strong style={{ color: "var(--text-primary)" }}>{event.ticket_count}</strong> / {event.capacity}</span>
                </div>
                <div style={{ width: "100%", height: "6px", background: "var(--bg-elevated)", borderRadius: "var(--radius-full)", overflow: "hidden" }}>
                  <div
                    style={{
                      height: "100%",
                      background: (event.ticket_count / event.capacity) > 0.9 ? "var(--error)" : "var(--green-500)",
                      width: `${Math.min((event.ticket_count / event.capacity) * 100, 100)}%`
                    }}
                  ></div>
                </div>
              </div>
            )}

          </div>
        </div>

      </div>

    </div>
  );
}
