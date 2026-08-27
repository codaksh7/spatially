import { useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import { LuRadar, LuShield, LuTicket, LuChartColumn, LuWifi, LuEye, LuArrowRight, LuMapPin, LuUsers, LuZap } from "react-icons/lu";

export default function Landing() {
  const heroRef = useRef(null);
  const featuresRef = useRef(null);
  const stepsRef = useRef(null);

  useEffect(() => {
    const observerOptions = { threshold: 0.15, rootMargin: "0px 0px -40px 0px" };
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("slide-up");
          entry.target.style.opacity = "1";
          observer.unobserve(entry.target);
        }
      });
    }, observerOptions);

    document.querySelectorAll(".animate-on-scroll").forEach((el) => {
      el.style.opacity = "0";
      observer.observe(el);
    });

    return () => observer.disconnect();
  }, []);

  return (
    <div className="landing-page">
      <nav className="landing-nav">
        <div className="landing-nav-logo">
          Spatial<span>Ly</span>
        </div>
        <div className="landing-nav-links">
          <a href="#features" className="hide-mobile">Features</a>
          <a href="#how-it-works" className="hide-mobile">How It Works</a>
          <Link to="/login" className="btn btn-primary btn-sm">
            Log In
          </Link>
        </div>
      </nav>

      <section className="landing-hero" ref={heroRef}>
        <div className="landing-hero-bg" />
        <div className="landing-hero-content">
          <div className="landing-hero-badge">
            <LuRadar size={14} />
            BLE-Powered Crowd Intelligence
          </div>
          <h1>
            Real-time <span className="highlight">crowd density</span> tracking for live events
          </h1>
          <p className="landing-hero-subtitle">
            SpatialLy uses Bluetooth Low Energy to passively monitor attendee flow across event zones.
            No GPS. No active check-ins. Privacy-first. Built for organizers who need actionable crowd data.
          </p>
          <div className="landing-hero-actions">
            <Link to="/signup" className="btn btn-primary btn-lg">
              Get Started
              <LuArrowRight size={18} />
            </Link>
            <a href="#features" className="btn btn-secondary btn-lg">
              Learn More
            </a>
          </div>
        </div>
      </section>

      <section id="features" className="landing-section" ref={featuresRef}>
        <div className="landing-section-header animate-on-scroll">
          <h2>Built for Scale. Designed for Privacy.</h2>
          <p>
            Every component is engineered to handle real-world event conditions
            while keeping attendee data anonymous.
          </p>
        </div>

        <div className="features-grid">
          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuRadar />
            </div>
            <h3>Passive BLE Detection</h3>
            <p>
              Attendee phones broadcast encrypted Bluetooth signals. Volunteer devices
              detect presence without any action from attendees.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuShield />
            </div>
            <h3>Rotating Ephemeral IDs</h3>
            <p>
              SHA-256 derived identifiers rotate every 5 minutes. No persistent tracking.
              No MAC address exposure. Privacy by design.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuChartColumn />
            </div>
            <h3>Zone-Level Analytics</h3>
            <p>
              Real-time crowd density data per zone. Know which areas are overcrowded,
              underutilized, or trending in real time.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuTicket />
            </div>
            <h3>QR Ticketing</h3>
            <p>
              Seamless ticket generation with QR codes. Volunteers scan at entry
              for instant validation and check-in.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuWifi />
            </div>
            <h3>Offline-First Architecture</h3>
            <p>
              Observations are queued locally in SQLite when network drops.
              Data syncs automatically when connectivity returns.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon">
              <LuEye />
            </div>
            <h3>Live Organizer Dashboard</h3>
            <p>
              Monitor crowd distribution, ticket sales, and volunteer coverage
              from a single real-time dashboard.
            </p>
          </div>
        </div>
      </section>

      <section id="how-it-works" className="landing-section" ref={stepsRef}>
        <div className="landing-section-header animate-on-scroll">
          <h2>How It Works</h2>
          <p>Three simple steps from setup to real-time crowd intelligence.</p>
        </div>

        <div className="how-it-works-steps">
          <div className="step-card animate-on-scroll">
            <div className="step-number">1</div>
            <h3>Create Your Event</h3>
            <p>
              Organizers set up events, define zones (Main Stage, Food Court, etc.), and invite volunteers through the web dashboard.
            </p>
          </div>

          <div className="step-card animate-on-scroll">
            <div className="step-number">2</div>
            <h3>Deploy at Venue</h3>
            <p>
              Volunteers open the mobile app, select their zone, and start scanning.
              Attendees just keep their app running in the background.
            </p>
          </div>

          <div className="step-card animate-on-scroll">
            <div className="step-number">3</div>
            <h3>Monitor in Real-Time</h3>
            <p>
              Watch crowd density data flow into your organizer dashboard. See zone heatmaps, historical trends, and live volunteer counts.
            </p>
          </div>
        </div>
      </section>

      <section className="landing-section">
        <div className="landing-section-header animate-on-scroll">
          <h2>Platform at a Glance</h2>
          <p>Three user roles, one unified platform.</p>
        </div>

        <div className="features-grid">
          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon" style={{ backgroundColor: "var(--olive-800)", color: "var(--olive-400)" }}>
              <LuUsers />
            </div>
            <h3>Attendees</h3>
            <p>
              Browse events, purchase tickets, display QR codes for entry.
              Phone silently broadcasts BLE beacon when at the venue.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon" style={{ backgroundColor: "var(--info-bg)", color: "var(--info)" }}>
              <LuMapPin />
            </div>
            <h3>Volunteers</h3>
            <p>
              Scan QR tickets at gates. Passively detect attendee BLE signals.
              Log crowd counts per zone to the cloud in real time.
            </p>
          </div>

          <div className="feature-card animate-on-scroll">
            <div className="feature-card-icon" style={{ backgroundColor: "var(--warning-bg)", color: "var(--warning)" }}>
              <LuZap />
            </div>
            <h3>Organizers</h3>
            <p>
              Full event lifecycle management. Real-time crowd heatmaps.
              Volunteer coordination. Analytics and historical data.
            </p>
          </div>
        </div>
      </section>

      <footer className="landing-footer">
        <p>SpatialLy — BLE-Powered Crowd Intelligence Platform</p>
        <p style={{ marginTop: "4px" }}>Built by Daksh Thakkar, Aryan Verma, Blaise Rodrigues, Devansh</p>
      </footer>
    </div>
  );
}
