defmodule StarTicketsWeb.Components.AuditActionsFilter do
  @moduledoc """
  Component for rendering audit actions filter checkboxes.
  Supports both single-select (dropdown) and multi-select (checkboxes) modes.
  """
  use StarTicketsWeb, :html

  alias StarTickets.Audit.Actions

  @doc """
  Renders a collapsible section with action filter checkboxes for live ingestion.
  """
  attr :id, :string, required: true
  attr :title, :string, default: "Live Ingestion"
  attr :selected_actions, :list, default: []
  attr :on_toggle, :string, default: "toggle_action_filter"
  attr :collapsed, :boolean, default: true

  def live_ingestion_filter(assigns) do
    grouped_actions = Actions.all_grouped()
    assigns = assign(assigns, :grouped_actions, grouped_actions)

    ~H"""
    <div class="bg-black/20 border border-white/10 rounded-lg overflow-hidden">
      <button
        type="button"
        phx-click="toggle_ingestion_panel"
        class="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-white/5 transition-colors"
      >
        <div class="flex items-center gap-2 text-sm font-medium text-white/80">
          <i class="fa-solid fa-rss text-cyan-400"></i>
          {@title}
          <span class="bg-cyan-900/50 text-cyan-300 px-2 py-0.5 rounded text-xs">
            {length(@selected_actions)} filtros ativos
          </span>
        </div>
        <i class={"fa-solid fa-chevron-down transition-transform duration-200 text-white/50 #{if @collapsed, do: "", else: "rotate-180"}"}>
        </i>
      </button>

      <div class={[
        "px-4 pb-4 transition-all duration-300",
        if(@collapsed, do: "hidden", else: "block")
      ]}>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mt-2">
          <%= for {category, actions} <- @grouped_actions do %>
            <div class="space-y-2">
              <h4 class="text-xs font-bold text-white/60 uppercase tracking-wider border-b border-white/10 pb-1">
                {category}
              </h4>
              <%= for action <- actions do %>
                <label class="flex items-center gap-2 text-xs cursor-pointer hover:bg-white/5 rounded px-2 py-1 transition-colors">
                  <input
                    type="checkbox"
                    name={"action_filter[#{action}]"}
                    value={action}
                    checked={action in @selected_actions}
                    phx-click={@on_toggle}
                    phx-value-action={action}
                    class="rounded border-white/30 bg-black/30 text-cyan-500 focus:ring-cyan-500/50"
                  />
                  <i class={"fa-solid #{Actions.icon_for(action)} text-#{Actions.color_for(action)}-400 w-4 text-center"}>
                  </i>
                  <span class="text-white/80">{action}</span>
                </label>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex items-center gap-2 mt-4 pt-3 border-t border-white/10">
          <button
            type="button"
            phx-click="select_all_actions"
            class="text-xs px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded transition-colors text-white/70"
          >
            <i class="fa-solid fa-check-double mr-1"></i> Selecionar Todos
          </button>
          <button
            type="button"
            phx-click="clear_all_actions"
            class="text-xs px-3 py-1.5 bg-white/10 hover:bg-white/20 rounded transition-colors text-white/70"
          >
            <i class="fa-solid fa-xmark mr-1"></i> Limpar
          </button>
          <button
            type="button"
            phx-click="reset_default_actions"
            class="text-xs px-3 py-1.5 bg-cyan-900/50 hover:bg-cyan-900/70 rounded transition-colors text-cyan-300"
          >
            <i class="fa-solid fa-rotate mr-1"></i> Padrão
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a dropdown select for single action filter.
  """
  attr :id, :string, required: true
  attr :selected_action, :string, default: nil
  attr :on_change, :string, default: "filter_by_action"
  attr :include_all, :boolean, default: true

  def action_dropdown(assigns) do
    actions = Actions.all()
    assigns = assign(assigns, :actions, actions)

    ~H"""
    <select
      id={@id}
      name="action"
      phx-change={@on_change}
      class="bg-black/30 border border-white/20 rounded-lg px-3 py-2 text-sm text-white focus:ring-cyan-500 focus:border-cyan-500"
    >
      <%= if @include_all do %>
        <option value="">Todas as ações</option>
      <% end %>
      <%= for action <- @actions do %>
        <option value={action} selected={@selected_action == action}>
          {action}
        </option>
      <% end %>
    </select>
    """
  end

  @doc """
  Renders an action badge with appropriate color and icon.
  """
  attr :action, :string, required: true
  attr :size, :string, default: "sm"

  def action_badge(assigns) do
    color = Actions.color_for(assigns.action)
    icon = Actions.icon_for(assigns.action)
    assigns = assign(assigns, color: color, icon: icon)

    ~H"""
    <span class={"inline-flex items-center gap-1.5 px-2 py-1 rounded text-#{@color}-300 bg-#{@color}-900/30 border border-#{@color}-500/30 #{if @size == "xs", do: "text-[10px]", else: "text-xs"}"}>
      <i class={"fa-solid #{@icon}"}></i>
      {@action}
    </span>
    """
  end
end
