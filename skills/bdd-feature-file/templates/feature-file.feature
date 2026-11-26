# name: feature-file
# product: <product>
# story-id: US-<n>
# version: 1.0.0
# phase: implement
# owner: test-strategist
# created: <yyyy-mm-dd>
# summary: <one sentence, 200 characters at most: which story, which criteria these scenarios prove>
# run: <agent-run or workshop>
# traces_to: ideate/acceptance-criteria/US-<n>.md; ideate/example-maps/US-<n>.md
# <agent-run: "Agent-run: one agent (test-strategist) wrote these from the approved criteria; no workshop was held." workshop: "Participants: names and roles">

Feature: <story title in the product's terms>
  As a <persona>
  I want <capability>
  So that <outcome>

  # Delete the Background if no Given is shared by every scenario.
  Background:
    Given <state every scenario below shares>

  # One Rule per business rule on the example map. Repeat Rule and Scenario blocks as needed.
  Rule: <R1 in business words>

    @AC-US-<n>.1 @happy
    Scenario: <behaviour proven>
      Given <state that already holds, with real names and values>
      When <one action>
      Then <outcome the persona can observe>

    @AC-US-<n>.2 @negative
    Scenario: <behaviour refused>
      Given <state in which the rule is about to be broken>
      When <one action>
      Then <what the persona sees>
      But <what must not happen>

  Rule: <R2 in business words>

    # An outline only where one behaviour holds across rows; every row must change what is proven.
    @AC-US-<n>.3 @edge
    Scenario Outline: <behaviour on and around a limit>
      Given <state described with "<column>">
      When <one action>
      Then <outcome described with "<expected>">

      Examples:
        | <column> | <expected> |
        | <value>  | <result>   |
