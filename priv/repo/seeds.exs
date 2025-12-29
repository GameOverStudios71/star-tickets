# Complete seed script: Client, Services, Establishments, TotemMenus, Users
# Usage: mix run priv/repo/seeds.exs

alias StarTickets.Repo
alias StarTickets.Accounts
alias StarTickets.Accounts.{Client, Establishment, Service, TotemMenu, TotemMenuService, User}
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

# Get first establishment for reception user
first_est =
  Repo.one(from(e in Establishment, where: e.client_id == ^client.id, order_by: e.id, limit: 1))

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
    establishment_id: first_est.id,
    client_id: client.id,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  })
  |> Repo.insert!()

IO.puts("   ✅ Recepção: recepcao@proocupacional.com.br (senha: minhasenha123)")
IO.puts("")

# ============================================
# 6. CREATE ROOMS (Salas) FOR EACH ESTABLISHMENT
# ============================================
alias StarTickets.Accounts.Room

IO.puts("🚪 Creating rooms for each establishment...")

# Get all establishments
all_ests = Repo.all(from(e in Establishment, where: e.client_id == ^client.id))

Enum.each(all_ests, fn est ->
  # Create 4 rooms per establishment
  Enum.each(1..4, fn n ->
    %Room{}
    |> Room.changeset(%{
      name: "Sala #{n}",
      establishment_id: est.id,
      capacity_threshold: 0
    })
    |> Repo.insert!()
  end)

  IO.puts("   ✅ #{est.name}: 4 salas criadas")
end)

IO.puts("")

# ============================================
# 7. CREATE RECEPTION DESKS (Mesas) FOR EACH ESTABLISHMENT
# ============================================
alias StarTickets.Reception.ReceptionDesk

IO.puts("🪑 Creating reception desks for each establishment...")

Enum.each(all_ests, fn est ->
  # Create 4 desks per establishment
  Enum.each(1..4, fn n ->
    %ReceptionDesk{}
    |> ReceptionDesk.changeset(%{
      name: "Mesa #{n}",
      establishment_id: est.id,
      is_active: true
    })
    |> Repo.insert!()
  end)

  IO.puts("   ✅ #{est.name}: 4 mesas criadas")
end)

IO.puts("")

IO.puts("=" |> String.duplicate(50))
IO.puts("🎉 Database seeding complete!")
IO.puts("=" |> String.duplicate(50))
