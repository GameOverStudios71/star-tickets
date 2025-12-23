defmodule StarTicketsWeb.ProfessionalLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header title="Profissional" show_home={true} current_scope={@current_scope} />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="🏥 Área do Profissional"
          description="Chamada de pacientes e atendimento."
          breadcrumb_items={[
            %{label: "Profissional"}
          ]}
        >
        </.page_header>
      </div>

      <.app_footer />
    </div>
    """
  end
end
