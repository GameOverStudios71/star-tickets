defmodule StarTickets.Sentinel.Overseer do
  @moduledoc """
  The AI Brain that monitors the system in real-time.
  Subscribes to audit logs and manages projections/expectations.
  """
  use GenServer
  require Logger
  alias Phoenix.PubSub
  alias StarTickets.Sentinel.Projection

  # Config
  @pubsub StarTickets.PubSub
  @audit_topic "audit_logs"
  @sentinel_topic "sentinel_events"
  # Check deadlines every 5s
  @tick_interval 5000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc "Register an observer (e.g., LiveView PID). Sentinel activates when at least one observer exists."
  def register_observer(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:register_observer, pid})
  end

  @doc "Unregister an observer. Sentinel deactivates when no observers remain."
  def unregister_observer(pid) when is_pid(pid) do
    GenServer.cast(__MODULE__, {:unregister_observer, pid})
  end

  @doc "Check if Sentinel is currently active."
  def active? do
    GenServer.call(__MODULE__, :is_active)
  end

  def dismiss_anomaly(idx) do
    GenServer.cast(__MODULE__, {:dismiss_anomaly, idx})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Start DISABLED - activate only when observers register
    Logger.info("🔮 Sentinel Overseer initialized (INACTIVE - waiting for observers)")

    {:ok,
     %{
       active: false,
       observers: MapSet.new(),
       timer_ref: nil,
       projections: [],
       anomalies: [],
       recent_logs: [],
       active_alerts: MapSet.new(),
       previous_presences: %{tvs: [], totems: [], reception: [], professional: []}
     }}
  end

  @impl true
  def handle_call(:is_active, _from, state) do
    {:reply, state.active, state}
  end

  @impl true
  def handle_call({:register_observer, pid}, _from, state) do
    # Monitor the observer so we can clean up if it dies
    Process.monitor(pid)
    new_observers = MapSet.put(state.observers, pid)

    # Activate if this is the first observer
    new_state =
      if not state.active and MapSet.size(new_observers) > 0 do
        activate_sentinel(%{state | observers: new_observers})
      else
        %{state | observers: new_observers}
      end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, Map.drop(state, [:timer_ref, :observers]), state}
  end

  @impl true
  def handle_info({:audit_log_created, log}, state) do
    # Ignore if not active
    if not state.active do
      {:noreply, state}
    else
      # 1. Store recent log for "stream" view (keep last 50)
      recent_logs = [log | state.recent_logs] |> Enum.take(50)

      # 2. Check for anomalies (Errors)
      new_anomalies = check_for_anomalies(log, state.anomalies)

      # 3. Process Projections (Verify existing or Create new)
      updated_projections = process_projections(log, state.projections)

      new_state = %{
        state
        | recent_logs: recent_logs,
          anomalies: new_anomalies,
          projections: updated_projections
      }

      # Broadcast update to UI
      broadcast_update(new_state)

      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    # Ignore if not active
    if not state.active do
      {:noreply, state}
    else
      # Check for expired projections
      now = DateTime.utc_now()

      {active, expired} =
        Enum.split_with(state.projections, fn p ->
          p.status != :pending or DateTime.compare(p.deadline, now) == :gt
        end)

      # Mark expired as failed
      failed_projections =
        expired
        |> Enum.map(fn p -> %{p | status: :failed} end)

      # If we had failures, we must update state and broadcast
      if length(failed_projections) > 0 do
        # Keep active + failed (for history, maybe limit history?)
        # For now, let's keep everything but maybe trim old completed ones later
        all_projections = active ++ failed_projections

        new_state = %{state | projections: all_projections}
        broadcast_update(new_state)
        {:noreply, new_state}
      else
        # Check connectivity every tick
        {new_active_alerts, current_presences} =
          check_connectivity(state.active_alerts, state.previous_presences)

        new_state = %{
          state
          | active_alerts: new_active_alerts,
            previous_presences: current_presences
        }

        if new_active_alerts != state.active_alerts or
             current_presences != state.previous_presences do
          {:noreply, new_state}
        else
          {:noreply, state}
        end
      end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Observer died - remove it
    new_observers = MapSet.delete(state.observers, pid)

    # Deactivate if no observers remain
    new_state =
      if state.active and MapSet.size(new_observers) == 0 do
        deactivate_sentinel(%{state | observers: new_observers})
      else
        %{state | observers: new_observers}
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:unregister_observer, pid}, state) do
    new_observers = MapSet.delete(state.observers, pid)

    # Deactivate if no observers remain
    new_state =
      if state.active and MapSet.size(new_observers) == 0 do
        deactivate_sentinel(%{state | observers: new_observers})
      else
        %{state | observers: new_observers}
      end

    {:noreply, new_state}
  end

  # Activation/Deactivation helpers

  defp activate_sentinel(state) do
    Logger.info("🔮 Sentinel Overseer ACTIVATED - monitoring started")
    PubSub.subscribe(@pubsub, @audit_topic)
    {:ok, timer_ref} = :timer.send_interval(@tick_interval, :tick)
    %{state | active: true, timer_ref: timer_ref}
  end

  defp deactivate_sentinel(state) do
    Logger.info("🔮 Sentinel Overseer DEACTIVATED - monitoring stopped")
    PubSub.unsubscribe(@pubsub, @audit_topic)
    if state.timer_ref, do: :timer.cancel(state.timer_ref)
    %{state | active: false, timer_ref: nil}
  end

  @impl true
  def handle_cast({:dismiss_anomaly, idx}, state) do
    new_anomalies = List.delete_at(state.anomalies, idx)
    new_state = %{state | anomalies: new_anomalies}
    broadcast_update(new_state)
    {:noreply, new_state}
  end

  # Helpers

  defp check_for_anomalies(log, current_anomalies) do
    action = to_string(log.action)

    is_anomaly =
      String.contains?(action, "ERROR") or
        String.contains?(action, "FAILED") or
        String.starts_with?(action, "SYSTEM_ERROR") or
        String.starts_with?(action, "SYSTEM_WARNING")

    if is_anomaly do
      # Don't use Logger here - it would cause an infinite loop!
      [log | current_anomalies] |> Enum.take(20)
    else
      current_anomalies
    end
  end

  defp process_projections(log, projections) do
    # A. Try to satisfy pending projections
    {satisfied, remaining} =
      Enum.split_with(projections, fn p ->
        p.status == :pending and matches_expectation?(log, p)
      end)

    satisfied = Enum.map(satisfied, fn p -> %{p | status: :verified} end)

    # B. Generate new projections based on heuristics
    new_projections = generate_projections(log)

    # Clean up old final states to avoid infinite growth?
    # For this demo, let's keep last 100 mixed
    (new_projections ++ satisfied ++ remaining)
    |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
    |> Enum.take(100)
  end

  defp matches_expectation?(log, projection) do
    # Simple match: Action matches and (if resource defined) resource matches
    action_match = log.action == projection.expected_action

    resource_match =
      if projection.resource_id do
        projection.resource_id == log.resource_id
      else
        # loosely match if no resource id tracked
        true
      end

    action_match and resource_match
  end

  defp generate_projections(log) do
    case log.action do
      "TICKET_CREATED" ->
        # Base projection: ticket should be called
        base = [
          Projection.new(
            name: "Ticket ##{log.resource_id} Flow",
            description: "Espero que este ticket seja chamado em breve.",
            trigger_event: log,
            expected_action: "TICKET_CALLED",
            resource_id: log.resource_id,
            # 30 min deadline
            deadline: DateTime.add(DateTime.utc_now(), 30 * 60, :second)
          )
        ]

        # If ticket has forms, also expect web checkin to be started
        has_forms = log.details["has_forms"] == true or log.details[:has_forms] == true

        if has_forms do
          base ++
            [
              Projection.new(
                name: "WebCheckin ##{log.resource_id}",
                description: "Ticket com formulário. Aguardando cliente acessar Web Check-in.",
                trigger_event: log,
                expected_action: "WEBCHECKIN_STARTED",
                resource_id: log.resource_id,
                # 10 min deadline (se demorar, talvez o cliente desistiu)
                deadline: DateTime.add(DateTime.utc_now(), 10 * 60, :second),
                confidence: 0.7
              )
            ]
        else
          base
        end

      "WEBCHECKIN_STARTED" ->
        [
          Projection.new(
            name: "WebCheckin Completion ##{log.resource_id}",
            description: "Cliente iniciou Web Check-in. Deve completar em breve.",
            trigger_event: log,
            expected_action: "WEBCHECKIN_COMPLETED",
            resource_id: log.resource_id,
            # 15 min deadline (formulários podem ser longos)
            deadline: DateTime.add(DateTime.utc_now(), 15 * 60, :second)
          )
        ]

      "TICKET_CALLED" ->
        [
          Projection.new(
            name: "Ticket ##{log.resource_id} Completion",
            description: "Ticket em atendimento. Deve ser finalizado.",
            trigger_event: log,
            expected_action: "TICKET_FINISHED",
            resource_id: log.resource_id,
            # 20 min deadline
            deadline: DateTime.add(DateTime.utc_now(), 20 * 60, :second)
          )
        ]

      "TOTEM_TICKET_GENERATION_STARTED" ->
        [
          Projection.new(
            name: "Totem Print ##{log.resource_id}",
            description: "Geração iniciada. Impressão deve ocorrer.",
            trigger_event: log,
            expected_action: "TOTEM_TICKET_PRINTED",
            resource_id: log.resource_id,
            # 15 sec deadline
            deadline: DateTime.add(DateTime.utc_now(), 15, :second)
          )
        ]

      _ ->
        []
    end
  end

  defp broadcast_update(state) do
    PubSub.broadcast(@pubsub, @sentinel_topic, {:sentinel_update, state})
  end

  defp check_connectivity(active_alerts, previous_presences) do
    presences = StarTicketsWeb.Presence.list("system:presence")
    grouped = group_presences(presences)

    # 1. Global/Group Checks (All Offline)
    group_checks = [
      {:totems, "SYSTEM_ALERT_TOTEM_OFFLINE", "Todos os Totems estão offline!", :error},
      {:reception, "SYSTEM_ALERT_RECEPTION_OFFLINE", "Nenhuma Recepção ativa!", :warning},
      {:tvs, "SYSTEM_ALERT_TV_OFFLINE", "Nenhuma TV conectada!", :warning},
      {:professional, "SYSTEM_ALERT_PROFESSIONAL_OFFLINE", "Nenhum Profissional conectado!",
       :warning}
    ]

    active_alerts =
      Enum.reduce(group_checks, active_alerts, fn {key, alert_key, message, severity}, acc ->
        is_empty = Enum.empty?(Map.get(grouped, key, []))

        if is_empty do
          if MapSet.member?(acc, alert_key) do
            acc
          else
            create_audit_log(alert_key, message, severity)
            MapSet.put(acc, alert_key)
          end
        else
          if MapSet.member?(acc, alert_key) do
            create_audit_log(
              String.replace(alert_key, "ALERT", "INFO") |> String.replace("OFFLINE", "ONLINE"),
              "Serviço recuperado: #{key} está online novamente.",
              :info
            )

            MapSet.delete(acc, alert_key)
          else
            acc
          end
        end
      end)

    # 2. Individual Drop Checks
    # For Users (Reception/Professional): Track ID loss consistently
    # For Devices (Totem/TV): Track COUNT loss to avoid refresh spam
    monitor_individual(active_alerts, grouped, previous_presences, :reception, "user")
    |> monitor_individual(grouped, previous_presences, :professional, "user")
    |> monitor_count_drop(grouped, previous_presences, :totems, "Totem")
    |> monitor_count_drop(grouped, previous_presences, :tvs, "TV")
    |> then(fn alerts -> {alerts, grouped} end)
  end

  # Monitor specific IDs leaving (User based)
  defp monitor_individual(active_alerts, current, previous, key, _type_label) do
    cur_list = Map.get(current, key, [])
    prev_list = Map.get(previous, key, [])

    cur_ids = MapSet.new(Enum.map(cur_list, &(&1.id || &1["id"])))
    prev_ids = MapSet.new(Enum.map(prev_list, &(&1.id || &1["id"])))

    # Find IDs that were present but are now gone
    lost_ids = MapSet.difference(prev_ids, cur_ids)

    Enum.reduce(lost_ids, active_alerts, fn id, acc ->
      # Try to find name for better log
      lost_meta = Enum.find(prev_list, fn m -> (m.id || m["id"]) == id end)
      name = lost_meta[:name] || lost_meta["name"] || "ID #{id}"

      create_audit_log(
        "SYSTEM_WARNING_#{String.upcase(to_string(key))}_DISCONNECT",
        "#{name} desconectou-se do sistema.",
        :warning
      )

      # We don't persist "individual" active alerts in the MapSet because they are events, not states
      # Unless we want to track "User X is offline" state.
      # User asked for "Notification" (Alert). Event log is sufficient.
      acc
    end)
  end

  # Monitor count drops (Device based)
  defp monitor_count_drop(active_alerts, current, previous, key, device_label) do
    cur_count = length(Map.get(current, key, []))
    prev_count = length(Map.get(previous, key, []))

    if cur_count < prev_count do
      dropped = prev_count - cur_count

      create_audit_log(
        "SYSTEM_WARNING_#{String.upcase(to_string(key))}_DROP",
        "#{dropped} unidade(s) de #{device_label} desconectada(s) (Total: #{cur_count}).",
        :warning
      )
    end

    active_alerts
  end

  defp group_presences(presences) do
    Enum.reduce(presences, %{tvs: [], totems: [], reception: [], professional: []}, fn {_key,
                                                                                        data},
                                                                                       acc ->
      meta = List.first(data.metas)
      type = Map.get(meta, :type) || Map.get(meta, "type")

      case type do
        "tv" -> Map.update!(acc, :tvs, &[meta | &1])
        "totem" -> Map.update!(acc, :totems, &[meta | &1])
        "reception" -> Map.update!(acc, :reception, &[meta | &1])
        "professional" -> Map.update!(acc, :professional, &[meta | &1])
        _ -> acc
      end
    end)
  end

  defp create_audit_log(action, details_text, severity) do
    StarTickets.Audit.log_action(
      action,
      %{
        resource_type: "System",
        resource_id: "Overseer",
        details: %{message: details_text},
        metadata: %{severity: to_string(severity)},
        user_id: 1
      }
    )
  end
end
