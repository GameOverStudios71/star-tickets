defmodule StarTicketsWeb.ClientRegisterLive do
  use StarTicketsWeb, :live_view

  alias StarTickets.Accounts
  alias StarTickets.Accounts.{Client, User}
  alias StarTickets.Repo

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form:
         to_form(%{
           "company_name" => "",
           "admin_name" => "",
           "admin_email" => "",
           "admin_phone" => "",
           "password" => "",
           "password_confirmation" => ""
         }),
       preview_username: nil,
       error_message: nil,
       success: false,
       created_user: nil
     )}
  end

  def handle_event("validate", %{"_target" => _target} = params, socket) do
    # Generate username preview
    company_name = params["company_name"] || ""
    admin_name = params["admin_name"] || ""

    preview = generate_username_preview(company_name, admin_name)

    {:noreply,
     assign(socket,
       form: to_form(params),
       preview_username: preview
     )}
  end

  def handle_event("register", params, socket) do
    case create_client_with_admin(params) do
      {:ok, %{client: _client, user: user}} ->
        # Send welcome email with confirmation link
        Accounts.deliver_login_instructions(
          user,
          fn token -> url(~p"/users/log-in?token=#{token}") end
        )

        {:noreply,
         assign(socket,
           success: true,
           created_user: user,
           preview_username: user.username
         )}

      {:error, failed_operation, changeset, _changes} ->
        error_msg =
          case failed_operation do
            :client -> "Erro ao criar empresa: #{format_errors(changeset)}"
            :user -> "Erro ao criar usuário: #{format_errors(changeset)}"
            _ -> "Erro inesperado"
          end

        {:noreply, assign(socket, error_message: error_msg, form: to_form(params))}
    end
  end

  defp create_client_with_admin(params) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:client, fn _changes ->
      Client.changeset(%Client{}, %{name: params["company_name"]})
    end)
    |> Ecto.Multi.insert(:user, fn %{client: client} ->
      username = generate_username(client.slug, params["admin_name"])

      %User{}
      |> User.email_changeset(%{email: params["admin_email"]})
      |> User.password_changeset(%{password: params["password"]})
      |> Ecto.Changeset.put_change(:name, params["admin_name"])
      |> Ecto.Changeset.put_change(:username, username)
      |> Ecto.Changeset.put_change(:phone_number, params["admin_phone"])
      |> Ecto.Changeset.put_change(:role, "admin")
      |> Ecto.Changeset.put_change(:client_id, client.id)

      # Não confirmar automaticamente - precisa do email
    end)
    |> Repo.transaction()
  end

  defp generate_username(client_slug, admin_name) do
    admin_slug = normalize_text(admin_name)
    "#{client_slug}.#{admin_slug}"
  end

  defp generate_username_preview(company_name, admin_name) do
    if String.trim(company_name) != "" and String.trim(admin_name) != "" do
      slug = normalize_text(company_name)
      admin_slug = normalize_text(admin_name)
      "#{slug}.#{admin_slug}"
    else
      nil
    end
  end

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^a-z0-9]/, "")
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  def render(assigns) do
    ~H"""
    <div class="st-app has-background min-h-screen flex items-center justify-center">
      <%!-- Header --%>
      <header class="st-app-header">
        <div class="st-header-left">
          <.link navigate={~p"/"} class="st-home-btn">🏠</.link>
          <h1>Cadastro de Empresa</h1>
        </div>
      </header>

      <%= if @success do %>
        <%!-- Success Message - Check Email --%>
        <div class="st-login-container st-animate-slide-up text-center">
          <div class="text-6xl mb-4">📧</div>
          <h1 class="text-2xl font-bold text-white mb-4">Cadastro Realizado!</h1>
          <p class="text-white/80 mb-6">
            Sua empresa foi cadastrada com sucesso!<br /> Enviamos um email de confirmação para:
          </p>

          <div class="st-card st-acrylic-light mb-4">
            <p class="text-lg font-bold text-white">{@created_user.email}</p>
          </div>

          <div class="st-card st-acrylic mb-6">
            <p class="text-sm text-white/70 mb-2">Seu login será:</p>
            <p class="text-xl font-mono font-bold text-white">{@preview_username}</p>
          </div>

          <div class="bg-amber-500/20 border border-amber-500/50 text-amber-200 p-4 rounded-lg mb-6">
            <p class="font-semibold mb-2">⚠️ Atenção</p>
            <p class="text-sm">
              Clique no link enviado para seu email para ativar sua conta e fazer login.
            </p>
          </div>

          <p class="text-white/60 text-sm mb-4">
            Não recebeu o email? Verifique sua caixa de spam ou
          </p>

          <.link navigate={~p"/users/log-in"} class="st-btn st-btn-acrylic w-full">
            Ir para Login
          </.link>

          <p :if={dev_mode?()} class="text-center text-white/50 mt-4 text-xs">
            <.link href="/dev/mailbox" class="underline">📬 Ver emails (modo dev)</.link>
          </p>
        </div>
      <% else %>
        <%!-- Register Form --%>
        <div class="st-login-container st-animate-fade-in" style="margin-top: 100px;">
          <h1 class="text-2xl font-bold text-center">🎫 Cadastrar Empresa</h1>

          <%= if @error_message do %>
            <div class="bg-red-500/20 border border-red-500/50 text-red-200 p-3 rounded-lg mb-4">
              {@error_message}
            </div>
          <% end %>

          <.form
            for={@form}
            phx-change="validate"
            phx-submit="register"
            class="space-y-4"
            autocomplete="off"
          >
            <div class="st-form-group">
              <label>Nome da Empresa</label>
              <input
                type="text"
                name="company_name"
                value={@form.source["company_name"]}
                class="st-input"
                placeholder="Ex: Minha Empresa"
                required
                autocomplete="off"
              />
            </div>

            <hr class="border-white/20 my-6" />

            <h3 class="text-lg font-semibold text-white mb-4">Dados do Administrador</h3>

            <div class="st-form-group">
              <label>Nome Completo</label>
              <input
                type="text"
                name="admin_name"
                value={@form.source["admin_name"]}
                class="st-input"
                placeholder="Seu nome"
                required
                autocomplete="off"
              />
            </div>

            <div class="st-form-group">
              <label>E-mail</label>
              <input
                type="email"
                name="admin_email"
                value={@form.source["admin_email"]}
                class="st-input"
                placeholder="seu@email.com"
                required
                autocomplete="off"
              />
            </div>

            <div class="st-form-group">
              <label>WhatsApp / Celular</label>
              <input
                type="tel"
                name="admin_phone"
                value={@form.source["admin_phone"]}
                class="st-input"
                placeholder="+55 (11) 99999-9999"
                required
                autocomplete="tel"
                phx-hook="PhoneMask"
                id="admin_phone_input"
              />
              <p class="text-xs text-amber-200/80 mt-1">
                ⚠️ Este será o Administrador do sistema. Erros críticos e debug serão enviados para este número via WhatsApp.
              </p>
            </div>

            <div class="st-form-group">
              <label>Senha (mínimo 12 caracteres)</label>
              <input
                type="password"
                name="password"
                value={@form.source["password"]}
                class="st-input"
                placeholder="••••••••••••"
                required
                minlength="12"
                autocomplete="new-password"
              />
            </div>

            <div class="st-form-group">
              <label>Confirmar Senha</label>
              <input
                type="password"
                name="password_confirmation"
                value={@form.source["password_confirmation"]}
                class="st-input"
                placeholder="••••••••••••"
                required
                autocomplete="new-password"
              />
            </div>

            <%= if @preview_username do %>
              <div class="st-card st-acrylic-light p-3">
                <p class="text-sm text-white/70">Seu username será:</p>
                <p class="text-lg font-mono font-bold text-white">{@preview_username}</p>
              </div>
            <% end %>

            <button
              id="register-submit-btn"
              type="submit"
              class="st-btn st-btn-large w-full"
              phx-disable-with="🔄 Criando conta..."
              phx-hook="DebounceSubmit"
            >
              🚀 Criar Minha Conta
            </button>
          </.form>

          <p class="text-center text-white/60 mt-4">
            Já tem conta?
            <.link navigate={~p"/users/log-in"} class="text-white underline">Fazer login</.link>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp dev_mode? do
    Application.get_env(:star_tickets, :dev_routes, false)
  end
end
