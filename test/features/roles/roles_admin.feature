Feature: Roles Admin
  Authenticated users will have a default "watcher" role for all Domain Groups and Data domains
  - App-admin will have "admin" role in all Domain Groups and Data domains
  - An admin in a Domain Group or Data Domain can grant watch, create, publish or admin role in that Group/Domain or its children to any users
  - A user with a role in a Domain Group or Data Domain has that role as default for also for all its children
  - The existing roles in order of level of permissions are admin, publish, create, watch

  Scenario Outline: Granting roles to domain group by group manager
    Given an existing Domain Group called "My Group"
    And an existing Data Domain called "My Domain" child of Domain Group "My Group"
    And following users exist with the indicated role in Domain Group "My Group"
      | user      | role    |
      | watcher   | watch   |
      | creator   | create  |
      | publisher | publish |
      | admin     | admin   |
    When "<user>" grants <role> role to user "johndoe" in Domain Group "My Group"
    Then the system returns a result with code "<code>"
    And if result "<code>" is "Created", the user "johndoe" has "<group_role>" role in Domain Group "My Group"
    And if result "<code>" is "Created", the user "johndoe" has "<domain_role>" role in Data Domain "My Domain"

    Examples:
      | user       | role      | code         | group_role  | domain_role |
      | watcher    | admin     | Unauthorized | -           | -           |
      | creator    | admin     | Unauthorized | -           | -           |
      | publisher  | admin     | Unauthorized | -           | -           |
      | admin      | admin     | Created      | admin       | admin       |
      | watcher    | publish   | Unauthorized | -           | -           |
      | creator    | publish   | Unauthorized | -           | -           |
      | publisher  | publish   | Unauthorized | -           | -           |
      | admin      | publish   | Created      | publish     | publish     |
      | watcher    | create    | Unauthorized | -           | -           |
      | creator    | create    | Unauthorized | -           | -           |
      | publisher  | create    | Unauthorized | -           | -           |
      | admin      | create    | Created      | create      | create      |


  Scenario Outline: Granting roles to data domain by domain manager
    Given an existing Domain Group called "My Group"
    And an existing Data Domain called "My Domain" child of Domain Group "My Group"
    And following users exist with the indicated role in Data Domain "My Domain"
      | user      | role    |
      | watcher   | watch   |
      | creator   | create  |
      | publisher | publish |
      | admin     | admin   |
    When "<user>" grants <role> role to user "johndoe" in Data Domain "My Domain"
    Then the system returns a result with code "<code>"
    And if result "<code>" is "Created", the user "johndoe" has "<domain_role>" role in Data Domain "My Domain"

    Examples:
      | user       | role      | code         | domain_role |
      | watcher    | admin     | Unauthorized | -           |
      | creator    | admin     | Unauthorized | -           |
      | publisher  | admin     | Unauthorized | -           |
      | admin      | admin     | Created      | admin       |
      | watcher    | publish   | Unauthorized | -           |
      | creator    | publish   | Unauthorized | -           |
      | publisher  | publish   | Unauthorized | -           |
      | admin      | publish   | Created      | publish     |
      | watcher    | create    | Unauthorized | -           |
      | creator    | create    | Unauthorized | -           |
      | publisher  | create    | Unauthorized | -           |
      | admin      | create    | Created      | create      |

   Scenario: List of user with custom permission in a Data Domain
     Given an existing Domain Group called "My Group"
     And an existing Data Domain called "My Domain" child of Domain Group "My Group"
     And following users exist with the indicated role in Data Domain "My Domain"
       | user           | role    |
       | pietro.alpin   | watch   |
       | Hari.seldon    | create  |
       | tomclancy      | create  |
       | publisher      | publish |
       | Peter.sellers  | create  |
       | tom.sawyer     | admin   |
     When "app-admin" lists all users with custom permissions in Data Domain "My Domain"
     Then the system returns a result with following data:
       | user           | role    |
       | tom.sawyer     | admin   |
       | publisher      | publish |
       | Hari.seldon    | create  |
       | tomclancy      | create  |
       | Peter.sellers  | create  |
       | pietro.alpin   | watch   |

   Scenario: List of user with custom permission in a Domain Group
     Given an existing Domain Group called "My Group"
     And following users exist with the indicated role in Domain Group "My Group"
       | user           | role    |
       | pietro.alpin   | watch   |
       | Hari.seldon    | create  |
       | tomclancy      | create  |
       | publisher      | publish |
       | Peter.sellers  | create  |
       | tom.sawyer     | admin   |
     When "app-admin" lists all users with custom permissions in Domain Group "My Group"
     Then the system returns a result with following data:
       | user           | role    |
       | tom.sawyer     | admin   |
       | publisher      | publish |
       | Hari.seldon    | create  |
       | tomclancy      | create  |
       | Peter.sellers  | create  |
       | pietro.alpin   | watch   |


   Scenario: List of users available for setting custom permission in a Domain Group
     Given an existing Domain Group called "My Group"
     And an existing Data Domain called "My Domain" child of Domain Group "My Group"
     And an existing user "superman" with password "cripto" with super-admin property "yes"
     And following users exist in the application:
       | user           |
       | pietro.alpin   |
       | Hari.seldon    |
       | tomclancy      |
       | publisher      |
       | Peter.sellers  |
       | tom.sawyer     |
     And following users exist with the indicated role in Domain Group "My Group"
       | user           | role    |
       | pietro.alpin   | watch   |
       | tom.sawyer     | admin   |
     When "app-admin" tries to list all users available to set custom permissions in Domain Group "My Group"
     Then the system returns an user list with following data:
       | user           |
       | Hari.seldon    |
       | Peter.sellers  |
       | publisher      |
       | tomclancy      |


    Scenario: List of users available for setting custom permission in a Data Domain
      Given an existing Domain Group called "My Group"
      And an existing Data Domain called "My Domain" child of Domain Group "My Group"
      And an existing user "superman" with password "cripto" with super-admin property "yes"
      And following users exist in the application:
        | user           |
        | pietro.alpin   |
        | Hari.seldon    |
        | tomclancy      |
        | publisher      |
        | Peter.sellers  |
        | tom.sawyer     |
      And following users exist with the indicated role in Data Domain "My Domain"
        | user           | role    |
        | pietro.alpin   | watch   |
        | tom.sawyer     | admin   |
      When "app-admin" tries to list all users available to set custom permissions in Data Domain "My Domain"
      Then the system returns an user list with following data:
        | user           |
        | Hari.seldon    |
        | Peter.sellers  |
        | publisher      |
        | tomclancy      |

    Scenario: List taxonomy DGs DDs roles
      Given an existing Domain Group called "DG 1"
      And an existing Domain Group called "DG 1.1" child of Domain Group "DG 1"
      And an existing Domain Group called "DG 1.1.1" child of Domain Group "DG 1.1"
      And an existing Domain Group called "DG 1.1.2" child of Domain Group "DG 1.1"
      And an existing Domain Group called "DG 2"
      And an existing Domain Group called "DG 2.1" child of Domain Group "DG 2"
      And an existing Data Domain called "DD 1.1" child of Domain Group "DG 1"
      And an existing Data Domain called "DD 1.2" child of Domain Group "DG 1"
      And following users exist in the application:
        | user           |
        | pietro.alpin   |
      And following users exist with the indicated role in Domain Group "DG 1"
        | user           | role    |
        | pietro.alpin   | publish |
      And following users exist with the indicated role in Domain Group "DG 1.1.2"
        | user           | role    |
        | pietro.alpin   | watch   |
      And following users exist with the indicated role in Domain Group "DG 2"
        | user           | role    |
        | pietro.alpin   | create  |
      And following users exist with the indicated role in Data Domain "DD 1.1"
        | user           | role    |
        | pietro.alpin   | admin   |
      When user "app-admin" lists taxonomy roles of user "pietro.alpin"
      Then the system returns a taxonomy roles list with following data:
        | type | name     | parent_name | role    | inherited
        | DG   | DG 1     |             | publish | false
        | DG   | DG 1.1   | DG 1        | publish | true
        | DG   | DG 1.1.1 | DG 1.1      | publish | true
        | DG   | DG 1.1.2 | DG 1.1      | watch   | false
        | DD   | DD 1.1   | DG 1        | admin   | false
        | DD   | DD 1.2   | DG 1        | publish | true
        | DG   | DG 2     |             | create  | false
        | DG   | DG 2.1   | DG 2        | create  | true