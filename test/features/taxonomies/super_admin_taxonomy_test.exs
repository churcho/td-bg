defmodule TdBg.SuperAdminTaxonomyTest do
  use Cabbage.Feature, async: false, file: "taxonomies/super_admin_taxonomy.feature"
  use TdBgWeb.FeatureCase

  import TdBgWeb.Taxonomy, only: :functions
  import TdBgWeb.BusinessConcept, only: :functions
  import TdBgWeb.Authentication, only: :functions
  import TdBgWeb.ResponseCode, only: :functions

  import_steps(TdBg.BusinessConceptSteps)
  import_steps(TdBg.DomainSteps)
  import_steps(TdBg.ResultSteps)

  import TdBg.ResultSteps
  import TdBg.BusinessConceptSteps

  alias TdBg.Cache.ConceptLoader
  alias TdBg.Cache.DomainLoader
  alias TdBg.Permissions.MockPermissionResolver
  alias TdBg.Search.IndexWorker
  alias TdBgWeb.ApiServices.MockTdAuditService
  alias TdBgWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(ConceptLoader)
    start_supervised(DomainLoader)
    start_supervised(IndexWorker)
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  defwhen ~r/^user "app-admin" tries to create a Domain with the name "(?<name>[^"]+)" and following data:$/,
          %{name: name, table: [%{Description: description, Type: type}]},
          state do
    token = get_user_token("app-admin")

    {_, status_code, _json_resp} =
      domain_create(token, %{name: name, description: description, type: type})

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  # Scenario Creating a Domain as child of an existing Domain
  defwhen ~r/^user "app-admin" tries to create a Domain with the name "(?<name>[^"]+)" as child of Domain "(?<parent_name>[^"]+)" with following data:$/,
          %{
            name: name,
            parent_name: parent_name,
            table: [%{Description: description, Type: type}]
          },
          state do
    token = get_user_token("app-admin")
    parent = get_domain_by_name(token, parent_name)
    assert parent["name"] == parent_name

    {_, status_code, _json_resp} =
      domain_create(token, %{
        name: name,
        parent_id: parent["id"],
        description: description,
        type: type
      })

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^Domain "(?<name>[^"]+)" is a child of Domain "(?<parent_name>[^"]+)"$/,
         %{name: name, parent_name: parent_name},
         _state do
    token = get_user_token("app-admin")
    child = get_domain_by_name(token, name)
    parent = get_domain_by_name(token, parent_name)
    assert child["name"] == name
    assert parent["name"] == parent_name
    assert child["parent_id"] == parent["id"]
  end

  defand ~r/^the user "(?<user_name>[^"]+)" is able to see the Domain "(?<domain_name>[^"]+)" with following data:$/,
         %{
           user_name: _user_name,
           domain_name: domain_name,
           table: [%{Description: description, Type: type}]
         },
         state do
    token = get_user_token("app-admin")
    domain_info = get_domain_by_name(token, domain_name)
    assert domain_name == domain_info["name"]
    {_, status_code, json_resp} = domain_show(token, domain_info["id"])
    assert rc_ok() == to_response_code(status_code)
    domain = json_resp["data"]
    assert domain_name == domain["name"]
    assert description == domain["description"]
    assert type == domain["type"]
    {:ok, %{state | status_code: nil}}
  end

  defand ~r/^user "app-admin" tries to modify a Domain with the name "(?<domain_name>[^"]+)" introducing following data:$/,
         %{domain_name: domain_name, table: [%{Description: description, Type: type}]},
         state do
    token = get_user_token("app-admin")
    domain = get_domain_by_name(token, domain_name)

    {_, status_code, _json_resp} =
      domain_update(token, domain["id"], %{
        name: domain_name,
        description: description,
        type: type
      })

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defwhen ~r/^user "app-admin" tries to modify a Domain with the name "(?<domain_name>[^"]+)" introducing following data:$/,
          %{domain_name: domain_name, table: [%{Description: description, Type: type}]},
          state do
    token = get_user_token("app-admin")
    domain_info = get_domain_by_name(token, domain_name)

    {:ok, status_code, _json_resp} =
      domain_update(token, domain_info["id"], %{
        name: domain_name,
        description: description,
        type: type
      })

    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^an existing Domain called "(?<child_name>[^"]+)" child of Domain "(?<parent_name>[^"]+)"$/,
         %{
           child_name: child_name,
           parent_name: parent_name,
           table: [%{Description: description, Type: type}]
         },
         _state do
    token = get_user_token("app-admin")
    parent = get_domain_by_name(token, parent_name)

    {_, http_status_code, _json_resp} =
      domain_create(token, %{
        name: child_name,
        parent_id: parent["id"],
        description: description,
        type: type
      })

    assert rc_created() == to_response_code(http_status_code)
  end

  defwhen ~r/^user "(?<user_name>[^"]+)" tries to delete a Domain with the name "(?<domain_name>[^"]+)"$/,
          %{user_name: user_name, domain_name: domain_name},
          state do
    token = get_user_token(user_name)
    domain = get_domain_by_name(token, domain_name)
    {_, status_code, _} = domain_delete(token, domain["id"])
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^Domain "(?<child_name>[^"]+)" does not exist as child of Domain "(?<parent_name>[^"]+)"$/,
         %{child_name: child_name, parent_name: parent_name},
         _state do
    token = get_user_token("app-admin")
    parent = get_domain_by_name(token, parent_name)
    child = get_domain_by_name_and_parent(token, child_name, parent["id"])
    assert !child
  end

  defand ~r/^Domain "(?<child_name>[^"]+)" exist as child of Domain "(?<parent_name>[^"]+)"$/,
         %{child_name: child_name, parent_name: parent_name},
         _state do
    token = get_user_token("app-admin")
    parent = get_domain_by_name(token, parent_name)
    child = get_domain_by_name_and_parent(token, child_name, parent["id"])
    assert child
  end

  defwhen ~r/^user "(?<user_name>[^"]+)" tries to delete a Domain with the name "(?<child_name>[^"]+)" child of Domain "(?<parent_name>[^"]+)"$/,
          %{user_name: user_name, child_name: child_name, parent_name: parent_name},
          state do
    token = get_user_token(user_name)
    domain = get_domain_by_name(token, parent_name)
    domain = get_domain_by_name_and_parent(token, child_name, domain["id"])
    {_, status_code, _} = domain_delete(token, domain["id"])
    {:ok, Map.merge(state, %{status_code: status_code})}
  end

  defand ~r/^Domain "(?<child_name>[^"]+)" does not exist as child of Domain "(?<parent_name>[^"]+)"$/,
         %{child_name: child_name, parent_name: parent_name},
         _state do
    token = get_user_token("app-admin")
    parent = get_domain_by_name(token, parent_name)
    child = get_domain_by_name_and_parent(token, child_name, parent["id"])
    assert !child
  end
end
