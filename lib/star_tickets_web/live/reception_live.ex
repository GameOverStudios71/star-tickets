defmodule StarTicketsWeb.ReceptionLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header title="Recepção" show_home={true} current_scope={@current_scope} />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="👥 Recepção"
          description="Gestão de filas, cadastro e chamada de senhas."
          breadcrumb_items={[
            %{label: "Recepção"}
          ]}
        >
        </.page_header>
      </div>

      <.app_footer />
    </div>
    """
  end
end
