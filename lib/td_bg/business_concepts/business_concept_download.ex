defmodule TdBg.BusinessConcept.Download do
  @moduledoc """
    Helper module to download business concepts.
  """

  alias TdBg.Templates

  def to_csv(concepts) do
    concepts_by_type = Enum.group_by(concepts, &Map.get(&1, "type"))
    types = Map.keys(concepts_by_type)
    templates_by_type = Enum.reduce(types, %{},  &Map.put(&2, &1, Templates.get_template_by_name(&1)))

    list = Enum.reduce(types, [], fn(type, acc) ->
      concepts = Map.get(concepts_by_type, type)
      template = Map.get(templates_by_type, type)
      acc ++ concepts_to_csv(template, concepts)
    end)

    to_string(list)
  end

  defp concepts_to_csv(template, concepts) do
    content = template.content
    content_names  = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "name")]))
    content_labels = Enum.reduce(content, [], &(&2 ++ [Map.get(&1, "label")]))
    content_names_to_types  = Enum.reduce(content, %{}, &Map.put(&2, Map.get(&1, "name"), Map.get(&1, "type")))

    concepts_list = concepts_to_list(content_names, content_names_to_types, concepts)

    [["type",
      "name",
      "domain",
      "status"] ++ content_labels| concepts_list]
    |> CSV.encode
    |> Enum.to_list
  end

  defp concepts_to_list(content_fields, _content_fields_to_types, concepts) do
    Enum.reduce(concepts, [], fn(concept, acc) ->
      content = concept["content"]
      values = [concept["type"],
                concept["name"],
                concept["domain"]["name"],
                concept["status"]]
      acc ++ [Enum.reduce(content_fields, values,
              &(&2 ++ [Map.get(content, &1, "")]))]
    end)
  end
end
