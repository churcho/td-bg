defmodule TrueBGWeb.BusinessConceptController do
  use TrueBGWeb, :controller

  alias TrueBG.BusinessConcepts
  alias TrueBG.BusinessConcepts.BusinessConcept
  alias TrueBG.Taxonomies.DataDomain
  alias Ecto.UUID
  alias TrueBGWeb.ErrorView

  alias Poison, as: JSON

  plug :load_canary_action, phoenix_action: :create, canary_action: :create_business_concept
  plug :load_and_authorize_resource, model: DataDomain, id_name: "data_domain_id", persisted: true, only: :create_business_concept

  plug :load_and_authorize_resource, model: BusinessConcept, only: [:update]

  action_fallback TrueBGWeb.FallbackController

  def index(conn, _params) do
    business_concepts = BusinessConcepts.list_business_concepts()
    render(conn, "index.json", business_concepts: business_concepts)
  end

  def index_children_business_concept(conn, %{"id" => id}) do
    business_concepts = BusinessConcepts.list_children_business_concept(id)
    render(conn, "index.json", business_concepts: business_concepts)
  end

  def create(conn, %{"business_concept" => business_concept_params}) do

    concept_type = Map.get(business_concept_params, "type")
    content_schema = get_content_schema(concept_type)

    concept_name = Map.get(business_concept_params, "name")

    creation_attrs = business_concept_params
      |> Map.put("data_domain_id", conn.assigns.data_domain.id)
      |> Map.put("content_schema", content_schema)
      |> Map.put("modifier", conn.assigns.current_user.id)
      |> Map.put("last_change", DateTime.utc_now())
      |> Map.put("version_group_id", UUID.generate)
      |> Map.put("version", 1)

    with {:ok, 0} <- count_business_concepts(concept_type, concept_name),
         {:ok, %BusinessConcept{} = business_concept} <-
          BusinessConcepts.create_business_concept(creation_attrs) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", business_concept_path(conn, :show, business_concept))
      |> render("show.json", business_concept: business_concept)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  def show(conn, %{"id" => id}) do
    business_concept = BusinessConcepts.get_business_concept!(id)
    render(conn, "show.json", business_concept: business_concept)
  end

  def update(conn, %{"id" => id, "business_concept" => business_concept_params}) do
    business_concept = BusinessConcepts.get_business_concept!(id)
    status_draft = BusinessConcept.status.draft
    status_published = BusinessConcept.status.published
    case business_concept.status do
      ^status_draft ->
        update_draft(conn, business_concept, business_concept_params)
      ^status_published ->
        update_published(conn, business_concept, business_concept_params)
    end

  end

  def delete(conn, %{"id" => id}) do
    business_concept = BusinessConcepts.get_business_concept!(id)
    with {:ok, %BusinessConcept{}} <-
        BusinessConcepts.delete_business_concept(business_concept) do
      send_resp(conn, :no_content, "")
    end
  end

  defp update_draft(conn, business_concept, business_concept_params) do
    concept_type = business_concept.type
    concept_name = Map.get(business_concept_params, "name")
    content_schema = get_content_schema(concept_type)

    business_concept_params = business_concept_params
      |> Map.put("content_schema", content_schema)
      |> Map.put("modifier", conn.assigns.current_user.id)
      |> Map.put("last_change", DateTime.utc_now())

    count = if concept_name == business_concept.name, do: 1, else: 0
    with {:ok, ^count} <- count_business_concepts(concept_type, concept_name),
         {:ok, %BusinessConcept{} = business_concept} <-
      BusinessConcepts.update_business_concept(business_concept,
                                                    business_concept_params) do
      render(conn, "show.json", business_concept: business_concept)
    else
      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(ErrorView, :"422.json")
    end
  end

  defp update_published(conn, business_concept, business_concept_params)  do
    content_schema = get_content_schema(business_concept.type)
    draft_attrs = Map.from_struct(business_concept)
    draft_attrs = draft_attrs
    |> Map.merge(business_concept_params)
    |> Map.put("content_schema", content_schema)
    |> Map.put("modifier", conn.assigns.current_user.id)
    |> Map.put("last_change", DateTime.utc_now())
    |> Map.put("mod_comments", business_concept_params["mod_comments"])
    |> Map.put("version_group_id", business_concept.version_group_id)
    |> Map.put("version", business_concept.version + 1)

    with {:ok, %BusinessConcept{} = draft} <-
          BusinessConcepts.create_business_concept(draft_attrs) do
      render(conn, "show.json", business_concept: draft)
    end
  end

  defp get_content_schema(content_type) do
    filename = Application.get_env(:trueBG, :bc_schema_location)
    filename
      |> File.read!
      |> JSON.decode!
      |> Map.get(content_type)
  end

  defp count_business_concepts(type, name) do
    BusinessConcepts.count_business_concepts(type, name,
                                      [BusinessConcept.status.draft,
                                       BusinessConcept.status.published])
  end
end
