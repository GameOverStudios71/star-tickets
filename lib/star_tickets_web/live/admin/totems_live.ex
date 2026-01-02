defmodule StarTicketsWeb.Admin.TotemsLive do
  use StarTicketsWeb, :live_view

  alias StarTicketsWeb.ImpersonationHelpers

  def mount(_params, session, socket) do
    impersonation_assigns =
      ImpersonationHelpers.load_impersonation_assigns(socket.assigns.current_scope, session)

    {:ok, assign(socket, impersonation_assigns)}
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex flex-col pt-20">
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

      <div class="st-container flex-1 m-4" style="margin-top: 0;">
        <.page_header
          title="🎫 Configuração do Totem"
          description="Configure os menus e opções dos totens de autoatendimento."
          breadcrumb_items={[
            %{label: "Administração", href: "/admin"},
            %{label: "Totem"}
          ]}
        >
          <hr class="my-6 border-white/10 border-dashed" />

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for establishment <- @establishments do %>
              <div class="card bg-white/10 backdrop-blur-md shadow-xl border border-gray-500/10 hover:border-orange-500/50 transition-colors">
                <div class="card-body">
                  <h2 class="card-title text-white">{establishment.name}</h2>
                  <p class="text-white/60 text-sm">
                    Configure o menu de navegação e serviços para este estabelecimento.
                  </p>
                  <div class="card-actions justify-end mt-4">
                    <.link
                      navigate={~p"/admin/establishments/#{establishment.id}/menus"}
                      class="btn btn-primary btn-sm"
                    >
                      Configurar Menu
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if Enum.empty?(@establishments) do %>
              <div class="col-span-full text-center py-12 bg-base-100/50 rounded-lg border border-dashed border-white/20">
                <p class="text-white/40">Nenhum estabelecimento encontrado.</p>
              </div>
            <% end %>
          </div>
        </.page_header>
      </div>
    </div>
    """
  end
end
