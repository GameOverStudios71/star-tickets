defmodule StarTickets.Accounts.UserNotifier do
  import Swoosh.Email

  alias StarTickets.Mailer
  alias StarTickets.Accounts.User

  @doc """
  Verifica se o módulo de email está habilitado.
  Controlado pela variável de ambiente ENABLE_EMAIL_NOTIFICATIONS ou config.
  """
  def email_enabled? do
    Application.get_env(:star_tickets, :email_notifications_enabled, true)
  end

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    if email_enabled?() do
      from_name = Application.get_env(:star_tickets, :email_from_name, "Star Tickets")

      from_email =
        Application.get_env(:star_tickets, :email_from_address, "noreply@startickets.com")

      email =
        new()
        |> to(recipient)
        |> from({from_name, from_email})
        |> subject(subject)
        |> text_body(body)

      with {:ok, _metadata} <- Mailer.deliver(email) do
        {:ok, email}
      end
    else
      {:ok, :email_disabled}
    end
  end

  @doc """
  Entrega email de boas-vindas e confirmação para novo cliente cadastrado.
  """
  def deliver_welcome_instructions(user, url) do
    deliver(user.email, "🎫 Bem-vindo ao Star Tickets! Confirme sua conta", """
    ==============================
     STAR TICKETS - Sistema de Gestão de Senhas
    ==============================

    Olá #{user.name || user.email}!

    Sua conta foi criada com sucesso! 🎉

    Dados do seu cadastro:
    • Nome: #{user.name}
    • Username: #{user.username}
    • Email: #{user.email}

    Para ativar sua conta, clique no link abaixo:

    #{url}

    Este link é válido por 7 dias.

    Se você não criou esta conta, ignore este email.

    ==============================
    Atenciosamente,
    Equipe Star Tickets
    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "🎫 Star Tickets - Atualização de Email", """
    ==============================
     STAR TICKETS - Atualização de Email
    ==============================

    Olá #{user.name || user.email},

    Você solicitou a alteração do seu email. Clique no link abaixo para confirmar:

    #{url}

    Se você não solicitou esta alteração, ignore este email.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "🎫 Star Tickets - Link de Acesso", """
    ==============================
     STAR TICKETS - Login
    ==============================

    Olá #{user.name || user.email},

    Clique no link abaixo para acessar sua conta:

    #{url}

    Este link expira em 10 minutos.

    Se você não solicitou este email, ignore-o.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "🎫 Star Tickets - Confirme sua Conta", """
    ==============================
     STAR TICKETS - Confirmação de Conta
    ==============================

    Olá #{user.name || user.email},

    Para confirmar sua conta, clique no link abaixo:

    #{url}

    Se você não criou uma conta conosco, ignore este email.

    ==============================
    """)
  end
end
