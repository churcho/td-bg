Background:
  Given an existing Domain Group called "My Parent Group"

Scenario: Create a simple business concept
  Given an existing Domain Group called "My Child Group" child of Domain Group "My Parent Group"
  And an existing Data Domain called "My Domain" child of Domain Group "My Child Group"
  And an existing Business Concept type called "Business Term" with empty definition
  When "app-admin" tries to create a business concept in the Data Domain "My Domain" with following data:
    | Field             | Value                                                                   |
    | Type              | Business Term                                                           |
    | Name              | My Simple Business Term                                                 |
    | Description       | This is the first description of my business term which is very simple  |
  Then the system returns a result with code "Created"
  And "app-admin" is able to view business concept "My Simple Business Term" as a child of Data Domain "My Domain" with following data:
    | Field             | Value                                                                    |
    | Type              | Business Term                                                            |
    | Name              | My Simple Business Term                                                  |
    | Description       | This is the first description of my business term which is very simple   |
    | Status            | draft                                                                    |
    | Last Modification | Some Timestamp                                                           |
    | Last User         | app-admin                                                                |
    | Version           | 1                                                                        |

Scenario: Create a business concept with dinamic data
  Given an existing Domain Group called "My Child Group" child of Domain Group "My Parent Group"
  And an existing Data Domain called "My Domain" child of Domain Group "My Child Group"
  And an existing Business Concept type called "Business Term" with following definition:
   | Field            | Format        | Max Size | Values                                        | Mandatory | Default Value | Group      |
   | Formula          | string        | 100      |                                               |    NO     |               | General    |
   | Format           | list          |          | Date, Numeric, Amount, Text                   |    YES    |               | General    |
   | List of Values   | variable_list | 100      |                                               |    NO     |               | Functional |
   | Sensitive Data   | list          |          | N/A, Personal Data, Related to personal Data  |    NO     | N/A           | Functional |
   | Update Frequence | list          |          | Not defined, Daily, Weekly, Monthly, Yearly   |    NO     | Not defined   | General    |
   | Related Area     | string        | 100      |                                               |    NO     |               | Functional |
   | Default Value    | string        | 100      |                                               |    NO     |               | General    |
   | Additional Data  | string        | 500      |                                               |    NO     |               | Functional |
  When "app-admin" tries to create a business concept in the Data Domain "My Domain" with following data:
    | Field             | Value                                                                    |
    | Type              | Business Term                                                            |
    | Name              | My Dinamic Business Term                                                 |
    | Description       | This is the first description of my business term which is a date        |
    | Formula           |                                                                          |
    | Format            | Date                                                                     |
    | List of Values    |                                                                          |
    | Related Area      |                                                                          |
    | Default Value     |                                                                          |
    | Additional Data   |                                                                          |
  Then the system returns a result with code "Created"
  And "app-admin" is able to view business concept "My Dinamic Business Term" as a child of Data Domain "My Domain" with following data:
    | Field             | Value                                                              |
    | Name              | My Dinamic Business Term                                           |
    | Type              | Business Term                                                      |
    | Description       | This is the first description of my business term which is a date  |
    | Formula           |                                                                    |
    | Format            | Date                                                               |
    | List of Values    |                                                                    |
    | Sensitive Data    | N/A                                                                |
    | Update Frequence  | Not defined                                                        |
    | Related Area      |                                                                    |
    | Default Value     |                                                                    |
    | Additional Data   |                                                                    |
    | Status            | draft                                                              |
    | Last Modification | Some timestamp                                                     |
    | Last User         | app-admin                                                          |
    | Version           | 1                                                                  |

Scenario Outline: Creating a business concept depending on your role
  Given an existing Domain Group called "My Child Group" child of Domain Group "My Parent Group"
  And an existing Data Domain called "My Domain" child of Domain Group "My Child Group"
  And an existing Business Concept type called "Business Term" with empty definition
  And following users exist with the indicated role in Data Domain "My Domain"
    | user      | role    |
    | watcher   | watch   |
    | creator   | create  |
    | publisher | publish |
    | admin     | admin   |
  When "<user>" tries to create a business concept in the Data Domain "My Domain" with following data:
    | Field             | Value                                                                   |
    | Type              | Business Term                                                           |
    | Name              | My Simple Business Term                                                 |
    | Description       | This is the first description of my business term which is very simple  |
  Then the system returns a result with code "<result>"
  Examples:
    | user      | result       |
    | watcher   | Unauthorized |
    | creator   | Created      |
    | publisher | Created      |
    | admin     | Created      |

  Scenario: User should not be able to create a business concept with same type and name as an existing one
    Given an existing Data Domain called "My Domain" child of Domain Group "My Parent Group"
    And an existing Business Concept type called "Business Term" with empty definition
    And an existing Business Concept in the Data Domain "My Domain" with following data:
     | Field             | Value                                                                   |
     | Type              | Business Term                                                           |
     | Name              | My Business Term                                                        |
     | Description       | This is the first description of my business term which is very simple  |
    And an existing Domain Group called "My Second Parent Group"
    And an existing Data Domain called "My Second Domain" child of Domain Group "My Second Parent Group"
    When "app-admin" tries to create a business concept in the Data Domain "My Second Domain" with following data:
     | Field             | Value                                                                   |
     | Type              | Business Term                                                           |
     | Name              | My Business Term                                                        |
     | Description       | This is the second description of my business term                      |
    Then the system returns a result with code "Unprocessable Entity"
    And "app-admin" is able to view business concept "My Business Term" as a child of Data Domain "My Domain" with following data:
      | Field             | Value                                                                   |
      | Type              | Business Term                                                           |
      | Name              | My Business Term                                                        |
      | Description       | This is the first description of my business term which is very simple  |
      | Status            | draft                                                                   |
      | Last Modification | Some Timestamp                                                          |
      | Last User         | app-admin                                                               |
      | Version           | 1                                                                       |
    And "app-admin" is not able to view business concept "My Business Term" as a child of Data Domain "My Second Domain"

  Scenario: User should not be able to create a business concept with same type and name as an existing alias
    Given an existing Data Domain called "My Domain" child of Domain Group "My Parent Group"
    And an existing Business Concept type called "Business Term" with empty definition
    And an existing Business Concept in the Data Domain "My Domain" with following data:
     | Field             | Value                                                                   |
     | Type              | Business Term                                                           |
     | Name              | My Business Term                                                        |
     | Description       | This is the first description of my business term which is very simple  |
    And business concept with name "My Business Term" of type "Business Term" has an alias "My Synonym Term"
    And an existing Domain Group called "My Second Parent Group"
    And an existing Data Domain called "My Second Domain" child of Domain Group "My Second Parent Group"
    When "app-admin" tries to create a business concept in the Data Domain "My Second Domain" with following data:
     | Field             | Value                                                                   |
     | Type              | Business Term                                                           |
     | Name              | My Synonym Term                                                         |
     | Description       | This is the second description of my business term                      |
    Then the system returns a result with code "Unprocessable Entity"
    And business concept "My Synonym Term" of type "Business Term" and version "1" does not exist