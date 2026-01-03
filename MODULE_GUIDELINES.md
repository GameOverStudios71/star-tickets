# StarTickets - Standard Module Guidelines

> [!IMPORTANT]
> **To all AI Agents and Developers:**
> This document defines the **MANDATORY** standards for any new module or page created in the StarTickets project. Failure to follow these guidelines results in a system that is inconsistent, fragile, and difficult to audit.
> **You MUST follow these rules strictly.**

---

## 1. UI/UX Standards (Premium Acrylic)

All admin and dashboards pages must follow the **StarTickets Premium Acrylic Design System**.

### 1.1 Page Layout
Use the specific classes for the main container to ensure background rendering:
```html
<div class="st-app has-background min-h-screen flex flex-col pt-20">
  <!-- Content -->
</div>
```

### 1.2 Header Component
You **MUST** use the `<.app_header>` component. Do not create custom headers unless absolutely necessary for branding (like Sentinel).

> [!IMPORTANT]
> **Required Assigns:**
> You must alias `StarTicketsWeb.ImpersonationHelpers` and load the required assigns in `mount/3`.

```elixir
def mount(_params, session, socket) do
  assigns = StarTicketsWeb.ImpersonationHelpers.load_impersonation_assigns(
    socket.assigns.current_scope, 
    session
  )
  
  {:ok, assign(socket, assigns)}
end
```

```elixir
<.app_header
  title="My Module"
  show_home={true}
  current_scope={@current_scope}
  client_name={@client_name}
  establishments={@establishments}
  users={@users}
  impersonating={@impersonating}
>
  <:actions>
    <.link navigate={~p"/my-module/new"} class="st-btn st-btn-primary">
      New Item
    </.link>
  </:actions>
</.app_header>
```

### 1.3 Cards and Containers
Use the `st-card` and `st-acrylic` classes for content containers.
```html
<div class="st-card st-acrylic p-6">
  <!-- Card Content -->
</div>
```

---

## 2. Resilience & Reliability

The system is designed to survive high traffic and user abuse (e.g., "Mega da Virada" scenario).

### 2.1 Rate Limiting (Backend)
**MANDATORY:** Every new route group in `router.ex` MUST be protected by a rate limit pipeline.

**Available Pipelines:**
- `:rate_limit_auth` (30 req/min) - Login/Register
- `:rate_limit_general` (100 req/min) - Admin/Dashboard (Authenticated)
- `:rate_limit_public` (60 req/min) - Public Pages (Ticket Status, etc)
- `:rate_limit_totem` (20 req/min) - Totem Specific

**Example:**
```elixir
scope "/admin", StarTicketsWeb do
  pipe_through [:browser, :require_authenticated_user, :rate_limit_general]
  # ... routes
end
```

### 2.2 Debounce (Frontend)
**MANDATORY:** All actionable buttons (Create, Update, Delete, Toggles) MUST use the `DebounceSubmit` hook to prevent double-clicks.

**Example:**
```elixir
<button
  phx-click="save"
  phx-hook="DebounceSubmit" <!-- REQUIRED -->
  id="save-btn"             <!-- REQUIRED unique ID -->
  class="btn btn-primary"
>
  Save
</button>
```
> [!TIP]
> Always add `phx-disable-with="Saving..."` for better UX.

---

## 3. Observability ("Paranoid Mode")

We log **EVERYTHING**. If a user changes a setting, deletes a record, or sneezes, we want to know.

### 3.1 Audit Logging
**MANDATORY:** In your LiveView `handle_event/3` callbacks, you MUST call `StarTickets.Audit.log_action/3` for any state change.

**Example:**
```elixir
def handle_event("delete_item", %{"id" => id}, socket) do
  # ... perform deletion ...
  
  StarTickets.Audit.log_action(
    "ITEM_DELETED",
    %{
      resource_type: "Item",
      resource_id: id,
      details: %{reason: "User request"},
      user_id: socket.assigns.current_scope.user.id
    }
  )
  
  {:noreply, socket}
end
```

### 3.2 Action Filters
If you create a completely new type of action (e.g., "SPACESHIP_LAUNCH"), add it to `StarTickets.Audit.Actions` module to ensure it appears in filters.

---

## 4. Security

### 4.1 Authentication Scope
Always place routes inside the correct `live_session`.
- `:admin_only`: For Admin/Manager modules.
- `:require_authenticated_user`: For general authenticated access.

### 4.2 Authorization Checks
Don't rely just on the router. Check permissions in the Context or Controller/LiveView if the action is sensitive.

---

## 5. Implementation Checklist for New Modules

Copy this into your `task.md` when starting a new module:

```markdown
- [ ] **UI Implementation**
  - [ ] Use `st-app has-background` container
  - [ ] Use `<.app_header>`
  - [ ] Use `st-card st-acrylic` for containers
- [ ] **Resilience**
  - [ ] Add Route to `router.ex` with Rate Limit pipeline
  - [ ] Add `phx-hook="DebounceSubmit"` to all action buttons
  - [ ] Add `id` attribute to all buttons with hooks
- [ ] **Observability**
  - [ ] Call `Audit.log_action/3` on Create
  - [ ] Call `Audit.log_action/3` on Update
  - [ ] Call `Audit.log_action/3` on Delete/Toggle
```

---

> [!NOTE]
> **"If it's not logged, it didn't happen. If it crashes, it's not finished."**
