defmodule StarTicketsWeb.Public.WebCheckinLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div class="text-center">
        <div class="text-6xl mb-6">📝</div>
        <h1 class="text-3xl font-bold text-white mb-4">Web Check-in</h1>
        <p class="text-gray-400 max-w-md mx-auto">
          Esta página está em construção. Aqui você poderá preencher os formulários dos serviços selecionados.
        </p>
      </div>
    </div>
    """
  end
end
