defmodule TdBg.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdBg.Repo
  alias TdBg.BusinessConcepts.BusinessConcept
  alias TdBg.BusinessConcepts.BusinessConceptAlias
  alias TdBg.BusinessConcepts.BusinessConceptVersion

  def user_factory do
    %TdBg.Accounts.User {
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end

  def template_factory do
    %TdBg.Templates.Template {
      label: "some type",
      name: "some_type",
      content: [],
      is_default: false
    }
  end

  def domain_factory do
    %TdBg.Taxonomies.Domain {
      name: "My domain",
      description: "My domain description",
      templates: []
    }
  end

  def child_domain_factory do
    %TdBg.Taxonomies.Domain {
      name: "My child domain",
      description: "My child domain description",
      parent: build(:domain)
    }
  end

  def business_concept_factory do
    %BusinessConcept {
      domain: build(:domain),
      parent_id: nil,
      type: "some_type",
      last_change_by: 1,
      last_change_at: DateTime.utc_now(),
      aliases: []
    }
  end

  def business_concept_version_factory do
    %BusinessConceptVersion {
      business_concept: build(:business_concept),
      content: %{},
      related_to: [],
      name: "My business term",
      description: %{"document" => "My business term description"},
      last_change_by: 1,
      last_change_at: DateTime.utc_now(),
      status: BusinessConcept.status.draft,
      version: 1,
    }
  end

  def business_concept_alias_factory do
    %BusinessConceptAlias {
      business_concept_id: 0,
      name: "my great alias",
    }
  end

end
