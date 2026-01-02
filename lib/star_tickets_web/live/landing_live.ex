defmodule StarTicketsWeb.LandingLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
      <%!-- Header --%>
      <header class="st-app-header">
        <div class="st-header-left">
          <span class="text-2xl">🎫</span>
          <h1>Star Tickets</h1>
        </div>
        <div class="st-header-right">
          <.link navigate={~p"/users/log-in"} class="st-btn st-btn-acrylic">
            Entrar
          </.link>
        </div>
      </header>

      <section class="st-container text-center py-10" style="margin-top: 0;">
        <div
          class="st-card st-acrylic-strong"
          style="max-width: 600px; margin: 0 auto; padding: 40px;"
        >
          <h1
            class="text-5xl font-bold text-white mb-4"
            style="text-shadow: 0 2px 10px rgba(0,0,0,0.3);"
          >
            Sistema de Gestão de Senhas
          </h1>
          <p class="text-xl text-white/80 mb-8">
            Solução completa para clínicas, hospitais e estabelecimentos públicos.
            Gerencie filas, otimize atendimentos e melhore a experiência dos seus clientes.
          </p>
          <div class="flex gap-4 justify-center">
            <.link navigate={~p"/users/register"} class="st-btn st-btn-large">
              🚀 Começar Agora
            </.link>
            <.link navigate={~p"/users/log-in"} class="st-btn st-btn-acrylic st-btn-large">
              Já tenho conta
            </.link>
          </div>
        </div>
      </section>

      <%!-- Footer --%>
      <footer class="st-acrylic" style="padding: 30px; text-align: center; margin-top: auto;">
        <p class="text-white/80">
          © 2024 Star Tickets - Sistema de Gestão de Senhas
        </p>
      </footer>
    </div>
    """
  end
end
