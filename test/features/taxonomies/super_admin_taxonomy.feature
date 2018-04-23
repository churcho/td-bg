Feature: Super-admin Taxonomy administration
  This feature will allow a super-admin user to create all levels of taxonomy necessary to classify the content defined within the application.

  # Background:
  #   Given user "app-admin" is logged in the application

  Scenario: Creating a Domain without any parent
    When user "app-admin" tries to create a Domain with the name "Financial Metrics" and following data:
      | Description |
      | First version of Financial Metrics |
    Then the system returns a result with code "Created"
    And the user "app-admin" is able to see the Domain "Financial Metrics" with following data:
      | Description |
      | First version of Financial Metrics |

  Scenario: Creating a Domain as child of an existing Domain
    Given an existing Domain called "Risks"
    When user "app-admin" tries to create a Domain with the name "Markets" as child of Domain "Risks" with following data:
      | Description |
      | First version of Markets |
    Then the system returns a result with code "Created"
    And the user "app-admin" is able to see the Domain "Markets" with following data:
      | Description |
      | First version of Markets |
    And Domain "Markets" is a child of Domain "Risks"

  # Scenario: Creating a Domain as child of a non existing Domain
  #   Given user "app-admin" is logged in the application
  #   When user "app-admin" tries to create a Domain with the name "Markets" as child of Domain "Imaginary Group" with following data:
  #     | Description |
  #     | First version of Markets |
  #   Then the system returns a result with code "NotFound"
  #   And the user "app-admin" is not able to see the Domain "Imaginary Group"


  Scenario: Creating a duplicated Domain
    Given an existing Domain called "Risks"
    When user "app-admin" tries to create a Domain with the name "Risks" and following data:
      | Description |
      | First version of Risks |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Creating a Domain depending on an existing Domain
    Given an existing Domain called "Risks"
    When user "app-admin" tries to create a Domain with the name "Operational Risk" as child of Domain "Risks" with following data:
       | Description |
       | First version of Operational Risk |
    Then the system returns a result with code "Created"
    And the user "app-admin" is able to see the Domain "Operational Risk" with following data:
       | Description |
       | First version of Operational Risk |
    And Domain "Operational Risk" is a child of Domain "Risks"

  # Scenario: Creating a Data Domain depending on a non existing Domain
  #   Given user "app-admin" is logged in the application
  #   When user "app-admin" tries to create a Data Domain with the name "Operational Risk" as child of Domain "Imaginary Group" with following data:
  #     | Description |
  #     | First version of Operational Risk |
  #   Then the system returns a result with code "Forbidden"
  #   And the user "app-admin" is not able to see the Domain "Imaginary Group"
  #

  Scenario: Creating a duplicated Domain depending on the same existing Domain
    Given an existing Domain called "Risks"
    And an existing Domain called "Operational Risk" child of Domain "Risks"
    When user "app-admin" tries to create a Domain with the name "Operational Risk" as child of Domain "Risks" with following data:
      | Description |
      | First version of Operational Risk |
    Then the system returns a result with code "Unprocessable Entity"

  Scenario: Modifying a Domain and seeing the new version
     Given an existing Domain called "Risks" with following data:
       | Description |
       | First version of Risks |
     When user "app-admin" tries to modify a Domain with the name "Risks" introducing following data:
       | Description |
       | Second version of Risks |
     Then the system returns a result with code "Ok"
     And the user "app-admin" is able to see the Domain "Risks" with following data:
       | Description |
       | Second version of Risks |

  # Scenario: Trying to modify a non existing Domain
  #   Given user "app-admin" is logged in the application
  #   When user "app-admin" tries to modify a Domain with the name "Imaginary Group" introducing following data:
  #     | Description |
  #     | Second version of Imaginary Group |
  #   Then the system returns a result with code "Forbidden"
  #   And the user "app-admin" is not able to see the Domain "Risks"

   Scenario: Modifying a Domain and seeing the new version
     Given an existing Domain called "Risks"
     And an existing Domain called "Credit Risks" child of Domain "Risks" with following data:
       | Description |
       | First version of Credit Risks |
     When user "app-admin" tries to modify a Domain with the name "Credit Risks" introducing following data:
       | Description |
       | Second version of Credit Risks |
     Then the system returns a result with code "Ok"
     And the user "app-admin" is able to see the Domain "Credit Risks" with following data:
       | Description |
       | Second version of Credit Risks |

   Scenario: Deleting a Domain without any Domain pending on it
     Given an existing Domain called "My Parent Domain"
     And an existing Domain called "My Child Domain" child of Domain "My Parent Domain"
     When user "app-admin" tries to delete a Domain with the name "My Child Domain"
     Then the system returns a result with code "Deleted"
     And Domain "My Child Domain" does not exist as child of Domain "My Parent Domain"

   Scenario: Deleting a Domain with a Domain pending on it
     Given an existing Domain called "My Parent Domain"
     And an existing Domain called "My Child Domain" child of Domain "My Parent Domain"
     When user "app-admin" tries to delete a Domain with the name "My Parent Domain"
     Then the system returns a result with code "Unprocessable Entity"
     And Domain "My Child Domain" exist as child of Domain "My Parent Domain"

   Scenario: Deleting a Domain
     Given an existing Domain called "My Parent Domain"
     And an existing Domain called "My Child Domain" child of Domain "My Parent Domain"
     When user "app-admin" tries to delete a Domain with the name "My Child Domain" child of Domain "My Parent Domain"
     Then the system returns a result with code "Deleted"
     And Domain "My Child Domain" does not exist as child of Domain "My Parent Domain"

   Scenario: Deleting a Domain with existing Business Concepts pending on them
     Given an existing Domain called "My Parent Domain"
     And an existing Domain called "My Child Domain" child of Domain "My Parent Domain"
     And an existing Business Concept type called "Business Term" with empty definition
     And an existing Business Concept in the Domain "My Child Domain" with following data:
      | Field             | Value                                                                   |
      | Type              | Business Term                                                           |
      | Name              | My Business Term                                                        |
      | Description       | This is the first description of my business term which is very simple  |
     When user "app-admin" tries to delete a Domain with the name "My Child Domain" child of Domain "My Parent Domain"
     Then the system returns a result with code "Unprocessable Entity"
     And Domain "My Child Domain" is a child of Domain "My Parent Domain"