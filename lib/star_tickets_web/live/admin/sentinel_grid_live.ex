defmodule StarTicketsWeb.Admin.SentinelGridLive do
  use StarTicketsWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sentinel Grid"), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="w-screen h-screen bg-black overflow-hidden grid grid-cols-2 grid-rows-2">
      <!-- Quadrant 1: Totem (Top Left) -->
      <div class="relative border-r border-b border-cyan-900/50 group">
        <div class="absolute top-2 left-2 z-10 bg-black/80 text-cyan-500 text-xs font-bold px-2 py-1 rounded border border-cyan-900/50 opacity-50 group-hover:opacity-100 transition-opacity pointer-events-none">
          <i class="fa-solid fa-tablet-screen-button mr-1"></i> TOTEM
        </div>
        <iframe src="/totem" class="w-full h-full border-0" frameborder="0"></iframe>
      </div>
      
    <!-- Quadrant 2: TV (Top Right) -->
      <div class="relative border-b border-cyan-900/50 group">
        <div class="absolute top-2 right-2 z-10 bg-black/80 text-cyan-500 text-xs font-bold px-2 py-1 rounded border border-cyan-900/50 opacity-50 group-hover:opacity-100 transition-opacity pointer-events-none">
          <i class="fa-solid fa-tv mr-1"></i> TV PANEL
        </div>
        <iframe src="/tv" class="w-full h-full border-0" frameborder="0"></iframe>
      </div>
      
    <!-- Quadrant 3: Reception (Bottom Left) -->
      <div class="relative border-r border-cyan-900/50 group">
        <div class="absolute bottom-2 left-2 z-10 bg-black/80 text-cyan-500 text-xs font-bold px-2 py-1 rounded border border-cyan-900/50 opacity-50 group-hover:opacity-100 transition-opacity pointer-events-none">
          <i class="fa-solid fa-desktop mr-1"></i> RECEPTION
        </div>
        <iframe src="/reception" class="w-full h-full border-0" frameborder="0"></iframe>
      </div>
      
    <!-- Quadrant 4: Professional (Bottom Right) -->
      <div class="relative group">
        <div class="absolute bottom-2 right-2 z-10 bg-black/80 text-cyan-500 text-xs font-bold px-2 py-1 rounded border border-cyan-900/50 opacity-50 group-hover:opacity-100 transition-opacity pointer-events-none">
          <i class="fa-solid fa-user-doctor mr-1"></i> PROFESSIONAL
        </div>
        <iframe src="/professional" class="w-full h-full border-0" frameborder="0"></iframe>
      </div>
      
    <!-- Center Overlay -->
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-12 h-12 bg-black rounded-full border-2 border-cyan-500 flex items-center justify-center z-20 shadow-[0_0_30px_rgba(6,182,212,0.5)]">
        <i class="fa-solid fa-eye text-cyan-400 animate-pulse"></i>
      </div>
      
    <!-- Back Button -->
      <div class="absolute top-4 right-1/2 translate-x-1/2 z-30">
        <.link
          navigate={~p"/admin/sentinel"}
          class="bg-black/80 hover:bg-black text-white px-3 py-1 rounded-full text-xs border border-white/10 hover:border-white/30 transition-all flex items-center gap-2"
        >
          <i class="fa-solid fa-arrow-left"></i> BACK TO SENTINEL
        </.link>
      </div>
    </div>
    """
  end
end
