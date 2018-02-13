defmodule TrueBGWeb.BusinessConceptView do
  use TrueBGWeb, :view
  alias TrueBGWeb.BusinessConceptView
  alias TrueBG.BusinessConcepts.BusinessConcept

  def render("index.json", %{business_concepts: business_concepts}) do
    %{data: render_many(business_concepts, BusinessConceptView, "business_concept.json")}
  end

  def render("show.json", %{business_concept: business_concept}) do
    %{data: render_one(business_concept, BusinessConceptView, "business_concept.json")}
  end

  def render("business_concept.json", %{business_concept: business_concept}) do
    %{id: business_concept.id,
      content: business_concept.content,
      type: business_concept.type,
      name: business_concept.name,
      description: business_concept.description,
      modifier: business_concept.modifier,
      last_change: business_concept.last_change,
      data_domain_id: business_concept.data_domain_id,
      status: business_concept.status,
      version: business_concept.version}
    |> add_reject_reason(business_concept)
  end

  defp add_reject_reason(%{} = bc_map, business_concept) do
    if String.to_atom(business_concept.status) == BusinessConcept.rejected do
      Map.merge(bc_map, %{reject_reason: business_concept.reject_reason})
    else
      bc_map
    end
  end
end
