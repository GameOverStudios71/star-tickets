defmodule StarTicketsWeb.TotemLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col" style="padding-top: 80px;">
      <.app_header title="Totem" show_home={true} current_scope={@current_scope} />

      <div class="st-container flex-1 m-4">
        <.page_header
          title="🎫 Totem de Autoatendimento"
          description="Sistema de emissão de senhas para clientes."
          breadcrumb_items={[
            %{label: "Totem"}
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
