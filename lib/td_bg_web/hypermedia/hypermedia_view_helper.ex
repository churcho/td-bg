defmodule TdBgWeb.Hypermedia.HypermediaViewHelper do
  @moduledoc """
  """
  import Phoenix.View
  alias TdBgWeb.Hypermedia.Link

  def render_many_hypermedia(resources, hypermedia, view, template, assigns \\ %{}) do
    Map.merge(
      render_hypermedia(hypermedia.collection_hypermedia),
      %{"collection" => render_many_hypermedia_element(resources,
        hypermedia.collection, view, template, assigns)}
      )
  end

  def render_one_hypermedia(resource, hypermedia, view, template, assigns \\ %{}) do
    Map.merge(
      render_hypermedia(hypermedia),
      render_one(resource, view, template, assigns))
  end

  defp render_many_hypermedia_element(resources, collection, view, template, assigns) do
    Enum.map(resources, fn resource ->
      render_one_hypermedia(
        resource, collection[resource], view, template, assigns)
    end)
  end

  defp render_hypermedia(hypermedia) do
    Enum.into(Enum.map(hypermedia, &render_link/1), %{})
  end

  defp render_link(%Link{} = link) do
    {map_action(link.action) , %{
        "action" => link.path,
        "method" => String.upcase(Atom.to_string(link.method)),
        "input" => input_map(link.schema)
      }
    }
  end
  defp render_link(map) do
    [{nested, hypermedia}] = Map.to_list(map)
    {String.to_atom(nested),
     Enum.into(Enum.map(hypermedia, &render_link/1), %{})}
  end

  defp map_action("show"), do: "ref"
  defp map_action("index"), do: "ref"
  defp map_action(other), do: other

  defp input_map(_schema) do
    %{}
  end

end