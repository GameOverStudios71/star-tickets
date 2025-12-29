alias StarTickets.Repo
alias StarTickets.Forms.FormTemplate
alias StarTickets.Forms.FormSection
alias StarTickets.Forms.FormField
alias StarTickets.Accounts.Service
alias StarTickets.Accounts.Client

defmodule ClinicalFormSeeder do
  import Ecto.Query

  def run do
    # 0. Ensure a client exists
    client = Repo.one(from(c in Client, limit: 1))

    client =
      if client do
        client
      else
        IO.puts("⚠️ No client found. Creating 'Empresa Demo'...")

        {:ok, c} =
          %Client{}
          |> Ecto.Changeset.change(name: "Empresa Demo", slug: "demo")
          |> Repo.insert()

        c
      end

    # 1. Find or Create "Medicina do Trabalho" service
    service = Repo.get_by(Service, name: "Medicina do Trabalho", client_id: client.id)

    service =
      if service do
        service
      else
        IO.puts("⚠️ Service 'Medicina do Trabalho' not found. Creating it...")

        {:ok, s} =
          %Service{}
          |> Ecto.Changeset.change(
            name: "Medicina do Trabalho",
            description: "Exames admissionais, demissionais e periódicos",
            duration: 30,
            client_id: client.id
          )
          |> Repo.insert()

        s
      end

    create_for_client(client.id)
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

    # Link services to this template
    services =
      Repo.all(
        from(s in Service,
          where: s.client_id == ^client_id and ilike(s.name, "%Medicina do Trabalho%")
        )
      )

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
        # Check if field exists globaly in template? Or specifically in this section?
        # Best to check by label within template to migrate existing ones if they exist?
        # Or just check within section.

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

    IO.puts("✅ Created/Updated form 'Anamnese Ocupacional' with sections for client #{client_id}")
  end
end

ClinicalFormSeeder.run()
