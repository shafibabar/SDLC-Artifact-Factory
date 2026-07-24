# features/[feature-slug].feature
Feature: [Feature Title]
  As a [role]
  I want [capability]
  So that [benefit]

  Background:
    Given [shared precondition true for every scenario below]

  Scenario: [Happy path description] # happy
    Given [precondition specific to this scenario]
    When [the single action under test]
    Then [the observable outcome]
    And [a Domain Event is published, if applicable]

  Scenario: [Negative path description] # negative
    Given [precondition specific to this scenario]
    When [the same or a related action, under a condition that should be rejected]
    Then [the observable rejection outcome]

  Scenario: [Edge case description, naming the domain invariant it protects] # edge
    Given [precondition specific to this scenario]
    When [the action that would violate the invariant]
    Then [the observable outcome proving the invariant held]

  Scenario Outline: [Description of the data-varying rule]
    When [action] "<input>"
    Then [outcome] "<expected>"

    Examples:
      | input   | expected |
      | [value] | [value]  |
