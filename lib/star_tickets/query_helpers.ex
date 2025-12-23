defmodule StarTickets.QueryHelpers do
  @moduledoc """
  Funções genéricas para CRUD com paginação, ordenação e filtros.
  """
  import Ecto.Query

  @default_per_page 20

  @doc """
  Pagina uma query Ecto.

  ## Exemplos

      iex> query |> paginate(1, 20)
  """
  def paginate(query, page, per_page \\ @default_per_page) do
    page = max(page, 1)
    per_page = max(per_page, 1)
    offset = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset)
  end

  @doc """
  Retorna dados paginados com metadados.

  Retorna um mapa com:
  - `:entries` - Lista de registros
  - `:page` - Página atual
  - `:per_page` - Itens por página
  - `:total` - Total de registros
  - `:total_pages` - Total de páginas

  ## Exemplos

      iex> paginated_list(Repo, User, 1, 20)
      %{entries: [...], page: 1, per_page: 20, total: 100, total_pages: 5}
  """
  def paginated_list(repo, query, page, per_page \\ @default_per_page) do
    page = max(page, 1)
    per_page = max(per_page, 1)

    total = repo.aggregate(query, :count)
    entries = query |> paginate(page, per_page) |> repo.all()
    total_pages = if total > 0, do: ceil(total / per_page), else: 1

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages
    }
  end

  @doc """
  Aplica filtros dinâmicos a uma query.

  Ignora filtros com valores nil ou string vazia.

  ## Exemplos

      iex> query |> apply_filters(%{name: "João", age: nil})
      # Retorna query filtrada por name, ignora age
  """
  def apply_filters(query, filters) when is_map(filters) do
    Enum.reduce(filters, query, fn
      {_key, nil}, q -> q
      {_key, ""}, q -> q
      {key, value}, q -> where(q, [r], field(r, ^key) == ^value)
    end)
  end

  @doc """
  Aplica busca LIKE em um campo.
  """
  def apply_search(query, _field, nil), do: query
  def apply_search(query, _field, ""), do: query

  def apply_search(query, field, term) do
    search_term = "%#{term}%"
    where(query, [r], ilike(field(r, ^field), ^search_term))
  end

  @doc """
  Aplica ordenação a uma query.

  ## Exemplos

      iex> query |> apply_sort(:name, :asc)
  """
  def apply_sort(query, field, direction \\ :asc) when direction in [:asc, :desc] do
    order_by(query, [r], [{^direction, field(r, ^field)}])
  end
end
