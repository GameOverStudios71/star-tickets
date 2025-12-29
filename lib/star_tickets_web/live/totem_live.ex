defmodule StarTicketsWeb.TotemLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts
  alias StarTickets.Tickets
  alias StarTicketsWeb.ImpersonationHelpers

  @doc """
  Totem Kiosk Interface
  States: :menu, :confirmation, :ticket
  """
  def mount(_params, session, socket) do
    # Load impersonation assigns to get selected_establishment_id
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    establishment_id = impersonation_assigns.selected_establishment_id

    if establishment_id do
      # Load root menus for the selected establishment
      root_menus = Accounts.list_root_totem_menus(establishment_id)

      {:ok,
       socket
       |> assign(impersonation_assigns)
       |> assign(
         current_step: :menu,
         current_menus: root_menus,
         menu_stack: [],
         selected_services: [],
         selected_tags: [],
         ticket: nil,
         establishment_id: establishment_id
       )}
    else
      # No establishment selected - show error
      {:ok,
       socket
       |> assign(impersonation_assigns)
       |> assign(
         current_step: :no_establishment,
         current_menus: [],
         menu_stack: [],
         selected_services: [],
         selected_tags: [],
         ticket: nil
       )}
    end
  end

  def render(assigns) do
    ~H"""
    <div id="totem-sounds" phx-hook="TotemSounds" class="st-app has-background totem-layout min-h-screen flex flex-col">
      <!-- Logo -->
      <div class="fixed bottom-6 right-6 z-50">
        <div class="px-6 py-4 rounded-2xl bg-white/5 backdrop-blur-xl border border-white/10">
          <span class="text-2xl font-bold text-white/80">⭐ Star Tickets</span>
        </div>
      </div>

      <!-- Back Button - Only show during menu/services navigation, not on confirmation/ticket -->
      <%= if length(@menu_stack) > 0 and @current_step in [:menu, :services] do %>
        <div class="fixed top-6 left-6 z-50">
          <button
            phx-click="go_back"
            class="px-8 py-4 rounded-xl text-lg font-bold text-white/90
                   bg-white/10 backdrop-blur-xl border border-white/20
                   hover:bg-white/20 hover:scale-105 transition-all duration-300
                   shadow-lg hover:shadow-xl"
          >
            ← VOLTAR
          </button>
        </div>
      <% end %>

      <!-- Main Content -->
      <div class="flex-1 flex flex-col items-center justify-center p-8">
        <%= case @current_step do %>
          <% :no_establishment -> %>
            <.no_establishment_screen />

          <% :menu -> %>
            <.menu_screen
              menus={@current_menus}
              selected_services={@selected_services}
              menu_stack={@menu_stack}
            />

          <% :services -> %>
            <.service_screen
              available_services={@available_services}
              selected_services={@selected_services}
              current_menu_name={@current_menu_name}
            />

          <% :confirmation -> %>
            <.confirmation_screen selected_services={@selected_services} />

          <% :ticket -> %>
            <.ticket_screen ticket={@ticket} />
        <% end %>
      </div>
    </div>
    """
  end

  # Menu Screen Component
  defp menu_screen(assigns) do
    ~H"""
    <div class="w-full max-w-5xl">
      <!-- Title -->
      <!--<div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-white/90 mb-4">
          <%= if length(@menu_stack) == 0, do: "Selecione o tipo de atendimento", else: "Selecione uma opção" %>
        </h1>
        <%= if length(@selected_services) > 0 do %>
          <p class="text-xl text-orange-400">
            <%= length(@selected_services) %> serviço(s) selecionado(s)
          </p>
        <% end %>
      </div>-->

      <!-- Menu Grid -->
      <% menu_cols = if length(@menus) >= 3, do: "grid-cols-3", else: "grid-cols-2" %>
      <div class={"grid #{menu_cols} gap-8 mb-8"}>
        <%= for menu <- @menus do %>
          <button
            phx-click="select_menu"
            phx-value-id={menu.id}
            class="group relative p-10 rounded-3xl text-center
                   bg-white/5 backdrop-blur-2xl border border-white/10
                   hover:bg-white/10 hover:border-white/30 hover:scale-[1.02] hover:-translate-y-2
                   transition-all duration-300 ease-out
                   shadow-lg hover:shadow-2xl"
          >
            <!-- Icon -->
            <div class="text-6xl mb-6 opacity-80 group-hover:opacity-100 transition-opacity">
              <%= get_menu_emoji(menu.name) %>
            </div>

            <!-- Name -->
            <div class="text-2xl font-bold text-white/90">
              <%= clean_menu_name(menu.name) %>
            </div>

            <!-- Description only if exists -->
            <%= if menu.description do %>
              <div class="text-base text-white/60 mt-2"><%= menu.description %></div>
            <% end %>
          </button>
        <% end %>
      </div>

      <!-- Action Buttons -->
      <%= if length(@selected_services) > 0 do %>
        <div class="flex flex-col gap-4 max-w-2xl mx-auto">
          <button
            phx-click="show_confirmation"
            class="w-full py-6 rounded-2xl text-2xl font-bold text-white
                   bg-gradient-to-r from-green-600/80 to-emerald-600/80
                   backdrop-blur-xl border border-green-400/30
                   hover:from-green-600 hover:to-emerald-600 hover:scale-[1.02]
                   transition-all duration-300 shadow-lg hover:shadow-green-500/25"
          >
            ✓ CONFIRMAR SELEÇÃO
          </button>
          <button
            phx-click="clear_selection"
            class="w-full py-4 rounded-xl text-lg font-semibold text-white/70
                   bg-white/5 backdrop-blur-xl border border-white/10
                   hover:bg-white/10 hover:text-white transition-all duration-300"
          >
            Limpar Tudo
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Service Selection Screen Component
  defp service_screen(assigns) do
    ~H"""
    <div class="w-full max-w-5xl">
      <!-- Title -->
      <div class="text-center mb-12">
        <!--<h1 class="text-4xl font-bold text-white/90 mb-4">
          <%= @current_menu_name %>
        </h1>
        <p class="text-xl text-white/60">
          Selecione os serviços desejados
        </p>-->
        <%= if length(@selected_services) > 0 do %>
          <!--<p class="text-lg text-orange-400 mt-2">
            <%= length(@selected_services) %> serviço(s) selecionado(s)
          </p>-->
        <% end %>
      </div>

      <!-- Services Grid -->
      <% service_cols = if length(@available_services) >= 3, do: "grid-cols-3", else: "grid-cols-2" %>
      <div class={"grid #{service_cols} gap-6 mb-8"}>
        <%= for menu_service <- @available_services do %>
          <% service = menu_service.service %>
          <% is_selected = Enum.any?(@selected_services, & &1.id == service.id) %>
          <button
            phx-click="toggle_service"
            phx-value-id={service.id}
            class={"group relative p-8 rounded-2xl text-center transition-all duration-300 ease-out shadow-lg hover:shadow-xl " <>
              if(is_selected,
                do: "bg-green-600/30 backdrop-blur-2xl border-2 border-green-400/60 scale-[1.02]",
                else: "bg-white/5 backdrop-blur-2xl border border-white/10 hover:bg-white/10 hover:border-white/30"
              )}
          >
            <!-- Checkmark indicator -->
            <div class={"absolute top-4 right-4 w-8 h-8 rounded-full flex items-center justify-center transition-all " <>
              if(is_selected, do: "bg-green-500 text-white", else: "bg-white/10 text-white/30")}>
              <%= if is_selected do %>
                ✓
              <% else %>
                ○
              <% end %>
            </div>

            <!-- Icon from TotemMenuService -->
            <%= if menu_service.icon_class do %>
              <div class="text-4xl mb-3 opacity-80">
                <%= menu_service.icon_class %>
              </div>
            <% end %>

            <!-- Service Name -->
            <div class={"text-2xl font-bold mb-2 " <> if(is_selected, do: "text-white", else: "text-white/90")}>
              <%= service.name %>
            </div>

            <!-- Description from Service -->
            <%= if service.description do %>
              <div class="text-base text-white/60 mb-2">
                <%= service.description %>
              </div>
            <% end %>

            <!-- Duration -->
            <!--<div class="text-sm text-white/50">
              <%= service.duration %> min
            </div>-->
          </button>
        <% end %>
      </div>

      <!-- Action Buttons -->
      <%= if length(@selected_services) > 0 do %>
        <div class="flex flex-col gap-4 max-w-2xl mx-auto">
          <button
            phx-click="show_confirmation"
            class="w-full py-6 rounded-2xl text-2xl font-bold text-white
                   bg-gradient-to-r from-green-600/80 to-emerald-600/80
                   backdrop-blur-xl border border-green-400/30
                   hover:from-green-600 hover:to-emerald-600 hover:scale-[1.02]
                   transition-all duration-300 shadow-lg hover:shadow-green-500/25"
          >
            ✓ CONFIRMAR SELEÇÃO
          </button>
          <button
            phx-click="clear_selection"
            class="w-full py-4 rounded-xl text-lg font-semibold text-white/70
                   bg-white/5 backdrop-blur-xl border border-white/10
                   hover:bg-white/10 hover:text-white transition-all duration-300"
          >
            Limpar Tudo
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Confirmation Screen Component
  defp confirmation_screen(assigns) do
    ~H"""
    <div class="w-full max-w-2xl">
      <div class="p-10 rounded-3xl bg-white/10 backdrop-blur-2xl border border-white/20 shadow-2xl">
        <h2 class="text-3xl font-bold text-white text-center mb-8">
          Confirme seus serviços
        </h2>

        <!-- Services List -->
        <div class="space-y-3 mb-8">
          <%= for service <- @selected_services do %>
            <div class="flex items-center gap-4 p-4 rounded-xl bg-white/5 border border-white/10">
              <div class="w-3 h-3 rounded-full bg-green-500"></div>
              <span class="text-lg text-white/90"><%= service.name %></span>
              <span class="ml-auto text-sm text-white/50"><%= service.duration %> min</span>
            </div>
          <% end %>
        </div>

        <!-- Total -->
        <div class="p-4 rounded-xl bg-white/5 border border-white/10 mb-8">
          <div class="flex justify-between items-center">
            <span class="text-white/70">Tempo estimado:</span>
            <span class="text-2xl font-bold text-white">
              <%= Enum.sum(Enum.map(@selected_services, & &1.duration)) %> minutos
            </span>
          </div>
        </div>

        <!-- Buttons -->
        <div class="flex flex-col gap-4">
          <button
            phx-click="generate_ticket"
            class="w-full py-6 rounded-2xl text-2xl font-bold text-white
                   bg-gradient-to-r from-green-600 to-emerald-600
                   hover:from-green-500 hover:to-emerald-500 hover:scale-[1.02]
                   transition-all duration-300 shadow-lg hover:shadow-green-500/25"
          >
            CONFIRMAR E GERAR SENHA
          </button>
          <button
            phx-click="back_to_services"
            class="w-full py-4 rounded-xl text-lg font-semibold text-white/70
                   bg-white/5 border border-white/10
                   hover:bg-white/10 hover:text-white transition-all duration-300"
          >
            ← Voltar
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Ticket Screen Component
  defp ticket_screen(assigns) do
    ~H"""
    <div class="w-full max-w-3xl">
      <div class="p-12 rounded-3xl bg-white/10 backdrop-blur-2xl border border-white/20 shadow-2xl text-center">
        <h2 class="text-3xl font-bold text-green-400 mb-8">
          Senha Gerada com Sucesso!
        </h2>

        <!-- Ticket Code -->
        <div class="mb-8">
          <div class="text-8xl font-bold text-white mb-4 font-mono">
            <%= @ticket.display_code %>
          </div>
          <p class="text-xl text-white/70">
            Aguarde ser chamado no painel
          </p>
        </div>

        <!-- Info Grid -->
        <div class="grid grid-cols-2 gap-6 mb-10">
          <div class="p-6 rounded-2xl bg-white/5 border border-white/10 flex flex-col items-center justify-center">
            <%= if assigns[:qr_code] do %>
              <div class="bg-white p-2 rounded-lg mb-2">
                <%= raw(@qr_code) %>
              </div>
              <p class="text-sm text-white/70 text-center">
                <strong><%= if @has_forms, do: "Faça WebCheckin!", else: "Acompanhe pelo celular" %></strong><br>
                Escaneie o QR Code
              </p>
            <% else %>
              <div class="text-2xl mb-2">📱</div>
              <p class="text-sm text-white/70">
                <strong>Acompanhe pelo celular!</strong><br>
                Escaneie o QR Code na impressão
              </p>
            <% end %>
          </div>
          <div class="p-6 rounded-2xl bg-white/5 border border-white/10 flex flex-col items-center justify-center">
            <div class="text-4xl mb-2">🔔</div>
            <p class="text-sm text-white/70 text-center">
              <strong>Fique atento!</strong><br>
              Sua senha será chamada em breve
            </p>
          </div>
        </div>

        <!-- Finish Button -->
        <button
          phx-click="reset"
          class="w-full py-6 rounded-2xl text-2xl font-bold text-white
                 bg-gradient-to-r from-blue-600 to-indigo-600
                 hover:from-blue-500 hover:to-indigo-500 hover:scale-[1.02]
                 transition-all duration-300 shadow-lg hover:shadow-blue-500/25"
        >
          FINALIZAR ATENDIMENTO
        </button>
      </div>
    </div>
    """
  end

  # No Establishment Screen Component
  defp no_establishment_screen(assigns) do
    ~H"""
    <div class="w-full max-w-2xl">
      <div class="p-12 rounded-3xl bg-white/10 backdrop-blur-2xl border border-white/20 shadow-2xl text-center">
        <div class="text-6xl mb-6">⚠️</div>
        <h2 class="text-3xl font-bold text-orange-400 mb-4">
          Estabelecimento não configurado
        </h2>
        <p class="text-lg text-white/70 mb-8">
          Este usuário não possui um estabelecimento vinculado.
          <br/>
          Por favor, faça login com um usuário de totem ou selecione um estabelecimento.
        </p>
        <a
          href="/dashboard"
          class="inline-block px-8 py-4 rounded-xl text-lg font-semibold text-white
                 bg-white/10 border border-white/20 hover:bg-white/20
                 transition-all duration-300"
        >
          ← Voltar ao Dashboard
        </a>
      </div>
    </div>
    """
  end

  # Event Handlers

  def handle_event("select_menu", %{"id" => id}, socket) do
    menu = Accounts.get_totem_menu!(String.to_integer(id))

    cond do
      # If menu has children, navigate to them
      has_children?(menu) ->
        children = Accounts.get_totem_menu_children(menu.id)
        new_stack = [socket.assigns.current_menus | socket.assigns.menu_stack]

        # Track taggable menus for filtering
        new_tags =
          if menu.is_taggable do
            [menu | socket.assigns.selected_tags]
          else
            socket.assigns.selected_tags
          end

        {:noreply,
         socket
         |> push_event("play_sound", %{sound: "click"})
         |> assign(
           current_menus: children,
           menu_stack: new_stack,
           selected_tags: new_tags
         )}

      # If menu has services, show service selection screen
      has_services?(menu) ->
        # Pass the full totem_menu_services for icon_class access
        menu_services = menu.totem_menu_services
        new_stack = [socket.assigns.current_menus | socket.assigns.menu_stack]

        new_tags =
          if menu.is_taggable do
            [menu | socket.assigns.selected_tags]
          else
            socket.assigns.selected_tags
          end

        {:noreply,
         socket
         |> push_event("play_sound", %{sound: "click"})
         |> assign(
           current_step: :services,
           available_services: menu_services,
           current_menu_name: clean_menu_name(menu.name),
           menu_stack: new_stack,
           selected_tags: new_tags
         )}

      # Otherwise just track tag if taggable
      true ->
        new_tags =
          if menu.is_taggable do
            [menu | socket.assigns.selected_tags]
          else
            socket.assigns.selected_tags
          end

        {:noreply, assign(socket, selected_tags: new_tags)}
    end
  end

  def handle_event("go_back", _params, socket) do
    case socket.assigns.menu_stack do
      [previous_menus | rest] ->
        {:noreply,
         socket
         |> push_event("play_sound", %{sound: "back"})
         |> assign(
           current_step: :menu,
           current_menus: previous_menus,
           menu_stack: rest,
           available_services: []
         )}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("show_confirmation", _params, socket) do
    {:noreply,
     socket
     |> push_event("play_sound", %{sound: "confirm"})
     |> assign(current_step: :confirmation)}
  end

  def handle_event("back_to_menu", _params, socket) do
    {:noreply,
     socket
     |> push_event("play_sound", %{sound: "back"})
     |> assign(current_step: :menu)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> push_event("play_sound", %{sound: "clear"})
     |> assign(selected_services: [], selected_tags: [])}
  end

  def handle_event("back_to_services", _params, socket) do
    {:noreply,
     socket
     |> push_event("play_sound", %{sound: "back"})
     |> assign(current_step: :services)}
  end

  def handle_event("toggle_service", %{"id" => id}, socket) do
    service_id = String.to_integer(id)
    available = socket.assigns[:available_services] || []
    selected = socket.assigns.selected_services

    # Find the TotemMenuService and extract the service
    menu_service = Enum.find(available, fn ms -> ms.service.id == service_id end)

    if menu_service do
      service = menu_service.service

      # Check if already selected
      is_selected = Enum.any?(selected, &(&1.id == service_id))

      new_selected =
        if is_selected do
          # Remove from selection
          Enum.reject(selected, &(&1.id == service_id))
        else
          # Add to selection
          [service | selected]
        end

      {:noreply,
       socket
       |> push_event("play_sound", %{sound: "select"})
       |> assign(selected_services: new_selected)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("generate_ticket", _params, socket) do
    # Create real ticket
    ticket_params = %{
      display_code: generate_ticket_code(),
      establishment_id: socket.assigns.establishment_id,
      services: socket.assigns.selected_services
    }

    case Tickets.create_ticket(ticket_params) do
      {:ok, ticket} ->
        # Determine URL based on forms
        has_forms = Tickets.ticket_has_forms?(ticket)
        path = if has_forms, do: "webcheckin", else: "ticket"
        url = "#{StarTicketsWeb.Endpoint.url()}/#{path}/#{ticket.token}"

        # Generate QR Code
        qr_code = url |> EQRCode.encode() |> EQRCode.svg(width: 200)

        {:noreply,
         socket
         |> push_event("play_sound", %{sound: "success"})
         |> assign(
           current_step: :ticket,
           ticket: ticket,
           qr_code: qr_code,
           has_forms: has_forms
         )}

      {:error, _changeset} ->
        # Fallback error handling (maybe show toast)
        {:noreply, socket}
    end
  end

  def handle_event("reset", _params, socket) do
    establishment_id = socket.assigns[:establishment_id]

    if establishment_id do
      root_menus = Accounts.list_root_totem_menus(establishment_id)

      {:noreply,
       assign(socket,
         current_step: :menu,
         current_menus: root_menus,
         menu_stack: [],
         selected_services: [],
         selected_tags: [],
         ticket: nil
       )}
    else
      {:noreply, assign(socket, current_step: :no_establishment)}
    end
  end

  # Helper Functions

  defp has_children?(%{children: children}) when is_list(children), do: length(children) > 0
  defp has_children?(_), do: false

  defp has_services?(%{totem_menu_services: services}) when is_list(services),
    do: length(services) > 0

  defp has_services?(_), do: false

  defp get_menu_emoji(name) do
    cond do
      String.contains?(name, "👤") or String.contains?(name, "Normal") -> "👤"
      String.contains?(name, "♿") or String.contains?(name, "Preferencial") -> "♿"
      String.contains?(name, "🔬") or String.contains?(name, "Análises") -> "🔬"
      String.contains?(name, "💳") or String.contains?(name, "Convênio") -> "💳"
      String.contains?(name, "💵") or String.contains?(name, "Particular") -> "💵"
      String.contains?(name, "🏥") or String.contains?(name, "Clínica") -> "🏥"
      String.contains?(name, "💼") or String.contains?(name, "Trabalho") -> "💼"
      true -> "📋"
    end
  end

  defp clean_menu_name(name) do
    name
    |> String.replace(~r/[👤♿🔬💳💵🏥💼📋]\s*/, "")
    |> String.trim()
  end

  defp generate_ticket_code do
    # Generate format: A001, B002, etc.
    letter = Enum.random(?A..?Z) |> List.wrap() |> to_string()
    number = :rand.uniform(999) |> Integer.to_string() |> String.pad_leading(3, "0")
    "#{letter}#{number}"
  end
end
