defmodule TdBg.BusinessConcepts do
  @moduledoc """
  The BusinessConcepts context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset

  alias Ecto.Multi
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptVersion
  alias TdBg.Cache.ConceptLoader
  alias TdBg.Repo
  alias TdBg.Search.Indexer
  alias TdCache.ConceptCache
  alias TdCache.EventStream.Publisher
  alias TdCache.TemplateCache
  alias TdDfLib.Format
  alias TdDfLib.Templates
  alias TdDfLib.Validation
  alias ValidationError

  @doc """
  check business concept name availability
  """
  def check_business_concept_name_availability(type, name, exclude_concept_id \\ nil)

  def check_business_concept_name_availability(type, name, _exclude_concept_id)
      when is_nil(name) or is_nil(type),
      do: {:name_available}

  def check_business_concept_name_availability(type, name, exclude_concept_id) do
    status = [BusinessConcept.status().versioned, BusinessConcept.status().deprecated]

    BusinessConcept
    |> join(:left, [c], _ in assoc(c, :versions))
    |> where([c, v], c.type == ^type and v.status not in ^status)
    |> include_name_where(name, exclude_concept_id)
    |> select([c, v], count(c.id))
    |> Repo.one!()
    |> case do
      0 -> {:name_available}
      _ -> {:name_not_available}
    end
  end

  defp include_name_where(query, name, nil) do
    query
    |> where([_, v], fragment("lower(?)", v.name) == ^String.downcase(name))
  end

  defp include_name_where(query, name, exclude_concept_id) do
    query
    |> where(
      [c, v],
      c.id != ^exclude_concept_id and fragment("lower(?)", v.name) == ^String.downcase(name)
    )
  end

  @doc """
  list all business concepts
  """
  def list_all_business_concepts do
    BusinessConcept
    |> Repo.all()
  end

  def list_current_business_concept_versions do
    BusinessConceptVersion
    |> where([v], v.current == true)
    |> preload(:business_concept)
    |> Repo.all()
  end

  @doc """
    Fetch an exsisting business_concept by its id
  """
  def get_business_concept!(business_concept_id) do
    Repo.one!(
      from(c in BusinessConcept,
        where: c.id == ^business_concept_id
      )
    )
  end

  @doc """
    count published business concepts
    business concept must be of indicated type
    business concept are resticted to indicated id list
  """
  def count_published_business_concepts(type, ids) do
    published = BusinessConcept.status().published

    BusinessConcept
    |> join(:left, [c], _ in assoc(c, :versions))
    |> where([c, v], c.type == ^type and c.id in ^ids and v.status == ^published)
    |> select([c, _v], count(c.id))
    |> Repo.one!()
  end

  @doc """
  Returns children of domain id passed as argument
  """
  def get_domain_children_versions!(domain_id) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> preload([_, c], business_concept: c)
    |> where([_, c], c.domain_id == ^domain_id)
    |> Repo.all()
  end

  def get_all_versions_by_business_concept_ids([]), do: []

  def get_all_versions_by_business_concept_ids(business_concept_ids) do
    BusinessConceptVersion
    |> where([v], v.business_concept_id in ^business_concept_ids)
    |> preload(:business_concept)
    |> Repo.all()
  end

  def get_active_ids do
    Repo.all(
      from(v in "business_concept_versions",
        where: v.current,
        where: v.status != "deprecated",
        select: v.business_concept_id
      )
    )
  end

  def get_confidential_ids do
    confidential = %{"_confidential" => "Si"}

    Repo.all(
      from(v in "business_concept_versions",
        where: v.current,
        where: v.status != "deprecated",
        where: fragment("(?) @> ?::jsonb", field(v, :content), ^confidential),
        select: v.business_concept_id
      )
    )
  end

  @doc """
  Gets a single business_concept.

  Raises `Ecto.NoResultsError` if the Business concept does not exist.

  ## Examples

      iex> get_current_version_by_business_concept_id!(123)
      %BusinessConcept{}

      iex> get_current_version_by_business_concept_id!(456)
      ** (Ecto.NoResultsError)

  """
  def get_current_version_by_business_concept_id!(business_concept_id) do
    BusinessConceptVersion
    |> where([v], v.business_concept_id == ^business_concept_id)
    |> order_by(desc: :version)
    |> limit(1)
    |> preload(business_concept: :domain)
    |> Repo.one!()
  end

  def get_current_version_by_business_concept_id!(business_concept_id, %{current: current}) do
    BusinessConceptVersion
    |> where([v], v.business_concept_id == ^business_concept_id)
    |> where([v], v.current == ^current)
    |> order_by(desc: :version)
    |> limit(1)
    |> preload(business_concept: :domain)
    |> Repo.one!()
  end

  @doc """
  Gets a single business_concept searching for the published version instead of the latest.

  Raises `Ecto.NoResultsError` if the Business concept does not exist.

  ## Examples

      iex> get_currently_published_version!(123)
      %BusinessConcept{}

      iex> get_currently_published_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_currently_published_version!(business_concept_id) do
    published = BusinessConcept.status().published

    version =
      BusinessConceptVersion
      |> where([v], v.business_concept_id == ^business_concept_id)
      |> where([v], v.status == ^published)
      |> preload(business_concept: [:domain])
      |> Repo.one()

    case version do
      nil -> get_current_version_by_business_concept_id!(business_concept_id)
      _ -> version
    end
  end

  @doc """
  Creates a business_concept.

  ## Examples

      iex> create_business_concept(%{field: value})
      {:ok, %BusinessConceptVersion{}}

      iex> create_business_concept(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_business_concept_and_index(attrs \\ %{}) do
    result = create_business_concept(attrs)

    case result do
      {:ok, business_concept_version} ->
        new_version = get_business_concept_version!(business_concept_version.id)
        business_concept_id = new_version.business_concept_id
        ConceptLoader.refresh(business_concept_id)
        {:ok, new_version}

      _ ->
        result
    end
  end

  def create_business_concept(attrs \\ %{}) do
    attrs
    |> attrs_keys_to_atoms
    |> raise_error_if_no_content_schema
    |> format_content
    |> set_content_defaults
    |> validate_new_concept
    |> validate_description
    |> validate_concept_content
    |> insert_concept
  end

  defp format_content(%{content: content} = attrs) when not is_nil(content) do
    content =
      attrs
      |> Map.get(:content_schema)
      |> Enum.filter(fn %{"type" => schema_type, "cardinality" => cardinality} ->
        schema_type in ["url", "enriched_text"] or
          (schema_type == "string" and cardinality in ["*", "+"])
      end)
      |> Enum.filter(fn %{"name" => name} ->
        field_content = Map.get(content, name)
        not is_nil(field_content) and is_binary(field_content) and field_content != ""
      end)
      |> Enum.into(
        content,
        &format_field(&1, content)
      )

    Map.put(attrs, :content, content)
  end

  defp format_content(attrs), do: attrs

  defp format_field(schema, content) do
    {Map.get(schema, "name"),
     Format.format_field(%{
       "content" => Map.get(content, Map.get(schema, "name")),
       "type" => Map.get(schema, "type"),
       "cardinality" => Map.get(schema, "cardinality"),
       "values" => Map.get(schema, "values")
     })}
  end

  @doc """
  Creates a new business_concept version.

  """
  def version_business_concept(user, %BusinessConceptVersion{} = business_concept_version) do
    business_concept = business_concept_version.business_concept

    business_concept =
      business_concept
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())

    draft_attrs = Map.from_struct(business_concept_version)

    draft_attrs =
      draft_attrs
      |> Map.put("business_concept", business_concept)
      |> Map.put("last_change_by", user.id)
      |> Map.put("last_change_at", DateTime.utc_now())
      |> Map.put("status", BusinessConcept.status().draft)
      |> Map.put("version", business_concept_version.version + 1)

    result =
      draft_attrs
      |> attrs_keys_to_atoms
      |> validate_new_concept
      |> version_concept(business_concept_version)

    case result do
      {:ok, %{current: new_version}} ->
        business_concept_id = new_version.business_concept_id
        ConceptLoader.refresh(business_concept_id)
        result

      _ ->
        result
    end
  end

  @doc """
  Updates a business_concept.

  ## Examples

      iex> update_business_concept_version(business_concept_version, %{field: new_value})
      {:ok, %BusinessConceptVersion{}}

      iex> update_business_concept_version(business_concept_version, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_business_concept_version(
        %BusinessConceptVersion{} = business_concept_version,
        attrs
      ) do
    result =
      attrs
      |> attrs_keys_to_atoms
      |> raise_error_if_no_content_schema
      |> add_content_if_not_exist
      |> merge_content_with_concept(business_concept_version)
      |> set_content_defaults
      |> validate_concept(business_concept_version)
      |> validate_concept_content
      |> validate_description
      |> update_concept

    case result do
      {:ok, _} ->
        updated_version = get_business_concept_version!(business_concept_version.id)
        refresh_cache_and_elastic(updated_version)
        {:ok, updated_version}

      _ ->
        result
    end
  end

  def bulk_update_business_concept_version(
        %BusinessConceptVersion{} = business_concept_version,
        attrs
      ) do
    result =
      attrs
      |> attrs_keys_to_atoms
      |> raise_error_if_no_content_schema
      |> add_content_if_not_exist
      |> merge_content_with_concept(business_concept_version)
      |> set_content_defaults
      |> bulk_validate_concept(business_concept_version)
      |> validate_concept_content
      |> validate_description
      |> update_concept

    case result do
      {:ok, _} ->
        updated_version = get_business_concept_version!(business_concept_version.id)
        {:ok, updated_version}

      _ ->
        result
    end
  end

  defp refresh_cache_and_elastic(%BusinessConceptVersion{} = business_concept_version) do
    business_concept_id = business_concept_version.business_concept_id
    ConceptLoader.refresh(business_concept_id)

    Publisher.publish(
      %{
        event: "concept_updated",
        resource_type: "business_concept",
        resource_id: business_concept_id
      },
      "business_concept:events"
    )
  end

  def update_business_concept_version_status(
        %BusinessConceptVersion{} = business_concept_version,
        %{status: "deprecated"} = attrs
      ) do
    result = do_update_business_concept_version_status(business_concept_version, attrs)
    ConceptCache.delete(business_concept_version.business_concept_id)
    result
  end

  def update_business_concept_version_status(
        %BusinessConceptVersion{} = business_concept_version,
        attrs
      ) do
    do_update_business_concept_version_status(business_concept_version, attrs)
  end

  defp do_update_business_concept_version_status(
         %BusinessConceptVersion{} = business_concept_version,
         attrs
       ) do
    result =
      business_concept_version
      |> BusinessConceptVersion.update_status_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_version} ->
        business_concept_id = updated_version.business_concept_id
        ConceptLoader.refresh(business_concept_id)
        result

      _ ->
        result
    end
  end

  def publish_business_concept_version(business_concept_version, %{id: id} = _user) do
    status_published = BusinessConcept.status().published
    attrs = %{status: status_published, last_change_at: DateTime.utc_now(), last_change_by: id}

    business_concept_id = business_concept_version.business_concept.id

    query =
      from(
        c in BusinessConceptVersion,
        where: c.business_concept_id == ^business_concept_id and c.status == ^status_published
      )

    result =
      Multi.new()
      |> Multi.update_all(:versioned, query, set: [status: BusinessConcept.status().versioned])
      |> Multi.update(
        :published,
        BusinessConceptVersion.update_status_changeset(business_concept_version, attrs)
      )
      |> Repo.transaction()

    case result do
      {:ok, %{published: %BusinessConceptVersion{business_concept_id: business_concept_id}}} ->
        ConceptLoader.refresh(business_concept_id)
        result

      _ ->
        result
    end
  end

  def get_concept_counts(business_concept_id) do
    case ConceptCache.get(business_concept_id) do
      {:ok, %{rule_count: rule_count, link_count: link_count}} ->
        %{rule_count: rule_count, link_count: link_count}

      _ ->
        %{rule_count: 0, link_count: 0}
    end
  end

  def reject_business_concept_version(%BusinessConceptVersion{} = business_concept_version, attrs) do
    result =
      business_concept_version
      |> BusinessConceptVersion.reject_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_version} ->
        business_concept_id = updated_version.business_concept_id
        ConceptLoader.refresh(business_concept_id)
        result

      _ ->
        result
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking business_concept changes.

  ## Examples

      iex> change_business_concept(business_concept)
      %Ecto.Changeset{source: %BusinessConcept{}}

  """
  def change_business_concept(%BusinessConcept{} = business_concept) do
    BusinessConcept.changeset(business_concept, %{})
  end

  alias TdBg.BusinessConcepts.BusinessConceptVersion

  @doc """
  Returns the list of business_concept_versions.

  ## Examples

      iex> list_all_business_concept_versions(filter)
      [%BusinessConceptVersion{}, ...]

  """
  def list_all_business_concept_versions do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> order_by(asc: :version)
    |> Repo.all()
  end

  @doc """
  Returns the list of business_concept_versions.

  ## Examples

      iex> list_all_business_concept_versions()
      [%BusinessConceptVersion{}, ...]

  """
  def find_business_concept_versions(filter) do
    query =
      BusinessConceptVersion
      |> join(:left, [v], _ in assoc(v, :business_concept))
      |> preload([_, c], business_concept: c)
      |> order_by(asc: :version)

    query =
      case Map.has_key?(filter, :id) && length(filter.id) > 0 do
        true ->
          id = Map.get(filter, :id)
          query |> where([_v, c], c.id in ^id)

        _ ->
          query
      end

    query =
      case Map.has_key?(filter, :status) && length(filter.status) > 0 do
        true ->
          status = Map.get(filter, :status)
          query |> where([v, _c], v.status in ^status)

        _ ->
          query
      end

    query |> Repo.all()
  end

  @doc """
  Returns the list of business_concept_versions of a
  business_concept

  ## Examples

      iex> list_business_concept_versions(business_concept_id)
      [%BusinessConceptVersion{}, ...]

  """
  def list_business_concept_versions(business_concept_id, status) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> where([_, c], c.id == ^business_concept_id)
    |> include_status_in_where(status)
    |> order_by(desc: :version)
    |> Repo.all()
  end

  @doc """
  Returns the list of business_concept_versions_by_ids giving a
  list of ids

  ## Examples

      iex> business_concept_versions_by_ids([bcv_id_1, bcv_id_2], status)
      [%BusinessConceptVersion{}, ...]

  """
  def business_concept_versions_by_ids(list_business_concept_version_ids, status \\ nil) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> where([v, _, _], v.id in ^list_business_concept_version_ids)
    |> include_status_in_where(status)
    |> order_by(desc: :version)
    |> Repo.all()
  end

  def list_all_business_concept_with_status(status) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> include_status_in_where(status)
    |> order_by(asc: :version)
    |> Repo.all()
  end

  defp include_status_in_where(query, nil), do: query

  defp include_status_in_where(query, status) do
    query |> where([v, _], v.status in ^status)
  end

  @doc """
  Gets a single business_concept_version.

  Raises `Ecto.NoResultsError` if the Business concept version does not exist.

  ## Examples

      iex> get_business_concept_version!(123)
      %BusinessConceptVersion{}

      iex> get_business_concept_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_business_concept_version!(id) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [_, c], _ in assoc(c, :domain))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> where([v, _], v.id == ^id)
    |> Repo.one!()
  end

  @doc """
  Deletes a BusinessCocneptVersion.

  ## Examples

      iex> delete_business_concept_version(data_structure)
      {:ok, %BusinessCocneptVersion{}}

      iex> delete_business_concept_version(data_structure)
      {:error, %Ecto.Changeset{}}

  """
  def delete_business_concept_version(%BusinessConceptVersion{} = business_concept_version) do
    if business_concept_version.version == 1 do
      business_concept = business_concept_version.business_concept
      business_concept_id = business_concept.id

      Multi.new()
      |> Multi.delete(:business_concept_version, business_concept_version)
      |> Multi.delete(:business_concept, business_concept)
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           business_concept: %BusinessConcept{},
           business_concept_version: %BusinessConceptVersion{} = version
         }} ->
          Publisher.publish(
            %{
              event: "concept_deleted",
              resource_type: "business_concept",
              resource_id: business_concept_id
            },
            "business_concept:events"
          )

          ConceptCache.delete(business_concept_id)
          # TODO: TD-1618 delete_search should be performed by a consumer of the event stream
          Indexer.delete(business_concept_version)
          {:ok, version}
      end
    else
      Multi.new()
      |> Multi.delete(:business_concept_version, business_concept_version)
      |> Multi.update(
        :current,
        BusinessConceptVersion.current_changeset(business_concept_version)
      )
      |> Repo.transaction()
      |> case do
        {:ok,
         %{
           business_concept_version: %BusinessConceptVersion{} = deleted_version,
           current: %BusinessConceptVersion{} = current_version
         }} ->
          Indexer.delete(deleted_version)
          {:ok, current_version}
      end
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking business_concept_version changes.

  ## Examples

      iex> change_business_concept_version(business_concept_version)
      %Ecto.Changeset{source: %BusinessConceptVersion{}}

  """
  def change_business_concept_version(%BusinessConceptVersion{} = business_concept_version) do
    BusinessConceptVersion.changeset(business_concept_version, %{})
  end

  defp map_keys_to_atoms(key_values) do
    Map.new(
      Enum.map(key_values, fn
        {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
        {key, value} when is_atom(key) -> {key, value}
      end)
    )
  end

  defp attrs_keys_to_atoms(key_values) do
    map = map_keys_to_atoms(key_values)

    case map.business_concept do
      %BusinessConcept{} -> map
      %{} = concept -> Map.put(map, :business_concept, map_keys_to_atoms(concept))
      _ -> map
    end
  end

  defp raise_error_if_no_content_schema(attrs) do
    if not Map.has_key?(attrs, :content_schema) do
      raise "Content Schema is not defined for Business Concept"
    end

    attrs
  end

  defp add_content_if_not_exist(attrs) do
    if Map.has_key?(attrs, :content) do
      attrs
    else
      Map.put(attrs, :content, %{})
    end
  end

  defp validate_new_concept(attrs) do
    changeset = BusinessConceptVersion.create_changeset(%BusinessConceptVersion{}, attrs)
    Map.put(attrs, :changeset, changeset)
  end

  defp validate_concept(attrs, %BusinessConceptVersion{} = business_concept_version) do
    changeset = BusinessConceptVersion.update_changeset(business_concept_version, attrs)
    Map.put(attrs, :changeset, changeset)
  end

  defp bulk_validate_concept(attrs, %BusinessConceptVersion{} = business_concept_version) do
    changeset = BusinessConceptVersion.bulk_update_changeset(business_concept_version, attrs)
    Map.put(attrs, :changeset, changeset)
  end

  defp merge_content_with_concept(attrs, %BusinessConceptVersion{} = business_concept_version) do
    content = Map.get(attrs, :content)
    concept_content = Map.get(business_concept_version, :content, %{})
    new_content = Map.merge(concept_content, content)
    Map.put(attrs, :content, new_content)
  end

  defp set_content_defaults(attrs) do
    content = Map.get(attrs, :content)
    content_schema = Map.get(attrs, :content_schema)

    case content do
      nil ->
        attrs

      _ ->
        content = Format.apply_template(content, content_schema)
        Map.put(attrs, :content, content)
    end
  end

  defp validate_concept_content(attrs) do
    changeset = Map.get(attrs, :changeset)

    if changeset.valid? do
      do_validate_concept_content(attrs)
    else
      attrs
    end
  end

  defp do_validate_concept_content(attrs) do
    content = Map.get(attrs, :content)
    content_schema = Map.get(attrs, :content_schema)
    changeset = Validation.build_changeset(content, content_schema)

    if changeset.valid? do
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    else
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    end
  end

  defp validate_description(attrs) do
    if Map.has_key?(attrs, :description) && Map.has_key?(attrs, :in_progress) &&
         !attrs.in_progress do
      do_validate_description(attrs)
    else
      attrs
    end
  end

  defp do_validate_description(attrs) do
    if !attrs.description == %{} do
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, true))
      |> Map.put(:in_progress, true)
    else
      attrs
      |> Map.put(:changeset, put_change(attrs.changeset, :in_progress, false))
      |> Map.put(:in_progress, false)
    end
  end

  defp update_concept(attrs) do
    changeset = Map.get(attrs, :changeset)

    if changeset.valid? do
      Repo.update(changeset)
    else
      {:error, changeset}
    end
  end

  defp insert_concept(attrs) do
    changeset = Map.get(attrs, :changeset)

    if changeset.valid? do
      Repo.insert(changeset)
    else
      {:error, changeset}
    end
  end

  defp version_concept(attrs, business_concept_version) do
    changeset = Map.get(attrs, :changeset)

    if changeset.valid? do
      Multi.new()
      |> Multi.update(
        :not_current,
        BusinessConceptVersion.not_anymore_current_changeset(business_concept_version)
      )
      |> Multi.insert(:current, changeset)
      |> Repo.transaction()
    else
      {:error, %{current: changeset}}
    end
  end

  def get_business_concept_by_name(name) do
    # Repo.all from r in BusinessConceptVersion, where:
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> where([v], ilike(v.name, ^"%#{name}%"))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def get_business_concept_by_term(term) do
    BusinessConceptVersion
    |> join(:left, [v], _ in assoc(v, :business_concept))
    |> join(:left, [v, c], _ in assoc(c, :domain))
    |> where([v], ilike(v.name, ^"%#{term}%") or ilike(v.description, ^"%#{term}%"))
    |> preload([_, c, d], business_concept: {c, domain: d})
    |> order_by(asc: :version)
    |> Repo.all()
  end

  def check_valid_related_to(_type, []), do: {:valid_related_to}

  def check_valid_related_to(type, ids) do
    input_count = length(ids)
    actual_count = count_published_business_concepts(type, ids)
    if input_count == actual_count, do: {:valid_related_to}, else: {:not_valid_related_to}
  end

  def diff(%BusinessConceptVersion{} = old, %BusinessConceptVersion{} = new) do
    old_content = Map.get(old, :content, %{})
    new_content = Map.get(new, :content, %{})
    content_diff = diff_content(old_content, new_content)

    [:name, :description]
    |> Enum.map(fn field -> {field, Map.get(old, field), Map.get(new, field)} end)
    |> Enum.reject(fn {_, old, new} -> old == new end)
    |> Enum.map(fn {field, _, new} -> {field, new} end)
    |> Map.new()
    |> Map.put(:content, content_diff)
  end

  defp diff_content(old, new) do
    added = Map.drop(new, Map.keys(old))
    removed = Map.drop(old, Map.keys(new))

    changed =
      new
      |> Map.drop(Map.keys(added))
      |> Map.drop(Map.keys(removed))
      |> Enum.reject(fn {key, val} -> Map.get(old, key) == val end)
      |> Map.new()

    %{added: added, changed: changed, removed: removed}
  end

  def get_template(%BusinessConceptVersion{business_concept: business_concept}) do
    get_template(business_concept)
  end

  def get_template(%BusinessConcept{type: type}) do
    TemplateCache.get_by_name!(type)
  end

  def get_content_schema(%BusinessConceptVersion{business_concept: business_concept}) do
    get_content_schema(business_concept)
  end

  def get_content_schema(%BusinessConcept{type: type}) do
    Templates.content_schema(type)
  end

  def get_completeness(%BusinessConceptVersion{content: content} = bcv) do
    case get_template(bcv) do
      template -> Templates.completeness(content, template)
    end
  end
end
