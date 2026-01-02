# 🤖 AGENTS.md - Guide for AI Assistants

This file provides high-level context for AI agents working on **StarTickets**.

## 🧠 System of Intelligence (Sentinel)

The core "brain" of the application is the **Overseer** (`lib/star_tickets/sentinel/overseer.ex`).
- **Pattern**: A dedicated GenServer that subscribes to all `audit_logs`.
- **Goal**: To act as an autonomous agent that monitors business health and system stability.
- **Key Functions**:
  - `monitor_connectivity/1`: Checks if devices (Totems/TVs) or User Groups (Reception) are online via `Phoenix.Presence`.
  - `detect_anomalies/1`: Listens for "Error" or "Crash" logs.
  - `predict_next_step/1`: (Future) Anticipates operational bottlenecks.

## 📱 Notifications & WhatsApp Integrations

- **Dispatcher**: `lib/star_tickets/notifications/dispatcher.ex` listens to `audit_logs` and filters for severity.
- **WhatsApp**: `lib/star_tickets/notifications/whatsapp.ex` is a Mock/Interface.
  - **Critical Rule**: All Admin users *must* have a valid `phone_number`. The first user created in `ClientRegisterLive` is the Super Admin.

## 🏗️ Architectural Decisions

1.  **Presence Tracking**: We use `StarTicketsWeb.Presence` to track not just "online status" but specific metadata:
    - **Totems**: `printer_status`, `paper_level`.
    - **Professionals**: `room_id` (location awareness).
    - **TVs**: `last_ping`.

2.  **Audit First**: All significant actions must produce an `AuditLog`. This feeds the Sentinel. If it's not in the Audit Log, the AI cannot see it.

3.  **Style Guide**:
    - **UI**: "Premium Acrylic" dark mode. Glassmorphism heavily stated in `app.css`.
    - **LiveView**: Use function components for everything. Avoid old `.eex` templates where possible.

## 🛠️ Common Tasks

- **Adding a new Alert**:
  1.  Ensure the event generates an `AuditLog` with severity "alert", "warning", or "error".
  2.  The `Dispatcher` will automatically pick it up and forward to WhatsApp if it's critical.
  3.  The `NotificationsLive` page will automatically display it.

- **Debugging Connectivity**:
  - Check `StarTicketsWeb.Presence` tracked in the respective LiveView `mount/3`.
  - Check `Overseer` logic in `handle_info(:tick, state)`.
