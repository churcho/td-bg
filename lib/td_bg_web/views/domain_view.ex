defmodule TdBgWeb.DomainView do
  use TdBgWeb, :view
  alias TdBgWeb.DomainView
  use TdHypermedia, :view

  def render("index.json", %{hypermedia: hypermedia}) do
    render_many_hypermedia(hypermedia, DomainView, "domain.json")
  end

  def render("index.json", %{domains: domains}) do
    %{data: render_many(domains, DomainView, "domain.json")}
  end

  def render("index_tiny.json", %{domains: domains}) do
    %{data: render_many(domains, DomainView, "domain_tiny.json")}
  end

  def render("show.json", %{domain: domain, hypermedia: hypermedia}) do
    render_one_hypermedia(domain, hypermedia, DomainView, "domain.json")
  end

  def render("show.json", %{domain: domain}) do
    %{data: render_one(domain, DomainView, "domain.json")}
  end

  def render("domain.json", %{domain: domain}) do
    %{
      id: domain.id,
      parent_id: domain.parent_id,
      name: domain.name,
      type: domain.type,
      external_id: domain.external_id,
      description: domain.description
    }
  end

  def render("domain_bc_count.json", %{counter: counter}) do
    %{data: %{counter: counter}}
  end

  def render("domain_tiny.json", %{domain: domain}) do
    %{id: domain.id, name: domain.name}
  end
end
