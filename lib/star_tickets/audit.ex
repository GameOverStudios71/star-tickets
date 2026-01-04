defmodule StarTickets.Audit do
  @moduledoc """
  The Audit context.
  Responsible for recording paranoid logs.
  """

  import Ecto.Query, warn: false
  alias StarTickets.Repo
  alias StarTickets.Audit.AuditLog
  alias Phoenix.PubSub

  @doc """
  Logs an action.
  """
  def log_action(action, attrs \\ %{}, user \\ nil) do
    # Ensure user_id is extracted if user struct is passed differently or if nil
    user_id = if user, do: user.id, else: attrs[:user_id]

    attrs =
      attrs
      |> Map.put(:action, action)
      |> Map.put(:user_id, user_id)

    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
    |> broadcast_log()
  end

  @doc """
  Logs a change in a struct (diff).
  Helper used inside Ecto.Multi or transactions.
  """
  def log_diff(repo, old_struct, new_struct, action_prefix, user \\ nil, metadata \\ %{}) do
    diff = map_diff(old_struct, new_struct)

    if map_size(diff) > 0 do
      details = %{
        diff: diff,
        original_state: truncate_state(old_struct)
      }

      attrs = %{
        action: "#{action_prefix}_UPDATED",
        resource_type: struct_name(new_struct),
        resource_id: to_string(new_struct.id),
        details: details,
        metadata: metadata
      }

      # If repo is passed (inside Multi), use it?
      # Actually `repo.insert` is safer inside a transaction context if we want it to be part of the transaction.
      # But for Audit logs, sometimes we want them even if transaction fails?
      # For now let's assume successful transaction logs.

      user_id = if user, do: user.id, else: nil
      attrs = Map.put(attrs, :user_id, user_id)

      %AuditLog{}
      |> AuditLog.changeset(attrs)
      |> repo.insert()
      |> broadcast_log()
    else
      {:ok, nil}
    end
  end

  def subscribe_to_logs do
    PubSub.subscribe(StarTickets.PubSub, "audit_logs")
  end

  defp broadcast_log({:ok, log}) do
    try do
      # Preload user for display
      log = Repo.preload(log, :user)
      PubSub.broadcast(StarTickets.PubSub, "audit_logs", {:audit_log_created, log})
      {:ok, log}
    rescue
      e ->
        require Logger
        Logger.error("Failed to broadcast audit log: #{inspect(e)}")
        # Return success to avoid failing the transaction
        {:ok, log}
    end
  end

  defp broadcast_log({:error, _} = error), do: error

  defp struct_name(struct) do
    struct.__struct__
    |> Module.split()
    |> List.last()
  end

  def map_diff(struct1, struct2) do
    map1 = Map.from_struct(struct1)
    map2 = Map.from_struct(struct2)

    Map.keys(map2)
    |> Enum.reduce(%{}, fn key, acc ->
      val1 = Map.get(map1, key)
      val2 = Map.get(map2, key)

      if val1 != val2 and not is_ignored_field?(key) do
        Map.put(acc, key, %{from: val1, to: val2})
      else
        acc
      end
    end)
  end

  defp is_ignored_field?(key) do
    key in [:updated_at, :inserted_at, :__meta__]
  end

  defp truncate_state(struct) do
    # Remove __meta__ and all associations (loaded or not) to avoid JSON encoding issues
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> Enum.reject(fn {_k, v} ->
      # Reject associations that are NotLoaded or are lists of structs
      match?(%Ecto.Association.NotLoaded{}, v) or
        is_struct(v) or
        (is_list(v) and length(v) > 0 and is_struct(hd(v)))
    end)
    |> Map.new()
  end

  @doc """
  Lists audit logs with optional filters.
  """
  def list_logs(params \\ %{}) do
    page = Map.get(params, "page", 1) |> to_integer()
    page_size = Map.get(params, "page_size", 20) |> to_integer()
    offset = (page - 1) * page_size

    AuditLog
    |> order_by(desc: :inserted_at)
    |> filter_by_date(params)
    |> filter_by_user(params)
    |> filter_by_action(params)
    |> filter_by_allowed_actions(params)
    |> filter_by_resource(params)
    |> filter_by_severity(params)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def count_logs(params \\ %{}) do
    AuditLog
    |> filter_by_date(params)
    |> filter_by_user(params)
    |> filter_by_action(params)
    |> filter_by_resource(params)
    |> filter_by_severity(params)
    |> Repo.aggregate(:count, :id)
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_binary(val), do: String.to_integer(val)
  defp to_integer(_), do: 1

  @doc """
  Lists all audit logs for a specific ticket by its ID.
  Returns logs in chronological order (oldest first).
  """
  def list_logs_for_ticket(ticket_id) when is_binary(ticket_id) or is_integer(ticket_id) do
    ticket_id_str = to_string(ticket_id)

    AuditLog
    |> where([q], q.resource_id == ^ticket_id_str and q.resource_type == "Ticket")
    |> order_by(asc: :inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Deletes logs older than N days.
  """
  def delete_logs_older_than(days) do
    date = DateTime.utc_now() |> DateTime.add(-days, :day)

    from(l in AuditLog, where: l.inserted_at < ^date)
    |> Repo.delete_all()
  end

  defp filter_by_date(query, %{"start_date" => start_date, "end_date" => end_date})
       when is_binary(start_date) and is_binary(end_date) and start_date != "" and end_date != "" do
    # Simple date filtering yyyy-mm-dd
    {:ok, start_dt} = Date.from_iso8601(start_date)
    {:ok, end_dt} = Date.from_iso8601(end_date)

    # Handle end of day
    end_dt = DateTime.new!(end_dt, ~T[23:59:59], "Etc/UTC")
    start_dt = DateTime.new!(start_dt, ~T[00:00:00], "Etc/UTC")

    where(query, [q], q.inserted_at >= ^start_dt and q.inserted_at <= ^end_dt)
  end

  defp filter_by_date(query, _), do: query

  defp filter_by_user(query, %{"user_id" => user_id}) when is_binary(user_id) and user_id != "" do
    where(query, user_id: ^user_id)
  end

  defp filter_by_user(query, _), do: query

  defp filter_by_action(query, %{"action" => actions}) when is_list(actions) and actions != [] do
    where(query, [q], q.action in ^actions)
  end

  defp filter_by_action(query, %{"action" => action}) when is_binary(action) and action != "" do
    if String.contains?(action, ",") do
      actions = String.split(action, ",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      where(query, [q], q.action in ^actions)
    else
      where(query, [q], ilike(q.action, ^"%#{action}%"))
    end
  end

  defp filter_by_action(query, _), do: query

  defp filter_by_resource(query, %{"resource_type" => type})
       when is_binary(type) and type != "" do
    where(query, resource_type: ^type)
  end

  defp filter_by_resource(query, _), do: query

  defp filter_by_allowed_actions(query, %{"allowed_actions" => actions}) when is_list(actions) do
    # Check if we should include system errors
    include_errors = "SYSTEM_ERROR" in actions

    # Filter out "SYSTEM_ERROR" from exact matches since actual logs don't use it
    exact_matches = List.delete(actions, "SYSTEM_ERROR")

    if include_errors do
      where(
        query,
        [q],
        q.action in ^exact_matches or
          ilike(q.action, "%ERROR%") or
          ilike(q.action, "%FAILED%") or
          ilike(q.action, "%CRITICAL%")
      )
    else
      where(query, [q], q.action in ^exact_matches)
    end
  end

  defp filter_by_allowed_actions(query, _), do: query

  defp filter_by_severity(query, %{"severity" => "error"}) do
    where(
      query,
      [q],
      ilike(q.action, "%ERROR%") or ilike(q.action, "%FAILED%") or ilike(q.action, "%CRITICAL%")
    )
  end

  defp filter_by_severity(query, %{"severity" => "warning"}) do
    where(query, [q], ilike(q.action, "%WARNING%") or ilike(q.action, "%ALERT%"))
  end

  defp filter_by_severity(query, %{"severity" => "info"}) do
    where(
      query,
      [q],
      not (ilike(q.action, "%ERROR%") or ilike(q.action, "%FAILED%") or
             ilike(q.action, "%CRITICAL%") or ilike(q.action, "%WARNING%") or
             ilike(q.action, "%ALERT%"))
    )
  end

  defp filter_by_severity(query, %{"severity" => "alerts"}) do
    where(
      query,
      [q],
      ilike(q.action, "%ERROR%") or ilike(q.action, "%FAILED%") or ilike(q.action, "%CRITICAL%") or
        ilike(q.action, "%WARNING%") or ilike(q.action, "%ALERT%")
    )
  end

  defp filter_by_severity(query, _), do: query
end
