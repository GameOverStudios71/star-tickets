defmodule StarTicketsWeb.ManagerLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header title="Gerente" show_home={true} current_scope={@current_scope} />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="📊 Painel do Gerente"
          description="Otimização de filas e monitoramento de fluxo."
          breadcrumb_items={[
            %{label: "Gerente"}
          ]}
        >
        </.page_header>
      </div>

      <.app_footer />
    </div>
    """
  end
end
