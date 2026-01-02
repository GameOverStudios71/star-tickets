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

  def dismiss_anomaly(idx) do
    GenServer.cast(__MODULE__, {:dismiss_anomaly, idx})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("🔮 Sentinel Overseer is online and watching...")
    PubSub.subscribe(@pubsub, @audit_topic)
    :timer.send_interval(@tick_interval, :tick)

    # State: %{projections: [Projection...], anomalies: [Log...], recent_logs: [Log...]}
    {:ok, %{projections: [], anomalies: [], recent_logs: []}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info({:audit_log_created, log}, state) do
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

  @impl true
  def handle_info(:tick, state) do
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
      {:noreply, state}
    end
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
end
