# Complete seed script: Client, Services, Establishments, TotemMenus, Users
# Usage: mix run priv/repo/seeds.exs

alias StarTickets.Repo
alias StarTickets.Accounts
alias StarTickets.Accounts.{Client, Establishment, Service, TotemMenu, TotemMenuService, User}
alias StarTickets.Forms.{FormTemplate, FormSection, FormField}
import Ecto.Query

IO.puts("=" |> String.duplicate(50))
IO.puts("🌱 Starting complete database seeding...")
IO.puts("=" |> String.duplicate(50))
IO.puts("")

# ============================================
# 1. CREATE CLIENT
# ============================================
IO.puts("🏢 Creating PRO Ocupacional client...")

client =
  %Client{}
  |> Client.changeset(%{
    name: "Pro Ocupacional",
    slug: "proocupacional"
  })
  |> Repo.insert!()

IO.puts("   ✅ Client created: #{client.name} (ID: #{client.id})")
IO.puts("")

# ============================================
# 2. CLEAR EXISTING DATA (for re-seeding)
# ============================================
IO.puts("🗑️  Clearing existing data...")
Repo.delete_all(TotemMenuService)
Repo.delete_all(TotemMenu)
Repo.delete_all(Service)
Repo.delete_all(Establishment)
IO.puts("   ✅ Cleared")
IO.puts("")

# Services from init.js with descriptions
services_data = [
  %{name: "Ultrassom", duration: 15, description: "Exame de ultrassonografia geral"},
  %{
    name: "Mamo / Dens / Raio - X",
    duration: 20,
    description: "Mamografia, Densitometria e Raio-X"
  },
  %{
    name: "Endoscopia / Colono",
    duration: 30,
    description: "Endoscopia digestiva e Colonoscopia"
  },
  %{name: "Tomografia", duration: 20, description: "Tomografia computadorizada"},
  %{
    name: "Exames Cardiológicos",
    duration: 20,
    description: "Eletrocardiograma e exames do coração"
  },
  %{name: "Retirada de Exames", duration: 5, description: "Retirada de resultados de exames"},
  %{name: "Triagem Completa", duration: 30, description: "Triagem médica completa"},
  %{name: "Endoscopia(Gastros)", duration: 25, description: "Endoscopia gástrica"},
  %{name: "Cardiológicos", duration: 20, description: "Exames cardiológicos gerais"},
  %{name: "Ecocardiograma / Eco Fetal", duration: 25, description: "Ecocardiograma e Eco Fetal"},
  %{name: "Recepção", duration: 10, description: "Atendimento na recepção"},
  %{name: "Ecodopplercardiograma", duration: 25, description: "Ecodopplercardiograma colorido"},
  %{
    name: "Endoscopia / Colonoscopia",
    duration: 30,
    description: "Endoscopia e Colonoscopia completa"
  },
  %{name: "Teste Ergométrico", duration: 20, description: "Teste de esforço em esteira"},
  %{name: "Eletroneuro", duration: 25, description: "Eletroneuromiografia"},
  %{name: "Colonoscopia / Vulvoscopia", duration: 30, description: "Colonoscopia e Vulvoscopia"},
  %{name: "Raio X", duration: 10, description: "Radiografia simples"},
  %{name: "Mamografia", duration: 15, description: "Mamografia digital"},
  %{name: "Exames de Imagem", duration: 20, description: "Exames de diagnóstico por imagem"},
  %{name: "Cedusp / Cadi", duration: 15, description: "Centro de diagnóstico"},
  %{name: "Resultado de Exames", duration: 5, description: "Entrega de resultados"},
  %{name: "Exames de Sangue", duration: 10, description: "Coleta de sangue laboratorial"},
  %{name: "Colpo / Vulvo", duration: 20, description: "Colposcopia e Vulvoscopia"},
  %{name: "Mamografia / Raio - X", duration: 20, description: "Mamografia e Raio-X"},
  %{name: "Eletroneuro / Doppler", duration: 25, description: "Eletroneuromiografia e Doppler"},
  %{
    name: "Ecodoppler / Teste Ergométrico",
    duration: 25,
    description: "Ecodoppler e Teste de Esforço"
  },
  %{
    name: "Mamo / Densi / Raio - X",
    duration: 20,
    description: "Mamografia, Densitometria e Raio-X"
  },
  %{name: "Demissional", duration: 15, description: "Exame médico de demissão"},
  %{name: "Admissional", duration: 20, description: "Exame médico de admissão"},
  %{name: "Retorno ao Trabalho", duration: 15, description: "Exame de retorno ao trabalho"},
  %{name: "Mudanças de Função", duration: 15, description: "Exame para mudança de função"},
  %{name: "Periódico", duration: 15, description: "Exame médico periódico"}
]

IO.puts("💉 Creating #{length(services_data)} services...")

Enum.each(services_data, fn data ->
  {:ok, _svc} =
    %Service{}
    |> Service.changeset(Map.put(data, :client_id, client.id))
    |> Repo.insert()
end)

IO.puts("   ✅ Services created")

# Establishments from init.js
establishments_data = [
  %{name: "Freguesia", code: "FREGUESIA"},
  %{name: "Santana", code: "SANTANA"},
  %{name: "Guarulhos Centro", code: "GUARULHOS"},
  %{name: "Guarulhos Taboão", code: "TABOAO"},
  %{name: "Tatuapé", code: "TATUAPE"},
  %{name: "Bela Cintra", code: "BELACINTRA"}
]

IO.puts("🏢 Creating #{length(establishments_data)} establishments...")

establishments =
  Enum.map(establishments_data, fn data ->
    {:ok, est} =
      %Establishment{}
      |> Establishment.changeset(Map.put(data, :client_id, client.id))
      |> Repo.insert()

    IO.puts("   ✅ #{est.name}")
    est
  end)

# Reload services mapping (name -> service)
services = Repo.all(from(s in Service, where: s.client_id == ^client.id))
service_map = Enum.reduce(services, %{}, fn s, acc -> Map.put(acc, s.name, s) end)

IO.puts("📋 Loaded #{length(services)} services for linking")

# Menu structure per establishment from init.js
establishment_services = %{
  "FREGUESIA" => [
    "Exames de Sangue",
    "Ultrassom",
    "Mamo / Dens / Raio - X",
    "Endoscopia / Colono",
    "Tomografia",
    "Exames Cardiológicos"
  ],
  "SANTANA" => [
    "Retirada de Exames",
    "Triagem Completa",
    "Endoscopia(Gastros)",
    "Ultrassom",
    "Mamo / Densi / Raio - X",
    "Cardiológicos",
    "Ecocardiograma / Eco Fetal"
  ],
  "GUARULHOS" => [
    "Recepção",
    "Retirada de Exames",
    "Ecodopplercardiograma",
    "Endoscopia / Colonoscopia",
    "Teste Ergométrico",
    "Eletroneuro",
    "Ultrassom",
    "Exames de Sangue",
    "Colonoscopia / Vulvoscopia"
  ],
  "TABOAO" => ["Exames de Sangue", "Raio X", "Mamografia", "Ultrassom"],
  "TATUAPE" => [
    "Exames de Imagem",
    "Cedusp / Cadi",
    "Resultado de Exames",
    "Ultrassom",
    "Exames de Sangue",
    "Colpo / Vulvo",
    "Exames de Sangue",
    "Mamografia / Raio - X",
    "Endoscopia / Colonoscopia",
    "Eletroneuro",
    "Eletroneuro / Doppler",
    "Ecodoppler / Teste Ergométrico"
  ],
  "BELACINTRA" => ["Ultrassom"]
}

medicina_trabalho_services = [
  "Demissional",
  "Admissional",
  "Retorno ao Trabalho",
  "Mudanças de Função",
  "Periódico"
]

# Service icons map (emoji icons)
service_icons = %{
  "Ultrassom" => "🔊",
  "Mamo / Dens / Raio - X" => "📷",
  "Endoscopia / Colono" => "🔬",
  "Tomografia" => "🖥️",
  "Exames Cardiológicos" => "❤️",
  "Retirada de Exames" => "📋",
  "Triagem Completa" => "📝",
  "Endoscopia(Gastros)" => "🔬",
  "Cardiológicos" => "❤️",
  "Ecocardiograma / Eco Fetal" => "💓",
  "Recepção" => "🏢",
  "Ecodopplercardiograma" => "💓",
  "Endoscopia / Colonoscopia" => "🔬",
  "Teste Ergométrico" => "🏃",
  "Eletroneuro" => "⚡",
  "Colonoscopia / Vulvoscopia" => "🔬",
  "Raio X" => "📷",
  "Mamografia" => "🎀",
  "Exames de Imagem" => "📷",
  "Cedusp / Cadi" => "🏥",
  "Resultado de Exames" => "📄",
  "Exames de Sangue" => "🩸",
  "Colpo / Vulvo" => "🔬",
  "Mamografia / Raio - X" => "📷",
  "Eletroneuro / Doppler" => "⚡",
  "Ecodoppler / Teste Ergométrico" => "💓",
  "Mamo / Densi / Raio - X" => "📷",
  "Demissional" => "👋",
  "Admissional" => "🤝",
  "Retorno ao Trabalho" => "🔙",
  "Mudanças de Função" => "🔄",
  "Periódico" => "📅"
}

# Helper to create menu with optional services and is_taggable
create_menu = fn est_id, name, icon_class, parent_id, position, service_names, is_taggable ->
  attrs = %{
    name: name,
    icon_class: icon_class,
    establishment_id: est_id,
    parent_id: parent_id,
    position: position,
    is_taggable: is_taggable
  }

  {:ok, menu} = Accounts.create_totem_menu(attrs)

  # Link services if specified
  if service_names && length(service_names) > 0 do
    services_data =
      service_names
      # Remove duplicates
      |> Enum.uniq()
      |> Enum.with_index()
      |> Enum.filter(fn {name, _} -> Map.has_key?(service_map, name) end)
      |> Enum.map(fn {name, _idx} ->
        svc = Map.get(service_map, name)
        icon = Map.get(service_icons, name, "📋")
        %{service_id: svc.id, description: nil, icon_class: icon}
      end)

    if length(services_data) > 0 do
      # Preload association before updating
      menu_with_assoc = Repo.preload(menu, :totem_menu_services)
      Accounts.update_totem_menu(menu_with_assoc, %{services_data: services_data})
    end
  end

  menu
end

IO.puts("🌳 Creating menu trees for each establishment...")

Enum.each(establishments, fn est ->
  est_services = Map.get(establishment_services, est.code, [])

  IO.puts("\n📍 #{est.name} (#{length(est_services)} services)...")

  # Root 1: Atendimento Normal (is_taggable=true)
  atend_normal =
    create_menu.(est.id, "👤 Atendimento Normal", "fa-solid fa-user", nil, 0, nil, true)

  # Root 2: Atendimento Preferencial (is_taggable=true)
  atend_pref =
    create_menu.(
      est.id,
      "♿ Atendimento Preferencial",
      "fa-solid fa-wheelchair",
      nil,
      1,
      nil,
      true
    )

  IO.puts("   ✅ Raízes: Atendimento Normal, Atendimento Preferencial")

  # Create sub-structure for Atendimento Normal
  # Level 2: Análises Clínicas
  analises_normal =
    create_menu.(
      est.id,
      "🔬 Análises Clínicas",
      "fa-solid fa-flask",
      atend_normal.id,
      0,
      nil,
      false
    )

  # Level 3: Convênio, Particular, Clínica Parceira (all is_taggable=true)
  _convenio_n =
    create_menu.(
      est.id,
      "💳 Convênio",
      "fa-solid fa-credit-card",
      analises_normal.id,
      0,
      est_services,
      true
    )

  _particular_n =
    create_menu.(
      est.id,
      "💵 Particular",
      "fa-solid fa-money-bill",
      analises_normal.id,
      1,
      est_services,
      true
    )

  _clinica_n =
    create_menu.(
      est.id,
      "🏥 Clínica Parceira",
      "fa-solid fa-hospital",
      analises_normal.id,
      2,
      est_services,
      true
    )

  # Level 2: Medicina do Trabalho (is_taggable=true)
  _med_trab_n =
    create_menu.(
      est.id,
      "💼 Medicina do Trabalho",
      "fa-solid fa-briefcase-medical",
      atend_normal.id,
      1,
      medicina_trabalho_services,
      true
    )

  IO.puts(
    "   ✅ Atendimento Normal → Análises Clínicas (Convênio/Particular/Clínica) + Medicina do Trabalho"
  )

  # Duplicate structure for Atendimento Preferencial
  analises_pref =
    create_menu.(est.id, "🔬 Análises Clínicas", "fa-solid fa-flask", atend_pref.id, 0, nil, false)

  _convenio_p =
    create_menu.(
      est.id,
      "💳 Convênio",
      "fa-solid fa-credit-card",
      analises_pref.id,
      0,
      est_services,
      true
    )

  _particular_p =
    create_menu.(
      est.id,
      "💵 Particular",
      "fa-solid fa-money-bill",
      analises_pref.id,
      1,
      est_services,
      true
    )

  _clinica_p =
    create_menu.(
      est.id,
      "🏥 Clínica Parceira",
      "fa-solid fa-hospital",
      analises_pref.id,
      2,
      est_services,
      true
    )

  _med_trab_p =
    create_menu.(
      est.id,
      "💼 Medicina do Trabalho",
      "fa-solid fa-briefcase-medical",
      atend_pref.id,
      1,
      medicina_trabalho_services,
      true
    )

  IO.puts("   ✅ Atendimento Preferencial → (mesma estrutura duplicada)")
end)

IO.puts("\n✅ TotemMenu seeding completed!")
IO.puts("")

# ============================================
# 5. CREATE USERS
# ============================================
IO.puts("👤 Creating users...")

# Get Freguesia establishment for all users
freguesia = Repo.get_by(Establishment, name: "Freguesia", client_id: client.id)

# Admin user
admin =
  %User{}
  |> Ecto.Changeset.change(%{
    email: "admin@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Administrador",
    username: "admin",
    role: "admin",
    client_id: client.id,
    establishment_id: freguesia && freguesia.id,
    phone_number: "55 11 999999999",
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

IO.puts("   ✅ Admin: admin@proocupacional.com.br (senha: minhasenha123)")

# Reception user
reception_user =
  %User{}
  |> Ecto.Changeset.change(%{
    email: "recepcao@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Recepcionista",
    username: "recepcao",
    role: "reception",
    establishment_id: freguesia && freguesia.id,
    client_id: client.id,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

IO.puts("   ✅ Recepção: recepcao@proocupacional.com.br (senha: minhasenha123)")

# Add specific users for Freguesia
freguesia = Repo.get_by(Establishment, name: "Freguesia", client_id: client.id)

if freguesia do
  # 1. Second Receptionist
  %User{}
  |> Ecto.Changeset.change(%{
    email: "recepcao.freguesia2@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Recepcionista Freguesia 2",
    username: "recep_freg2",
    role: "reception",
    establishment_id: freguesia.id,
    client_id: client.id,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

  IO.puts("   ✅ Recepção 2 (Freguesia): recepcao.freguesia2@proocupacional.com.br")

  # 2. Manager
  %User{}
  |> Ecto.Changeset.change(%{
    email: "gerente.freguesia@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Gerente Freguesia",
    username: "gerente_freg",
    role: "manager",
    establishment_id: freguesia.id,
    client_id: client.id,
    phone_number: "55 11 999999999",
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

  IO.puts("   ✅ Gerente (Freguesia): gerente.freguesia@proocupacional.com.br")

  # 3. Professional 1
  %User{}
  |> Ecto.Changeset.change(%{
    email: "medico1.freguesia@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Dr. Silva (Médico)",
    username: "medico1",
    role: "professional",
    establishment_id: freguesia.id,
    client_id: client.id,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

  IO.puts("   ✅ Profissional 1 (Freguesia): medico1.freguesia@proocupacional.com.br")

  # 4. Professional 2
  %User{}
  |> Ecto.Changeset.change(%{
    email: "medico2.freguesia@proocupacional.com.br",
    hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
    name: "Dra. Santos (Médica)",
    username: "medico2",
    role: "professional",
    establishment_id: freguesia.id,
    client_id: client.id,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

  IO.puts("   ✅ Profissional 2 (Freguesia): medico2.freguesia@proocupacional.com.br")
end

IO.puts("")

# ============================================
# 6. CREATE ROOMS (Salas) FOR EACH ESTABLISHMENT
# ============================================
alias StarTickets.Accounts.Room

IO.puts("🚪 Creating rooms for each establishment...")

# Get all establishments
all_ests = Repo.all(from(e in Establishment, where: e.client_id == ^client.id))

Enum.each(all_ests, fn est ->
  # Create 1 room per establishment (Simplification)
  %Room{}
  |> Room.changeset(%{
    name: "Consultório 1",
    establishment_id: est.id,
    capacity_threshold: 0,
    type: "professional",
    # Enable all services as requested
    all_services: true
  })
  |> Repo.insert!()

  IO.puts("   ✅ #{est.name}: 1 sala (Consultório 1) criada com 'All Services'")
end)

IO.puts("")

# ============================================
# 7. CREATE RECEPTION DESKS (Mesas) AS ROOMS FOR EACH ESTABLISHMENT
# ============================================
alias StarTickets.Accounts.Room

IO.puts("🪑 Creating reception desks (as Rooms) for each establishment...")

Enum.each(all_ests, fn est ->
  # Create 1 desk per establishment
  %Room{}
  |> Room.changeset(%{
    name: "Recepção 1",
    establishment_id: est.id,
    is_active: true,
    type: "reception",
    all_services: false
  })
  |> Repo.insert!()

  IO.puts("   ✅ #{est.name}: 1 mesa (Recepção 1) criada")
end)

IO.puts("")

# ============================================
# 8. CREATE TV FOR EACH ESTABLISHMENT
# ============================================
IO.puts("📺 Creating TV for each establishment...")

Enum.each(all_ests, fn est ->
  # 1. Create TV User
  tv_username = "tv.#{est.code |> String.downcase()}"

  tv_user =
    case StarTickets.Accounts.get_user_by_username(tv_username) do
      nil ->
        %StarTickets.Accounts.User{}
        |> Ecto.Changeset.change(%{
          email: "#{tv_username}@proocupacional.com.br",
          hashed_password: Bcrypt.hash_pwd_salt("minhasenha123"),
          name: "TV #{est.name}",
          username: tv_username,
          role: "tv",
          establishment_id: est.id,
          client_id: client.id,
          confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.insert!()

      user ->
        user
    end

  # 2. Create TV linked to this user
  {:ok, _tv} =
    StarTickets.Accounts.create_tv(%{
      name: "TV Principal",
      establishment_id: est.id,
      all_services: true,
      all_rooms: true,
      user_id: tv_user.id
    })

  IO.puts("   ✅ #{est.name}: TV User (#{tv_username}) e TV criados")
end)

IO.puts("")

IO.puts("=" |> String.duplicate(50))

# ============================================
# 8. CREATE CLINICAL FORMS
# ============================================
IO.puts("📋 Creating Clinical Forms...")

defmodule ClinicalFormSeeder do
  import Ecto.Query
  alias StarTickets.Repo
  alias StarTickets.Forms.{FormTemplate, FormSection, FormField}
  alias StarTickets.Accounts.{Service, Client}

  def run(client_id) do
    create_for_client(client_id)
  end

  defp create_for_client(client_id) do
    # Define the template
    template_data = %{
      name: "Anamnese Ocupacional",
      description: "Formulário de histórico médico e ocupacional",
      client_id: client_id
    }

    # Insert or Get Template
    template =
      case Repo.get_by(FormTemplate, name: template_data.name, client_id: client_id) do
        nil ->
          {:ok, t} =
            %FormTemplate{}
            |> FormTemplate.changeset(template_data)
            |> Repo.insert()

          t

        t ->
          t
      end

    # Link occupational services to this template
    occupational_services = [
      "Admissional",
      "Demissional",
      "Periódico",
      "Retorno ao Trabalho",
      "Mudanças de Função",
      "Medicina do Trabalho"
    ]

    services =
      Repo.all(
        from(s in Service,
          where: s.client_id == ^client_id and s.name in ^occupational_services
        )
      )

    count = length(services)
    IO.puts("   🔗 Linking form to #{count} occupational services...")

    for service <- services do
      service
      |> Ecto.Changeset.change(form_template_id: template.id)
      |> Repo.update()
    end

    # Define Sections and Fields
    json_structure = [
      %{
        id: "historico_ocupacional",
        title: "Histórico Ocupacional",
        fields: [
          %{
            label: "Última empresa trabalhada",
            type: "text",
            name: "ultima_empresa",
            value: "Construtora Lettieri Cordaro Ltda"
          },
          %{label: "Função", type: "text", name: "funcao", value: "Gerente de Suprimentos"},
          %{label: "Tempo na função", type: "text", name: "tempo_funcao", value: "2 anos"},
          %{
            label: "Já recebeu algum benefício da previdência social (INSS)?",
            type: "radio",
            name: "beneficio_inss",
            options: %{
              "items" => [
                %{"label" => "Não", "checked" => true},
                %{"label" => "Sim, por acidente de trabalho", "checked" => false},
                %{"label" => "Sim, por doença ocupacional", "checked" => false},
                %{"label" => "Sim, por outras doenças", "checked" => false}
              ]
            }
          },
          %{
            label: "Houve acidente de trabalho ou doença ocupacional nos últimos 12 meses?",
            type: "radio",
            name: "acidente_recente",
            options: %{
              "items" => [
                %{"label" => "Não", "checked" => true},
                %{"label" => "Sim, mas não nos últimos 12 meses", "checked" => false},
                %{"label" => "Sim, nos últimos 12 meses", "checked" => false}
              ]
            }
          }
        ]
      },
      %{
        id: "historia_patologica_pregressa",
        title: "História patológica pregressa",
        fields: [
          %{
            label: "Você tem histórico de alguma doença infectocontagiosa?",
            type: "checkbox",
            name: "doencas_infectocontagiosas",
            options: %{
              "items" => [
                %{"label" => "Pneumonia", "checked" => false},
                %{"label" => "Tuberculose pulmonar", "checked" => false},
                %{"label" => "Hepatite", "checked" => false},
                %{"label" => "Sarampo, Caxumba, Catapora, Rubéola", "checked" => true},
                %{"label" => "Dengue", "checked" => false},
                %{"label" => "ISTs (HPV, Sífilis, Gonorreia)", "checked" => false},
                %{"label" => "Não mencionada ou outras", "checked" => false}
              ]
            }
          },
          %{
            label: "Você possui dessas doenças?",
            type: "checkbox",
            name: "doencas_gerais",
            note: "Lista unificada removendo a sobreposição das imagens 3 e 4",
            options: %{
              "items" => [
                %{"label" => "Pressão alta", "checked" => false},
                %{"label" => "Diabetes", "checked" => false},
                %{"label" => "Epilepsia (convulsão)", "checked" => false},
                %{"label" => "Depressão", "checked" => false},
                %{"label" => "Ansiedade / Compulsão", "checked" => false},
                %{"label" => "Doença do coração", "checked" => false},
                %{"label" => "Doença da Tireóide", "checked" => false},
                %{"label" => "Rinite alérgica", "checked" => false},
                %{"label" => "Asma / Bronquite", "checked" => false},
                %{"label" => "Sinusite", "checked" => false},
                %{"label" => "Enxaqueca / Cefaleia", "checked" => false},
                %{"label" => "Labirintite", "checked" => false},
                %{"label" => "Gastrite", "checked" => false},
                %{"label" => "Câncer", "checked" => false},
                %{"label" => "Varizes", "checked" => false},
                %{"label" => "Dores nas costas, lombar", "checked" => true},
                %{"label" => "Rinites / Sinusites / Resfriados frequentes", "checked" => false},
                %{"label" => "Hemorróidas", "checked" => false},
                %{"label" => "Insônia / Nervosismos frequentes", "checked" => false},
                %{"label" => "Desmaios", "checked" => false},
                %{"label" => "Doenças de pele", "checked" => false},
                %{"label" => "Infecções, dor ou zumbido nos ouvidos", "checked" => false},
                %{"label" => "Outros", "checked" => false}
              ]
            }
          },
          %{
            label: "Você faz uso de algum medicamento?",
            type: "checkbox",
            name: "uso_medicamento",
            options: %{
              "items" => [
                %{"label" => "Anti-hipertensivos", "checked" => false},
                %{"label" => "Antidepressivos", "checked" => false},
                %{"label" => "Antidiabéticos", "checked" => false},
                %{"label" => "Antilipidêmicos", "checked" => false},
                %{"label" => "Anticoncepcional", "checked" => false},
                %{"label" => "Outros", "checked" => true}
              ]
            }
          },
          %{
            label: "Você já realizou algum procedimento cirúrgico?",
            type: "checkbox",
            name: "procedimento_cirurgico",
            options: %{
              "items" => [
                %{"label" => "Herniorrafia", "checked" => false},
                %{"label" => "Apendicectomia", "checked" => true},
                %{"label" => "Amigdalectomia", "checked" => false},
                %{"label" => "Postectomia", "checked" => false},
                %{"label" => "Cardíaca", "checked" => false},
                %{"label" => "Safenectomia", "checked" => false},
                %{"label" => "Hemorroidectomia", "checked" => false},
                %{"label" => "Colecistectomia", "checked" => false},
                %{"label" => "Correção de disturbios da visão", "checked" => false},
                %{"label" => "Cesária", "checked" => false},
                %{"label" => "Histerectomia", "checked" => false},
                %{"label" => "Laqueadura", "checked" => false},
                %{"label" => "Outros", "checked" => true}
              ]
            }
          }
        ]
      },
      %{
        id: "historico_familiar",
        title: "Histórico Familiar",
        fields: [
          %{
            label: "Selecione as condições presentes no histórico familiar",
            type: "checkbox",
            name: "condicoes_familiares",
            options: %{
              "items" => [
                %{"label" => "Hipertensão arterial", "checked" => false},
                %{"label" => "Diabetes", "checked" => true},
                %{"label" => "Doença do coração (cardiopatia)", "checked" => true},
                %{"label" => "Câncer / Neoplasias", "checked" => true},
                %{"label" => "Doenças psiquiátricas", "checked" => false},
                %{"label" => "Acidente Vascular Cerebral (AVC)", "checked" => false},
                %{"label" => "Doenças da Tireoide", "checked" => false},
                %{"label" => "Colecistopatias", "checked" => false},
                %{"label" => "Alergias/Asma", "checked" => false},
                %{"label" => "Doenças reumáticas", "checked" => false},
                %{"label" => "Epilepsia", "checked" => false},
                %{"label" => "Gota / Ácido úrico", "checked" => false}
              ]
            }
          }
        ]
      },
      %{
        id: "historico_hospitalar_ortopedico",
        title: "Histórico Hospitalar e Ortopédico",
        fields: [
          %{
            label: "Histórico hospitalar",
            type: "checkbox",
            name: "historico_hospitalar",
            options: %{
              "items" => [
                %{"label" => "Já fui internado", "checked" => true},
                %{"label" => "Já doei sangue", "checked" => false},
                %{"label" => "Já fiz transfusão de sangue", "checked" => false}
              ]
            }
          },
          %{
            label: "Histórico ortopédico",
            type: "checkbox",
            name: "historico_ortopedico",
            options: %{
              "items" => [
                %{"label" => "Já sofri fraturas", "checked" => true},
                %{"label" => "Já sofri luxações", "checked" => false},
                %{"label" => "Já tive tendinite", "checked" => false}
              ]
            }
          }
        ]
      },
      %{
        id: "habitos_estilo_vida",
        title: "Hábitos e estilo de vida",
        fields: [
          %{
            label: "Você fuma?",
            type: "radio",
            name: "fuma",
            options: %{
              "items" => [
                %{"label" => "Não, nunca fumei", "checked" => true},
                %{"label" => "Não, eu parei", "checked" => false},
                %{"label" => "Sim", "checked" => false}
              ]
            }
          },
          %{
            label: "Você consome bebidas alcoólicas?",
            type: "radio",
            name: "bebida_alcoolica",
            options: %{
              "items" => [
                %{"label" => "Não", "checked" => false},
                %{"label" => "Sim, consumo eventualmente", "checked" => true},
                %{"label" => "Sim, consumo diariamente", "checked" => false}
              ]
            }
          },
          %{
            label: "Você pratica atividades físicas?",
            type: "radio",
            name: "atividade_fisica",
            options: %{
              "items" => [
                %{"label" => "Não", "checked" => true},
                %{"label" => "Sim, menos de 3 vezes por semana", "checked" => false},
                %{"label" => "Sim, 3 ou mais vezes por semana", "checked" => false}
              ]
            }
          }
        ]
      }
    ]

    # Process Sections
    Enum.with_index(json_structure, 1)
    |> Enum.each(fn {section_data, sec_index} ->
      # Create or Get Section
      section =
        case Repo.get_by(FormSection, title: section_data.title, form_template_id: template.id) do
          nil ->
            %FormSection{}
            |> FormSection.changeset(%{
              title: section_data.title,
              position: sec_index,
              form_template_id: template.id
            })
            |> Repo.insert!()

          s ->
            # Update position if needed
            s |> FormSection.changeset(%{position: sec_index}) |> Repo.update!()
        end

      # Process Fields in this section
      Enum.with_index(section_data.fields, 1)
      |> Enum.each(fn {field_data, field_index} ->
        # We'll check by label in current template. If it exists, update its section.
        existing = Repo.get_by(FormField, form_template_id: template.id, label: field_data.label)

        field_attrs =
          Map.merge(field_data, %{
            form_template_id: template.id,
            form_section_id: section.id,
            position: field_index
          })

        # Remove extra keys not in schema
        field_attrs = Map.drop(field_attrs, [:name, :note, :value, :checked])

        # Transform "checkbox_group" to "checkbox" if needed
        field_attrs =
          if field_attrs.type == "checkbox_group",
            do: Map.put(field_attrs, :type, "checkbox"),
            else: field_attrs

        if existing do
          existing
          |> FormField.changeset(field_attrs)
          |> Repo.update!()
        else
          %FormField{}
          |> FormField.changeset(field_attrs)
          |> Repo.insert!()
        end
      end)
    end)

    IO.puts("   ✅ Form 'Anamnese Ocupacional' created")
  end
end

ClinicalFormSeeder.run(client.id)

IO.puts("=" |> String.duplicate(50))
IO.puts("🎉 Database seeding complete!")
IO.puts("=" |> String.duplicate(50))
