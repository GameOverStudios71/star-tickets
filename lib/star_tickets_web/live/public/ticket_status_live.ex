defmodule StarTicketsWeb.Public.TicketStatusLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Tickets

  def mount(%{"token" => token}, _session, socket) do
    ticket = Tickets.get_ticket_by_token!(token)
    {:ok, assign(socket, ticket: ticket)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-black text-white flex items-center justify-center p-4">
      <div class="w-full max-w-md">
        <!-- Logo -->
        <div class="text-center mb-10">
          <h1 class="text-2xl font-bold tracking-tight text-white/80">⭐ Star Tickets</h1>
        </div>

        <div class="bg-white/10 backdrop-blur-xl border border-white/10 rounded-3xl p-8 text-center shadow-2xl">
           <div class="text-6xl mb-6 font-mono font-bold tracking-widest text-white">
             {@ticket.display_code}
           </div>

           <div class="inline-block px-4 py-2 rounded-full bg-yellow-500/20 text-yellow-300 border border-yellow-500/30 text-sm font-semibold mb-8">
             Aguardando Atendimento
           </div>

           <div class="border-t border-white/10 pt-8 mt-4">
             <div class="text-5xl mb-4">🚧</div>
             <h2 class="text-xl font-bold mb-2">Em Construção</h2>
             <p class="text-white/60 text-sm">
               Em breve você poderá acompanhar sua posição na fila e tempo estimado por aqui.
             </p>
           </div>
        </div>

        <div class="text-center mt-8 text-white/30 text-xs">
          Token: {@ticket.token}
        </div>
      </div>
    </div>
    """
  end
end
