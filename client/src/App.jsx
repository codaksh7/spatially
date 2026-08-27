import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { ToastProvider } from "./components/Toast";
import ProtectedRoute from "./components/ProtectedRoute";
import DashboardLayout from "./components/DashboardLayout";

import Landing from "./pages/Landing";
import Login from "./pages/Login";
import Signup from "./pages/Signup";
import VolunteerSignup from "./pages/VolunteerSignup";
import VerifyEmail from "./pages/VerifyEmail";

import UserDashboard from "./pages/UserDashboard";
import UserEvents from "./pages/UserEvents";
import UserMyEvents from "./pages/UserMyEvents";

import VolunteerDashboard from "./pages/VolunteerDashboard";
import VolunteerAssignments from "./pages/VolunteerAssignments";
import VolunteerInvitations from "./pages/VolunteerInvitations";

import OrganizerDashboard from "./pages/OrganizerDashboard";
import OrganizerEvents from "./pages/OrganizerEvents";
import EventDetail from "./pages/EventDetail";
import CreateEvent from "./pages/CreateEvent";
import InviteVolunteer from "./pages/InviteVolunteer";

import Profile from "./pages/Profile";
import ForgotPassword from "./pages/ForgotPassword";
import ResetPassword from "./pages/ResetPassword";

function AuthRedirect() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="loading-screen">
        <div className="spinner spinner-lg"></div>
        <p>Loading...</p>
      </div>
    );
  }

  if (!user) return <Landing />;

  const redirectMap = {
    user: "/user/dashboard",
    volunteer: "/volunteer/dashboard",
    organizer: "/organizer/dashboard",
  };

  return <Navigate to={redirectMap[user.user_type] || "/login"} replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ToastProvider>
          <Routes>
            {/* Public routes */}
            <Route path="/" element={<AuthRedirect />} />
            <Route path="/login" element={<Login />} />
            <Route path="/signup" element={<Signup />} />
            <Route path="/volunteer-signup" element={<VolunteerSignup />} />
            <Route path="/verify" element={<VerifyEmail />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />
            <Route path="/reset-password" element={<ResetPassword />} />

            {/* User dashboard routes */}
            <Route
              element={
                <ProtectedRoute allowedRoles={["user"]}>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/user/dashboard" element={<UserDashboard />} />
              <Route path="/user/events" element={<UserEvents />} />
              <Route path="/user/my-events" element={<UserMyEvents />} />
            </Route>

            {/* Volunteer dashboard routes */}
            <Route
              element={
                <ProtectedRoute allowedRoles={["volunteer"]}>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/volunteer/dashboard" element={<VolunteerDashboard />} />
              <Route path="/volunteer/assignments" element={<VolunteerAssignments />} />
              <Route path="/volunteer/invitations" element={<VolunteerInvitations />} />
            </Route>

            {/* Organizer dashboard routes */}
            <Route
              element={
                <ProtectedRoute allowedRoles={["organizer"]}>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/organizer/dashboard" element={<OrganizerDashboard />} />
              <Route path="/organizer/events" element={<OrganizerEvents />} />
              <Route path="/organizer/events/:id" element={<EventDetail />} />
              <Route path="/organizer/create-event" element={<CreateEvent />} />
              <Route path="/organizer/volunteers" element={<InviteVolunteer />} />
            </Route>

            {/* Shared authenticated routes */}
            <Route
              element={
                <ProtectedRoute>
                  <DashboardLayout />
                </ProtectedRoute>
              }
            >
              <Route path="/profile" element={<Profile />} />
            </Route>

            {/* Catch-all redirect */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </ToastProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
