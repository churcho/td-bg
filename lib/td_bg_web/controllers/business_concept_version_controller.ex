defmodule TdBgWeb.BusinessConceptVersionController do
  use TdBgWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias Jason, as: JSON
  alias TdBg.BusinessConcept.BulkUpdate
  alias TdBg.BusinessConcept.Download
  alias TdBg.BusinessConcept.Search
  alias TdBg.BusinessConcept.Upload
  alias TdBg.BusinessConcepts
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptVersion
  alias TdBg.BusinessConcepts.Events
  alias TdBg.BusinessConcepts.Links
  alias TdBg.Taxonomies
  alias TdBgWeb.BusinessConceptSupport
  alias TdBgWeb.ErrorView
  alias TdBgWeb.SwaggerDefinitions
  alias TdCache.TemplateCache
  alias TdDfLib.Format

  require Logger

  action_fallback(TdBgWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.business_concept_version_definitions()
  end

  swagger_path :index do
    description("Business Concept Versions")

    parameters do
      search(
        :body,
        Schema.ref(:BusinessConceptVersionFilterRequest),
        "Search query and filter parameters"
      )
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionsResponse))
  end

  def index(conn, params) do
    user = conn.assigns[:current_user]

    params
    |> Search.search_business_concept_versions(user)
    |> render_search_results(conn)
  end

  swagger_path :search do
    description("Business Concept Versions")

    parameters do
      search(
        :body,
        Schema.ref(:BusinessConceptVersionFilterRequest),
        "Search query and filter parameters"
      )
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionsResponse))
  end

  def search(conn, params) do
    user = conn.assigns[:current_user]
    page = params |> Map.get("page", 0)
    size = params |> Map.get("size", 50)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_business_concept_versions(user, page, size)
    |> render_search_results(conn)
  end

  defp render_search_results(%{results: business_concept_versions, total: total}, conn) do
    hypermedia =
      collection_hypermedia(
        "business_concept_version",
        conn,
        business_concept_versions,
        BusinessConceptVersion
      )

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render(
      "list.json",
      business_concept_versions: business_concept_versions,
      hypermedia: hypermedia
    )
  end

  def csv(conn, params) do
    user = conn.assigns[:current_user]

    header_labels =
      params
      |> Map.get("header_labels", %{})

    params =
      params
      |> Map.drop(["header_labels"])

    %{results: business_concept_versions} =
      Search.search_business_concept_versions(params, user, 0, 10_000)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"concepts.zip\"")
    |> send_resp(200, Download.to_csv(business_concept_versions, header_labels))
  end

  def upload(conn, params) do
    user = conn.assigns[:current_user]
    business_concepts_upload = Map.get(params, "business_concepts")

    with true <- user.is_admin,
         {:ok, response} <- Upload.from_csv(business_concepts_upload, user) do
      body = JSON.encode!(%{data: %{message: response}})
      send_resp(conn, 200, body)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, error} ->
        Logger.error("While uploading business concepts... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> send_resp(422, JSON.encode!(error))

      error ->
        Logger.error("While uploading business concepts... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  rescue
    e in RuntimeError ->
      Logger.error("While uploading business concepts... #{e.message}")
      send_resp(conn, :unprocessable_entity, JSON.encode!(%{error: e.message}))
  end

  swagger_path :create do
    description("Creates a Business Concept version child of Data Domain")
    produces("application/json")

    parameters do
      business_concept(
        :body,
        Schema.ref(:BusinessConceptVersionCreate),
        "Business Concept create attrs"
      )
    end

    response(201, "Created", Schema.ref(:BusinessConceptVersionResponse))
    response(400, "Client Error")
  end

  defp get_flat_template_content(%{content: content}) do
    Format.flatten_content_fields(content)
  end

  defp get_flat_template_content(_), do: []

  def create(conn, %{"business_concept_version" => business_concept_params}) do
    user = conn.assigns[:current_user]

    # validate fields that if not present are throwing internal server errors in bc creation
    validate_required_bc_fields(business_concept_params)

    concept_type = Map.get(business_concept_params, "type")
    template = TemplateCache.get_by_name!(concept_type)
    content_schema = get_flat_template_content(template)
    concept_name = Map.get(business_concept_params, "name")

    domain_id = Map.get(business_concept_params, "domain_id")
    domain = Taxonomies.get_domain!(domain_id)

    business_concept_attrs =
      %{}
      |> Map.put("domain_id", domain_id)
      |> Map.put("type", concept_type)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    creation_attrs =
      business_concept_params
      |> Map.put("business_concept", business_concept_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.update("related_to", [], & &1)
      |> Map.put("last_change_by", conn.assigns.current_user.id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", BusinessConcept.status().draft)
      |> Map.put("version", 1)

    related_to = Map.get(creation_attrs, "related_to")

    with true <- can?(user, create_business_concept(domain)),
         {:name_available} <-
           BusinessConcepts.check_business_concept_name_availability(concept_type, concept_name),
         {:valid_related_to} <- check_valid_related_to(concept_type, related_to),
         {:ok, %BusinessConceptVersion{} = version} <-
           BusinessConcepts.create_business_concept_and_index(creation_attrs) do
      Events.business_concept_created(version)

      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.business_concept_version_path(conn, :show, version.id)
      )
      |> render("show.json", business_concept_version: version, template: template)
    else
      error ->
        BusinessConceptSupport.handle_bc_errors(conn, error)
    end
  rescue
    validation_error in ValidationError ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: %{"#{validation_error.field}": [validation_error.error]}})
  end

  defp validate_required_bc_fields(attrs) do
    if not Map.has_key?(attrs, "content") do
      raise ValidationError, field: "content", error: "blank"
    end

    if not Map.has_key?(attrs, "type") do
      raise ValidationError, field: "type", error: "blank"
    end
  end

  defp check_valid_related_to(_type, []), do: {:valid_related_to}

  defp check_valid_related_to(type, ids) do
    input_count = length(ids)
    actual_count = BusinessConcepts.count_published_business_concepts(type, ids)
    if input_count == actual_count, do: {:valid_related_to}, else: {:not_valid_related_to}
  end

  swagger_path :versions do
    description("List Business Concept Versions")

    parameters do
      business_concept_version_id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionsResponse))
  end

  def versions(conn, %{"business_concept_version_id" => business_concept_version_id}) do
    user = conn.assigns[:current_user]

    business_concept_version =
      BusinessConcepts.get_business_concept_version!(business_concept_version_id)

    case Search.list_business_concept_versions(business_concept_version.business_concept_id, user) do
      %{results: business_concept_versions} ->
        render(
          conn,
          "versions.json",
          business_concept_versions: business_concept_versions,
          hypermedia: hypermedia("business_concept_version", conn, business_concept_versions)
        )

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :show do
    description("Show Business Concept Version")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)

    if can?(user, view_business_concept(business_concept_version)) do
      template = BusinessConcepts.get_template(business_concept_version)

      business_concept_version =
        business_concept_version
        |> add_completeness()
        |> add_counts()

      links = Links.get_links(business_concept_version)

      render(
        conn,
        "show.json",
        business_concept_version: business_concept_version,
        links: links,
        links_hypermedia: links_hypermedia(conn, links, business_concept_version),
        hypermedia: hypermedia("business_concept_version", conn, business_concept_version),
        template: template
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(ErrorView)
      |> render("403.json")
    end
  end

  defp add_counts(%BusinessConceptVersion{} = business_concept_version) do
    counts = BusinessConcepts.get_concept_counts(business_concept_version.business_concept_id)
    Map.merge(business_concept_version, counts)
  end

  defp links_hypermedia(conn, links, business_concept_version) do
    collection_hypermedia(
      "business_concept_version_business_concept_link",
      conn,
      Enum.map(links, &annotate(&1, business_concept_version)),
      Link
    )
  end

  defp annotate(link, %BusinessConceptVersion{
         id: business_concept_version_id,
         business_concept: %{domain_id: domain_id}
       }) do
    link
    |> Map.put(:business_concept_version_id, business_concept_version_id)
    |> Map.put(:domain_id, domain_id)
    |> Map.put(:hint, :link)
  end

  swagger_path :delete do
    description("Delete a business concept version")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(204, "No Content")
    response(400, "Client Error")
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)

    with true <- can?(user, delete(business_concept_version)),
         {:ok, %BusinessConceptVersion{}} <-
           BusinessConcepts.delete_business_concept_version(business_concept_version) do
      Events.business_concept_deleted(business_concept_version, user.id)
      send_resp(conn, :no_content, "")
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :send_for_approval do
    description("Submit a draft business concept for approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def send_for_approval(conn, %{"business_concept_version_id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    draft = BusinessConcept.status().draft

    case {business_concept_version.status, business_concept_version.current} do
      {^draft, true} ->
        send_for_approval(conn, user, business_concept_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :publish do
    description("Publish a business concept which is pending approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def publish(conn, %{"business_concept_version_id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    pending_approval = BusinessConcept.status().pending_approval

    case {business_concept_version.status, business_concept_version.current} do
      {^pending_approval, true} ->
        publish(conn, user, business_concept_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :reject do
    description("Reject a business concept which is pending approval")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
      reject_reason(:body, :string, "Rejection reason")
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def reject(conn, %{"business_concept_version_id" => id} = params) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    pending_approval = BusinessConcept.status().pending_approval

    case {business_concept_version.status, business_concept_version.current} do
      {^pending_approval, true} ->
        reject(conn, user, business_concept_version, Map.get(params, "reject_reason"))

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :undo_rejection do
    description("Create a draft from a rejected business concept")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def undo_rejection(conn, %{"business_concept_version_id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    rejected = BusinessConcept.status().rejected

    case {business_concept_version.status, business_concept_version.current} do
      {^rejected, true} ->
        undo_rejection(conn, user, business_concept_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :version do
    description("Create a new draft from a published business concept")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def version(conn, %{"business_concept_version_id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    published = BusinessConcept.status().published

    case {business_concept_version.status, business_concept_version.current} do
      {^published, true} ->
        do_version(conn, user, business_concept_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  swagger_path :deprecate do
    description("Deprecate a published business concept")
    produces("application/json")

    parameters do
      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Business concept invalid state")
  end

  def deprecate(conn, %{"business_concept_version_id" => id}) do
    user = conn.assigns[:current_user]
    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    published = BusinessConcept.status().published

    case {business_concept_version.status, business_concept_version.current} do
      {^published, true} ->
        deprecate(conn, user, business_concept_version)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp add_completeness(business_concept_version) do
    case BusinessConcepts.get_completeness(business_concept_version) do
      c -> Map.put(business_concept_version, :completeness, c)
    end
  end

  defp send_for_approval(conn, user, business_concept_version) do
    update_status(
      conn,
      business_concept_version,
      BusinessConcept.status().pending_approval,
      &Events.business_concept_submitted/1,
      can?(user, send_for_approval(business_concept_version))
    )
  end

  defp undo_rejection(conn, user, business_concept_version) do
    update_status(
      conn,
      business_concept_version,
      BusinessConcept.status().draft,
      &Events.business_concept_redrafted/1,
      can?(user, undo_rejection(business_concept_version))
    )
  end

  defp deprecate(conn, user, business_concept_version) do
    update_status(
      conn,
      business_concept_version,
      BusinessConcept.status().deprecated,
      &Events.business_concept_deprecated/1,
      can?(user, deprecate(business_concept_version))
    )
  end

  defp publish(conn, user, business_concept_version) do
    with true <- can?(user, publish(business_concept_version)),
         {:ok, %{published: %BusinessConceptVersion{} = concept}} <-
           BusinessConcepts.publish_business_concept_version(business_concept_version, user) do
      Events.business_concept_published(concept)
      render_concept(conn, concept)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp reject(conn, user, business_concept_version, reason) do
    attrs = %{reject_reason: reason}

    with true <- can?(user, reject(business_concept_version)),
         {:ok, %BusinessConceptVersion{} = version} <-
           BusinessConcepts.reject_business_concept_version(business_concept_version, attrs) do
      Events.business_concept_rejected(version)
      render_concept(conn, version)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp update_status(conn, business_concept_version, status, audit_fn, authorized) do
    attrs = %{status: status}

    with true <- authorized,
         {:ok, %BusinessConceptVersion{} = concept} <-
           BusinessConcepts.update_business_concept_version_status(
             business_concept_version,
             attrs
           ) do
      audit_fn.(concept)
      render_concept(conn, concept)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp do_version(conn, user, business_concept_version) do
    with true <- can?(user, version(business_concept_version)),
         {:ok, %{current: %BusinessConceptVersion{} = new_version}} <-
           BusinessConcepts.version_business_concept(user, business_concept_version) do
      conn = put_status(conn, :created)
      Events.business_concept_versioned(new_version)
      render_concept(conn, new_version)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      _error ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp render_concept(conn, concept) do
    template = BusinessConcepts.get_template(concept)

    business_concept_version =
      concept
      |> add_completeness()

    render(
      conn,
      "show.json",
      business_concept_version: business_concept_version,
      hypermedia: hypermedia("business_concept_version", conn, business_concept_version),
      template: template
    )
  end

  swagger_path :update do
    description("Updates Business Concept Version")
    produces("application/json")

    parameters do
      business_concept_version(
        :body,
        Schema.ref(:BusinessConceptVersionUpdate),
        "Business Concept Version update attrs"
      )

      id(:path, :integer, "Business Concept Version ID", required: true)
    end

    response(200, "OK", Schema.ref(:BusinessConceptVersionResponse))
    response(400, "Client Error")
  end

  def update(conn, %{"id" => id, "business_concept_version" => business_concept_version_params}) do
    user = conn.assigns[:current_user]

    business_concept_version = BusinessConcepts.get_business_concept_version!(id)
    concept_name = Map.get(business_concept_version_params, "name")
    template = BusinessConcepts.get_template(business_concept_version)
    content_schema = get_flat_template_content(template)

    business_concept_attrs =
      %{}
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    update_params =
      business_concept_version_params
      |> Map.put("business_concept", business_concept_attrs)
      |> Map.put("content_schema", content_schema)
      |> Map.update("content", %{}, & &1)
      |> Map.update("related_to", [], & &1)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    related_to = Map.get(update_params, "related_to")

    with true <- can?(user, update(business_concept_version)),
         {:name_available} <-
           BusinessConcepts.check_business_concept_name_availability(
             template.name,
             concept_name,
             business_concept_version.business_concept.id
           ),
         {:valid_related_to} <-
           BusinessConcepts.check_valid_related_to(template.name, related_to),
         {:ok, %BusinessConceptVersion{} = concept_version} <-
           BusinessConcepts.update_business_concept_version(
             business_concept_version,
             update_params
           ) do
      Events.business_concept_updated(business_concept_version, concept_version)

      render(
        conn,
        "show.json",
        business_concept_version: concept_version,
        hypermedia: hypermedia("business_concept_version", conn, concept_version),
        template: template
      )
    else
      error ->
        BusinessConceptSupport.handle_bc_errors(conn, error)
    end
  end

  swagger_path :bulk_update do
    description("Bulk Update of Business Concept Versions")
    produces("application/json")

    parameters do
      bulk_update_request(
        :body,
        Schema.ref(:BulkUpdateRequest),
        "Search query filter parameters and update attributes"
      )
    end

    response(200, "OK", Schema.ref(:BulkUpdateResponse))
    response(403, "User is not authorized to perform this action")
    response(422, "Error while bulk update")
  end

  def bulk_update(conn, %{
        "update_attributes" => update_attributes,
        "search_params" => search_params
      }) do
    user = conn.assigns[:current_user]

    with true <- user.is_admin,
         %{results: results} <- search_all_business_concept_versions(user, search_params),
         {:ok, response} <- BulkUpdate.update_all(user, results, update_attributes) do
      body = JSON.encode!(%{data: %{message: response}})

      conn
      |> put_resp_content_type("application/json", "utf-8")
      |> send_resp(200, body)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, error} ->
        Logger.info("While updating business concepts... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_resp_content_type("application/json", "utf-8")
        |> send_resp(422, JSON.encode!(%{error: error}))

      error ->
        Logger.info("Unexpected error while updating business concepts... #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> put_view(ErrorView)
        |> render("422.json")
    end
  end

  defp search_all_business_concept_versions(user, params) do
    params
    |> Map.drop(["page", "size"])
    |> Search.search_business_concept_versions(user, 0, 10_000)
  end
end
