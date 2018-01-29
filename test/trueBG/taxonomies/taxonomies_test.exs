defmodule TrueBG.TaxonomiesTest do
  use TrueBG.DataCase

  alias TrueBG.Taxonomies

  describe "domain_groups" do
    alias TrueBG.Taxonomies.DomainGroup

    @valid_attrs %{description: "some description", name: "some name"}
    @update_attrs %{description: "some updated description", name: "some updated name"}
    @invalid_attrs %{description: nil, name: nil}

    @child_attrs %{description: "child of some name description", name: "child of some name"}

    #@parent_attrs %{description: "parent description", name: "parent name"}

    def domain_group_fixture(attrs \\ %{}) do
      {:ok, domain_group} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Taxonomies.create_domain_group()

      domain_group
    end

    test "list_domain_groups/0 returns all domain_groups" do
      domain_group = domain_group_fixture()
      assert Taxonomies.list_domain_groups() == [domain_group]
    end

    test "get_domain_group!/1 returns the domain_group with given id" do
      domain_group = domain_group_fixture()
      assert Taxonomies.get_domain_group!(domain_group.id) == domain_group
    end

    test "create_domain_group/1 with valid data creates a domain_group" do
      assert {:ok, %DomainGroup{} = domain_group} = Taxonomies.create_domain_group(@valid_attrs)
      assert domain_group.description == "some description"
      assert domain_group.name == "some name"
    end

    test "create_domain_group/2 child of a parent group" do
      parent_domain_group = domain_group_fixture()
      child_attrs = Map.put(@child_attrs, :parent_id, parent_domain_group.id)

      assert {:ok, %DomainGroup{} = domain_group} = Taxonomies.create_domain_group(child_attrs)
      assert domain_group.description == child_attrs.description
      assert domain_group.name == child_attrs.name
      assert domain_group.parent_id == parent_domain_group.id
    end

    test "create_domain_group/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Taxonomies.create_domain_group(@invalid_attrs)
    end

    test "update_domain_group/2 with valid data updates the domain_group" do
      domain_group = domain_group_fixture()
      assert {:ok, domain_group} = Taxonomies.update_domain_group(domain_group, @update_attrs)
      assert %DomainGroup{} = domain_group
      assert domain_group.description == "some updated description"
      assert domain_group.name == "some updated name"
    end

    test "update_domain_group/2 with invalid data returns error changeset" do
      domain_group = domain_group_fixture()
      assert {:error, %Ecto.Changeset{}} = Taxonomies.update_domain_group(domain_group, @invalid_attrs)
      assert domain_group == Taxonomies.get_domain_group!(domain_group.id)
    end

    test "delete_domain_group/1 deletes the domain_group" do
      domain_group = domain_group_fixture()
      assert {:ok, %DomainGroup{}} = Taxonomies.delete_domain_group(domain_group)
      assert_raise Ecto.NoResultsError, fn -> Taxonomies.get_domain_group!(domain_group.id) end
    end

    test "change_domain_group/1 returns a domain_group changeset" do
      domain_group = domain_group_fixture()
      assert %Ecto.Changeset{} = Taxonomies.change_domain_group(domain_group)
    end
  end

  describe "data_domains" do
    alias TrueBG.Taxonomies.DataDomain

    @valid_attrs %{description: "some description", name: "some name"}
    @update_attrs %{description: "some updated description", name: "some updated name"}
    @invalid_attrs %{description: nil, name: nil}

    def data_domain_fixture(attrs \\ %{}) do
      {:ok, data_domain} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Taxonomies.create_data_domain()

      data_domain
    end

    test "list_data_domains/0 returns all data_domains" do
      data_domain = data_domain_fixture()
      assert Taxonomies.list_data_domains() == [data_domain]
    end

    test "get_data_domain!/1 returns the data_domain with given id" do
      data_domain = data_domain_fixture()
      assert Taxonomies.get_data_domain!(data_domain.id) == data_domain
    end

    test "create_data_domain/1 with valid data creates a data_domain" do
      assert {:ok, %DataDomain{} = data_domain} = Taxonomies.create_data_domain(@valid_attrs)
      assert data_domain.description == "some description"
      assert data_domain.name == "some name"
    end

    test "create_data_domain/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Taxonomies.create_data_domain(@invalid_attrs)
    end

    test "update_data_domain/2 with valid data updates the data_domain" do
      data_domain = data_domain_fixture()
      assert {:ok, data_domain} = Taxonomies.update_data_domain(data_domain, @update_attrs)
      assert %DataDomain{} = data_domain
      assert data_domain.description == "some updated description"
      assert data_domain.name == "some updated name"
    end

    test "update_data_domain/2 with invalid data returns error changeset" do
      data_domain = data_domain_fixture()
      assert {:error, %Ecto.Changeset{}} = Taxonomies.update_data_domain(data_domain, @invalid_attrs)
      assert data_domain == Taxonomies.get_data_domain!(data_domain.id)
    end

    test "delete_data_domain/1 deletes the data_domain" do
      data_domain = data_domain_fixture()
      assert {:ok, %DataDomain{}} = Taxonomies.delete_data_domain(data_domain)
      assert_raise Ecto.NoResultsError, fn -> Taxonomies.get_data_domain!(data_domain.id) end
    end

    test "change_data_domain/1 returns a data_domain changeset" do
      data_domain = data_domain_fixture()
      assert %Ecto.Changeset{} = Taxonomies.change_data_domain(data_domain)
    end
  end

  # describe "business_concepts" do
  #   alias TrueBG.Taxonomies.BusinessConcept
  #
  #   @valid_attrs %{content: %{}, type: "some type"}
  #   @update_attrs %{content: %{}, type: "some updated type"}
  #   @invalid_attrs %{content: nil, type: nil}
  #
  #   def business_concept_fixture(attrs \\ %{}) do
  #     {:ok, business_concept} =
  #       attrs
  #       |> Enum.into(@valid_attrs)
  #       |> Taxonomies.create_business_concept()
  #
  #     business_concept
  #   end
  #
  #   test "list_business_concepts/0 returns all business_concepts" do
  #     business_concept = business_concept_fixture()
  #     assert Taxonomies.list_business_concepts() == [business_concept]
  #   end
  #
  #   test "get_business_concept!/1 returns the business_concept with given id" do
  #     business_concept = business_concept_fixture()
  #     assert Taxonomies.get_business_concept!(business_concept.id) == business_concept
  #   end
  #
  #   test "create_business_concept/1 with valid data creates a business_concept" do
  #     assert {:ok, %BusinessConcept{} = business_concept} = Taxonomies.create_business_concept(@valid_attrs)
  #     assert business_concept.content == %{}
  #     assert business_concept.type == "some type"
  #   end
  #
  #   test "create_business_concept/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Taxonomies.create_business_concept(@invalid_attrs)
  #   end
  #
  #   test "update_business_concept/2 with valid data updates the business_concept" do
  #     business_concept = business_concept_fixture()
  #     assert {:ok, business_concept} = Taxonomies.update_business_concept(business_concept, @update_attrs)
  #     assert %BusinessConcept{} = business_concept
  #     assert business_concept.content == %{}
  #     assert business_concept.type == "some updated type"
  #   end
  #
  #   test "update_business_concept/2 with invalid data returns error changeset" do
  #     business_concept = business_concept_fixture()
  #     assert {:error, %Ecto.Changeset{}} = Taxonomies.update_business_concept(business_concept, @invalid_attrs)
  #     assert business_concept == Taxonomies.get_business_concept!(business_concept.id)
  #   end
  #
  #   test "delete_business_concept/1 deletes the business_concept" do
  #     business_concept = business_concept_fixture()
  #     assert {:ok, %BusinessConcept{}} = Taxonomies.delete_business_concept(business_concept)
  #     assert_raise Ecto.NoResultsError, fn -> Taxonomies.get_business_concept!(business_concept.id) end
  #   end
  #
  #   test "change_business_concept/1 returns a business_concept changeset" do
  #     business_concept = business_concept_fixture()
  #     assert %Ecto.Changeset{} = Taxonomies.change_business_concept(business_concept)
  #   end
  # end
end
