defmodule StarTicketsWeb.Admin.RoomsLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    {:ok, assign(socket, impersonation_assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header
        title="Administração"
        show_home={true}
        current_scope={@current_scope}
        client_name={@client_name}
        establishment_name={if length(@establishments) == 0, do: @establishment_name}
        establishments={@establishments}
        users={@users}
        selected_establishment_id={@selected_establishment_id}
        selected_user_id={@selected_user_id}
        impersonating={@impersonating}
      />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="🚪 Salas"
          description="Gerencie as salas de atendimento."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Salas"}
          ]}
        >
        <hr class="my-6 border-white/500 opacity-40 border-dashed" />
        </.page_header>
      </div>

      <.app_footer />
    </div>
    """
  end
end
