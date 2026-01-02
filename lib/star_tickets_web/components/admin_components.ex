defmodule StarTicketsWeb.AdminComponents do
  use Phoenix.Component
  use StarTicketsWeb, :html

  @doc """
  Renders a table with consistent styling for admin pages.
  """
  attr(:id, :string, required: true)
  attr(:rows, :list, required: true)
  attr(:row_id, :any, default: nil)
  attr(:row_click, :any, default: nil)

  slot :col, required: true do
    attr(:label, :string)
  end

  slot(:action, doc: "Actions for each row")

  def admin_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table st-table w-full" id={@id}>
        <thead class="text-xs uppercase st-table-header font-bold st-text-table-header">
          <tr>
            <th :for={col <- @col} class="px-6 py-3">{col[:label]}</th>
            <th :if={@action != []} class="px-6 py-3 text-right">Ações</th>
          </tr>
        </thead>
        <tbody class="text-sm divide-y divide-base-200">
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)} class="transition-colors">
            <td
              :for={col <- @col}
              class={"px-6 py-4 whitespace-nowrap st-text-body #{if @row_click, do: "cursor-pointer"}"}
              phx-click={@row_click && @row_click.(row)}
            >
              {render_slot(col, row)}
            </td>
            <td :if={@action != []} class="px-6 py-4 text-right whitespace-nowrap">
              <div class="flex items-center justify-end gap-2">
                {render_slot(@action, row)}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders pagination controls.
  """
  attr(:page, :integer, required: true)
  attr(:total_pages, :integer, required: true)
  attr(:on_change, :string, default: "change_page", doc: "Event name to trigger on page change")

  def pagination(assigns) do
    ~H"""
    <div :if={@total_pages > 1} class="flex items-center justify-center gap-2 mt-4">
      <button
        class="btn btn-sm btn-ghost"
        disabled={@page <= 1}
        phx-click={@on_change}
        phx-value-page={@page - 1}
      >
        <.icon name="hero-chevron-left" class="size-4" />
      </button>

      <span class="text-sm font-medium st-text-body">
        Página {@page} de {@total_pages}
      </span>

      <button
        class="btn btn-sm btn-ghost"
        disabled={@page >= @total_pages}
        phx-click={@on_change}
        phx-value-page={@page + 1}
      >
        <.icon name="hero-chevron-right" class="size-4" />
      </button>
    </div>
    """
  end

  @doc """
  Renders a search bar.
  """
  attr(:value, :string, default: "")
  attr(:placeholder, :string, default: "Buscar")
  attr(:on_search, :string, default: "search", doc: "Event name")

  def search_bar(assigns) do
    ~H"""
    <form
      phx-change={@on_search}
      phx-submit={@on_search}
      class="form-control w-full max-w-xs opacity-85"
    >
      <div class="input-group">
        <input
          type="text"
          name="search"
          value={@value}
          placeholder={@placeholder}
          class="input input-bordered w-full h-10 st-text-inverse bg-white"
          phx-debounce="300"
        />
      </div>
    </form>
    """
  end

  @doc """
  Renders an action header with title and a primary action button.
  """
  attr(:title, :string, required: true)
  slot(:actions)

  def action_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-xl font-bold st-text-title">
        {@title}
      </h2>
      <div class="flex gap-2">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal with distinct styling (red warning).
  """
  attr(:show, :boolean, default: false)
  attr(:title, :string, required: true)
  attr(:message, :string, required: true)
  attr(:confirm_label, :string, default: "Confirmar")
  attr(:cancel_label, :string, default: "Cancelar")
  attr(:on_confirm, :string, required: true)
  attr(:on_cancel, :string, required: true)
  attr(:id, :string, default: "confirm-modal")

  def confirm_modal(assigns) do
    ~H"""
    <.modal :if={@show} id={@id} show={@show} on_cancel={JS.push(@on_cancel)} transparent={true}>
      <div class="st-modal-confirm">
        <div class="st-modal-icon-container">
          <.icon name="hero-exclamation-triangle" class="size-12 text-red-500" />
        </div>
        <h3 class="st-modal-title">{@title}</h3>
        <p class="st-modal-text">{@message}</p>
        <div class="flex justify-center gap-3">
          <button
            class="st-modal-btn st-modal-btn-cancel"
            phx-click={@on_cancel}
          >
            {@cancel_label}
          </button>
          <button
            class="st-modal-btn st-modal-btn-confirm"
            phx-click={@on_confirm}
          >
            {@confirm_label}
          </button>
        </div>
      </div>
    </.modal>
    """
  end
end
