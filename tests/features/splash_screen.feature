Feature: Splash Screen features
  In order navigate on the site in my language of preference
  As a citizen of the European Union
  I want to be able to choose my language at my first site connection
  
  Background:
    Given these modules are enabled
      |modules|
      |splash_screen|
    And these following languages are available:
      | languages |
      | en        |
      | de        |
      | fr        |
      | bg        |

  @api
  Scenario: Users can access to splash screen pages
    Given I am an anonymous user
    When I go to "/"
    Then I should see an "body.not-front.page-splash" element
    And I should see "English"
    And I should see "Deutsch"
    And I should see "Français"
    And I should see "Български"
	
  @api
  Scenario: Administrators can blacklisted languages for the splash screen page
    Given I am logged in as a user with the 'administrator' role
    When I go to "admin/config/regional/splash_screen_settings"
    And I fill in "edit-splash-screen-blacklist" with "fr bg"
    And I press the "Save" button
    Then I should see the success message "The configuration options have been saved."
    When I go to "/"
    Then I should see an "body.not-front.page-splash" element
    And I should see "English"
    And I should see "Deutsch"
    And I should not see "Български"
    And I should not see "Français"
	