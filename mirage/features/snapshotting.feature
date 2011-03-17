Feature: Having set up the Mirage with a number of defaults, your tests may continue to change its state.
  Clearing and resetting all of your responses, potentially hundreds of times, can be time expensive.

  Mirage provides the ability to take a snapshot of its current state and to roll it back to that state.

  Background: The MockServer has been setup with some default responses
    Given I hit 'http://localhost:7001/mirage/set/greeting' with parameters:
      | response | The default greeting |


  Scenario: Taking a snapshot and rolling it back
    Given  I hit 'http://localhost:7001/mirage/snapshot'
    And I hit 'http://localhost:7001/mirage/set/leaving' with parameters:
      | response | Goodye |

    And I hit 'http://localhost:7001/mirage/set/greeting' with parameters:
      | response | Changed |

    And I hit 'http://localhost:7001/mirage/rollback'

    When I hit 'http://localhost:7001/mirage/get/leaving'
    Then a 404 should be returned

    When I hit 'http://localhost:7001/mirage/get/greeting'
    Then 'The default greeting' should be returned