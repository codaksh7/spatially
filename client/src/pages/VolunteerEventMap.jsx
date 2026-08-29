import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useToast } from "../components/Toast";
import { api } from "../utils/api";
import { formatDate, formatTime, getStatusColor } from "../utils/validators";
import VenueMap from "../components/VenueMap";
import SwitchRequestModal from "../components/SwitchRequestModal";
import EventCountdown from "../components/EventCountdown";
import { LuArrowLeft, LuArrowLeftRight, LuMapPin, LuClock, LuRadar } from "react-icons/lu";

export default function VolunteerEventMap() {
  const { eventId } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const { user } = useAuth();

  const [event, setEvent] = useState(null);
  const [myPosition, setMyPosition] = useState(null);
  const [volPositions, setVolPositions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showSwitch, setShowSwitch] = useState(false);
  const [switchCount, setSwitchCount] = useState(0);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    async function fetchAll() {
      try {
        const [eventRes, posRes] = await Promise.all([
          api.get(`/api/events/${eventId}`),
          api.get(`/api/venue-map/${eventId}/volunteers`),
        ]);
        setEvent(eventRes.event);
        setVolPositions(posRes.positions || []);
        const mine = (posRes.positions || []).find(
          (p) => p.volunteer_user_id === user?.user_id
        );
        setMyPosition(mine || null);
      } catch (err) {
        toast(err.message, "error");
        navigate("/volunteer/assignments");
      } finally {
        setLoading(false);
      }
    }
    fetchAll();
  }, [eventId, refreshKey]);

  // Fetch switch request count
  useEffect(() => {
    api.get("/api/venue-map/my-switch-requests")
      .then((res) => {
        const eventIncoming = (res.incoming || []).filter((r) => r.event_id === eventId);
        setSwitchCount(eventIncoming.length);
      })
      .catch(() => {});
  }, [eventId, refreshKey]);

  if (loading) {
    return (
      <div className="loading-screen" style={{ minHeight: "60vh" }}>
        <div className="spinner spinner-lg"></div>
      </div>
    );
  }

  if (!event) return null;

  return (
    <div className="fade-in">
      <button
        className="btn btn-ghost"
        style={{ marginBottom: "20px", padding: "8px 12px" }}
        onClick={() => navigate("/volunteer/assignments")}
      >
        <LuArrowLeft /> Back to Assignments
      </button>

      {/* Event header */}
      <div className="card" style={{ marginBottom: "24px", borderTop: "4px solid var(--info)" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: "16px" }}>
          <div>
            <div style={{ display: "flex", alignItems: "center", gap: "12px", marginBottom: "8px" }}>
              <h1 style={{ fontSize: "1.6rem", fontWeight: "700" }}>{event.name}</h1>
              <span className={`badge ${getStatusColor(event.status)}`}>{event.status}</span>
            </div>
            <div style={{ display: "flex", gap: "20px", flexWrap: "wrap", color: "var(--text-secondary)", fontSize: "0.85rem" }}>
              <span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                <LuMapPin size={14} color="var(--green-400)" /> {event.venue}
              </span>
              <span style={{ display: "flex", alignItems: "center", gap: "6px" }}>
                <LuClock size={14} color="var(--green-400)" /> {formatDate(event.event_date)}
                {event.start_time && ` • ${formatTime(event.start_time)}`}
              </span>
            </div>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            {event.status === "upcoming" && (
              <EventCountdown eventDate={event.event_date} startTime={event.start_time} />
            )}
          </div>
        </div>
      </div>

      {/* My position info */}
      {myPosition && (
        <div className="card" style={{ marginBottom: "24px", borderLeft: "4px solid #0077B6" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "12px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
              <div style={{
                width: "40px", height: "40px", borderRadius: "50%", backgroundColor: "rgba(0, 119, 182, 0.15)",
                border: "2px solid #0077B6", display: "flex", alignItems: "center", justifyContent: "center",
                color: "#0077B6", fontWeight: "700", fontSize: "0.8rem"
              }}>
                <LuRadar size={18} />
              </div>
              <div>
                <div style={{ fontWeight: "600", fontSize: "0.95rem" }}>Your Assigned Position</div>
                <div style={{ color: "var(--text-secondary)", fontSize: "0.85rem" }}>
                  Zone <strong>{myPosition.zone}</strong>
                </div>
              </div>
            </div>
            <button
              className="btn btn-sm btn-secondary"
              onClick={() => setShowSwitch(true)}
              style={{ position: "relative" }}
            >
              <LuArrowLeftRight size={14} /> Switch Position
              {switchCount > 0 && (
                <span className="switch-request-badge">{switchCount}</span>
              )}
            </button>
          </div>
        </div>
      )}

      {!myPosition && (
        <div className="card" style={{ marginBottom: "24px", textAlign: "center", padding: "24px", color: "var(--text-muted)" }}>
          <LuRadar size={28} style={{ marginBottom: "8px", opacity: 0.5 }} />
          <p>You haven't been placed on the map yet. Your organizer will assign your position.</p>
        </div>
      )}

      {/* Map */}
      <div className="card" style={{ marginBottom: "24px" }}>
        <div className="section-header">
          <h3 className="section-title" style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <LuRadar size={18} color="var(--green-400)" /> Venue Map — Live View
          </h3>
        </div>
        <VenueMap
          eventId={eventId}
          zones={event.zones || []}
          mode="volunteer"
          currentUserId={user?.user_id}
          refreshTrigger={refreshKey}
        />
      </div>

      {/* Other volunteers */}
      {volPositions.length > 0 && (
        <div className="card">
          <div className="section-header">
            <h3 className="section-title">Volunteers on Map</h3>
            <span className="badge badge-upcoming">{volPositions.length}</span>
          </div>
          <div className="table-container">
            <table className="table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>Zone</th>
                </tr>
              </thead>
              <tbody>
                {volPositions.map((v) => (
                  <tr
                    key={v.volunteer_user_id}
                    style={v.volunteer_user_id === user?.user_id ? { backgroundColor: "rgba(0, 119, 182, 0.08)" } : {}}
                  >
                    <td style={{ fontWeight: "600" }}>
                      {v.volunteer_user_id}
                      {v.volunteer_user_id === user?.user_id && (
                        <span className="badge badge-live" style={{ marginLeft: "8px", fontSize: "0.6rem" }}>You</span>
                      )}
                    </td>
                    <td>{v.volunteer_name}</td>
                    <td><span className="zone-tag">{v.zone}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Switch Modal */}
      {showSwitch && (
        <SwitchRequestModal
          eventId={eventId}
          currentUserId={user?.user_id}
          volPositions={volPositions}
          onClose={() => setShowSwitch(false)}
          onSwitch={() => setRefreshKey((k) => k + 1)}
        />
      )}
    </div>
  );
}
