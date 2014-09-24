use utf8;
{
  'account/auth/login-simple.html.tmpl' => {
    'Log in to $terms.Bugzilla' =>
      'Log in to $terms.Bugzilla',
    'Login:' =>
      'Login:',
    'Password:' =>
      'Password:',
    'Remember my Login' =>
      'Remember my Login',
    'Restrict this session to this IP address (using this option improves security)' =>
      'Restrict this session to this IP address (using this option improves security)',
    'Restrict to IP' =>
      'Restrict to IP',
    '^Bugzilla_(login|password|restrictlogin)$|^logout$|^GoAheadAndLogIn$' =>
      '^Bugzilla_(login|password|restrictlogin)$|^logout$|^GoAheadAndLogIn$',
  },
  'account/auth/login-small.html.tmpl' => {
    'Log In' =>
      'Log In',
    'Remember' =>
      'Remember',
    'Log in' =>
      'Log in',
    'Forgot Password' =>
      'Forgot Password',
    'Login:' =>
      'Login:',
  },
  'account/auth/login.html.tmpl' => {
    'Log in to $terms.Bugzilla' =>
      'Log in to $terms.Bugzilla',
    'I need a legitimate login and password to continue.' =>
      'I need a legitimate login and password to continue.',
    'Login:' =>
      'Login:',
    'Password:' =>
      'Password:',
    'Remember my Login' =>
      'Remember my Login',
    'Restrict this session to this IP address (using this option improves security)' =>
      'Restrict this session to this IP address (using this option improves security)',
    '^Bugzilla_(login|password|restrictlogin)$|^logout$|^GoAheadAndLogIn$' =>
      '^Bugzilla_(login|password|restrictlogin)$|^logout$|^GoAheadAndLogIn$',
    'Log in' =>
      'Log in',
    '(Note: you should make sure cookies are enabled for this site. Otherwise, you will be required to log in frequently.)' =>
      '(Note: you should make sure cookies are enabled for this site. Otherwise, you will be required to log in frequently.)',
    'If you don\'t have a $terms.Bugzilla account, you can' =>
      'If you don\'t have a $terms.Bugzilla account, you can',
    'create a new account' =>
      'create a new account',
    'If you have an account, but have forgotten your password, enter your login name below and submit a request to change your password.' =>
      'If you have an account, but have forgotten your password, enter your login name below and submit a request to change your password.',
    'Reset Password' =>
      'Reset Password',
  },
  'account/cancel-token.txt.tmpl' => {
    'A request was canceled from' =>
      'A request was canceled from',
    'If you did not request this, it could be either an honest mistake or someone attempting to break into your $terms.Bugzilla account.' =>
      'If you did not request this, it could be either an honest mistake or someone attempting to break into your $terms.Bugzilla account.',
    'Take a look at the information below and forward this email to' =>
      'Take a look at the information below and forward this email to',
    'if you suspect foul play.' =>
      'if you suspect foul play.',
    'Token:' =>
      'Token:',
    'Token Type:' =>
      'Token Type:',
    'User:' =>
      'User:',
    'Issue Date:' =>
      'Issue Date:',
    'Event Data:' =>
      'Event Data:',
    'Canceled Because:' =>
      'Canceled Because:',
    'User account creation request canceled' =>
      'User account creation request canceled',
    'Password change request canceled' =>
      'Password change request canceled',
    'Email change request canceled' =>
      'Email change request canceled',
    'token canceled' =>
      'token canceled',
    'Account' =>
      'Account',
    'already exists.' =>
      'already exists.',
    'The request to change the email address for the' =>
      'The request to change the email address for the',
    'account to' =>
      'account to',
    'has been canceled.' =>
      'has been canceled.',
    'The request to change the email address for your account to' =>
      'The request to change the email address for your account to',
    'has been canceled. Your old account settings have been reinstated.' =>
      'has been canceled. Your old account settings have been reinstated.',
    'You have requested cancellation.' =>
      'You have requested cancellation.',
    'The creation of the user account' =>
      'The creation of the user account',
    'You have logged in.' =>
      'You have logged in.',
    'You have tried to use the token to change the password.' =>
      'You have tried to use the token to change the password.',
    'You have tried to use the token to cancel the email address change.' =>
      'You have tried to use the token to cancel the email address change.',
    'You have tried to use the token to confirm the email address change.' =>
      'You have tried to use the token to confirm the email address change.',
    'You have tried to use the token to create a user account.' =>
      'You have tried to use the token to create a user account.',
    'You are using $terms.Bugzilla\'s cancel-token function incorrectly. You passed in the string \'' =>
      'You are using $terms.Bugzilla\'s cancel-token function incorrectly. You passed in the string \'',
    '\'. The correct use is to pass in a tag, and define that tag in the file cancel-token.txt.tmpl.' =>
      '\'. The correct use is to pass in a tag, and define that tag in the file cancel-token.txt.tmpl.',
    'If you are a $terms.Bugzilla end-user seeing this message, please forward this email to' =>
      'If you are a $terms.Bugzilla end-user seeing this message, please forward this email to',
  },
  'account/create.html.tmpl' => {
    'Create a new $terms.Bugzilla account' =>
      'Create a new $terms.Bugzilla account',
    'To create a $terms.Bugzilla account, all you need to do is to enter' =>
      'To create a $terms.Bugzilla account, all you need to do is to enter',
    'a legitimate email address.' =>
      'a legitimate email address.',
    'an account name which when combined with' =>
      'an account name which when combined with',
    'corresponds to an address where you receive email.' =>
      'corresponds to an address where you receive email.',
    'You will receive an email at this address to confirm the creation of your account. <b>You will not be able to log in until you receive the email.</b> If it doesn\'t arrive within a reasonable amount of time, you may contact the maintainer of this $terms.Bugzilla installation at' =>
      'You will receive an email at this address to confirm the creation of your account. <b>You will not be able to log in until you receive the email.</b> If it doesn\'t arrive within a reasonable amount of time, you may contact the maintainer of this $terms.Bugzilla installation at',
    '<b>PRIVACY NOTICE:</b> $terms.Bugzilla is an open $terms.bug tracking system. Activity on most $terms.bugs, including email addresses, will be visible to the public. We <b>recommend</b> using a secondary account or free web email service (such as Gmail, Yahoo, Hotmail, or similar) to avoid receiving spam at your primary email address.' =>
      '<b>PRIVACY NOTICE:</b> $terms.Bugzilla is an open $terms.bug tracking system. Activity on most $terms.bugs, including email addresses, will be visible to the public. We <b>recommend</b> using a secondary account or free web email service (such as Gmail, Yahoo, Hotmail, or similar) to avoid receiving spam at your primary email address.',
    '<b>Email address:</b>' =>
      '<b>Email address:</b>',
    'Send' =>
      'Send',
  },
  'account/created.html.tmpl' => {
    'Request for new user account \'' =>
      'Request for new user account \'',
    '\' submitted' =>
      '\' submitted',
    'A confirmation email has been sent containing a link to continue creating an account. The link will expire if an account is not created within' =>
      'A confirmation email has been sent containing a link to continue creating an account. The link will expire if an account is not created within',
    'days.' =>
      'days.',
  },
  'account/email/change-new.txt.tmpl' => {
    '$terms.Bugzilla Change Email Address Request' =>
      '$terms.Bugzilla Change Email Address Request',
    'Subject:' =>
      'Subject:',
    '$terms.Bugzilla has received a request to change the email address for the account' =>
      '$terms.Bugzilla has received a request to change the email address for the account',
    'to your address.' =>
      'to your address.',
    'To confirm the change, visit the following link:' =>
      'To confirm the change, visit the following link:',
    'If you are not the person who made this request, or you wish to cancel this request, visit the following link:' =>
      'If you are not the person who made this request, or you wish to cancel this request, visit the following link:',
    'If you do nothing, the request will lapse after' =>
      'If you do nothing, the request will lapse after',
    'days (on' =>
      'days (on',
  },
  'account/email/change-old.txt.tmpl' => {
    '$terms.Bugzilla Change Email Address Request' =>
      '$terms.Bugzilla Change Email Address Request',
    '$terms.Bugzilla has received a request to change the email address for your account to' =>
      '$terms.Bugzilla has received a request to change the email address for your account to',
    'If you are not the person who made this request, or you wish to cancel this request, visit the following link:' =>
      'If you are not the person who made this request, or you wish to cancel this request, visit the following link:',
    'If you do nothing, and' =>
      'If you do nothing, and',
    'confirms this request, the change will be made permanent after' =>
      'confirms this request, the change will be made permanent after',
    'days (on' =>
      'days (on',
  },
  'account/email/confirm-new.html.tmpl' => {
    'Create a new user account for \'' =>
      'Create a new user account for \'',
    'To create your account, you must enter a password in the form below. Your email address and Real Name (if provided) will be shown with changes you make.' =>
      'To create your account, you must enter a password in the form below. Your email address and Real Name (if provided) will be shown with changes you make.',
    'Email Address:' =>
      'Email Address:',
    '<i>(OPTIONAL)</i>' =>
      '<i>(OPTIONAL)</i>',
    'Real Name' =>
      'Real Name',
    'Type your password' =>
      'Type your password',
    '(minimum' =>
      '(minimum',
    'characters)' =>
      'characters)',
    'Confirm your password' =>
      'Confirm your password',
    'Send' =>
      'Send',
    'This account will not be created if this form is not completed by <u>' =>
      'This account will not be created if this form is not completed by <u>',
    'If you do not wish to create an account with this email click the cancel account button below and your details will be forgotten.' =>
      'If you do not wish to create an account with this email click the cancel account button below and your details will be forgotten.',
    'Cancel Account' =>
      'Cancel Account',
  },
  'account/email/confirm.html.tmpl' => {
    'Confirm Change Email' =>
      'Confirm Change Email',
    'To change your email address, please enter the old email address:' =>
      'To change your email address, please enter the old email address:',
    'Old Email Address:' =>
      'Old Email Address:',
    'Submit' =>
      'Submit',
  },
  'account/email/request-new.txt.tmpl' => {
    '$terms.Bugzilla: confirm account creation' =>
      '$terms.Bugzilla: confirm account creation',
    '$terms.Bugzilla has received a request to create a user account using your email address (' =>
      '$terms.Bugzilla has received a request to create a user account using your email address (',
    'To continue creating an account using this email address, visit the following link by' =>
      'To continue creating an account using this email address, visit the following link by',
    'If you did not receive this email before' =>
      'If you did not receive this email before',
    'or you wish to create an account using a different email address you can begin again by going to:' =>
      'or you wish to create an account using a different email address you can begin again by going to:',
    'PRIVACY NOTICE: $terms.Bugzilla is an open $terms.bug tracking system. Activity on most $terms.bugs, including email addresses, will be visible to the public. We recommend using a secondary account or free web email service (such as Gmail, Yahoo, Hotmail, or similar) to avoid receiving spam at your primary email address.' =>
      'PRIVACY NOTICE: $terms.Bugzilla is an open $terms.bug tracking system. Activity on most $terms.bugs, including email addresses, will be visible to the public. We recommend using a secondary account or free web email service (such as Gmail, Yahoo, Hotmail, or similar) to avoid receiving spam at your primary email address.',
    'If you do not wish to create an account, or if this request was made in error you can do nothing or visit the following link:' =>
      'If you do not wish to create an account, or if this request was made in error you can do nothing or visit the following link:',
    'If the above links do not work, or you have any other issues regarding your account, please contact administration at' =>
      'If the above links do not work, or you have any other issues regarding your account, please contact administration at',
  },
  'account/password/forgotten-password.txt.tmpl' => {
    '$terms.Bugzilla Change Password Request' =>
      '$terms.Bugzilla Change Password Request',
    'You have (or someone impersonating you has) requested to change your $terms.Bugzilla password. To complete the change, visit the following link:' =>
      'You have (or someone impersonating you has) requested to change your $terms.Bugzilla password. To complete the change, visit the following link:',
    'If you are not the person who made this request, or you wish to cancel this request, visit the following link:' =>
      'If you are not the person who made this request, or you wish to cancel this request, visit the following link:',
    'If you do nothing, the request will lapse after' =>
      'If you do nothing, the request will lapse after',
    'days (on' =>
      'days (on',
    ') or when you log in successfully.' =>
      ') or when you log in successfully.',
  },
  'account/password/set-forgotten-password.html.tmpl' => {
    'Change Password' =>
      'Change Password',
    'To change your password, enter a new password twice:' =>
      'To change your password, enter a new password twice:',
    'New Password:' =>
      'New Password:',
    '(minimum' =>
      '(minimum',
    'characters)' =>
      'characters)',
    'New Password Again:' =>
      'New Password Again:',
    'Submit' =>
      'Submit',
  },
  'account/prefs/account.html.tmpl' => {
    'Please enter your existing password to confirm account changes.' =>
      'Please enter your existing password to confirm account changes.',
    'Password:' =>
      'Password:',
    'New password:' =>
      'New password:',
    'Confirm new password:' =>
      'Confirm new password:',
    'Your real name (optional, but encouraged):' =>
      'Your real name (optional, but encouraged):',
    'Pending email address:' =>
      'Pending email address:',
    'Change request expires:' =>
      'Change request expires:',
    'Confirmed email address:' =>
      'Confirmed email address:',
    'Completion date:' =>
      'Completion date:',
    'New email address:' =>
      'New email address:',
  },
  'account/prefs/email.html.tmpl' => {
    'If you don\'t like getting a notification for "trivial" changes to $terms.bugs, you can use the settings below to filter some or all notifications.' =>
      'If you don\'t like getting a notification for "trivial" changes to $terms.bugs, you can use the settings below to filter some or all notifications.',
    'Enable All Mail' =>
      'Enable All Mail',
    'Disable All Mail' =>
      'Disable All Mail',
    '<b>Global options:</b>' =>
      '<b>Global options:</b>',
    'Email me when someone asks me to set a flag' =>
      'Email me when someone asks me to set a flag',
    'Email me when someone sets a flag I asked for' =>
      'Email me when someone sets a flag I asked for',
    'You are watching all $terms.bugs. To be removed from this role, contact' =>
      'You are watching all $terms.bugs. To be removed from this role, contact',
    '<b>Field/recipient specific options:</b>' =>
      '<b>Field/recipient specific options:</b>',
    'I\'m added to or removed from this capacity' =>
      'I\'m added to or removed from this capacity',
    'A new $terms.bug is created' =>
      'A new $terms.bug is created',
    'The $terms.bug is resolved or reopened' =>
      'The $terms.bug is resolved or reopened',
    'The priority, status, severity, or milestone changes' =>
      'The priority, status, severity, or milestone changes',
    'New comments are added' =>
      'New comments are added',
    'New attachments are added' =>
      'New attachments are added',
    'Some attachment data changes' =>
      'Some attachment data changes',
    'The keywords field changes' =>
      'The keywords field changes',
    'The CC field changes' =>
      'The CC field changes',
    'The dependency tree changes' =>
      'The dependency tree changes',
    'Any field not mentioned above changes' =>
      'Any field not mentioned above changes',
    'A blocking bug is reopened or closed' =>
      'A blocking bug is reopened or closed',
    'The $terms.bug is in the unconfirmed state' =>
      'The $terms.bug is in the unconfirmed state',
    'The change was made by me' =>
      'The change was made by me',
    'Assignee' =>
      'Assignee',
    'QA Contact' =>
      'QA Contact',
    'Reporter' =>
      'Reporter',
    'CCed' =>
      'CCed',
    'Voter' =>
      'Voter',
    'When my relationship to this $terms.bug is:' =>
      'When my relationship to this $terms.bug is:',
    'I want to receive mail when:' =>
      'I want to receive mail when:',
    'but not when (overrides above):' =>
      'but not when (overrides above):',
    '<b>User Watching</b>' =>
      '<b>User Watching</b>',
    'If you watch a user, it is as if you are standing in their shoes for the purposes of getting email. Email is sent or not according to <u>your</u> preferences for <u>their</u> relationship to the $terms.bug (e.g. Assignee).' =>
      'If you watch a user, it is as if you are standing in their shoes for the purposes of getting email. Email is sent or not according to <u>your</u> preferences for <u>their</u> relationship to the $terms.bug (e.g. Assignee).',
    'You are watching everyone in the following list:' =>
      'You are watching everyone in the following list:',
    'Remove selected users from my watch list' =>
      'Remove selected users from my watch list',
    'You are currently not watching any users.' =>
      'You are currently not watching any users.',
    'Add users to my watch list (comma separated list)' =>
      'Add users to my watch list (comma separated list)',
    'Users watching you' =>
      'Users watching you',
    'Remove selected users watching me' =>
      'Remove selected users watching me',
    '<i>No one</i>' =>
      '<i>No one</i>',
    'Add users to watch me (comma separated list)' =>
      'Add users to watch me (comma separated list)',
    'No users found' =>
      'No users found',
  },
  'account/prefs/group-list.html.tmpl' => {
    ' access' =>
      ' access',
    'Optional ' =>
      'Optional ',
    ' edit access' =>
      ' edit access',
    'Product administration' =>
      'Product administration',
    'Bug field change access' =>
      'Bug field change access',
    ' confirm access' =>
      ' confirm access',
    'Used as \'chartgroup\'. Allows to use' =>
      'Used as \'chartgroup\'. Allows to use',
    'New Charts' =>
      'New Charts',
    'Used as \'insidergroup\'. Allows to see private comments and attachments.' =>
      'Used as \'insidergroup\'. Allows to see private comments and attachments.',
    'Used as \'querysharegroup\'. Allows to' =>
      'Used as \'querysharegroup\'. Allows to',
    'share Saved Searches' =>
      'share Saved Searches',
    'with other users.' =>
      'with other users.',
    'Used as \'timetrackinggroup\'. Allows to register add see working time for $terms.bugs.' =>
      'Used as \'timetrackinggroup\'. Allows to register add see working time for $terms.bugs.',
    '<b>System groups</b> just grant you some system-wide permission.' =>
      '<b>System groups</b> just grant you some system-wide permission.',
    '<b>$terms.Bug groups</b> are configured by $terms.Bugzilla administrators to grant you some per-product permissions. Note that several groups may restrict access to a single product; in this case you must be a member of <b>all</b> of them to see $terms.bugs in that product.' =>
      '<b>$terms.Bug groups</b> are configured by $terms.Bugzilla administrators to grant you some per-product permissions. Note that several groups may restrict access to a single product; in this case you must be a member of <b>all</b> of them to see $terms.bugs in that product.',
    ' group' =>
      ' group',
    'System group' =>
      'System group',
    'Description' =>
      'Description',
    'Product permissions' =>
      'Product permissions',
  },
  'account/prefs/permissions.html.tmpl' => {
    ' either' =>
      ' either',
    'You are' =>
      'You are',
    ' and/or can include/exclude other users from them (clickable groups are editable)' =>
      ' and/or can include/exclude other users from them (clickable groups are editable)',
    'a member of the following groups' =>
      'a member of the following groups',
    'You are not a member of any $terms.Bugzilla groups. This means you have default (or no) permissions for most $terms.bugs, and no administrative permissions.' =>
      'You are not a member of any $terms.Bugzilla groups. This means you have default (or no) permissions for most $terms.bugs, and no administrative permissions.',
  },
  'account/prefs/prefs.html.tmpl' => {
    'User Preferences' =>
      'User Preferences',
    'General Preferences' =>
      'General Preferences',
    'Email Preferences' =>
      'Email Preferences',
    'saved-searches' =>
      'saved-searches',
    'Saved Searches' =>
      'Saved Searches',
    'Name and Password' =>
      'Name and Password',
    'Permissions' =>
      'Permissions',
    'The changes to your' =>
      'The changes to your',
    'have been saved.' =>
      'have been saved.',
    'An email has been sent to both old and new email addresses to confirm the change of email address.' =>
      'An email has been sent to both old and new email addresses to confirm the change of email address.',
    'Submit Changes' =>
      'Submit Changes',
  },
  'account/prefs/saved-searches.html.tmpl' => {
    'Your saved searches are as follows:' =>
      'Your saved searches are as follows:',
    'Search' =>
      'Search',
    'Run' =>
      'Run',
    'Edit' =>
      'Edit',
    'Forget' =>
      'Forget',
    'Show in Footer' =>
      'Show in Footer',
    'Share With a Group' =>
      'Share With a Group',
    'My $terms.Bugs' =>
      'My $terms.Bugs',
    'Remove from' =>
      'Remove from',
    'whining' =>
      'whining',
    ' and ' =>
      ' and ',
    'checkers' =>
      'checkers',
    'first' =>
      'first',
    'Don\'t share' =>
      'Don\'t share',
    'Add to footer' =>
      'Add to footer',
    '(shared with' =>
      '(shared with',
    'Note that for every search that has the "Add to footer" selected, a link to the shared search is added to the footer of every user that is a direct member of the group at the time you click Submit Changes.' =>
      'Note that for every search that has the "Add to footer" selected, a link to the shared search is added to the footer of every user that is a direct member of the group at the time you click Submit Changes.',
    'Add Bookmark' =>
      'Add Bookmark',
    'You may remember an arbitrary URL as a saved search:' =>
      'You may remember an arbitrary URL as a saved search:',
    'Name:' =>
      'Name:',
    '&nbsp; URL:' =>
      '&nbsp; URL:',
    'Shared Searches' =>
      'Shared Searches',
    'You may use these searches saved and shared by others:' =>
      'You may use these searches saved and shared by others:',
    'Shared By' =>
      'Shared By',
    'Shared To' =>
      'Shared To',
    'No searches are shared with you by other users.' =>
      'No searches are shared with you by other users.',
  },
  'account/prefs/settings.html.tmpl' => {
    'All user preferences have been disabled by the' =>
      'All user preferences have been disabled by the',
    'maintainer' =>
      'maintainer',
    'of this installation, and so you cannot customize any.' =>
      'of this installation, and so you cannot customize any.',
    'Site Default (' =>
      'Site Default (',
  },
  'account/profile-activity.html.tmpl' => {
    'Account History for \'' =>
      'Account History for \'',
    'Who' =>
      'Who',
    'When' =>
      'When',
    'What' =>
      'What',
    'Removed' =>
      'Removed',
    'Added' =>
      'Added',
    'Edit user ' =>
      'Edit user ',
    'Edit this user' =>
      'Edit this user',
    'Search For Users' =>
      'Search For Users',
    'or' =>
      'or',
    'search for other accounts' =>
      'search for other accounts',
    'Return to the user list' =>
      'Return to the user list',
    'or go' =>
      'or go',
    'back to the user list' =>
      'back to the user list',
  },
  'admin/admin.html.tmpl' => {
    'Administer your installation (Bugzilla4Intranet' =>
      'Administer your installation (Bugzilla4Intranet',
    'This page is only accessible to empowered users. You can access administrative pages from here (based on your privileges), letting you configure different aspects of this installation. Note: some sections may not be accessible to you and are marked using a lighter color.' =>
      'This page is only accessible to empowered users. You can access administrative pages from here (based on your privileges), letting you configure different aspects of this installation. Note: some sections may not be accessible to you and are marked using a lighter color.',
    'Parameters' =>
      'Parameters',
    'Set core parameters of the installation. That\'s the place where you specify the URL to access this installation, determine how users authenticate, choose which $terms.bug fields to display, select the mail transfer agent to send email notifications, choose which group of users can use charts and share queries, and much more.' =>
      'Set core parameters of the installation. That\'s the place where you specify the URL to access this installation, determine how users authenticate, choose which $terms.bug fields to display, select the mail transfer agent to send email notifications, choose which group of users can use charts and share queries, and much more.',
    'Default Preferences' =>
      'Default Preferences',
    'Set the default user preferences. These are the values which will be used by default for all users. Users will be able to edit their own preferences from the' =>
      'Set the default user preferences. These are the values which will be used by default for all users. Users will be able to edit their own preferences from the',
    'Preferences' =>
      'Preferences',
    'Sanity Check' =>
      'Sanity Check',
    'Run sanity checks to locate problems in your database. This may take several tens of minutes depending on the size of your installation. You can also automate this check by running' =>
      'Run sanity checks to locate problems in your database. This may take several tens of minutes depending on the size of your installation. You can also automate this check by running',
    'from a cron job. A notification will be sent per email to the specified user if errors are detected.' =>
      'from a cron job. A notification will be sent per email to the specified user if errors are detected.',
    'Users' =>
      'Users',
    'Create new user accounts or edit existing ones. You can also add and remove users from groups (also known as "user privileges").' =>
      'Create new user accounts or edit existing ones. You can also add and remove users from groups (also known as "user privileges").',
    'Classifications' =>
      'Classifications',
    'If your installation has to manage many products at once, it\'s a good idea to group these products into distinct categories. This lets users find information more easily when doing searches or when filing new $terms.bugs.' =>
      'If your installation has to manage many products at once, it\'s a good idea to group these products into distinct categories. This lets users find information more easily when doing searches or when filing new $terms.bugs.',
    'Products' =>
      'Products',
    'Edit all aspects of products, including group restrictions which let you define who can access $terms.bugs being in these products. You can also edit some specific attributes of products such as' =>
      'Edit all aspects of products, including group restrictions which let you define who can access $terms.bugs being in these products. You can also edit some specific attributes of products such as',
    'components' =>
      'components',
    'versions' =>
      'versions',
    'and' =>
      'and',
    'milestones' =>
      'milestones',
    'directly.' =>
      'directly.',
    'Flags' =>
      'Flags',
    'A flag is a custom 4-states attribute of $terms.bugs and/or attachments. These states are: granted, denied, requested and undefined. You can set as many flags as desired per $terms.bug, and define which users are allowed to edit them.' =>
      'A flag is a custom 4-states attribute of $terms.bugs and/or attachments. These states are: granted, denied, requested and undefined. You can set as many flags as desired per $terms.bug, and define which users are allowed to edit them.',
    '$terms.Bug Fields' =>
      '$terms.Bug Fields',
    'Edit properties of existing $terms.bug fields, disable them or define new ones.' =>
      'Edit properties of existing $terms.bug fields, disable them or define new ones.',
    '$terms.Bugzilla lets you define complex relationships between fields, disable some standard fields and even create your own "custom" ones which can then be used just like any other field.' =>
      '$terms.Bugzilla lets you define complex relationships between fields, disable some standard fields and even create your own "custom" ones which can then be used just like any other field.',
    'Field Values' =>
      'Field Values',
    'Define legal values for fields whose values must belong to some given list. This is also the place where you define legal values for some types of custom fields.' =>
      'Define legal values for fields whose values must belong to some given list. This is also the place where you define legal values for some types of custom fields.',
    '$terms.Bug Status Workflow' =>
      '$terms.Bug Status Workflow',
    'Customize your workflow and choose initial $terms.bug statuses available on $terms.bug creation and allowed $terms.bug status transitions when editing existing $terms.bugs.' =>
      'Customize your workflow and choose initial $terms.bug statuses available on $terms.bug creation and allowed $terms.bug status transitions when editing existing $terms.bugs.',
    'Groups' =>
      'Groups',
    'Add/remove users in groups you are allowed to do so.' =>
      'Add/remove users in groups you are allowed to do so.',
    'Define groups which will be used in the installation. They can either be used to define new user privileges or to restrict the access to some $terms.bugs.' =>
      'Define groups which will be used in the installation. They can either be used to define new user privileges or to restrict the access to some $terms.bugs.',
    'Keywords' =>
      'Keywords',
    'Set keywords to be used with $terms.bugs. Keywords are an easy way to "tag" $terms.bugs to let you find them more easily later.' =>
      'Set keywords to be used with $terms.bugs. Keywords are an easy way to "tag" $terms.bugs to let you find them more easily later.',
    'Whining' =>
      'Whining',
    'Set queries which will be run at some specified date and time, and get the result of these queries directly per email. This is a good way to create reminders and to keep track of the activity in your installation.' =>
      'Set queries which will be run at some specified date and time, and get the result of these queries directly per email. This is a good way to create reminders and to keep track of the activity in your installation.',
    'Checkers' =>
      'Checkers',
    'Set queries which will be run at each bug change and used as predicates for checking change correctness.' =>
      'Set queries which will be run at each bug change and used as predicates for checking change correctness.',
  },
  'admin/classifications/del.html.tmpl' => {
    'Delete classification' =>
      'Delete classification',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Classification:' =>
      'Classification:',
    'Description:' =>
      'Description:',
    'description missing' =>
      'description missing',
    'Sortkey:' =>
      'Sortkey:',
    'Confirmation' =>
      'Confirmation',
    'Do you really want to delete this classification?' =>
      'Do you really want to delete this classification?',
  },
  'admin/classifications/edit.html.tmpl' => {
    'Edit classification ' =>
      'Edit classification ',
    'Add classification' =>
      'Add classification',
    'Classification:' =>
      'Classification:',
    'Description:' =>
      'Description:',
    'Sortkey:' =>
      'Sortkey:',
    'Edit Products' =>
      'Edit Products',
    'description missing' =>
      'description missing',
    'none' =>
      'none',
    'Update' =>
      'Update',
    'Add' =>
      'Add',
  },
  'admin/classifications/footer.html.tmpl' => {
    'Back to the' =>
      'Back to the',
    'main $terms.bugs page' =>
      'main $terms.bugs page',
    'or' =>
      'or',
    'edit' =>
      'edit',
    'more classifications.' =>
      'more classifications.',
  },
  'admin/classifications/reclassify.html.tmpl' => {
    'Reclassify products' =>
      'Reclassify products',
    'Classification:' =>
      'Classification:',
    'Description:' =>
      'Description:',
    'description missing' =>
      'description missing',
    'Sortkey:' =>
      'Sortkey:',
    'Products:' =>
      'Products:',
    'Other Classifications' =>
      'Other Classifications',
    'This Classification' =>
      'This Classification',
  },
  'admin/classifications/select.html.tmpl' => {
    'Select classification' =>
      'Select classification',
    'Edit Classification ...' =>
      'Edit Classification ...',
    'Description' =>
      'Description',
    'Sortkey' =>
      'Sortkey',
    'Products' =>
      'Products',
    'Action' =>
      'Action',
    'none' =>
      'none',
    'reclassify (' =>
      'reclassify (',
    'delete' =>
      'delete',
    'Add a new classification' =>
      'Add a new classification',
  },
  'admin/components/confirm-delete.html.tmpl' => {
    'Delete component \'' =>
      'Delete component \'',
    '\' from \'' =>
      '\' from \'',
    '\' product' =>
      '\' product',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Component:' =>
      'Component:',
    'Component Description:' =>
      'Component Description:',
    'Default assignee:' =>
      'Default assignee:',
    'Default QA contact:' =>
      'Default QA contact:',
    'Component of Product:' =>
      'Component of Product:',
    'Product Description:' =>
      'Product Description:',
    'Open for $terms.bugs:' =>
      'Open for $terms.bugs:',
    'Yes' =>
      'Yes',
    'No' =>
      'No',
    'List of $terms.bugs for component ' =>
      'List of $terms.bugs for component ',
    'None' =>
      'None',
    'Confirmation' =>
      'Confirmation',
    'Sorry, there' =>
      'Sorry, there',
    'are' =>
      'are',
    'is' =>
      'is',
    'outstanding for this component. You must reassign' =>
      'outstanding for this component. You must reassign',
    'those $terms.bugs' =>
      'those $terms.bugs',
    'that $terms.bug' =>
      'that $terms.bug',
    'to another component before you can delete this one.' =>
      'to another component before you can delete this one.',
    'There' =>
      'There',
    'is 1 $terms.bug' =>
      'is 1 $terms.bug',
    'entered for this component! When you delete this component, <b>' =>
      'entered for this component! When you delete this component, <b>',
    'ALL' =>
      'ALL',
    '</b> stored $terms.bugs and their history will be deleted too.' =>
      '</b> stored $terms.bugs and their history will be deleted too.',
    'Do you really want to delete this component?' =>
      'Do you really want to delete this component?',
    'Yes, delete' =>
      'Yes, delete',
  },
  'admin/components/edit.html.tmpl' => {
    'Edit component \'' =>
      'Edit component \'',
    '\' of product \'' =>
      '\' of product \'',
    'Add component to the' =>
      'Add component to the',
    'product' =>
      'product',
    'Component:' =>
      'Component:',
    'Description:' =>
      'Description:',
    'Default Assignee:' =>
      'Default Assignee:',
    'Default QA contact:' =>
      'Default QA contact:',
    'Default CC List:' =>
      'Default CC List:',
    '<em>Enter user names for the CC list as a comma-separated list.</em>' =>
      '<em>Enter user names for the CC list as a comma-separated list.</em>',
    'Open for $terms.bug entry:' =>
      'Open for $terms.bug entry:',
    'Wiki URL:' =>
      'Wiki URL:',
    '<em>Or use product setting when empty.</em>' =>
      '<em>Or use product setting when empty.</em>',
    '$terms.Bugs in component ' =>
      '$terms.Bugs in component ',
    'None' =>
      'None',
    'Save Changes' =>
      'Save Changes',
    'Add Component' =>
      'Add Component',
    'or' =>
      'or',
    'Delete' =>
      'Delete',
    'this component.' =>
      'this component.',
  },
  'admin/components/footer.html.tmpl' => {
    'Edit' =>
      'Edit',
    'Edit Component ' =>
      'Edit Component ',
    'component' =>
      'component',
    'or edit' =>
      'or edit',
    'Choose a component from product ' =>
      'Choose a component from product ',
    'other components of product' =>
      'other components of product',
    ', or edit' =>
      ', or edit',
    'Edit Product ' =>
      'Edit Product ',
    'product' =>
      'product',
  },
  'admin/components/list.html.tmpl' => {
    'Select component of product \'' =>
      'Select component of product \'',
    'Edit component...' =>
      'Edit component...',
    'Description' =>
      'Description',
    'Default Assignee' =>
      'Default Assignee',
    'Wiki URL' =>
      'Wiki URL',
    'Active' =>
      'Active',
    'QA Contact' =>
      'QA Contact',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    'Add' =>
      'Add',
    'a new component to product \'' =>
      'a new component to product \'',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/components/select-product.html.tmpl' => {
    'Edit components for which product?' =>
      'Edit components for which product?',
    'Edit components of...' =>
      'Edit components of...',
    'Description' =>
      'Description',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/confirm-action.html.tmpl' => {
    'Suspicious Action' =>
      'Suspicious Action',
    'When you view an administrative form in $terms.Bugzilla, a token string is randomly generated and stored both in the database and in the form you loaded, to make sure that the requested changes are being made as a result of submitting a form generated by $terms.Bugzilla. Unfortunately, the token used right now is incorrect, meaning that it looks like you didn\'t come from the right page. The following token has been used :' =>
      'When you view an administrative form in $terms.Bugzilla, a token string is randomly generated and stored both in the database and in the form you loaded, to make sure that the requested changes are being made as a result of submitting a form generated by $terms.Bugzilla. Unfortunately, the token used right now is incorrect, meaning that it looks like you didn\'t come from the right page. The following token has been used :',
    'Action&nbsp;stored:' =>
      'Action&nbsp;stored:',
    'This action doesn\'t match the one expected (' =>
      'This action doesn\'t match the one expected (',
    'Generated&nbsp;by:' =>
      'Generated&nbsp;by:',
    'This token has not been generated by you. It is possible that someone tried to trick you!' =>
      'This token has not been generated by you. It is possible that someone tried to trick you!',
    'Please report this problem to' =>
      'Please report this problem to',
    'It looks like you didn\'t come from the right page (you have no valid token for the <em>' =>
      'It looks like you didn\'t come from the right page (you have no valid token for the <em>',
    '</em> action while processing the \'' =>
      '</em> action while processing the \'',
    '\' script). The reason could be one of:' =>
      '\' script). The reason could be one of:',
    'You clicked the "Back" button of your web browser after having successfully submitted changes, which is generally not a good idea (but harmless).' =>
      'You clicked the "Back" button of your web browser after having successfully submitted changes, which is generally not a good idea (but harmless).',
    'You entered the URL in the address bar of your web browser directly, which should be safe.' =>
      'You entered the URL in the address bar of your web browser directly, which should be safe.',
    'You clicked on a URL which redirected you here <b>without your consent</b>, in which case this action is much more critical.' =>
      'You clicked on a URL which redirected you here <b>without your consent</b>, in which case this action is much more critical.',
    'Are you sure you want to commit these changes anyway? This may result in unexpected and undesired results.' =>
      'Are you sure you want to commit these changes anyway? This may result in unexpected and undesired results.',
    'Confirm Changes' =>
      'Confirm Changes',
    'Or throw away these changes and go back to' =>
      'Or throw away these changes and go back to',
  },
  'admin/custom_fields/confirm-changes.html.tmpl' => {
    'Confirm Changes' =>
      'Confirm Changes',
    'Warning: value dependencies are set for' =>
      'Warning: value dependencies are set for',
    'values of' =>
      'values of',
    'field. They will be <b>lost</b> when changing value controlling field.' =>
      'field. They will be <b>lost</b> when changing value controlling field.',
    'Warning: default' =>
      'Warning: default',
    'values are set for' =>
      'values are set for',
    'field. They will be <b>lost</b> when changing default controlling field.' =>
      'field. They will be <b>lost</b> when changing default controlling field.',
    'Clear dependencies and save changes' =>
      'Clear dependencies and save changes',
  },
  'admin/custom_fields/confirm-delete.html.tmpl' => {
    'Delete the Custom Field \'' =>
      'Delete the Custom Field \'',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Custom Field:' =>
      'Custom Field:',
    'Description:' =>
      'Description:',
    'Type:' =>
      'Type:',
    'Confirmation' =>
      'Confirmation',
    'Are you sure you want to remove this field from the database?' =>
      'Are you sure you want to remove this field from the database?',
    '<em>This action will only be successful if the field is obsolete, and cleared in all' =>
      '<em>This action will only be successful if the field is obsolete, and cleared in all',
    'Delete field \'' =>
      'Delete field \'',
    'Back to the list of existing custom fields' =>
      'Back to the list of existing custom fields',
  },
  'admin/custom_fields/edit.html.tmpl' => {
    'Custom' =>
      'Custom',
    'Edit the' =>
      'Edit the',
    'field \'' =>
      'field \'',
    'Add a new Custom Field' =>
      'Add a new Custom Field',
    'Adding custom fields can make the interface of $terms.Bugzilla very complicated. Many admins who are new to $terms.Bugzilla start off adding many custom fields, and then their users complain that the interface is "too complex". Please think carefully before adding any custom fields. It may be the case that $terms.Bugzilla already does what you need, and you just haven\'t enabled the correct feature yet.' =>
      'Adding custom fields can make the interface of $terms.Bugzilla very complicated. Many admins who are new to $terms.Bugzilla start off adding many custom fields, and then their users complain that the interface is "too complex". Please think carefully before adding any custom fields. It may be the case that $terms.Bugzilla already does what you need, and you just haven\'t enabled the correct feature yet.',
    'Custom field names must begin with "cf_" to distinguish them from standard fields. If you omit "cf_" from the beginning of the name, it will be added for you.' =>
      'Custom field names must begin with "cf_" to distinguish them from standard fields. If you omit "cf_" from the beginning of the name, it will be added for you.',
    'Descriptions are a very short string describing the field and will be used as the label for this field in the user interface.' =>
      'Descriptions are a very short string describing the field and will be used as the label for this field in the user interface.',
    'If this field is enabled, $terms.Bugzilla will associate each product with a specific classification.' =>
      'If this field is enabled, $terms.Bugzilla will associate each product with a specific classification.',
    'But you must have \'editclassification\' permissions enabled in order to edit classifications.' =>
      'But you must have \'editclassification\' permissions enabled in order to edit classifications.',
    'If this field is enabled, users will be allowed to vote for $terms.bugs.' =>
      'If this field is enabled, users will be allowed to vote for $terms.bugs.',
    'Note that in order for this to be effective, you will have to change the maximum votes allowed in a product to be non-zero in' =>
      'Note that in order for this to be effective, you will have to change the maximum votes allowed in a product to be non-zero in',
    'the product edit page' =>
      'the product edit page',
    'Enabling this field allows you to assign $terms.bugs "aliases", which are easy-to-remember names by which you can refer to $terms.bugs.' =>
      'Enabling this field allows you to assign $terms.bugs "aliases", which are easy-to-remember names by which you can refer to $terms.bugs.',
    'Enabling See Also field allows you to refer to $terms.bugs in other installations.' =>
      'Enabling See Also field allows you to refer to $terms.bugs in other installations.',
    'Even if you disable this field, $terms.bug relationships (URLs) which are already set will still appear and can be removed.' =>
      'Even if you disable this field, $terms.bug relationships (URLs) which are already set will still appear and can be removed.',
    'Name:' =>
      'Name:',
    'Title:' =>
      'Title:',
    'Sortkey:' =>
      'Sortkey:',
    '1000-1999: second column' =>
      '1000-1999: second column',
    '2000-2999: third column' =>
      '2000-2999: third column',
    '>= 3000: 4th column' =>
      '>= 3000: 4th column',
    'Type:' =>
      'Type:',
    'Deps:' =>
      'Deps:',
    'Do not add' =>
      'Do not add',
    'Add field value to blocked' =>
      'Add field value to blocked',
    'Add field value to blockers' =>
      'Add field value to blockers',
    'Edit legal values for this field' =>
      'Edit legal values for this field',
    'URL:' =>
      'URL:',
    '<i>This field will link to this URL with $1' =>
      '<i>This field will link to this URL with $1',
    'replaced by the field value.</i>' =>
      'replaced by the field value.</i>',
    'Displayed in $terms.bugmail for new $terms.bugs:' =>
      'Displayed in $terms.bugmail for new $terms.bugs:',
    'Is copied into the cloned $terms.bug:' =>
      'Is copied into the cloned $terms.bug:',
    'Is disabled:' =>
      'Is disabled:',
    'Default value:' =>
      'Default value:',
    'Allow empty value:' =>
      'Allow empty value:',
    'Show/hide the field depending on the value of:' =>
      'Show/hide the field depending on the value of:',
    'Allow empty value depending on the value of:' =>
      'Allow empty value depending on the value of:',
    'Clone field depending on the value of:' =>
      'Clone field depending on the value of:',
    'Make default value dependent on the value of:' =>
      'Make default value dependent on the value of:',
    'Field that controls the values that appear in this field:' =>
      'Field that controls the values that appear in this field:',
    'Direct Bug ID field for this reverse one:' =>
      'Direct Bug ID field for this reverse one:',
    'Show the field only if' =>
      'Show the field only if',
    'is set to:' =>
      'is set to:',
    'Allow empty value only if' =>
      'Allow empty value only if',
    'Clone field only if' =>
      'Clone field only if',
    'of the cloned $terms.bug is set to:' =>
      'of the cloned $terms.bug is set to:',
    'Save' =>
      'Save',
    'Create' =>
      'Create',
    'Remove this custom field from the database.' =>
      'Remove this custom field from the database.',
    'This action will only be successful if the custom field is cleared in all $terms.bugs.' =>
      'This action will only be successful if the custom field is cleared in all $terms.bugs.',
    'Back to the list of existing fields' =>
      'Back to the list of existing fields',
  },
  'admin/custom_fields/list.html.tmpl' => {
    'Custom Fields' =>
      'Custom Fields',
    'Edit custom field...' =>
      'Edit custom field...',
    'Description' =>
      'Description',
    'Sortkey' =>
      'Sortkey',
    'Type' =>
      'Type',
    'Included in $terms.bugmail for new $terms.bugs' =>
      'Included in $terms.bugmail for new $terms.bugs',
    'Yes' =>
      'Yes',
    'Cloned' =>
      'Cloned',
    'Is copied into the cloned bug' =>
      'Is copied into the cloned bug',
    'Nullable' =>
      'Nullable',
    'Allows empty (NULL) value' =>
      'Allows empty (NULL) value',
    'Disabled' =>
      'Disabled',
    'Is disabled and unused' =>
      'Is disabled and unused',
    'Yes, Delete' =>
      'Yes, Delete',
    'Custom fields' =>
      'Custom fields',
    'WARNING: Before creating new fields, keep in mind that too many fields may make the user interface more complex and harder to use.' =>
      'WARNING: Before creating new fields, keep in mind that too many fields may make the user interface more complex and harder to use.',
    'Be sure you have investigated other ways to satisfy your needs before doing this.' =>
      'Be sure you have investigated other ways to satisfy your needs before doing this.',
    'Add a new custom field' =>
      'Add a new custom field',
    'Standard fields' =>
      'Standard fields',
    'You can tweak the behaviour of standard $terms.Bugzilla fields in various ways: enable/disable them, set default values, allow or deny empty value, or even make some of them depend on other fields.' =>
      'You can tweak the behaviour of standard $terms.Bugzilla fields in various ways: enable/disable them, set default values, allow or deny empty value, or even make some of them depend on other fields.',
    'Look for "Yes/No/Always" and tooltips in the table below for details.' =>
      'Look for "Yes/No/Always" and tooltips in the table below for details.',
    'Edit standard field...' =>
      'Edit standard field...',
    'Default' =>
      'Default',
    'Can you select the default value for this field?' =>
      'Can you select the default value for this field?',
    'Values' =>
      'Values',
    'Can you make this field values to depend on other fields?' =>
      'Can you make this field values to depend on other fields?',
    'Visible' =>
      'Visible',
    'Can you show/hide this field depending on other fields?' =>
      'Can you show/hide this field depending on other fields?',
    'You can show/hide this field from new ' =>
      'You can show/hide this field from new ',
    ' mail' =>
      ' mail',
    'You can choose whether to copy this field when cloning ' =>
      'You can choose whether to copy this field when cloning ',
    'You can choose whether to allow this field to be empty' =>
      'You can choose whether to allow this field to be empty',
    'You can enable/disable this field' =>
      'You can enable/disable this field',
    'You can select the default value for this field and make the default value depend on other fields' =>
      'You can select the default value for this field and make the default value depend on other fields',
    'You can show or hide this field based on the value of some other field' =>
      'You can show or hide this field based on the value of some other field',
    'Always' =>
      'Always',
    'per-' =>
      'per-',
    'You can select the default value for this field globally ' =>
      'You can select the default value for this field globally ',
    'or per each ' =>
      'or per each ',
  },
  'admin/edit-checkers.html.tmpl' => {
    'Правка предикатов корректности изменений' =>
      'Правка предикатов корректности изменений',
    'Редактирование предикатов корректности' =>
      'Редактирование предикатов корректности',
    'Добавить новый предикат.' =>
      'Добавить новый предикат.',
    'Список определённых предикатов корректности:' =>
      'Список определённых предикатов корректности:',
    'Название поиска' =>
      'Название поиска',
    'Запрет' =>
      'Запрет',
    'Режим' =>
      'Режим',
    'Проверяются ли новые баги?' =>
      'Проверяются ли новые баги?',
    'C' =>
      'C',
    'Проверяются ли обновления багов?' =>
      'Проверяются ли обновления багов?',
    'U' =>
      'U',
    'Действия' =>
      'Действия',
    'Сообщение' =>
      'Сообщение',
    'Вообще не запрет, а триггер: при попадании под условия запроса в баг вносятся изменения' =>
      'Вообще не запрет, а триггер: при попадании под условия запроса в баг вносятся изменения',
    'Триггер' =>
      'Триггер',
    'Жёсткий запрет: При нарушении правила изменения блокируются и выдаётся ошибка' =>
      'Жёсткий запрет: При нарушении правила изменения блокируются и выдаётся ошибка',
    'Жёсткий' =>
      'Жёсткий',
    'Мягкий запрет: При нарушении правила выдаётся предупреждение, но изменение не блокируется' =>
      'Мягкий запрет: При нарушении правила выдаётся предупреждение, но изменение не блокируется',
    'Мягкий' =>
      'Мягкий',
    'Заморозка (защита от изменения)' =>
      'Заморозка (защита от изменения)',
    'Проверка корректности новых значений' =>
      'Проверка корректности новых значений',
    'Заморозка' =>
      'Заморозка',
    'Проверка' =>
      'Проверка',
    'править' =>
      'править',
    'выполнить поиск' =>
      'выполнить поиск',
    'править поиск' =>
      'править поиск',
    'удалить' =>
      'удалить',
    'Ещё не определено ни одного предиката корректности.' =>
      'Ещё не определено ни одного предиката корректности.',
    'Добавление нового предиката' =>
      'Добавление нового предиката',
    'Редактирование предиката' =>
      'Редактирование предиката',
    'Сохранённый запрос:' =>
      'Сохранённый запрос:',
    'Описание проверки:' =>
      'Описание проверки:',
    'Момент проверки:' =>
      'Момент проверки:',
    'Проверять создание новых багов (требуется «Запрещать изменения всех полей»)' =>
      'Проверять создание новых багов (требуется «Запрещать изменения всех полей»)',
    'Проверять изменения багов' =>
      'Проверять изменения багов',
    'Параметры:' =>
      'Параметры:',
    'Заморозка багов (защита от изменений, только для режима обновления)' =>
      'Заморозка багов (защита от изменений, только для режима обновления)',
    'Жёсткий запрет (если нет, то изменения не блокируются, а только даётся предупреждение)' =>
      'Жёсткий запрет (если нет, то изменения не блокируются, а только даётся предупреждение)',
    'Разрешить следующим пользователям обходить эту проверку:' =>
      'Разрешить следующим пользователям обходить эту проверку:',
    'Группа:' =>
      'Группа:',
    '&mdash; (не разрешать)' =>
      '&mdash; (не разрешать)',
    'Запреты изменений отдельных полей, действуют только при обновлении багов:' =>
      'Запреты изменений отдельных полей, действуют только при обновлении багов:',
    'Запрещать:' =>
      'Запрещать:',
    'Запрещать изменения всех полей' =>
      'Запрещать изменения всех полей',
    'Добавить отдельное поле' =>
      'Добавить отдельное поле',
    '<b>Подсказка:</b> в списке есть специальное поле "Backdated worktime", с помощью которого можно запретить вводить трудозатраты задним числом. Например, чтобы запретить вводить трудозатраты задним числом раньше 2010-09-01, нужно выбрать поле "Backdated worktime" и значение "2010-09-01". Пустое значение означает полный запрет ввода трудозатрат задним числом. Флажок "Запрещать изменения всех полей" должен быть <b>сброшен</b>.' =>
      '<b>Подсказка:</b> в списке есть специальное поле "Backdated worktime", с помощью которого можно запретить вводить трудозатраты задним числом. Например, чтобы запретить вводить трудозатраты задним числом раньше 2010-09-01, нужно выбрать поле "Backdated worktime" и значение "2010-09-01". Пустое значение означает полный запрет ввода трудозатрат задним числом. Флажок "Запрещать изменения всех полей" должен быть <b>сброшен</b>.',
    'Добавить CC:' =>
      'Добавить CC:',
    'Снять флаги (через ,):' =>
      'Снять флаги (через ,):',
    'Сохранить ' =>
      'Сохранить ',
    'поле:&nbsp;' =>
      'поле:&nbsp;',
    '&nbsp; новое&nbsp;значение:&nbsp;' =>
      '&nbsp; новое&nbsp;значение:&nbsp;',
    '(пусто=любое)' =>
      '(пусто=любое)',
    'Но разрешать:' =>
      'Но разрешать:',
    'Задайте действие триггера!' =>
      'Задайте действие триггера!',
    'wiki:[[Bugzilla: проверки изменений багов]]' =>
      'wiki:[[Bugzilla: проверки изменений багов]]',
  },
  'admin/editemailin.html.tmpl' => {
    'Edit incoming addresses of email_in.pl' =>
      'Edit incoming addresses of email_in.pl',
    'Group ID\'s to grant automatically' =>
      'Group ID\'s to grant automatically',
    'Field' =>
      'Field',
    'Value' =>
      'Value',
    'add a field value for this address' =>
      'add a field value for this address',
    'delete' =>
      'delete',
    'Save Changes' =>
      'Save Changes',
    'or' =>
      'or',
    'Add a new field value' =>
      'Add a new field value',
    'E-mail address:' =>
      'E-mail address:',
    'Field:' =>
      'Field:',
    'Value:' =>
      'Value:',
    'Add field' =>
      'Add field',
  },
  'admin/fieldvalues/confirm-delete.html.tmpl' => {
    'Delete Value "$1" from the field "$2" ($3)' =>
      'Delete Value "$1" from the field "$2" ($3)',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Field Name:' =>
      'Field Name:',
    'Field Value:' =>
      'Field Value:',
    'List of $terms.bugs where ' =>
      'List of $terms.bugs where ',
    'None' =>
      'None',
    'Confirmation' =>
      'Confirmation',
    'Sorry, but the \'' =>
      'Sorry, but the \'',
    '\' value cannot be deleted from the \'' =>
      '\' value cannot be deleted from the \'',
    '\' field for the following reason(s):' =>
      '\' field for the following reason(s):',
    '\' is the default value for the \'' =>
      '\' is the default value for the \'',
    '\' field.' =>
      '\' field.',
    'You first have to' =>
      'You first have to',
    'change the default value' =>
      'change the default value',
    'for this field before you can delete this value.' =>
      'for this field before you can delete this value.',
    'There are' =>
      'There are',
    '$terms.bugs with this field value.' =>
      '$terms.bugs with this field value.',
    'There is 1 $terms.bug with this field value.' =>
      'There is 1 $terms.bug with this field value.',
    'You must change the field value on' =>
      'You must change the field value on',
    'those $terms.bugs' =>
      'those $terms.bugs',
    'that $terms.bug' =>
      'that $terms.bug',
    'to another value before you can delete this value.' =>
      'to another value before you can delete this value.',
    'This value controls the visibility of the following fields:' =>
      'This value controls the visibility of the following fields:',
    'This value controls the visibility of the following values in other fields:' =>
      'This value controls the visibility of the following values in other fields:',
    'Do you really want to delete this value?' =>
      'Do you really want to delete this value?',
    'Yes, delete' =>
      'Yes, delete',
  },
  'admin/fieldvalues/control-list-common.html.tmpl' => {
    'Visible fields:' =>
      'Visible fields:',
    'Show these fields in this' =>
      'Show these fields in this',
    'Edit values:' =>
      'Edit values:',
    'Edit values of dependent fields for this' =>
      'Edit values of dependent fields for this',
    'Allow empty values:' =>
      'Allow empty values:',
    'Allow these fields to be empty in this' =>
      'Allow these fields to be empty in this',
    'Clone fields:' =>
      'Clone fields:',
    'Copy these fields when cloning from this' =>
      'Copy these fields when cloning from this',
    'Default values:' =>
      'Default values:',
    'Override default field values for new and moved $terms.bugs in this' =>
      'Override default field values for new and moved $terms.bugs in this',
  },
  'admin/fieldvalues/control-list.html.tmpl' => {
    'Select Active ' =>
      'Select Active ',
    ' Objects For ' =>
      ' Objects For ',
    'Active' =>
      'Active',
    'Value' =>
      'Value',
    'Edit this value' =>
      'Edit this value',
    'Save' =>
      'Save',
    'Edit or add' =>
      'Edit or add',
    'objects' =>
      'objects',
    'Edit product' =>
      'Edit product',
    'Edit classification' =>
      'Edit classification',
    'Edit milestone' =>
      'Edit milestone',
    'Edit version' =>
      'Edit version',
    'Edit component' =>
      'Edit component',
    'Edit' =>
      'Edit',
  },
  'admin/fieldvalues/edit.html.tmpl' => {
    'Edit Value \'' =>
      'Edit Value \'',
    '\' for the \'' =>
      '\' for the \'',
    ') field' =>
      ') field',
    'Add Value for the \'' =>
      'Add Value for the \'',
    'Field Value:' =>
      'Field Value:',
    'Sortkey:' =>
      'Sortkey:',
    'Is open:' =>
      'Is open:',
    'Is it an assigned state?' =>
      'Is it an assigned state?',
    'Is it a confirmed state?' =>
      'Is it a confirmed state?',
    'User Agent Regexp:' =>
      'User Agent Regexp:',
    'Enabled for $terms.bugs:' =>
      'Enabled for $terms.bugs:',
    '(this value is selected as default in the parameters for this field)' =>
      '(this value is selected as default in the parameters for this field)',
    'Description:' =>
      'Description:',
    'none' =>
      'none',
    'Only appears when' =>
      'Only appears when',
    'is set to:' =>
      'is set to:',
    'Save Changes' =>
      'Save Changes',
    'Add' =>
      'Add',
  },
  'admin/fieldvalues/footer.html.tmpl' => {
    'Add a value for the ' =>
      'Add a value for the ',
    'Add' =>
      'Add',
    'a value.' =>
      'a value.',
    'Edit value ' =>
      'Edit value ',
    'Edit value' =>
      'Edit value',
    'Edit other values for the' =>
      'Edit other values for the',
    'field.' =>
      'field.',
  },
  'admin/fieldvalues/list.html.tmpl' => {
    'Select value for the \'' =>
      'Select value for the \'',
    ') field' =>
      ') field',
    'Edit field value...' =>
      'Edit field value...',
    'Sortkey' =>
      'Sortkey',
    'Enabled' =>
      'Enabled',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    '(Default value)' =>
      '(Default value)',
    'Values for the \'' =>
      'Values for the \'',
    's must be edited from a product page.' =>
      's must be edited from a product page.',
    'Select a product' =>
      'Select a product',
    'first.' =>
      'first.',
  },
  'admin/fieldvalues/select-field.html.tmpl' => {
    'Edit values for which field?' =>
      'Edit values for which field?',
    'Edit field values for...' =>
      'Edit field values for...',
  },
  'admin/flag-type/confirm-delete.html.tmpl' => {
    'Confirm Deletion of Flag Type \'' =>
      'Confirm Deletion of Flag Type \'',
    'There are' =>
      'There are',
    'flags of type' =>
      'flags of type',
    '. If you delete this type, those flags will also be deleted.' =>
      '. If you delete this type, those flags will also be deleted.',
    'Note that instead of deleting the type you can' =>
      'Note that instead of deleting the type you can',
    'deactivate it' =>
      'deactivate it',
    ', in which case the type' =>
      ', in which case the type',
    'and its flags' =>
      'and its flags',
    'will remain in the database but will not appear in the $terms.Bugzilla UI.' =>
      'will remain in the database but will not appear in the $terms.Bugzilla UI.',
    'Do you really want to delete this type?' =>
      'Do you really want to delete this type?',
    'Yes, delete' =>
      'Yes, delete',
    'No, don\'t delete' =>
      'No, don\'t delete',
  },
  'admin/flag-type/edit.html.tmpl' => {
    'Create Flag Type for $terms.Bugs' =>
      'Create Flag Type for $terms.Bugs',
    'Create Flag Type for Attachments' =>
      'Create Flag Type for Attachments',
    'attachments' =>
      'attachments',
    'attachment' =>
      'attachment',
    'Create Flag Type Based on' =>
      'Create Flag Type Based on',
    'Edit Flag Type' =>
      'Edit Flag Type',
    'Submit' =>
      'Submit',
    'Name:' =>
      'Name:',
    'a short name identifying this type' =>
      'a short name identifying this type',
    'Description:' =>
      'Description:',
    'a comprehensive description of this type' =>
      'a comprehensive description of this type',
    'Category:' =>
      'Category:',
    'the products/components to which' =>
      'the products/components to which',
    'must (inclusions) or must not (exclusions) belong in order for users to be able to set flags of this type for them' =>
      'must (inclusions) or must not (exclusions) belong in order for users to be able to set flags of this type for them',
    '<b>Product/Component:</b>' =>
      '<b>Product/Component:</b>',
    'Include' =>
      'Include',
    'Exclude' =>
      'Exclude',
    '<b>Inclusions:</b>' =>
      '<b>Inclusions:</b>',
    'Remove Inclusion' =>
      'Remove Inclusion',
    '<b>Exclusions:</b>' =>
      '<b>Exclusions:</b>',
    'Remove Exclusion' =>
      'Remove Exclusion',
    'Sort Key:' =>
      'Sort Key:',
    'a number between 1 and 32767 by which this type will be sorted when displayed to users in a list; ignore if you don\'t care what order the types appear in or if you want them to appear in alphabetical order' =>
      'a number between 1 and 32767 by which this type will be sorted when displayed to users in a list; ignore if you don\'t care what order the types appear in or if you want them to appear in alphabetical order',
    'active (flags of this type appear in the UI and can be set)' =>
      'active (flags of this type appear in the UI and can be set)',
    'requestable (users can ask for flags of this type to be set)' =>
      'requestable (users can ask for flags of this type to be set)',
    'CC List:' =>
      'CC List:',
    'if requestable, who should get carbon copied on email notification of requests. This is a comma-separated list of full e-mail addresses which do not need to be $terms.Bugzilla logins.' =>
      'if requestable, who should get carbon copied on email notification of requests. This is a comma-separated list of full e-mail addresses which do not need to be $terms.Bugzilla logins.',
    'Note that the configured emailsuffix' =>
      'Note that the configured emailsuffix',
    'will <em>not</em> be appended to these addresses, so you should add it explicitly if so desired.' =>
      'will <em>not</em> be appended to these addresses, so you should add it explicitly if so desired.',
    'specifically requestable (users can ask specific other users to set flags of this type as opposed to just asking the wind)' =>
      'specifically requestable (users can ask specific other users to set flags of this type as opposed to just asking the wind)',
    'multiplicable (multiple flags of this type can be set on the same' =>
      'multiplicable (multiple flags of this type can be set on the same',
    'Grant Group:' =>
      'Grant Group:',
    'the group allowed to grant/deny flags of this type (to allow all users to grant/deny these flags, select no group)' =>
      'the group allowed to grant/deny flags of this type (to allow all users to grant/deny these flags, select no group)',
    'Request Group:' =>
      'Request Group:',
    'if flags of this type are requestable, the group allowed to request them (to allow all users to request these flags, select no group)' =>
      'if flags of this type are requestable, the group allowed to request them (to allow all users to request these flags, select no group)',
    'Note that the request group alone has no effect if the grant group is not defined!' =>
      'Note that the request group alone has no effect if the grant group is not defined!',
    'Create ' =>
      'Create ',
    'Save Changes ' =>
      'Save Changes ',
    '(no group)' =>
      '(no group)',
  },
  'admin/flag-type/list.html.tmpl' => {
    'Administer Flag Types' =>
      'Administer Flag Types',
    '
table#flag_types_bugs tr th,
table#flag_types_attachments tr th { text-align: left; }
.inactive { color: #787878; }
.multiplicable { display: block; }
' =>
      '
table#flag_types_bugs tr th,
table#flag_types_attachments tr th { text-align: left; }
.inactive { color: #787878; }
.multiplicable { display: block; }
',
    'var f = document.flagtype_form; selectProduct(f.product, f.component, null, null, \'__All__\');' =>
      'var f = document.flagtype_form; selectProduct(f.product, f.component, null, null, \'__All__\');',
    'Flags are markers that identify whether $terms.abug or attachment has been granted or denied some status. Flags appear in the UI as a name and a status symbol ("+" for granted, "-" for denied, and "?" for statuses requested by users).' =>
      'Flags are markers that identify whether $terms.abug or attachment has been granted or denied some status. Flags appear in the UI as a name and a status symbol ("+" for granted, "-" for denied, and "?" for statuses requested by users).',
    'For example, you might define a "review" status for users to request review for their patches. When a patch writer requests review, the string "review?" will appear in the attachment. When a patch reviewer reviews the patch, either the string "review+" or the string "review-" will appear in the patch, depending on whether the patch passed or failed review.' =>
      'For example, you might define a "review" status for users to request review for their patches. When a patch writer requests review, the string "review?" will appear in the attachment. When a patch reviewer reviews the patch, either the string "review+" or the string "review-" will appear in the patch, depending on whether the patch passed or failed review.',
    'You can restrict the list of flag types to those available for a given product and component. If a product is selected with no component, only flag types which are available to at least one component of the product are shown.' =>
      'You can restrict the list of flag types to those available for a given product and component. If a product is selected with no component, only flag types which are available to at least one component of the product are shown.',
    'Product:' =>
      'Product:',
    '__Any__' =>
      '__Any__',
    'Component:' =>
      'Component:',
    'Show flag counts' =>
      'Show flag counts',
    'Filter' =>
      'Filter',
    'Flag Types for $terms.Bugs' =>
      'Flag Types for $terms.Bugs',
    'Create Flag Type for $terms.Bugs' =>
      'Create Flag Type for $terms.Bugs',
    'Flag Types for Attachments' =>
      'Flag Types for Attachments',
    'Create Flag Type For Attachments' =>
      'Create Flag Type For Attachments',
    'Name' =>
      'Name',
    'Description' =>
      'Description',
    'Sortkey' =>
      'Sortkey',
    'Properties' =>
      'Properties',
    'Grant group' =>
      'Grant group',
    'Request group' =>
      'Request group',
    'Flags' =>
      'Flags',
    'Actions' =>
      'Actions',
    'requestable' =>
      'requestable',
    '(specifically)' =>
      '(specifically)',
    'multiplicable' =>
      'multiplicable',
    'Copy' =>
      'Copy',
    'Delete' =>
      'Delete',
  },
  'admin/groups/confirm-remove.html.tmpl' => {
    'Confirm: Remove Explicit Members in the Regular Expression?' =>
      'Confirm: Remove Explicit Members in the Regular Expression?',
    'Confirm: Remove All Explicit Members?' =>
      'Confirm: Remove All Explicit Members?',
    'This option will remove all users from \'' =>
      'This option will remove all users from \'',
    '\' whose login names match the regular expression: \'' =>
      '\' whose login names match the regular expression: \'',
    'This option will remove all explicitly defined users from \'' =>
      'This option will remove all explicitly defined users from \'',
    'Generally, you will only need to do this when upgrading groups created with $terms.Bugzilla versions 2.16 and earlier. Use this option with <b>extreme care</b> and consult the documentation for further information.' =>
      'Generally, you will only need to do this when upgrading groups created with $terms.Bugzilla versions 2.16 and earlier. Use this option with <b>extreme care</b> and consult the documentation for further information.',
    'Confirm' =>
      'Confirm',
    'Or' =>
      'Or',
    'return to the Edit Groups page' =>
      'return to the Edit Groups page',
  },
  'admin/groups/create.html.tmpl' => {
    'Add group' =>
      'Add group',
    'This page allows you to define a new user group.' =>
      'This page allows you to define a new user group.',
    'New Name:' =>
      'New Name:',
    'New Description:' =>
      'New Description:',
    'New User RegExp:' =>
      'New User RegExp:',
    'Use For $terms.Bugs:' =>
      'Use For $terms.Bugs:',
    'Icon URL:' =>
      'Icon URL:',
    'Associate new group with ALL existing products' =>
      'Associate new group with ALL existing products',
    'Add' =>
      'Add',
    '<b>Name</b> is the group name displayed for users when limitting $terms.bugs to a certain set of groups.' =>
      '<b>Name</b> is the group name displayed for users when limitting $terms.bugs to a certain set of groups.',
    '<b>Description</b> is what will be shown in the $terms.bug reports to members of the group where they can choose whether the $terms.bug will be restricted to others in the same group.' =>
      '<b>Description</b> is what will be shown in the $terms.bug reports to members of the group where they can choose whether the $terms.bug will be restricted to others in the same group.',
    'The <b>Use For $terms.Bugs</b> flag determines whether or not the group is eligible to be used for $terms.bugs. If you clear this, it will no longer be possible for users to add $terms.bugs to this group, although $terms.bugs already in the group will remain in the group. Doing so is a much less drastic way to stop a group from growing than deleting the group would be. <b>Note: If you are creating a group, you probably want it to be usable for $terms.bugs, in which case you should leave this checked.</b>' =>
      'The <b>Use For $terms.Bugs</b> flag determines whether or not the group is eligible to be used for $terms.bugs. If you clear this, it will no longer be possible for users to add $terms.bugs to this group, although $terms.bugs already in the group will remain in the group. Doing so is a much less drastic way to stop a group from growing than deleting the group would be. <b>Note: If you are creating a group, you probably want it to be usable for $terms.bugs, in which case you should leave this checked.</b>',
    '<b>User RegExp</b> is optional, and if filled in, will automatically grant membership to this group to anyone with an email address that matches this regular expression.' =>
      '<b>User RegExp</b> is optional, and if filled in, will automatically grant membership to this group to anyone with an email address that matches this regular expression.',
    '<b>Icon URL</b> is optional, and is the URL pointing to the icon used to identify the group. It may be either a relative URL to the base URL of this installation or an absolute URL. This icon will be displayed in comments in $terms.bugs besides the name of the author of comments.' =>
      '<b>Icon URL</b> is optional, and is the URL pointing to the icon used to identify the group. It may be either a relative URL to the base URL of this installation or an absolute URL. This icon will be displayed in comments in $terms.bugs besides the name of the author of comments.',
    'If you select "Associate new group with ALL existing products", new group will be added as optional (SHOWN/NA) into ALL existing products, so any member of this group will be able to decide whether to restrict bug access in ANY product by this group.' =>
      'If you select "Associate new group with ALL existing products", new group will be added as optional (SHOWN/NA) into ALL existing products, so any member of this group will be able to decide whether to restrict bug access in ANY product by this group.',
    'Back to the' =>
      'Back to the',
    'main $terms.bugs page' =>
      'main $terms.bugs page',
    'or to the' =>
      'or to the',
    'group list' =>
      'group list',
  },
  'admin/groups/delete.html.tmpl' => {
    'Delete group' =>
      'Delete group',
    'Id' =>
      'Id',
    'Name' =>
      'Name',
    'Description' =>
      'Description',
    'users belong directly to this group. You cannot delete this group while there are users in it.</b>' =>
      'users belong directly to this group. You cannot delete this group while there are users in it.</b>',
    'Show me which users' =>
      'Show me which users',
    'Remove all users from this group for me.' =>
      'Remove all users from this group for me.',
    '<b>Members of this group inherit membership in the following groups:</b>' =>
      '<b>Members of this group inherit membership in the following groups:</b>',
    '$terms.bug reports are visible only to this group. You cannot delete this group while any $terms.bugs are using it.</b>' =>
      '$terms.bug reports are visible only to this group. You cannot delete this group while any $terms.bugs are using it.</b>',
    'Show me which $terms.bugs' =>
      'Show me which $terms.bugs',
    'Remove all $terms.bugs from this group restriction for me.' =>
      'Remove all $terms.bugs from this group restriction for me.',
    '<b>NOTE:</b> It\'s quite possible to make confidential $terms.bugs public by checking this box. It is <B>strongly</B> suggested that you review the $terms.bugs in this group before checking the box.' =>
      '<b>NOTE:</b> It\'s quite possible to make confidential $terms.bugs public by checking this box. It is <B>strongly</B> suggested that you review the $terms.bugs in this group before checking the box.',
    '<b>This group is tied to the following products:</b>' =>
      '<b>This group is tied to the following products:</b>',
    'Mandatory' =>
      'Mandatory',
    'Shown' =>
      'Shown',
    'Default' =>
      'Default',
    '<strong>WARNING: This product is currently hidden. Deleting this group will make this product publicly visible. </strong>' =>
      '<strong>WARNING: This product is currently hidden. Deleting this group will make this product publicly visible. </strong>',
    'Delete this group anyway, and remove these controls.' =>
      'Delete this group anyway, and remove these controls.',
    '<b>This group restricts who can make changes to flags of certain types. You cannot delete this group while there are flag types using it.</b>' =>
      '<b>This group restricts who can make changes to flags of certain types. You cannot delete this group while there are flag types using it.</b>',
    'Show me which types' =>
      'Show me which types',
    'Remove all flag types from this group for me.' =>
      'Remove all flag types from this group for me.',
    '<b>There' =>
      '<b>There',
    'are' =>
      'are',
    'saved searches' =>
      'saved searches',
    'is a saved search' =>
      'is a saved search',
    'being shared with this group.</b> If you delete this group,' =>
      'being shared with this group.</b> If you delete this group,',
    'these saved searches' =>
      'these saved searches',
    'this saved search' =>
      'this saved search',
    'will fall back to being private again.' =>
      'will fall back to being private again.',
    'Confirmation' =>
      'Confirmation',
    'Do you really want to delete this group?' =>
      'Do you really want to delete this group?',
    '<b>You must check all of the above boxes or correct the indicated problems first before you can proceed.</b>' =>
      '<b>You must check all of the above boxes or correct the indicated problems first before you can proceed.</b>',
    'Yes, delete' =>
      'Yes, delete',
    'Go back to the' =>
      'Go back to the',
    'group list' =>
      'group list',
  },
  'admin/groups/edit.html.tmpl' => {
    'Change Group:' =>
      'Change Group:',
    'Group:' =>
      'Group:',
    'Description:' =>
      'Description:',
    'User Regexp:' =>
      'User Regexp:',
    'Icon URL:' =>
      'Icon URL:',
    'Use For $terms.Bugs:' =>
      'Use For $terms.Bugs:',
    'Add/remove users in this group' =>
      'Add/remove users in this group',
    'Group Permissions' =>
      'Group Permissions',
    'Groups That Are a Member of This Group' =>
      'Groups That Are a Member of This Group',
    '(&quot;Users in' =>
      '(&quot;Users in',
    'X' =>
      'X',
    'are automatically in' =>
      'are automatically in',
    'Groups That This Group Is a Member Of' =>
      'Groups That This Group Is a Member Of',
    '(&quot;If you are in' =>
      '(&quot;If you are in',
    ', you are automatically also in...&quot;)' =>
      ', you are automatically also in...&quot;)',
    'Groups That Can Grant Membership in This Group' =>
      'Groups That Can Grant Membership in This Group',
    'can add other users to' =>
      'can add other users to',
    'Groups That This Group Can Grant Membership In' =>
      'Groups That This Group Can Grant Membership In',
    'can add users to...&quot;)' =>
      'can add users to...&quot;)',
    'Groups That Can See This Group' =>
      'Groups That Can See This Group',
    'can see users in' =>
      'can see users in',
    'Groups That This Group Can See' =>
      'Groups That This Group Can See',
    'can see users in...&quot;)' =>
      'can see users in...&quot;)',
    'Update Group' =>
      'Update Group',
    'Mass Remove' =>
      'Mass Remove',
    'You can use this form to do mass-removal of users from groups. This is often very useful if you upgraded from $terms.Bugzilla 2.16.' =>
      'You can use this form to do mass-removal of users from groups. This is often very useful if you upgraded from $terms.Bugzilla 2.16.',
    'Remove all explicit memberships from users whose login names match the following regular expression:' =>
      'Remove all explicit memberships from users whose login names match the following regular expression:',
    'Remove Memberships' =>
      'Remove Memberships',
    'If you leave the field blank, all explicit memberships in this group will be removed.' =>
      'If you leave the field blank, all explicit memberships in this group will be removed.',
    '<b>Description</b> is what will be shown in the $terms.bug reports to members of the group where they can choose whether the $terms.bug will be restricted to others in the same group.' =>
      '<b>Description</b> is what will be shown in the $terms.bug reports to members of the group where they can choose whether the $terms.bug will be restricted to others in the same group.',
    '<b>User RegExp</b> is optional, and if filled in, will automatically grant membership to this group to anyone with an email address that matches this perl regular expression. Do not forget the trailing \'$\'. Example \'@mycompany\\.com$\'' =>
      '<b>User RegExp</b> is optional, and if filled in, will automatically grant membership to this group to anyone with an email address that matches this perl regular expression. Do not forget the trailing \'$\'. Example \'@mycompany\\.com$\'',
    'The <b>Use For $terms.Bugs</b> flag determines whether or not the group is eligible to be used for $terms.bugs. If you remove this flag, it will no longer be possible for users to add $terms.bugs to this group, although $terms.bugs already in the group will remain in the group. Doing so is a much less drastic way to stop a group from growing than deleting the group as well as a way to maintain lists of users without cluttering the lists of groups used for $terms.bug restrictions.' =>
      'The <b>Use For $terms.Bugs</b> flag determines whether or not the group is eligible to be used for $terms.bugs. If you remove this flag, it will no longer be possible for users to add $terms.bugs to this group, although $terms.bugs already in the group will remain in the group. Doing so is a much less drastic way to stop a group from growing than deleting the group as well as a way to maintain lists of users without cluttering the lists of groups used for $terms.bug restrictions.',
    'Back to the' =>
      'Back to the',
    'group list' =>
      'group list',
    'Add' =>
      'Add',
    '(select to add)' =>
      '(select to add)',
    'Current' =>
      'Current',
    '(select to remove)' =>
      '(select to remove)',
  },
  'admin/groups/list.html.tmpl' => {
    'Edit Groups' =>
      'Edit Groups',
    'This lets you edit the groups available to put users in.' =>
      'This lets you edit the groups available to put users in.',
    'edit' =>
      'edit',
    'delete' =>
      'delete',
    'Actions' =>
      'Actions',
    'Add Group' =>
      'Add Group',
  },
  'admin/groups/usersingroup.html.tmpl' => {
    'Add/remove users in group: ' =>
      'Add/remove users in group: ',
    'Group:' =>
      'Group:',
    'Description:' =>
      'Description:',
    'Regexp:' =>
      'Regexp:',
    'Edit group parameters and inclusions' =>
      'Edit group parameters and inclusions',
    'Add users to this group:' =>
      'Add users to this group:',
    'Allow these users to grant this group ("grant option"):' =>
      'Allow these users to grant this group ("grant option"):',
    'Active users in group &laquo;' =>
      'Active users in group &laquo;',
    'Login' =>
      'Login',
    'User Name' =>
      'User Name',
    'Is member?' =>
      'Is member?',
    'Can grant?' =>
      'Can grant?',
    'explicit,' =>
      'explicit,',
    'remove ' =>
      'remove ',
    'from ' =>
      'from ',
    'remove' =>
      'remove',
    'matches regexp' =>
      'matches regexp',
    'via' =>
      'via',
    'explicit' =>
      'explicit',
    'revoke ' =>
      'revoke ',
    'grant permission from ' =>
      'grant permission from ',
    'revoke' =>
      'revoke',
  },
  'admin/milestones/confirm-delete.html.tmpl' => {
    'Delete Milestone of Product \'' =>
      'Delete Milestone of Product \'',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Milestone:' =>
      'Milestone:',
    'Milestone of Product:' =>
      'Milestone of Product:',
    'List of $terms.bugs targetted at milestone ' =>
      'List of $terms.bugs targetted at milestone ',
    'None' =>
      'None',
    'Confirmation' =>
      'Confirmation',
    'You can\'t delete this milestone, because there' =>
      'You can\'t delete this milestone, because there',
    'are' =>
      'are',
    'is 1 $terms.bug' =>
      'is 1 $terms.bug',
    'targetted to it.' =>
      'targetted to it.',
    'Do you really want to delete this milestone?' =>
      'Do you really want to delete this milestone?',
    'Yes, delete' =>
      'Yes, delete',
  },
  'admin/milestones/edit.html.tmpl' => {
    'Edit Milestone \'' =>
      'Edit Milestone \'',
    '\' of product \'' =>
      '\' of product \'',
    'Add Milestone to Product \'' =>
      'Add Milestone to Product \'',
    'This page allows you to add a new milestone to product \'' =>
      'This page allows you to add a new milestone to product \'',
    'Milestone:' =>
      'Milestone:',
    'Sortkey:' =>
      'Sortkey:',
    'Enabled For $terms.Bugs:' =>
      'Enabled For $terms.Bugs:',
    'Save Changes' =>
      'Save Changes',
    'Add' =>
      'Add',
  },
  'admin/milestones/footer.html.tmpl' => {
    'Add a milestone to product ' =>
      'Add a milestone to product ',
    'Add' =>
      'Add',
    'a milestone.' =>
      'a milestone.',
    'Edit Milestone ' =>
      'Edit Milestone ',
    'Edit milestone' =>
      'Edit milestone',
    'Edit other milestones of product' =>
      'Edit other milestones of product',
    'Edit product' =>
      'Edit product',
  },
  'admin/milestones/list.html.tmpl' => {
    'Select milestone of product \'' =>
      'Select milestone of product \'',
    'Edit milestone...' =>
      'Edit milestone...',
    'Sortkey' =>
      'Sortkey',
    'Active' =>
      'Active',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    'Empty milestone (---)' =>
      'Empty milestone (---)',
    'disabled globally' =>
      'disabled globally',
    'Empty milestone (---) is' =>
      'Empty milestone (---) is',
    'in this product.' =>
      'in this product.',
    'Disable' =>
      'Disable',
    'Enable' =>
      'Enable',
    'empty milestone' =>
      'empty milestone',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/milestones/select-product.html.tmpl' => {
    'Edit milestones for which product?' =>
      'Edit milestones for which product?',
    'Edit milestones of...' =>
      'Edit milestones of...',
    'Description' =>
      'Description',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/params/admin.html.tmpl' => {
    'Administrative Policies' =>
      'Administrative Policies',
    'Set up account policies' =>
      'Set up account policies',
    'The pages to edit products and components can delete all associated $terms.bugs when you delete a product (or component). Since that is a pretty scary idea, you have to turn on this option before any such deletions will ever happen.' =>
      'The pages to edit products and components can delete all associated $terms.bugs when you delete a product (or component). Since that is a pretty scary idea, you have to turn on this option before any such deletions will ever happen.',
    'Users can change their own email address through the preferences. Note that the change is validated by emailing both addresses, so switching this option on will not let users use an invalid address.' =>
      'Users can change their own email address through the preferences. Note that the change is validated by emailing both addresses, so switching this option on will not let users use an invalid address.',
    'The user editing pages are capable of letting you delete user accounts. $terms.Bugzilla will issue a warning in case you\'d run into inconsistencies when you\'re about to do so, but such deletions remain kinda scary. So, you have to turn on this option before any such deletions will ever happen.' =>
      'The user editing pages are capable of letting you delete user accounts. $terms.Bugzilla will issue a warning in case you\'d run into inconsistencies when you\'re about to do so, but such deletions remain kinda scary. So, you have to turn on this option before any such deletions will ever happen.',
  },
  'admin/params/advanced.html.tmpl' => {
    'Advanced' =>
      'Advanced',
    'Settings for advanced configurations.' =>
      'Settings for advanced configurations.',
    'If your website is at \'www.foo.com\', setting this to \'.foo.com\' will also allow \'bar.foo.com\' to access $terms.Bugzilla cookies. This is useful if you have more than one hostname pointing at the same web server, and you want them to share the $terms.Bugzilla cookie.' =>
      'If your website is at \'www.foo.com\', setting this to \'.foo.com\' will also allow \'bar.foo.com\' to access $terms.Bugzilla cookies. This is useful if you have more than one hostname pointing at the same web server, and you want them to share the $terms.Bugzilla cookie.',
    'When inbound traffic to $terms.Bugzilla goes through a proxy, $terms.Bugzilla thinks that the IP address of every single user is the IP address of the proxy. If you enter a comma-separated list of IPs in this parameter, then $terms.Bugzilla will trust any <code>X-Forwarded-For</code> header sent from those IPs, and use the value of that header as the end user\'s IP address.' =>
      'When inbound traffic to $terms.Bugzilla goes through a proxy, $terms.Bugzilla thinks that the IP address of every single user is the IP address of the proxy. If you enter a comma-separated list of IPs in this parameter, then $terms.Bugzilla will trust any <code>X-Forwarded-For</code> header sent from those IPs, and use the value of that header as the end user\'s IP address.',
    '$terms.Bugzilla may have to access the web to get notifications about new releases (see the <tt>upgrade_notification</tt> parameter). If your $terms.Bugzilla server is behind a proxy, it may be necessary to enter its URL if the web server cannot access the HTTP_PROXY environment variable. If you have to authenticate, use the <code>http://user:pass@proxy_url/</code> syntax.' =>
      '$terms.Bugzilla may have to access the web to get notifications about new releases (see the <tt>upgrade_notification</tt> parameter). If your $terms.Bugzilla server is behind a proxy, it may be necessary to enter its URL if the web server cannot access the HTTP_PROXY environment variable. If you have to authenticate, use the <code>http://user:pass@proxy_url/</code> syntax.',
  },
  'admin/params/attachment.html.tmpl' => {
    'Attachments' =>
      'Attachments',
    'Set up attachment options' =>
      'Set up attachment options',
    'If this option is on, users will be able to view attachments from their browser, if their browser supports the attachment\'s MIME type. If this option is off, users are forced to download attachments, even if the browser is able to display them.<p>This is a security restriction for installations where untrusted users may upload attachments that could be potentially damaging if viewed directly in the browser.</p><p>It is highly recommended that you set the <tt>attachment_base</tt> parameter if you turn this parameter on.' =>
      'If this option is on, users will be able to view attachments from their browser, if their browser supports the attachment\'s MIME type. If this option is off, users are forced to download attachments, even if the browser is able to display them.<p>This is a security restriction for installations where untrusted users may upload attachments that could be potentially damaging if viewed directly in the browser.</p><p>It is highly recommended that you set the <tt>attachment_base</tt> parameter if you turn this parameter on.',
    'When the <tt>allow_attachment_display</tt> parameter is on, it is  possible for a malicious attachment to steal your cookies or perform an attack on $terms.Bugzilla using your credentials.<p>If you would like additional security on attachments to avoid this, set this parameter to an alternate URL for your $terms.Bugzilla that is not the same as <tt>urlbase</tt> or <tt>sslbase</tt>. That is, a different domain name that resolves to this exact same $terms.Bugzilla installation.</p><p>Note that if you have set the <a href="editparams.cgi?section=advanced#cookiedomain"><tt>cookiedomain</tt> parameter</a>, you should set <tt>attachment_base</tt> to use a domain that would <em>not</em> be matched by <tt>cookiedomain</tt>.</p><p>For added security, you can insert <tt>%bugid%</tt> into the URL, which will be replaced with the ID of the current $terms.bug that the attachment is on, when you access an attachment. This will limit attachments to accessing only other attachments on the same $terms.bug. Remember, though, that all those possible domain names  (such as <tt>1234.your.domain.com</tt>) must point to this same $terms.Bugzilla instance.' =>
      'When the <tt>allow_attachment_display</tt> parameter is on, it is  possible for a malicious attachment to steal your cookies or perform an attack on $terms.Bugzilla using your credentials.<p>If you would like additional security on attachments to avoid this, set this parameter to an alternate URL for your $terms.Bugzilla that is not the same as <tt>urlbase</tt> or <tt>sslbase</tt>. That is, a different domain name that resolves to this exact same $terms.Bugzilla installation.</p><p>Note that if you have set the <a href="editparams.cgi?section=advanced#cookiedomain"><tt>cookiedomain</tt> parameter</a>, you should set <tt>attachment_base</tt> to use a domain that would <em>not</em> be matched by <tt>cookiedomain</tt>.</p><p>For added security, you can insert <tt>%bugid%</tt> into the URL, which will be replaced with the ID of the current $terms.bug that the attachment is on, when you access an attachment. This will limit attachments to accessing only other attachments on the same $terms.bug. Remember, though, that all those possible domain names  (such as <tt>1234.your.domain.com</tt>) must point to this same $terms.Bugzilla instance.',
    'If this option is on, administrators will be able to delete the content of attachments.' =>
      'If this option is on, administrators will be able to delete the content of attachments.',
    'If this option is on, the <a href=\'http://supa.sourceforge.net/\'>SUPA</a> java applet (Screenshot UPload Applet) will be enabled to allow uploading of images from the clipboard. Note this requires <a href=\'http://www.java.com/\'>Java</a> support in user\'s browser.' =>
      'If this option is on, the <a href=\'http://supa.sourceforge.net/\'>SUPA</a> java applet (Screenshot UPload Applet) will be enabled to allow uploading of images from the clipboard. Note this requires <a href=\'http://www.java.com/\'>Java</a> support in user\'s browser.',
    'Sometimes you may want to specify different URL for Supa applet instead of default <tt>js/Supa.jar</tt>. An example of such situation is when your Bugzilla is protected by SSL <i>with client certificate verification</i> very non-trivial, but possible sometimes. Java plugin does applet download by itself and can\'t use certificate from the browser, so Supa must be available under different \'open\' URL.' =>
      'Sometimes you may want to specify different URL for Supa applet instead of default <tt>js/Supa.jar</tt>. An example of such situation is when your Bugzilla is protected by SSL <i>with client certificate verification</i> very non-trivial, but possible sometimes. Java plugin does applet download by itself and can\'t use certificate from the browser, so Supa must be available under different \'open\' URL.',
    'The maximum size (in kilobytes) of attachments <b>stored in the database</b>. $terms.Bugzilla will not accept attachments greater than this number of kilobytes in size. Setting this parameter to 0 will prevent attaching files to $terms.bugs.' =>
      'The maximum size (in kilobytes) of attachments <b>stored in the database</b>. $terms.Bugzilla will not accept attachments greater than this number of kilobytes in size. Setting this parameter to 0 will prevent attaching files to $terms.bugs.',
    'If this option is on, all attachments will be stored as local files, not inside the database.' =>
      'If this option is on, all attachments will be stored as local files, not inside the database.',
    'The maximum size (in megabytes) of attachments <b>stored on the server filesystem</b>. These are either the attachments marked as \'Big Files\' by user, or all attachments, if force_attach_bigfile is turned ON. If set to zero, attachments will never be kept on the server filesystem.' =>
      'The maximum size (in megabytes) of attachments <b>stored on the server filesystem</b>. These are either the attachments marked as \'Big Files\' by user, or all attachments, if force_attach_bigfile is turned ON. If set to zero, attachments will never be kept on the server filesystem.',
    'Perl regular expression for detecting browser-viewable MIME content types.<br />These probably are text and image files.' =>
      'Perl regular expression for detecting browser-viewable MIME content types.<br />These probably are text and image files.',
    'Path to a file with MIME types to file extensions mapping for guessing file types. Usually /etc/mime.types on Linux/UNIX systems, but you may specify the path to a customized version here.' =>
      'Path to a file with MIME types to file extensions mapping for guessing file types. Usually /etc/mime.types on Linux/UNIX systems, but you may specify the path to a customized version here.',
  },
  'admin/params/auth.html.tmpl' => {
    'User Authentication' =>
      'User Authentication',
    'Set up your authentication policies' =>
      'Set up your authentication policies',
    '<p>This page contains the settings that control how this Bugzilla installation will do its authentication. Choose what authentication mechanism to use (the Bugzilla database, or an external source such as LDAP), and set basic behavioral parameters. For example, choose whether to require users to login to browse bugs, the management of authentication cookies, and the regular expression used to validate email addresses.</p>' =>
      '<p>This page contains the settings that control how this Bugzilla installation will do its authentication. Choose what authentication mechanism to use (the Bugzilla database, or an external source such as LDAP), and set basic behavioral parameters. For example, choose whether to require users to login to browse bugs, the management of authentication cookies, and the regular expression used to validate email addresses.</p>',
    'Environment variable used by external authentication system to store a unique identifier for each user. Leave it blank if there isn\'t one or if this method of authentication is not being used.' =>
      'Environment variable used by external authentication system to store a unique identifier for each user. Leave it blank if there isn\'t one or if this method of authentication is not being used.',
    'Environment variable used by external authentication system to store each user\'s email address. This is a required field for environmental authentication. Leave it blank if you are not going to use this feature.' =>
      'Environment variable used by external authentication system to store each user\'s email address. This is a required field for environmental authentication. Leave it blank if you are not going to use this feature.',
    'Environment variable used by external authentication system to store the user\'s real name. Leave it blank if there isn\'t one or if this method of authentication is not being used.' =>
      'Environment variable used by external authentication system to store the user\'s real name. Leave it blank if there isn\'t one or if this method of authentication is not being used.',
    'Mechanism(s) to be used for gathering a user\'s login information.
More than one may be selected. If the first one returns nothing,
the second is tried, and so on.<br />
The types are:
<dl>
<dt>CGI</dt>
<dd>
Asks for username and password via CGI form interface.
</dd>
<dt>Env</dt>
<dd>
Info for a pre-authenticated user is passed in system
environment variables.
</dd>
</dl>' =>
      'Mechanism(s) to be used for gathering a user\'s login information.
More than one may be selected. If the first one returns nothing,
the second is tried, and so on.<br />
The types are:
<dl>
<dt>CGI</dt>
<dd>
Asks for username and password via CGI form interface.
</dd>
<dt>Env</dt>
<dd>
Info for a pre-authenticated user is passed in system
environment variables.
</dd>
</dl>',
    'Mechanism(s) to be used for verifying (authenticating) information
gathered by user_info_class.
More than one may be selected. If the first one cannot find the
user, the second is tried, and so on.<br />
The types are:
<dl>
<dt>DB</dt>
<dd>
$terms.Bugzilla\'s built-in authentication. This is the most common
choice.
</dd>
<dt>RADIUS</dt>
<dd>
RADIUS authentication using a RADIUS server.
This method is experimental; please see the
$terms.Bugzilla documentation for more information.
Using this method requires
<a href="?section=radius">additional
parameters</a> to be set.
</dd>
<dt>LDAP</dt>
<dd>
LDAP authentication using an LDAP server.
Please see the $terms.Bugzilla documentation
for more information. Using this method requires
<a href="?section=ldap">additional
parameters</a> to be set.
</dd>
</dl>' =>
      'Mechanism(s) to be used for verifying (authenticating) information
gathered by user_info_class.
More than one may be selected. If the first one cannot find the
user, the second is tried, and so on.<br />
The types are:
<dl>
<dt>DB</dt>
<dd>
$terms.Bugzilla\'s built-in authentication. This is the most common
choice.
</dd>
<dt>RADIUS</dt>
<dd>
RADIUS authentication using a RADIUS server.
This method is experimental; please see the
$terms.Bugzilla documentation for more information.
Using this method requires
<a href="?section=radius">additional
parameters</a> to be set.
</dd>
<dt>LDAP</dt>
<dd>
LDAP authentication using an LDAP server.
Please see the $terms.Bugzilla documentation
for more information. Using this method requires
<a href="?section=ldap">additional
parameters</a> to be set.
</dd>
</dl>',
    'Controls management of session cookies
<ul>
<li>
on - Session cookies never expire (the user has to login only
once per browser).
</li>
<li>
off - Session cookies last until the users session ends (the user
will have to login in each new browser session).
</li>
<li>
defaulton/defaultoff - Default behavior as described
above, but user can choose whether $terms.Bugzilla will remember his
login or not.
</li>
</ul>' =>
      'Controls management of session cookies
<ul>
<li>
on - Session cookies never expire (the user has to login only
once per browser).
</li>
<li>
off - Session cookies last until the users session ends (the user
will have to login in each new browser session).
</li>
<li>
defaulton/defaultoff - Default behavior as described
above, but user can choose whether $terms.Bugzilla will remember his
login or not.
</li>
</ul>',
    'If this option is set, all access to the system beyond the front page will require a login. No anonymous users will be permitted.' =>
      'If this option is set, all access to the system beyond the front page will require a login. No anonymous users will be permitted.',
    'This defines the regexp to use for legal email addresses. The default tries to match fully qualified email addresses. Another popular value to put here is <tt>^[^@]+$</tt>, which means \'local usernames, no @ allowed.\'' =>
      'This defines the regexp to use for legal email addresses. The default tries to match fully qualified email addresses. Another popular value to put here is <tt>^[^@]+$</tt>, which means \'local usernames, no @ allowed.\'',
    'This describes in English words what kinds of legal addresses are allowed by the <tt>emailregexp</tt> param.' =>
      'This describes in English words what kinds of legal addresses are allowed by the <tt>emailregexp</tt> param.',
    'This is a string to append to any email addresses when actually sending mail to that address. It is useful if you have changed the <tt>emailregexp</tt> param to only allow local usernames, but you want the mail to be delivered to username@my.local.hostname.' =>
      'This is a string to append to any email addresses when actually sending mail to that address. It is useful if you have changed the <tt>emailregexp</tt> param to only allow local usernames, but you want the mail to be delivered to username@my.local.hostname.',
    'This defines the regexp to use for email addresses that are permitted to self-register using a \'New Account\' feature. The default (.*) permits any account matching the emailregexp to be created. If this parameter is left blank, no users will be permitted to create their own accounts and all accounts will have to be created by an administrator.' =>
      'This defines the regexp to use for email addresses that are permitted to self-register using a \'New Account\' feature. The default (.*) permits any account matching the emailregexp to be created. If this parameter is left blank, no users will be permitted to create their own accounts and all accounts will have to be created by an administrator.',
    'Maximum failed logins to lock account for one IP address. 0 means no limit.' =>
      'Maximum failed logins to lock account for one IP address. 0 means no limit.',
    'If the maximum login attempts occur during this many minutes, the account is locked.' =>
      'If the maximum login attempts occur during this many minutes, the account is locked.',
  },
  'admin/params/bugchange.html.tmpl' => {
    '$terms.Bug Change Policies' =>
      '$terms.Bug Change Policies',
    'Set up $terms.bug change policies' =>
      'Set up $terms.bug change policies',
    '<p>Set policy on default behavior for bug change events. For example, choose which status to set a bug to when it is marked as a duplicate, choose whether to allow bug reporters to set the priority or target milestone, and what changes should require the user to make a comment.</p><p>Note that bug status transitions (including those that require comments) are configured on the <a href=\'editworkflow.cgi\'>Bug Status Workflow</a> page.</p>' =>
      '<p>Set policy on default behavior for bug change events. For example, choose which status to set a bug to when it is marked as a duplicate, choose whether to allow bug reporters to set the priority or target milestone, and what changes should require the user to make a comment.</p><p>Note that bug status transitions (including those that require comments) are configured on the <a href=\'editworkflow.cgi\'>Bug Status Workflow</a> page.</p>',
    'If this is on, users are allowed to make bug changes without notifying anyone by checking the Silent checkbox.' =>
      'If this is on, users are allowed to make bug changes without notifying anyone by checking the Silent checkbox.',
    'When $terms.abug is marked as a duplicate of another one or is moved to another installation, use this $terms.bug status.' =>
      'When $terms.abug is marked as a duplicate of another one or is moved to another installation, use this $terms.bug status.',
    'The status considered as being "finally closed". Used for the operation of \'Clear flag requests when closing bugs\' user preference: when it is \'On\', the flags are cleared when setting bug status to this value.' =>
      'The status considered as being "finally closed". Used for the operation of \'Clear flag requests when closing bugs\' user preference: when it is \'On\', the flags are cleared when setting bug status to this value.',
    'Duplicate bugs are marked as this resolution.' =>
      'Duplicate bugs are marked as this resolution.',
    'If this is on, then people submitting $terms.bugs can choose an initial priority for that $terms.bug. If off, then all $terms.bugs initially have the default priority selected below.' =>
      'If this is on, then people submitting $terms.bugs can choose an initial priority for that $terms.bug. If off, then all $terms.bugs initially have the default priority selected below.',
    'If this is on, then people submitting $terms.bugs can choose the Target Milestone for that $terms.bug. If off, then all $terms.bugs initially have the default milestone for the product being filed in.' =>
      'If this is on, then people submitting $terms.bugs can choose the Target Milestone for that $terms.bug. If off, then all $terms.bugs initially have the default milestone for the product being filed in.',
    'If you are using Target Milestone, do you want to require that the milestone be set in order for a user to ACCEPT a $terms.bug?' =>
      'If you are using Target Milestone, do you want to require that the milestone be set in order for a user to ACCEPT a $terms.bug?',
    'If this option is on, the user needs to enter a short comment if the resolution of the $terms.bug changes.' =>
      'If this option is on, the user needs to enter a short comment if the resolution of the $terms.bug changes.',
    'If this option is on, the user needs to enter a short comment if the $terms.bug is marked as duplicate.' =>
      'If this option is on, the user needs to enter a short comment if the $terms.bug is marked as duplicate.',
    'Don\\\'t allow $terms.bugs to be resolved as fixed if they have unresolved dependencies.' =>
      'Don\\\'t allow $terms.bugs to be resolved as fixed if they have unresolved dependencies.',
    'Allow to assign bugs to other people, i.e. allow to set bug status that has \'is assigned\' flag turned on if \'assigned to\' is not equal to you.' =>
      'Allow to assign bugs to other people, i.e. allow to set bug status that has \'is assigned\' flag turned on if \'assigned to\' is not equal to you.',
    'Add flag requestees to bug CC list automatically to grant them the rights to view/change the bug if they aren\'t in product groups.' =>
      'Add flag requestees to bug CC list automatically to grant them the rights to view/change the bug if they aren\'t in product groups.',
    'Show product name to the user in Unauthorized message if he doesn\'t have access to bug.' =>
      'Show product name to the user in Unauthorized message if he doesn\'t have access to bug.',
    'Set this to N to partially hide comments longer than N lines.' =>
      'Set this to N to partially hide comments longer than N lines.',
    'This count of characters counts as a \'line\' when hiding comments, even if there are no line breaks.' =>
      'This count of characters counts as a \'line\' when hiding comments, even if there are no line breaks.',
  },
  'admin/params/bugmove.html.tmpl' => {
    '$terms.Bug Moving' =>
      '$terms.Bug Moving',
    'Set up parameters to move $terms.bugs to/from another installation' =>
      'Set up parameters to move $terms.bugs to/from another installation',
    '<p>This page controls whether this Bugzilla installation allows certain users to move bugs to an external database. If bug moving is enabled, there are a number of parameters that control bug moving behaviors.</p>' =>
      '<p>This page controls whether this Bugzilla installation allows certain users to move bugs to an external database. If bug moving is enabled, there are a number of parameters that control bug moving behaviors.</p>',
    'If this is on, $terms.Bugzilla will allow certain people to move $terms.bugs to the defined database.' =>
      'If this is on, $terms.Bugzilla will allow certain people to move $terms.bugs to the defined database.',
    'The text written on the Move button. Explain where the $terms.bug is being moved to.' =>
      'The text written on the Move button. Explain where the $terms.bug is being moved to.',
    'The URL of the database we allow some of our $terms.bugs to be moved to.' =>
      'The URL of the database we allow some of our $terms.bugs to be moved to.',
    'To move $terms.bugs, an email is sent to the target database. This is the email address that database uses to listen for incoming $terms.bugs.' =>
      'To move $terms.bugs, an email is sent to the target database. This is the email address that database uses to listen for incoming $terms.bugs.',
    'To move $terms.bugs, an email is sent to the target database. This is the email address from which this mail, and error messages are sent.' =>
      'To move $terms.bugs, an email is sent to the target database. This is the email address from which this mail, and error messages are sent.',
    'A list of people with permission to move $terms.bugs and reopen moved $terms.bugs (in case the move operation fails).' =>
      'A list of people with permission to move $terms.bugs and reopen moved $terms.bugs (in case the move operation fails).',
    '$terms.Bugs moved from other databases to here are assigned to this product.' =>
      '$terms.Bugs moved from other databases to here are assigned to this product.',
    '$terms.Bugs moved from other databases to here are assigned to this component.' =>
      '$terms.Bugs moved from other databases to here are assigned to this component.',
  },
  'admin/params/common.html.tmpl' => {
    'On' =>
      'On',
    'Off' =>
      'Off',
    'Unknown param type' =>
      'Unknown param type',
    'Reset' =>
      'Reset',
  },
  'admin/params/core.html.tmpl' => {
    'Required Settings' =>
      'Required Settings',
    'Settings that are required for proper operation of $terms.Bugzilla' =>
      'Settings that are required for proper operation of $terms.Bugzilla',
    'The core required parameters for any Bugzilla installation are set here. These parameters must be set before a new Bugzilla installation can be used. Administrators should review this list before deploying a new Bugzilla installation.' =>
      'The core required parameters for any Bugzilla installation are set here. These parameters must be set before a new Bugzilla installation can be used. Administrators should review this list before deploying a new Bugzilla installation.',
    '<p>The URL that is the common initial leading part of all $terms.Bugzilla URLs.</p><p>For example, if the Bugzilla query page is <i>http://www.foo.com/bugzilla/query.cgi</i>, the \'urlbase\' should be set to <i>http://www.foo.com/bugzilla/</i></p>' =>
      '<p>The URL that is the common initial leading part of all $terms.Bugzilla URLs.</p><p>For example, if the Bugzilla query page is <i>http://www.foo.com/bugzilla/query.cgi</i>, the \'urlbase\' should be set to <i>http://www.foo.com/bugzilla/</i></p>',
    'Similar to urlbase, this is the URL that is the common initial leading part of all HTTPS (SSL) $terms.Bugzilla URLs.' =>
      'Similar to urlbase, this is the URL that is the common initial leading part of all HTTPS (SSL) $terms.Bugzilla URLs.',
    'When this is enabled, $terms.Bugzilla will ensure that every page is accessed over SSL, by redirecting any plain HTTP requests to HTTPS using the <tt>sslbase</tt> parameter. Also, when this is enabled, $terms.Bugzilla will send out links using <tt>sslbase</tt> in emails instead of <tt>urlbase</tt>.' =>
      'When this is enabled, $terms.Bugzilla will ensure that every page is accessed over SSL, by redirecting any plain HTTP requests to HTTPS using the <tt>sslbase</tt> parameter. Also, when this is enabled, $terms.Bugzilla will send out links using <tt>sslbase</tt> in emails instead of <tt>urlbase</tt>.',
    'Path, relative to your web document root, to which to restrict $terms.Bugzilla cookies. Normally this is the URI portion of your URL base. Begin with a / (single slash mark). For instance, if $terms.Bugzilla serves from \'http://www.somedomain.com/bugzilla/\', set this parameter to /bugzilla/. Setting it to / will allow all sites served by this web server or virtual host to read $terms.Bugzilla cookies.' =>
      'Path, relative to your web document root, to which to restrict $terms.Bugzilla cookies. Normally this is the URI portion of your URL base. Begin with a / (single slash mark). For instance, if $terms.Bugzilla serves from \'http://www.somedomain.com/bugzilla/\', set this parameter to /bugzilla/. Setting it to / will allow all sites served by this web server or virtual host to read $terms.Bugzilla cookies.',
  },
  'admin/params/dependencygraph.html.tmpl' => {
    'Dependency Graphs' =>
      'Dependency Graphs',
    'Optional setup for dependency graphing' =>
      'Optional setup for dependency graphing',
    'It is possible to show graphs of dependent $terms.bugs. You may set
this parameter to any of the following:
<ul>
<li>
A complete file path to \'dot\' (part of
<a href="http://www.graphviz.org">GraphViz</a>) will
generate the graphs locally.
</li>
<li>
A URL prefix pointing to an installation of the
<a href="http://www.research.att.com/~north/cgi-bin/webdot.cgi">webdot
package</a> will generate the graphs remotely.
</li>
<li>
A blank value will disable dependency graphing.
</li>
</ul>
The default value is a publicly-accessible webdot server. If you change
this value, make certain that the webdot server can read files from your
webdot directory. On Apache you do this by editing the .htaccess file,
for other systems the needed measures may vary. You can run checksetup.pl
to recreate the .htaccess file if it has been lost.' =>
      'It is possible to show graphs of dependent $terms.bugs. You may set
this parameter to any of the following:
<ul>
<li>
A complete file path to \'dot\' (part of
<a href="http://www.graphviz.org">GraphViz</a>) will
generate the graphs locally.
</li>
<li>
A URL prefix pointing to an installation of the
<a href="http://www.research.att.com/~north/cgi-bin/webdot.cgi">webdot
package</a> will generate the graphs remotely.
</li>
<li>
A blank value will disable dependency graphing.
</li>
</ul>
The default value is a publicly-accessible webdot server. If you change
this value, make certain that the webdot server can read files from your
webdot directory. On Apache you do this by editing the .htaccess file,
for other systems the needed measures may vary. You can run checksetup.pl
to recreate the .htaccess file if it has been lost.',
    'Alternative program or URL for plotting dependency graphs (for example /usr/bin/twopi). May be slow sometimes.' =>
      'Alternative program or URL for plotting dependency graphs (for example /usr/bin/twopi). May be slow sometimes.',
    'Default dependency graph orientation' =>
      'Default dependency graph orientation',
    'Timeout for locally executed Graphviz instances in seconds' =>
      'Timeout for locally executed Graphviz instances in seconds',
    'Font name or path to TrueType font file to use on graphs' =>
      'Font name or path to TrueType font file to use on graphs',
    'Font size in points to use on graphs' =>
      'Font size in points to use on graphs',
  },
  'admin/params/editparams.html.tmpl' => {
    'Parameters: Index' =>
      'Parameters: Index',
    'Configuration:' =>
      'Configuration:',
    'Show all parameters' =>
      'Show all parameters',
    'Index' =>
      'Index',
    '<strong>Note:</strong>' =>
      '<strong>Note:</strong>',
    'Bugzilla4Intranet' =>
      'Bugzilla4Intranet',
    '&nbsp;is free software based on the original' =>
      '&nbsp;is free software based on the original',
    'Bugzilla' =>
      'Bugzilla',
    '&nbsp;and developed entirely by volunteers.' =>
      '&nbsp;and developed entirely by volunteers.',
    'The best way to give back to the Bugzilla4Intranet project is to contribute yourself, at least by testing it and' =>
      'The best way to give back to the Bugzilla4Intranet project is to contribute yourself, at least by testing it and',
    'filing bugs' =>
      'filing bugs',
    'This lets you edit the basic operating parameters of $terms.Bugzilla. Be careful! Any item you check "Reset" on will get reset to its default value.' =>
      'This lets you edit the basic operating parameters of $terms.Bugzilla. Be careful! Any item you check "Reset" on will get reset to its default value.',
    'Save Changes' =>
      'Save Changes',
  },
  'admin/params/general.html.tmpl' => {
    'General' =>
      'General',
    'Miscellaneous general settings that are not required.' =>
      'Miscellaneous general settings that are not required.',
    'The email address of the person who maintains this installation  of $terms.Bugzilla. The address need not be that of a valid Bugzilla account.' =>
      'The email address of the person who maintains this installation  of $terms.Bugzilla. The address need not be that of a valid Bugzilla account.',
    'Path to Bugzilla error log file or empty string if you don\'t want to write an error log. Relative paths will be prepended with Bugzilla data directory.' =>
      'Path to Bugzilla error log file or empty string if you don\'t want to write an error log. Relative paths will be prepended with Bugzilla data directory.',
    'Whether to send e-mail messages about each \'code\' (internal) error to Bugzilla maintainer (recommended).' =>
      'Whether to send e-mail messages about each \'code\' (internal) error to Bugzilla maintainer (recommended).',
    'Whether to send e-mail messages about each \'user\' (invalid input, non-fatal) error to Bugzilla maintainer (not recommended).' =>
      'Whether to send e-mail messages about each \'user\' (invalid input, non-fatal) error to Bugzilla maintainer (not recommended).',
    '<b>Use only for debug purposes!</b> Path to the file to which Bugzilla should log all database queries with all parameters.' =>
      '<b>Use only for debug purposes!</b> Path to the file to which Bugzilla should log all database queries with all parameters.',
    'The URL that is the common initial leading part of all $terms.Bugzilla documentation URLs. It may be an absolute URL, or a URL relative to the <tt>urlbase</tt> parameter. Leave this empty to suppress links to the documentation.\'%lang%\' will be replaced by user\'s preferred language (if documentation is available in that language).' =>
      'The URL that is the common initial leading part of all $terms.Bugzilla documentation URLs. It may be an absolute URL, or a URL relative to the <tt>urlbase</tt> parameter. Leave this empty to suppress links to the documentation.\'%lang%\' will be replaced by user\'s preferred language (if documentation is available in that language).',
    'Use UTF-8 (Unicode) encoding for all text in $terms.Bugzilla. New installations should set this to true to avoid character encoding problems. <strong>Existing databases should set this to true only after the data has been converted from existing legacy character encodings to UTF-8, using the <kbd>contrib/recode.pl</kbd> script</strong>. <p>Note that if you turn this parameter from &quot;off&quot; to &quot;on&quot;, you must re-run checksetup.pl immediately afterward.</p>' =>
      'Use UTF-8 (Unicode) encoding for all text in $terms.Bugzilla. New installations should set this to true to avoid character encoding problems. <strong>Existing databases should set this to true only after the data has been converted from existing legacy character encodings to UTF-8, using the <kbd>contrib/recode.pl</kbd> script</strong>. <p>Note that if you turn this parameter from &quot;off&quot; to &quot;on&quot;, you must re-run checksetup.pl immediately afterward.</p>',
    'If this field is non-empty, then $terms.Bugzilla will display whatever is in this field at the top of every HTML page. The HTML you put in this field is not wrapped or enclosed in anything. You might want to wrap it inside a <tt>&lt;div&gt;</tt>. Give the div <em>id="message"</em> to get green text inside a red box, or <em>class="bz_private"</em> for dark red on a red background.  Anything defined in  <tt>skins/standard/global.css</tt> or <tt>skins/custom/global.css</tt> will work.  To get centered text, use <em>style="text-align:  center;"</em>.' =>
      'If this field is non-empty, then $terms.Bugzilla will display whatever is in this field at the top of every HTML page. The HTML you put in this field is not wrapped or enclosed in anything. You might want to wrap it inside a <tt>&lt;div&gt;</tt>. Give the div <em>id="message"</em> to get green text inside a red box, or <em>class="bz_private"</em> for dark red on a red background.  Anything defined in  <tt>skins/standard/global.css</tt> or <tt>skins/custom/global.css</tt> will work.  To get centered text, use <em>style="text-align:  center;"</em>.',
    'This parameter specifies HTML code to be displayed above the bug entry form in the case when it is not overridden by product settings.' =>
      'This parameter specifies HTML code to be displayed above the bug entry form in the case when it is not overridden by product settings.',
    'This parameter specifies HTML code to be displayed at the very top of the page.' =>
      'This parameter specifies HTML code to be displayed at the very top of the page.',
    '<p>If this field is non-empty, then $terms.Bugzilla will be completely disabled and this text will be displayed instead of all the $terms.Bugzilla pages to all users, including Admins. Used in the event of site maintenance or outage situations.</p><p>NOTE: Although regular log-in capability is disabled while \'shutdownhtml\' is enabled, safeguards are in place to protect the unfortunate admin who loses connection to Bugzilla. Should this happen to you, go directly to the <tt>editparams.cgi</tt> (by typing the URL in manually, if necessary). Doing this will prompt you to log in, and your name/password will be accepted here (but nowhere else).</p>' =>
      '<p>If this field is non-empty, then $terms.Bugzilla will be completely disabled and this text will be displayed instead of all the $terms.Bugzilla pages to all users, including Admins. Used in the event of site maintenance or outage situations.</p><p>NOTE: Although regular log-in capability is disabled while \'shutdownhtml\' is enabled, safeguards are in place to protect the unfortunate admin who loses connection to Bugzilla. Should this happen to you, go directly to the <tt>editparams.cgi</tt> (by typing the URL in manually, if necessary). Doing this will prompt you to log in, and your name/password will be accepted here (but nowhere else).</p>',
    'You may use this text when you want to notify your Bugzilla users about some news.<br /> After you set <i>new_functionality_tsp</i> to current date and <i>new_functionality_msg</i> to the desired message, that message is displayed to every Bugzilla user until he closes it.' =>
      'You may use this text when you want to notify your Bugzilla users about some news.<br /> After you set <i>new_functionality_tsp</i> to current date and <i>new_functionality_msg</i> to the desired message, that message is displayed to every Bugzilla user until he closes it.',
    'Last <i>new_functionality_msg</i> update timestamp. Set to current date and time to start showing <i>new_functionality_msg</i> to your users.' =>
      'Last <i>new_functionality_msg</i> update timestamp. Set to current date and time to start showing <i>new_functionality_msg</i> to your users.',
    '$terms.Bugzilla can inform you when a new release is available. The notification will appear on the $terms.Bugzilla homepage, for administrators only. <ul><li>\'development_snapshot\' notifies you about the development  snapshot that has been released.</li> <li>\'latest_stable_release\' notifies you about the most recent release available on the most recent stable branch. This branch may be different from the branch your installation is based on.</li> <li>\'stable_branch_release\' notifies you only about new releases corresponding to the branch your installation is based on. If you are running a release candidate, you will get a notification for newer release candidates too.</li> <li>\'disabled\' will never notify you about new releases and no connection will be established to a remote server.</li></ul> <p>Note that if your $terms.Bugzilla server requires a proxy to access the Internet, you may also need to set the <tt>proxy_url</tt> parameter in the Advanced section.</p>' =>
      '$terms.Bugzilla can inform you when a new release is available. The notification will appear on the $terms.Bugzilla homepage, for administrators only. <ul><li>\'development_snapshot\' notifies you about the development  snapshot that has been released.</li> <li>\'latest_stable_release\' notifies you about the most recent release available on the most recent stable branch. This branch may be different from the branch your installation is based on.</li> <li>\'stable_branch_release\' notifies you only about new releases corresponding to the branch your installation is based on. If you are running a release candidate, you will get a notification for newer release candidates too.</li> <li>\'disabled\' will never notify you about new releases and no connection will be established to a remote server.</li></ul> <p>Note that if your $terms.Bugzilla server requires a proxy to access the Internet, you may also need to set the <tt>proxy_url</tt> parameter in the Advanced section.</p>',
  },
  'admin/params/groupsecurity.html.tmpl' => {
    'Group Security' =>
      'Group Security',
    'Decide how you will use Security Groups' =>
      'Decide how you will use Security Groups',
    'Bugzilla security is based on the concept of \'groups\' which are sets of specific users. This page allows you to select some special functions of groups and their global behaviour.' =>
      'Bugzilla security is based on the concept of \'groups\' which are sets of specific users. This page allows you to select some special functions of groups and their global behaviour.',
    'If this is on, $terms.Bugzilla will by default associate newly created groups with each product in the database. Generally only useful for small databases.' =>
      'If this is on, $terms.Bugzilla will by default associate newly created groups with each product in the database. Generally only useful for small databases.',
    'The name of the group of users who can use the \'New Charts\' feature. Administrators should ensure that the public categories and series definitions do not divulge confidential information before enabling this for an untrusted population. If left blank, no users will be able to use New Charts.' =>
      'The name of the group of users who can use the \'New Charts\' feature. Administrators should ensure that the public categories and series definitions do not divulge confidential information before enabling this for an untrusted population. If left blank, no users will be able to use New Charts.',
    'The name of the group of users who can see/change private comments and attachments.' =>
      'The name of the group of users who can see/change private comments and attachments.',
    'The name of the group of users who can see/change time tracking information.' =>
      'The name of the group of users who can see/change time tracking information.',
    'The name of the group of users who can share their saved searches with others.' =>
      'The name of the group of users who can share their saved searches with others.',
    '<p>Do you wish to restrict visibility of users to members of specific groups, based on the configuration specified in group settings?</p><p>If yes, each group can be allowed to see members of selected other groups.</p>' =>
      '<p>Do you wish to restrict visibility of users to members of specific groups, based on the configuration specified in group settings?</p><p>If yes, each group can be allowed to see members of selected other groups.</p>',
    'Don\'t allow users to be assigned to, be qa-contacts on, be added to CC list, or make or remove dependencies involving any bug that is in a product on which that user is forbidden to edit.' =>
      'Don\'t allow users to be assigned to, be qa-contacts on, be added to CC list, or make or remove dependencies involving any bug that is in a product on which that user is forbidden to edit.',
  },
  'admin/params/index.html.tmpl' => {
    'All parameters are displayed below, per section. If you cannot find one from here, then the parameter does not exist.' =>
      'All parameters are displayed below, per section. If you cannot find one from here, then the parameter does not exist.',
    'Parameter' =>
      'Parameter',
    'Section' =>
      'Section',
  },
  'admin/params/integration.html.tmpl' => {
    'Integration config' =>
      'Integration config',
    'Configuration for integrating Bugzilla with external systems (MediaWiki, ViewVC, etc)' =>
      'Configuration for integrating Bugzilla with external systems (MediaWiki, ViewVC, etc)',
    '<p style=\'margin: 0\'>Perl regular expressions for checking \'See Also\' field. Only values that match one of these regexes are allowed. Format:</p><pre style=\'margin: 8px 0; padding: 4px; background: white; border: 1px solid gray;\'># Lines that start with # are treated as comments\\n&lt;REGEX&gt;   &lt;REPLACEMENT&gt;</pre>' =>
      '<p style=\'margin: 0\'>Perl regular expressions for checking \'See Also\' field. Only values that match one of these regexes are allowed. Format:</p><pre style=\'margin: 8px 0; padding: 4px; background: white; border: 1px solid gray;\'># Lines that start with # are treated as comments\\n&lt;REGEX&gt;   &lt;REPLACEMENT&gt;</pre>',
    'URL template for Gravatar-like avatars. You can use either \\$MD5 or \\$EMAIL in it to get avatar picture by user email. \\$EMAIL will be replaced by cleartext user email, so you should only never use it in public networks; \\$MD5 will be replaced by MD5 hash of user email, just like it is required by real Gravatar service. You can also disable avatar display by clearing this parameter.' =>
      'URL template for Gravatar-like avatars. You can use either \\$MD5 or \\$EMAIL in it to get avatar picture by user email. \\$EMAIL will be replaced by cleartext user email, so you should only never use it in public networks; \\$MD5 will be replaced by MD5 hash of user email, just like it is required by real Gravatar service. You can also disable avatar display by clearing this parameter.',
    '<p style=\'margin: 0\'>VCS/Wiki/whatever query URLs for \'Look for bug in ...\' links, one per line, separated by \':\'.</p><pre class=\'cfg_example\'>CVS/SVN: http://viewvc.local/?view=query&comment=bug\\$BUG+\\$BUG&comment_match=fulltext&querysort=date&date=all</pre><p style=\'margin: 0; clear: both\'>$BUG will be replaced with bug ID in these URLs.</p>' =>
      '<p style=\'margin: 0\'>VCS/Wiki/whatever query URLs for \'Look for bug in ...\' links, one per line, separated by \':\'.</p><pre class=\'cfg_example\'>CVS/SVN: http://viewvc.local/?view=query&comment=bug\\$BUG+\\$BUG&comment_match=fulltext&querysort=date&date=all</pre><p style=\'margin: 0; clear: both\'>$BUG will be replaced with bug ID in these URLs.</p>',
    'Default MediaWiki URL for bug links. Bugzilla4Intranet links to <tt>&lt;wiki_url&gt;/Bug_XXX</tt> pages when this is non-empty.' =>
      'Default MediaWiki URL for bug links. Bugzilla4Intranet links to <tt>&lt;wiki_url&gt;/Bug_XXX</tt> pages when this is non-empty.',
    '<p style=\'margin: 0\'>Known MediaWiki URLs to be quoted in bug comments, one per line. Example:</p><pre class=\'cfg_example\'>wikipedia http://en.wikipedia.org/wiki/</pre><p style=\'margin: 0; clear: both\'>Links like <b><tt>wikipedia:Article_name#Section</tt></b> and <b><tt>wikipedia:[[Article name#Section]]</tt></b><br /> will be quoted and lead to <b>Section</b> (optional) of <b>Article name</b> page in the Wikipedia.</p>' =>
      '<p style=\'margin: 0\'>Known MediaWiki URLs to be quoted in bug comments, one per line. Example:</p><pre class=\'cfg_example\'>wikipedia http://en.wikipedia.org/wiki/</pre><p style=\'margin: 0; clear: both\'>Links like <b><tt>wikipedia:Article_name#Section</tt></b> and <b><tt>wikipedia:[[Article name#Section]]</tt></b><br /> will be quoted and lead to <b>Section</b> (optional) of <b>Article name</b> page in the Wikipedia.</p>',
    'Substitution for \'mailto:\', you may use a link to user search by email in an external system.' =>
      'Substitution for \'mailto:\', you may use a link to user search by email in an external system.',
    'Disable automatic refresh of DB views on user/group/saved search changes.' =>
      'Disable automatic refresh of DB views on user/group/saved search changes.',
  },
  'admin/params/ldap.html.tmpl' => {
    'Configure this first before choosing LDAP as an authentication method' =>
      'Configure this first before choosing LDAP as an authentication method',
    '<p>LDAP authentication is a module for Bugzilla\'s plugin authentication architecture. This page contains the parameters required to use it. After setting them up, also set \'LDAP\' value for the \'user_verify_class\' parameter.</p><p>NOTE: If you end up with no working authentication methods listed as \'user_verify_class\', you may not be able to log back in to Bugzilla once you log out. If this happens to you, you will need to manually edit <tt>data/params</tt> and set \'user_verify_class\' to \'DB\'.</p><p>The existing authentication scheme for Bugzilla uses email addresses as the primary user ID, and a password to authenticate that user. All places within Bugzilla that require a user ID (e.g assigning a bug) use the email address. The LDAP authentication builds on top of this scheme, rather than replacing it. The initial log-in is done with a username and password for the LDAP directory. Bugzilla tries to bind to LDAP using those credentials and, if successful, tries to map this account to a Bugzilla account. If an LDAP mail attribute is defined, the value of this attribute is used, otherwise the \'emailsuffix\' parameter is appended to LDAP username to form a full email address. If an account for this address already exists in the Bugzilla installation, it will log in to that account. If no account for that email address exists, one is created at the time of login. (In this case, Bugzilla will attempt to use the \'displayName\' or \'cn\' attribute to determine the user\'s full name.) After authentication, all other user-related tasks are still handled by email address, not LDAP username. For example, bugs are still assigned by email address and users are still queried by email address.</p><p>CAUTION: Because the Bugzilla account is not created until the first time a user logs in, a user who has not yet logged is unknown to Bugzilla. This means they cannot be used as an assignee or QA contact (default or otherwise), added to any CC list, or any other such operation. One possible workaround is the <i><tt>bugzilla_ldapsync.rb</tt></i> script in the _contrib_ directory. Another possible solution is fixing <a href=\'https://bugzilla.mozilla.org/show_bug.cgi?id=201069\'>bug 201069</a>.</p>' =>
      '<p>LDAP authentication is a module for Bugzilla\'s plugin authentication architecture. This page contains the parameters required to use it. After setting them up, also set \'LDAP\' value for the \'user_verify_class\' parameter.</p><p>NOTE: If you end up with no working authentication methods listed as \'user_verify_class\', you may not be able to log back in to Bugzilla once you log out. If this happens to you, you will need to manually edit <tt>data/params</tt> and set \'user_verify_class\' to \'DB\'.</p><p>The existing authentication scheme for Bugzilla uses email addresses as the primary user ID, and a password to authenticate that user. All places within Bugzilla that require a user ID (e.g assigning a bug) use the email address. The LDAP authentication builds on top of this scheme, rather than replacing it. The initial log-in is done with a username and password for the LDAP directory. Bugzilla tries to bind to LDAP using those credentials and, if successful, tries to map this account to a Bugzilla account. If an LDAP mail attribute is defined, the value of this attribute is used, otherwise the \'emailsuffix\' parameter is appended to LDAP username to form a full email address. If an account for this address already exists in the Bugzilla installation, it will log in to that account. If no account for that email address exists, one is created at the time of login. (In this case, Bugzilla will attempt to use the \'displayName\' or \'cn\' attribute to determine the user\'s full name.) After authentication, all other user-related tasks are still handled by email address, not LDAP username. For example, bugs are still assigned by email address and users are still queried by email address.</p><p>CAUTION: Because the Bugzilla account is not created until the first time a user logs in, a user who has not yet logged is unknown to Bugzilla. This means they cannot be used as an assignee or QA contact (default or otherwise), added to any CC list, or any other such operation. One possible workaround is the <i><tt>bugzilla_ldapsync.rb</tt></i> script in the _contrib_ directory. Another possible solution is fixing <a href=\'https://bugzilla.mozilla.org/show_bug.cgi?id=201069\'>bug 201069</a>.</p>',
    'The name (and optionally port) of your LDAP server (e.g. ldap.company.com, or ldap.company.com:portnum). URI syntax can also be used, such as ldaps://ldap.company.com (for a secure connection) or ldapi://%2fvar%2flib%2fldap_sock (for a socket-based local connection. Multiple hostnames or URIs can be comma separated; each will be tried in turn until a connection is established.' =>
      'The name (and optionally port) of your LDAP server (e.g. ldap.company.com, or ldap.company.com:portnum). URI syntax can also be used, such as ldaps://ldap.company.com (for a secure connection) or ldapi://%2fvar%2flib%2fldap_sock (for a socket-based local connection. Multiple hostnames or URIs can be comma separated; each will be tried in turn until a connection is established.',
    'Whether to require encrypted communication once a normal LDAP connection is achieved with the server.' =>
      'Whether to require encrypted communication once a normal LDAP connection is achieved with the server.',
    'If your LDAP server requires that you use a binddn and password instead of binding anonymously, enter it here (e.g. cn=default,cn=user:password). Leave this empty for the normal case of an anonymous bind.' =>
      'If your LDAP server requires that you use a binddn and password instead of binding anonymously, enter it here (e.g. cn=default,cn=user:password). Leave this empty for the normal case of an anonymous bind.',
    'The BaseDN for authenticating users against (e.g. ou=People,o=Company).' =>
      'The BaseDN for authenticating users against (e.g. ou=People,o=Company).',
    'The name of the attribute containing the user\'s login name.' =>
      'The name of the attribute containing the user\'s login name.',
    'The name of the attribute of a user in your directory that contains the email address, to be used as $terms.Bugzilla username. If this parameter is empty, $terms.Bugzilla will use the LDAP username as the $terms.Bugzilla username. You may also want to set the "emailsuffix" parameter, in this case.' =>
      'The name of the attribute of a user in your directory that contains the email address, to be used as $terms.Bugzilla username. If this parameter is empty, $terms.Bugzilla will use the LDAP username as the $terms.Bugzilla username. You may also want to set the "emailsuffix" parameter, in this case.',
    'LDAP filter to AND with the <tt>LDAPuidattribute</tt> for filtering the list of valid users.' =>
      'LDAP filter to AND with the <tt>LDAPuidattribute</tt> for filtering the list of valid users.',
  },
  'admin/params/mta.html.tmpl' => {
    'Email' =>
      'Email',
    'How will outgoing mail be delivered?' =>
      'How will outgoing mail be delivered?',
    'This page contains all of the parameters for configuring how Bugzilla deals with the email notifications it sends.' =>
      'This page contains all of the parameters for configuring how Bugzilla deals with the email notifications it sends.',
    'Defines how email is sent, or if it is sent at all.<br />
<ul>
<li>
\'Sendmail\', \'SMTP\' and \'Qmail\' are all MTAs.
You need to install a third-party sendmail replacement if
you want to use sendmail on Windows.
</li>
<li>
\'Test\' is useful for debugging: all email is stored
in \'data/mailer.testfile\' instead of being sent.
</li>
<li>
\'none\' will completely disable email. $terms.Bugzilla continues
to act as though it is sending mail, but nothing is sent or
stored.
</li>
</ul>' =>
      'Defines how email is sent, or if it is sent at all.<br />
<ul>
<li>
\'Sendmail\', \'SMTP\' and \'Qmail\' are all MTAs.
You need to install a third-party sendmail replacement if
you want to use sendmail on Windows.
</li>
<li>
\'Test\' is useful for debugging: all email is stored
in \'data/mailer.testfile\' instead of being sent.
</li>
<li>
\'none\' will completely disable email. $terms.Bugzilla continues
to act as though it is sending mail, but nothing is sent or
stored.
</li>
</ul>',
    'The email address of the $terms.Bugzilla mail daemon.  Some email systems require this to be a valid email address.' =>
      'The email address of the $terms.Bugzilla mail daemon.  Some email systems require this to be a valid email address.',
    'In a large $terms.Bugzilla installation, updating $terms.bugs can be very slow, because $terms.Bugzilla sends all email at once. If you enable this parameter, $terms.Bugzilla will queue all mail and then send it in the background. This requires that you have installed certain Perl modules (as listed by <code>checksetup.pl</code> for this feature), and that you are running the <code>jobqueue.pl</code> daemon (otherwise your mail won\'t get sent). This affects all mail sent by $terms.Bugzilla, not just $terms.bug updates.' =>
      'In a large $terms.Bugzilla installation, updating $terms.bugs can be very slow, because $terms.Bugzilla sends all email at once. If you enable this parameter, $terms.Bugzilla will queue all mail and then send it in the background. This requires that you have installed certain Perl modules (as listed by <code>checksetup.pl</code> for this feature), and that you are running the <code>jobqueue.pl</code> daemon (otherwise your mail won\'t get sent). This affects all mail sent by $terms.Bugzilla, not just $terms.bug updates.',
    'Sites using anything older than version 8.12 of \'sendmail\' can achieve a significant performance increase in the UI -- at the cost of delaying the sending of mail -- by disabling this parameter. Sites using \'sendmail\' 8.12 or higher should leave this on, as they will see no benefit from turning it off. Sites using an MTA other than \'sendmail\' <b>must</b> leave it on, or no $terms.bug mail will be sent.' =>
      'Sites using anything older than version 8.12 of \'sendmail\' can achieve a significant performance increase in the UI -- at the cost of delaying the sending of mail -- by disabling this parameter. Sites using \'sendmail\' 8.12 or higher should leave this on, as they will see no benefit from turning it off. Sites using an MTA other than \'sendmail\' <b>must</b> leave it on, or no $terms.bug mail will be sent.',
    'The SMTP server address (if using SMTP for mail delivery).' =>
      'The SMTP server address (if using SMTP for mail delivery).',
    'The username to pass to the SMTP server for SMTP authentication. Leave this field empty if your SMTP server doesn\'t require authentication.' =>
      'The username to pass to the SMTP server for SMTP authentication. Leave this field empty if your SMTP server doesn\'t require authentication.',
    'The password to pass to the SMTP server for SMTP authentication. This field has no effect if the smtp_username parameter is left empty.' =>
      'The password to pass to the SMTP server for SMTP authentication. This field has no effect if the smtp_username parameter is left empty.',
    'If enabled, this will print detailed information to your web server\'s error log about the communication between $terms.Bugzilla and your SMTP server. You can use this to troubleshoot email problems.' =>
      'If enabled, this will print detailed information to your web server\'s error log about the communication between $terms.Bugzilla and your SMTP server. You can use this to troubleshoot email problems.',
    'The number of days that we\'ll let a $terms.bug sit untouched in a NEW state before our cronjob will whine at the owner.<br /> Set to 0 to disable whining.' =>
      'The number of days that we\'ll let a $terms.bug sit untouched in a NEW state before our cronjob will whine at the owner.<br /> Set to 0 to disable whining.',
    'A comma-separated list of users who should receive a copy of every notification mail the system sends.' =>
      'A comma-separated list of users who should receive a copy of every notification mail the system sends.',
  },
  'admin/params/patchviewer.html.tmpl' => {
    'Patch Viewer' =>
      'Patch Viewer',
    'Set up third-party applications to run with PatchViewer' =>
      'Set up third-party applications to run with PatchViewer',
    'The <a href="http://www.cvshome.org">CVS</a> root that most users of your system will be using for \'cvs diff\'. Used in Patch Viewer (\'Diff\' option on patches) to figure out where patches are rooted even if users did the \'cvs diff\' from different places in the directory structure. (NOTE: if your CVS repository is remote and requires a password, you must either ensure the $terms.Bugzilla user has done a \'cvs login\' or specify the password <a href="http://www.cvshome.org/docs/manual/cvs_2.html#SEC26">as part of the CVS root</a>.) Leave this blank if you have no CVS repository.' =>
      'The <a href="http://www.cvshome.org">CVS</a> root that most users of your system will be using for \'cvs diff\'. Used in Patch Viewer (\'Diff\' option on patches) to figure out where patches are rooted even if users did the \'cvs diff\' from different places in the directory structure. (NOTE: if your CVS repository is remote and requires a password, you must either ensure the $terms.Bugzilla user has done a \'cvs login\' or specify the password <a href="http://www.cvshome.org/docs/manual/cvs_2.html#SEC26">as part of the CVS root</a>.) Leave this blank if you have no CVS repository.',
    'The CVS root $terms.Bugzilla will be using to get patches from. Some installations may want to mirror their CVS repository on the $terms.Bugzilla server or even have it on that same server, and thus the repository can be the local file system (and much faster). Make this the same as cvsroot if you don\'t understand what this is (if cvsroot is blank, make this blank too).' =>
      'The CVS root $terms.Bugzilla will be using to get patches from. Some installations may want to mirror their CVS repository on the $terms.Bugzilla server or even have it on that same server, and thus the repository can be the local file system (and much faster). Make this the same as cvsroot if you don\'t understand what this is (if cvsroot is blank, make this blank too).',
    'The URL to a <a href="http://www.mozilla.org/bonsai.html">Bonsai</a> server containing information about your CVS repository. Patch Viewer will use this information to create links to bonsai\'s blame for each section of a patch (it will append \'/cvsblame.cgi?...\' to this url). Leave this blank if you don\'t understand what this is.' =>
      'The URL to a <a href="http://www.mozilla.org/bonsai.html">Bonsai</a> server containing information about your CVS repository. Patch Viewer will use this information to create links to bonsai\'s blame for each section of a patch (it will append \'/cvsblame.cgi?...\' to this url). Leave this blank if you don\'t understand what this is.',
    'The URL to an <a href="http://sourceforge.net/projects/lxr">LXR</a> server that indexes your CVS repository. Patch Viewer will use this information to create links to LXR for each file in a patch. Leave this blank if you don\'t understand what this is.' =>
      'The URL to an <a href="http://sourceforge.net/projects/lxr">LXR</a> server that indexes your CVS repository. Patch Viewer will use this information to create links to LXR for each file in a patch. Leave this blank if you don\'t understand what this is.',
    'Some LXR installations do not index the CVS repository from the root -- <a href="http://lxr.mozilla.org/mozilla">Mozilla\'s</a>, for example, starts indexing under <code>mozilla/</code>. This means URLs are relative to that extra path under the root. Enter this if you have a similar situation. Leave it blank if you don\'t know what this is.' =>
      'Some LXR installations do not index the CVS repository from the root -- <a href="http://lxr.mozilla.org/mozilla">Mozilla\'s</a>, for example, starts indexing under <code>mozilla/</code>. This means URLs are relative to that extra path under the root. Enter this if you have a similar situation. Leave it blank if you don\'t know what this is.',
  },
  'admin/params/query.html.tmpl' => {
    'Query Defaults' =>
      'Query Defaults',
    'Default options for query and $terms.bug lists' =>
      'Default options for query and $terms.bug lists',
    'Controls how easily users can add entries to the quip list.
<ul>
<li>
open - Users may freely add to the quip list, and
their entries will immediately be available for viewing.
</li>
<li>
moderated - quips can be entered, but need to be approved
by an admin before they will be shown.
</li>
<li>
closed - no new additions to the quips list are allowed.
</li>
</ul>' =>
      'Controls how easily users can add entries to the quip list.
<ul>
<li>
open - Users may freely add to the quip list, and
their entries will immediately be available for viewing.
</li>
<li>
moderated - quips can be entered, but need to be approved
by an admin before they will be shown.
</li>
<li>
closed - no new additions to the quips list are allowed.
</li>
</ul>',
    'The minimum number of duplicates $terms.abug needs to show up on the <a href="duplicates.cgi">most frequently reported $terms.bugs page</a>. If you have a large database and this page takes a long time to load, try increasing this number.' =>
      'The minimum number of duplicates $terms.abug needs to show up on the <a href="duplicates.cgi">most frequently reported $terms.bugs page</a>. If you have a large database and this page takes a long time to load, try increasing this number.',
    'This is the URL to use to bring up a simple \'all of my $terms.bugs\' list for a user. %userid% will get replaced with the login name of a user.' =>
      'This is the URL to use to bring up a simple \'all of my $terms.bugs\' list for a user. %userid% will get replaced with the login name of a user.',
    'This is the default query that initially comes up when you access the advanced query page. It\'s in URL parameter format, which makes it hard to read. Sorry!' =>
      'This is the default query that initially comes up when you access the advanced query page. It\'s in URL parameter format, which makes it hard to read. Sorry!',
    'Whether to allow a search on the \'Simple Search\' page with an empty \'Words\' field.' =>
      'Whether to allow a search on the \'Simple Search\' page with an empty \'Words\' field.',
    'Language for stemming words in full-text search, 2-letter code (one of: da, de, en, es, fi, fr, hu, it, nl, no, pt, ro, ru, sv, tr)' =>
      'Language for stemming words in full-text search, 2-letter code (one of: da, de, en, es, fi, fr, hu, it, nl, no, pt, ro, ru, sv, tr)',
    'Set it to the same value as max_matches in your Sphinx search configuration. Default is 1000 and if it\'s not enough you may sometimes miss some search results when using Sphinx.' =>
      'Set it to the same value as max_matches in your Sphinx search configuration. Default is 1000 and if it\'s not enough you may sometimes miss some search results when using Sphinx.',
  },
  'admin/params/radius.html.tmpl' => {
    'Configure this first before choosing RADIUS as an authentication method' =>
      'Configure this first before choosing RADIUS as an authentication method',
    '<p>RADIUS authentication is a module for Bugzilla\'s plugin authentication architecture. This page contains the parameters required to use it. After setting them up, also set \'RADIUS\' value for the \'user_verify_class\' parameter.</p><p>NOTE: Most caveats that apply to LDAP authentication apply to RADIUS authentication as well.</p>' =>
      '<p>RADIUS authentication is a module for Bugzilla\'s plugin authentication architecture. This page contains the parameters required to use it. After setting them up, also set \'RADIUS\' value for the \'user_verify_class\' parameter.</p><p>NOTE: Most caveats that apply to LDAP authentication apply to RADIUS authentication as well.</p>',
    'The name (and optionally port) of your RADIUS server (e.g. <code>radius.company.com</code>, or <code>radius.company.com:portnum</code>).<br />Required only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.' =>
      'The name (and optionally port) of your RADIUS server (e.g. <code>radius.company.com</code>, or <code>radius.company.com:portnum</code>).<br />Required only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.',
    'Your RADIUS server\'s secret.<br />Required only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.' =>
      'Your RADIUS server\'s secret.<br />Required only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.',
    'The NAS-IP-Address attribute to be used when exchanging data with your RADIUS server. If unspecified, <code>127.0.0.1</code> will be used.<br />Useful only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.' =>
      'The NAS-IP-Address attribute to be used when exchanging data with your RADIUS server. If unspecified, <code>127.0.0.1</code> will be used.<br />Useful only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.',
    'Suffix to append to a RADIUS user name to form an e-mail address.<br />Useful only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.' =>
      'Suffix to append to a RADIUS user name to form an e-mail address.<br />Useful only if <a href="?section=auth#user_verify_class">the <code>user_verify_class</code> parameter</a> contains <code>RADIUS</code>.',
  },
  'admin/params/shadowdb.html.tmpl' => {
    'Shadow Database' =>
      'Shadow Database',
    'An optional hack to increase database performance' =>
      'An optional hack to increase database performance',
    '<p>Versions of Bugzilla prior to 3.2 used the MySQL MyISAM table type, which supports only table-level write locking. With MyISAM, any time someone is making a change to a bug, the entire table is locked until the write operation is complete. Locking for write also blocks reads until the write is complete.</p><p>The \'Shadow DB\' feature was designed to get around this limitation. The idea was to set up replication to a separate MySQL "slave" instance and use it for read queries. This allowed everyone to read tables that were otherwise locked by the concurrent users.</p><p>As of version 3.2, Bugzilla no longer uses the MyISAM table type. Instead, InnoDB is used, which has <a href="http://en.wikipedia.org/wiki/Multiversion_concurrency_control">MVCC</a> allowing writers to not block readers. Therefore, the limitations the Shadow Database feature was designed to workaround <b>no longer exist</b>. Nobody is blocked even by very complex long-running search queries.</p>' =>
      '<p>Versions of Bugzilla prior to 3.2 used the MySQL MyISAM table type, which supports only table-level write locking. With MyISAM, any time someone is making a change to a bug, the entire table is locked until the write operation is complete. Locking for write also blocks reads until the write is complete.</p><p>The \'Shadow DB\' feature was designed to get around this limitation. The idea was to set up replication to a separate MySQL "slave" instance and use it for read queries. This allowed everyone to read tables that were otherwise locked by the concurrent users.</p><p>As of version 3.2, Bugzilla no longer uses the MyISAM table type. Instead, InnoDB is used, which has <a href="http://en.wikipedia.org/wiki/Multiversion_concurrency_control">MVCC</a> allowing writers to not block readers. Therefore, the limitations the Shadow Database feature was designed to workaround <b>no longer exist</b>. Nobody is blocked even by very complex long-running search queries.</p>',
    'The host the shadow database is on.' =>
      'The host the shadow database is on.',
    'The port the shadow database is on. Ignored if <tt>shadowdbhost</tt> is blank. Note: if the host is the local machine, then MySQL will ignore this setting, and you must specify a socket below.' =>
      'The port the shadow database is on. Ignored if <tt>shadowdbhost</tt> is blank. Note: if the host is the local machine, then MySQL will ignore this setting, and you must specify a socket below.',
    'The socket used to connect to the shadow database, if the host is the local machine. This setting is required because MySQL ignores the port specified by the client and connects using its compiled-in socket path (on unix machines) when connecting from a client to a local server. If you leave this blank, and have the database on localhost, then the <tt>shadowdbport</tt> will be ignored.' =>
      'The socket used to connect to the shadow database, if the host is the local machine. This setting is required because MySQL ignores the port specified by the client and connects using its compiled-in socket path (on unix machines) when connecting from a client to a local server. If you leave this blank, and have the database on localhost, then the <tt>shadowdbport</tt> will be ignored.',
    'If non-empty, then this is the name of another database in which $terms.Bugzilla will use as a read-only copy of everything. This is done so that long slow read-only operations can be used against this db, and not lock up things for everyone else. This database is on the <tt>shadowdbhost</tt>, and must exist. $terms.Bugzilla does not update it, if you use this parameter, then you need to set up replication for your database.' =>
      'If non-empty, then this is the name of another database in which $terms.Bugzilla will use as a read-only copy of everything. This is done so that long slow read-only operations can be used against this db, and not lock up things for everyone else. This database is on the <tt>shadowdbhost</tt>, and must exist. $terms.Bugzilla does not update it, if you use this parameter, then you need to set up replication for your database.',
  },
  'admin/params/usermatch.html.tmpl' => {
    'User Matching' =>
      'User Matching',
    'Set up your user matching policies' =>
      'Set up your user matching policies',
    'The settings on this page control how users are selected and queried when adding a user to a bug.' =>
      'The settings on this page control how users are selected and queried when adding a user to a bug.',
    'If this option is set, all registered users will be shown in user autocomplete boxes when the corresponding field is empty. Enable only if you have a fairly small amount of registered users.' =>
      'If this option is set, all registered users will be shown in user autocomplete boxes when the corresponding field is empty. Enable only if you have a fairly small amount of registered users.',
    'Search for no more than this many matches.<br /> If set to \'1\', no users will be displayed on ambiguous matches. A value of zero means no limit.' =>
      'Search for no more than this many matches.<br /> If set to \'1\', no users will be displayed on ambiguous matches. A value of zero means no limit.',
    'Whether a confirmation screen should be displayed when only one user matches a search entry.' =>
      'Whether a confirmation screen should be displayed when only one user matches a search entry.',
    'Whether an unknown e-mail address should be converted into an automatically registered disabled user account when processing incoming emails by email_in.pl' =>
      'Whether an unknown e-mail address should be converted into an automatically registered disabled user account when processing incoming emails by email_in.pl',
    'If this option is set to a positive integer N, $terms.Bugzilla will effectively correct N \'misprints\' in user login names by using the Levenshtein distance function for matching users. If N is a floating point value, it is treated relative to the length of user name. <br />WARNING: Levenshtein distance is calculated via SQL function <tt>LEVENSHTEIN()</tt> which <b>must be installed separately</b> as a <a href=\'https://github.com/vitalif/mysql-levenshtein\'>UDF for MySQL</a> or <a href=\'http://www.postgresql.org/docs/9.3/static/fuzzystrmatch.html\'>fuzzystrmatch module for PostgreSQL</a>.' =>
      'If this option is set to a positive integer N, $terms.Bugzilla will effectively correct N \'misprints\' in user login names by using the Levenshtein distance function for matching users. If N is a floating point value, it is treated relative to the length of user name. <br />WARNING: Levenshtein distance is calculated via SQL function <tt>LEVENSHTEIN()</tt> which <b>must be installed separately</b> as a <a href=\'https://github.com/vitalif/mysql-levenshtein\'>UDF for MySQL</a> or <a href=\'http://www.postgresql.org/docs/9.3/static/fuzzystrmatch.html\'>fuzzystrmatch module for PostgreSQL</a>.',
  },
  'admin/products/confirm-delete.html.tmpl' => {
    'Delete Product \'' =>
      'Delete Product \'',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Classification:' =>
      'Classification:',
    'Classification Description:' =>
      'Classification Description:',
    'missing' =>
      'missing',
    'Product:' =>
      'Product:',
    'Description:' =>
      'Description:',
    'Closed for $terms.bugs:' =>
      'Closed for $terms.bugs:',
    'open' =>
      'open',
    'closed' =>
      'closed',
    'Edit components for product ' =>
      'Edit components for product ',
    'Components:' =>
      'Components:',
    'none' =>
      'none',
    'Versions:' =>
      'Versions:',
    'Milestones:' =>
      'Milestones:',
    'List of $terms.bugs for product ' =>
      'List of $terms.bugs for product ',
    'Confirmation' =>
      'Confirmation',
    'Sorry, there' =>
      'Sorry, there',
    'are' =>
      'are',
    'is 1 $terms.bug' =>
      'is 1 $terms.bug',
    'outstanding for this product. You must reassign' =>
      'outstanding for this product. You must reassign',
    'those $terms.bugs' =>
      'those $terms.bugs',
    'that $terms.bug' =>
      'that $terms.bug',
    'to another product before you can delete this one.' =>
      'to another product before you can delete this one.',
    'There' =>
      'There',
    'entered for this product! When you delete this product, <b>' =>
      'entered for this product! When you delete this product, <b>',
    'ALL' =>
      'ALL',
    '</b> stored $terms.bugs and their history will be deleted, too.' =>
      '</b> stored $terms.bugs and their history will be deleted, too.',
    'Do you really want to delete this product?' =>
      'Do you really want to delete this product?',
    'Delete all related series (you can also delete them later, by visiting the' =>
      'Delete all related series (you can also delete them later, by visiting the',
    'New Charts page' =>
      'New Charts page',
    'Yes, delete' =>
      'Yes, delete',
  },
  'admin/products/create.html.tmpl' => {
    'Add Product' =>
      'Add Product',
    'Version (optional):' =>
      'Version (optional):',
    'Create chart datasets for this product' =>
      'Create chart datasets for this product',
    'Create access group for this product' =>
      'Create access group for this product',
    'Create administration group for this product' =>
      'Create administration group for this product',
    'Add' =>
      'Add',
  },
  'admin/products/edit-common.html.tmpl' => {
    '<b>Classification:</b>' =>
      '<b>Classification:</b>',
    'Product:' =>
      'Product:',
    'Description:' =>
      'Description:',
    'HTML code to display' =>
      'HTML code to display',
    'above the bug form:' =>
      'above the bug form:',
    'Open for $terms.bug entry:' =>
      'Open for $terms.bug entry:',
    'Allow unconfirmed:' =>
      'Allow unconfirmed:',
    '...and automatically confirm $terms.bugs if they get' =>
      '...and automatically confirm $terms.bugs if they get',
    'votes. (Setting this to 0 disables auto-confirming $terms.bugs by vote.)' =>
      'votes. (Setting this to 0 disables auto-confirming $terms.bugs by vote.)',
    'Wiki URL prefix:' =>
      'Wiki URL prefix:',
    '<em>Empty means use default setting.</em>' =>
      '<em>Empty means use default setting.</em>',
    'Prefer no timetracking:' =>
      'Prefer no timetracking:',
    'External product:' =>
      'External product:',
    'CC group:' =>
      'CC group:',
    '<i> Disallow users not in this group to be Assignee, QA or CC in this product.' =>
      '<i> Disallow users not in this group to be Assignee, QA or CC in this product.',
    'They will still be allowed to see this product bugs or even report new ones if group permissions allow them to do so though. </i>' =>
      'They will still be allowed to see this product bugs or even report new ones if group permissions allow them to do so though. </i>',
    'Maximum votes:' =>
      'Maximum votes:',
    'per user:' =>
      'per user:',
    'per user, per single $terms.bug:' =>
      'per user, per single $terms.bug:',
  },
  'admin/products/edit.html.tmpl' => {
    'Edit Product \'' =>
      'Edit Product \'',
    'Shown' =>
      'Shown',
    'Default' =>
      'Default',
    'Mandatory' =>
      'Mandatory',
    'Edit components:' =>
      'Edit components:',
    'description missing' =>
      'description missing',
    'missing' =>
      'missing',
    'Edit versions:' =>
      'Edit versions:',
    'Edit milestones:' =>
      'Edit milestones:',
    'Group access controls:' =>
      'Group access controls:',
    ', ENTRY' =>
      ', ENTRY',
    ', CANEDIT' =>
      ', CANEDIT',
    ', editcomponents' =>
      ', editcomponents',
    ', canconfirm' =>
      ', canconfirm',
    ', editbugs' =>
      ', editbugs',
    'DISABLED' =>
      'DISABLED',
    'no groups' =>
      'no groups',
    'Save Changes' =>
      'Save Changes',
  },
  'admin/products/footer.html.tmpl' => {
    'of classification \'' =>
      'of classification \'',
    'Add a product to classification ' =>
      'Add a product to classification ',
    'Add a product to classification \'' =>
      'Add a product to classification \'',
    'Add a product to other classification' =>
      'Add a product to other classification',
    ', to' =>
      ', to',
    'other classification' =>
      'other classification',
    'Add a product' =>
      'Add a product',
    'Edit Product ' =>
      'Edit Product ',
    'Edit product' =>
      'Edit product',
    'Edit' =>
      'Edit',
    'other products' =>
      'other products',
    'Edit classification' =>
      'Edit classification',
  },
  'admin/products/groupcontrol/confirm-edit.html.tmpl' => {
    'Confirm Group Control Change for product \'' =>
      'Confirm Group Control Change for product \'',
    'group \'' =>
      'group \'',
    '\' impacts' =>
      '\' impacts',
    '$terms.bugs for which the group is newly mandatory and will be added.' =>
      '$terms.bugs for which the group is newly mandatory and will be added.',
    '&nbsp; $terms.bugs for which the group is no longer applicable and will be removed.' =>
      '&nbsp; $terms.bugs for which the group is no longer applicable and will be removed.',
    'Click "Continue" to proceed with the change including the changes indicated above. If you do not want these changes, use "back" to return to the previous page.' =>
      'Click "Continue" to proceed with the change including the changes indicated above. If you do not want these changes, use "back" to return to the previous page.',
    'Continue' =>
      'Continue',
  },
  'admin/products/groupcontrol/edit.html.tmpl' => {
    'Edit Group Controls for' =>
      'Edit Group Controls for',
    'Shown' =>
      'Shown',
    'Default' =>
      'Default',
    'Mandatory' =>
      'Mandatory',
    'Delete this group' =>
      'Delete this group',
    '&lt;no groups&gt;' =>
      '&lt;no groups&gt;',
    'Add a group:' =>
      'Add a group:',
    'Add this group' =>
      'Add this group',
    'Group controls for product' =>
      'Group controls for product',
    'Access control (Member/Other):' =>
      'Access control (Member/Other):',
    'used in' =>
      'used in',
    'bugs' =>
      'bugs',
    'Delete' =>
      'Delete',
    '&lt;no control groups&gt;' =>
      '&lt;no control groups&gt;',
    'Add new group' =>
      'Add new group',
    'Restrict bug entry to intersection of following groups:' =>
      'Restrict bug entry to intersection of following groups:',
    'Restrict editing and commenting bugs to:' =>
      'Restrict editing and commenting bugs to:',
    'Allow product and component administration for members of any of the following groups:' =>
      'Allow product and component administration for members of any of the following groups:',
    'Allow to confirm bugs for:' =>
      'Allow to confirm bugs for:',
    'Allow to change any field of this product bugs for:' =>
      'Allow to change any field of this product bugs for:',
    'Save changes' =>
      'Save changes',
    'If any group has <b>Entry</b> selected, then this product will restrict $terms.bug entry to only those users who are members of all the groups with entry selected.' =>
      'If any group has <b>Entry</b> selected, then this product will restrict $terms.bug entry to only those users who are members of all the groups with entry selected.',
    'If any group has <b>Canedit</b> selected, then this product will be read-only for any users who are not members of all of the groups with Canedit selected. ONLY users who are members of all the canedit groups will be able to edit. This is an additional restriction that further restricts what can be edited by a user.' =>
      'If any group has <b>Canedit</b> selected, then this product will be read-only for any users who are not members of all of the groups with Canedit selected. ONLY users who are members of all the canedit groups will be able to edit. This is an additional restriction that further restricts what can be edited by a user.',
    'Any group having <b>editcomponents</b> selected allows users who are in this group to edit all aspects of this product, including components, milestones and versions.' =>
      'Any group having <b>editcomponents</b> selected allows users who are in this group to edit all aspects of this product, including components, milestones and versions.',
    'Any group having <b>canconfirm</b> selected allows users who are in this group to confirm $terms.bugs in this product.' =>
      'Any group having <b>canconfirm</b> selected allows users who are in this group to confirm $terms.bugs in this product.',
    'Any group having <b>editbugs</b> selected allows users who are in this group to edit all fields of $terms.bugs in this product.' =>
      'Any group having <b>editbugs</b> selected allows users who are in this group to edit all fields of $terms.bugs in this product.',
    'Show &#x25BE;' =>
      'Show &#x25BE;',
    'Help on Member/Other group control combinations:' =>
      'Help on Member/Other group control combinations:',
    'Access to <i>every particular $terms.bug</i> may be restricted by number of groups. The more groups bug is restricted by, the more secret it is.' =>
      'Access to <i>every particular $terms.bug</i> may be restricted by number of groups. The more groups bug is restricted by, the more secret it is.',
    'Some of these groups may be optional &mdash; in this case <i>some people</i> will be able to decide about making the bug more or less secret by setting or clearing the checkboxes shown on the $terms.bug entry/edit form for such groups.' =>
      'Some of these groups may be optional &mdash; in this case <i>some people</i> will be able to decide about making the bug more or less secret by setting or clearing the checkboxes shown on the $terms.bug entry/edit form for such groups.',
    'Group is optional when it has "Shown" or "Default" MemberControl or OtherControl.' =>
      'Group is optional when it has "Shown" or "Default" MemberControl or OtherControl.',
    '"Some people" means "members of the group" for MemberControl and "everyone else" for OtherControl.' =>
      '"Some people" means "members of the group" for MemberControl and "everyone else" for OtherControl.',
    'MemberControl' =>
      'MemberControl',
    'OtherControl' =>
      'OtherControl',
    'Interpretation' =>
      'Interpretation',
    'Simplest case: all $terms.bugs in this product are always restricted by this group.' =>
      'Simplest case: all $terms.bugs in this product are always restricted by this group.',
    'Members of this group are able to restrict or not to restrict $terms.bugs in this product by this group.' =>
      'Members of this group are able to restrict or not to restrict $terms.bugs in this product by this group.',
    'Non-members are forced to restrict their new $terms.bugs by this group and may not change the restriction of existing $terms.bugs by this group.' =>
      'Non-members are forced to restrict their new $terms.bugs by this group and may not change the restriction of existing $terms.bugs by this group.',
    '$terms.Bug entry form has the group checkbox checked by default for group members.' =>
      '$terms.Bug entry form has the group checkbox checked by default for group members.',
    'Everyone is able to restrict or not to restrict $terms.bugs in this product by this group.' =>
      'Everyone is able to restrict or not to restrict $terms.bugs in this product by this group.',
    '$terms.Bug entry form has the group checkbox checked by default for everyone.' =>
      '$terms.Bug entry form has the group checkbox checked by default for everyone.',
    'NA' =>
      'NA',
    'Non-members may not restrict $terms.bugs by this group.' =>
      'Non-members may not restrict $terms.bugs by this group.',
    '$terms.Bug entry form has the group checkbox unchecked by default for group members.' =>
      '$terms.Bug entry form has the group checkbox unchecked by default for group members.',
    '$terms.Bug entry form has the group checkbox unchecked by default for members of this group, and checked by default for non-members of this group.' =>
      '$terms.Bug entry form has the group checkbox unchecked by default for members of this group, and checked by default for non-members of this group.',
    '$terms.Bug entry form has the group checkbox unchecked by default for everyone.' =>
      '$terms.Bug entry form has the group checkbox unchecked by default for everyone.',
    '$terms.Bug entry form has the group checkbox unchecked by default.' =>
      '$terms.Bug entry form has the group checkbox unchecked by default.',
    '$terms.Bugs in this product are never restricted by this group. Equivalent to removing the group from the list.' =>
      '$terms.Bugs in this product are never restricted by this group. Equivalent to removing the group from the list.',
    'Please note that the above table delineates the only allowable combinations for the <b>MemberControl</b> and <b>OtherControl</b> field settings. Attempting to submit a combination not listed there (e.g. Mandatory/NA, Default/Shown, etc.) will produce an error message.' =>
      'Please note that the above table delineates the only allowable combinations for the <b>MemberControl</b> and <b>OtherControl</b> field settings. Attempting to submit a combination not listed there (e.g. Mandatory/NA, Default/Shown, etc.) will produce an error message.',
  },
  'admin/products/groupcontrol/updated.html.tmpl' => {
    'Update group access controls for' =>
      'Update group access controls for',
    'Removing $terms.bugs from group \'' =>
      'Removing $terms.bugs from group \'',
    '\' which no longer applies to this product' =>
      '\' which no longer applies to this product',
    '$terms.bugs removed' =>
      '$terms.bugs removed',
    'Adding $terms.bugs to group \'' =>
      'Adding $terms.bugs to group \'',
    '\' which is mandatory for this product' =>
      '\' which is mandatory for this product',
    '$terms.bugs added' =>
      '$terms.bugs added',
    'Group control updates done' =>
      'Group control updates done',
  },
  'admin/products/list-classifications.html.tmpl' => {
    'Select Classification' =>
      'Select Classification',
    'Edit products of...' =>
      'Edit products of...',
    'Description' =>
      'Description',
    'Product Count' =>
      'Product Count',
    'Action...' =>
      'Action...',
    'Add product' =>
      'Add product',
  },
  'admin/products/list.html.tmpl' => {
    'in classification \'' =>
      'in classification \'',
    'Select product: ' =>
      'Select product: ',
    'Edit product...' =>
      'Edit product...',
    'Description' =>
      'Description',
    'Open For New $terms.Bugs' =>
      'Open For New $terms.Bugs',
    'Votes Per User' =>
      'Votes Per User',
    'Maximum Votes Per $terms.Bug' =>
      'Maximum Votes Per $terms.Bug',
    'Votes To Confirm' =>
      'Votes To Confirm',
    '$terms.Bug Count' =>
      '$terms.Bug Count',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/products/updated.html.tmpl' => {
    'of classification \'' =>
      'of classification \'',
    'Updating Product \'' =>
      'Updating Product \'',
    'Updated product name from \'' =>
      'Updated product name from \'',
    '\' to \'' =>
      '\' to \'',
    'Product moved from classification \'' =>
      'Product moved from classification \'',
    'Updated description to:' =>
      'Updated description to:',
    'Updated bug entry header HTML to:' =>
      'Updated bug entry header HTML to:',
    'Product is now' =>
      'Product is now',
    'for new $terms.bugs.' =>
      'for new $terms.bugs.',
    'Updated votes per user from' =>
      'Updated votes per user from',
    'to' =>
      'to',
    'Updated maximum votes per $terms.bug from' =>
      'Updated maximum votes per $terms.bug from',
    'Updated number of votes needed to confirm a $terms.bug from' =>
      'Updated number of votes needed to confirm a $terms.bug from',
    'The product now allows unconfirmed states.' =>
      'The product now allows unconfirmed states.',
    'The product no longer allows unconfirmed states. Note that any' =>
      'The product no longer allows unconfirmed states. Note that any',
    '$terms.bugs that currently have unconfirmed states' =>
      '$terms.bugs that currently have unconfirmed states',
    'will remain in that status until they are edited.' =>
      'will remain in that status until they are edited.',
    'Updated Wiki URL from' =>
      'Updated Wiki URL from',
    'not ' =>
      'not ',
    'Product is now preferred to be' =>
      'Product is now preferred to be',
    'time-tracked.' =>
      'time-tracked.',
    'External product is' =>
      'External product is',
    'set to' =>
      'set to',
    'cleared' =>
      'cleared',
    'Empty version' =>
      'Empty version',
    'Empty milestone' =>
      'Empty milestone',
    'Nothing changed for product \'' =>
      'Nothing changed for product \'',
    'Checking existing votes in this product for anybody who now has too many votes for $terms.abug...' =>
      'Checking existing votes in this product for anybody who now has too many votes for $terms.abug...',
    '&rarr;removed votes for $terms.bug' =>
      '&rarr;removed votes for $terms.bug',
    'from' =>
      'from',
    '&rarr;there were none.' =>
      '&rarr;there were none.',
    'Checking existing votes in this product for anybody who now has too many total votes...' =>
      'Checking existing votes in this product for anybody who now has too many total votes...',
    'Checking unconfirmed $terms.bugs in this product for any which now have sufficient votes...' =>
      'Checking unconfirmed $terms.bugs in this product for any which now have sufficient votes...',
    '$terms.bugs confirmed.' =>
      '$terms.bugs confirmed.',
  },
  'admin/sanitycheck/list.html.tmpl' => {
    'Sanity Check' =>
      'Sanity Check',
    '$terms.Bugzilla is checking the referential integrity of your database. This may take several minutes to complete.' =>
      '$terms.Bugzilla is checking the referential integrity of your database. This may take several minutes to complete.',
    'Errors, if any, will be' =>
      'Errors, if any, will be',
    'emphasized like this' =>
      'emphasized like this',
    '. Depending on the errors found, some links will be displayed allowing you to easily fix them. Fixing these errors will automatically run this script again (so be aware that it may take an even longer time than the first run).' =>
      '. Depending on the errors found, some links will be displayed allowing you to easily fix them. Fixing these errors will automatically run this script again (so be aware that it may take an even longer time than the first run).',
  },
  'admin/sanitycheck/messages.html.tmpl' => {
    'OK, now running sanity checks.' =>
      'OK, now running sanity checks.',
    'Sanity check completed.' =>
      'Sanity check completed.',
    'OK, now removing all references to deleted attachments.' =>
      'OK, now removing all references to deleted attachments.',
    'All references to deleted attachments have been removed.' =>
      'All references to deleted attachments have been removed.',
    'Checking for $terms.bugs with no creation date (which makes them invisible).' =>
      'Checking for $terms.bugs with no creation date (which makes them invisible).',
    '$terms.Bugs with no creation date' =>
      '$terms.Bugs with no creation date',
    'Repair missing creation date for these $terms.bugs' =>
      'Repair missing creation date for these $terms.bugs',
    'Checking for $terms.bugs with no entry for full text searching.' =>
      'Checking for $terms.bugs with no entry for full text searching.',
    '$terms.Bugs with no entry for full text searching' =>
      '$terms.Bugs with no entry for full text searching',
    'Repair missing full text search entries for these $terms.bugs' =>
      'Repair missing full text search entries for these $terms.bugs',
    'Checking resolution/duplicates' =>
      'Checking resolution/duplicates',
    '$terms.Bugs found on duplicates table that are not marked duplicate' =>
      '$terms.Bugs found on duplicates table that are not marked duplicate',
    '$terms.Bugs found marked resolved duplicate and not on duplicates table' =>
      '$terms.Bugs found marked resolved duplicate and not on duplicates table',
    'Checking statuses/resolutions' =>
      'Checking statuses/resolutions',
    '$terms.Bugs with open status and a resolution' =>
      '$terms.Bugs with open status and a resolution',
    '$terms.Bugs with non-open status and no resolution' =>
      '$terms.Bugs with non-open status and no resolution',
    'Checking statuses/everconfirmed' =>
      'Checking statuses/everconfirmed',
    '$terms.Bugs that are UNCONFIRMED but have everconfirmed set' =>
      '$terms.Bugs that are UNCONFIRMED but have everconfirmed set',
    '$terms.Bugs with confirmed status but don\'t have everconfirmed set' =>
      '$terms.Bugs with confirmed status but don\'t have everconfirmed set',
    'Checking votes/everconfirmed' =>
      'Checking votes/everconfirmed',
    '$terms.Bugs that have enough votes to be confirmed but haven\'t been' =>
      '$terms.Bugs that have enough votes to be confirmed but haven\'t been',
    'Checking for bad values in group_control_map' =>
      'Checking for bad values in group_control_map',
    'Found' =>
      'Found',
    'bad group_control_map entries' =>
      'bad group_control_map entries',
    'Checking for $terms.bugs with groups violating their product\'s group controls' =>
      'Checking for $terms.bugs with groups violating their product\'s group controls',
    'Have groups not permitted for their products' =>
      'Have groups not permitted for their products',
    'Permit the missing groups for the affected products (set member control to' =>
      'Permit the missing groups for the affected products (set member control to',
    'SHOWN' =>
      'SHOWN',
    'Are missing groups required for their products' =>
      'Are missing groups required for their products',
    'OK, now fixing missing $terms.bug creation dates.' =>
      'OK, now fixing missing $terms.bug creation dates.',
    '$terms.bugs have been fixed.' =>
      '$terms.bugs have been fixed.',
    'OK, now fixing $terms.bug entries for full text searching.' =>
      'OK, now fixing $terms.bug entries for full text searching.',
    'OK, now removing all references to deleted $terms.bugs.' =>
      'OK, now removing all references to deleted $terms.bugs.',
    'All references to deleted $terms.bugs have been removed.' =>
      'All references to deleted $terms.bugs have been removed.',
    'Checking references to' =>
      'Checking references to',
    '... from' =>
      '... from',
    'Bad value \'' =>
      'Bad value \'',
    '\' found in' =>
      '\' found in',
    'Remove invalid references to non existent attachments.' =>
      'Remove invalid references to non existent attachments.',
    'Remove invalid references to non existent $terms.bugs.' =>
      'Remove invalid references to non existent $terms.bugs.',
    'Bad values \'' =>
      'Bad values \'',
    'OK, now fixing everconfirmed.' =>
      'OK, now fixing everconfirmed.',
    'everconfirmed fixed.' =>
      'everconfirmed fixed.',
    'Checking for flags being in the wrong product/component.' =>
      'Checking for flags being in the wrong product/component.',
    'OK, now deleting invalid flags.' =>
      'OK, now deleting invalid flags.',
    'Invalid flags deleted.' =>
      'Invalid flags deleted.',
    'Invalid flag' =>
      'Invalid flag',
    'for' =>
      'for',
    'attachment' =>
      'attachment',
    'in' =>
      'in',
    'Click here to delete invalid flags' =>
      'Click here to delete invalid flags',
    'OK, now creating' =>
      'OK, now creating',
    'member control entries for product/group combinations lacking one.' =>
      'member control entries for product/group combinations lacking one.',
    'Updating' =>
      'Updating',
    'NA/<em>xxx</em>' =>
      'NA/<em>xxx</em>',
    'group control setting for group <em>' =>
      'group control setting for group <em>',
    '</em> to' =>
      '</em> to',
    'SHOWN/<em>xxx</em>' =>
      'SHOWN/<em>xxx</em>',
    'in product <em>' =>
      'in product <em>',
    'Generating' =>
      'Generating',
    'SHOWN/NA' =>
      'SHOWN/NA',
    '</em> in product <em>' =>
      '</em> in product <em>',
    'Repaired' =>
      'Repaired',
    'defective group control settings.' =>
      'defective group control settings.',
    'Checking keywords table.' =>
      'Checking keywords table.',
    'Bogus keywordids' =>
      'Bogus keywordids',
    'found in keywords table.' =>
      'found in keywords table.',
    'Duplicate keyword IDs found in' =>
      'Duplicate keyword IDs found in',
    'Checking profile logins.' =>
      'Checking profile logins.',
    'Bad profile email address, id=' =>
      'Bad profile email address, id=',
    'Repair these $terms.bugs.' =>
      'Repair these $terms.bugs.',
    'OK, now attempting to send unsent mail.' =>
      'OK, now attempting to send unsent mail.',
    '$terms.bugs found with possibly unsent mail.' =>
      '$terms.bugs found with possibly unsent mail.',
    'Unsent mail has been sent.' =>
      'Unsent mail has been sent.',
    'Checking for unsent mail' =>
      'Checking for unsent mail',
    '$terms.Bugs that have changes but no mail sent for at least half an hour:' =>
      '$terms.Bugs that have changes but no mail sent for at least half an hour:',
    'Send these mails' =>
      'Send these mails',
    'OK, now rebuilding vote cache.' =>
      'OK, now rebuilding vote cache.',
    'Vote cache has been rebuilt.' =>
      'Vote cache has been rebuilt.',
    'Click here to rebuild the vote cache' =>
      'Click here to rebuild the vote cache',
    'Bad vote cache for' =>
      'Bad vote cache for',
    'Checking cached vote counts.' =>
      'Checking cached vote counts.',
    'Bad vote sum for $terms.bug' =>
      'Bad vote sum for $terms.bug',
    'OK, now removing non-existent users/groups from whines.' =>
      'OK, now removing non-existent users/groups from whines.',
    'Non-existent users/groups have been removed from whines.' =>
      'Non-existent users/groups have been removed from whines.',
    'Checking for whines with non-existent users/groups.' =>
      'Checking for whines with non-existent users/groups.',
    'Non-existent' =>
      'Non-existent',
    'for whine schedule' =>
      'for whine schedule',
    'Click here to remove old users/groups' =>
      'Click here to remove old users/groups',
    'The status message string' =>
      'The status message string',
    'was not found. Please send email to' =>
      'was not found. Please send email to',
    'describing the steps taken to obtain this message.' =>
      'describing the steps taken to obtain this message.',
    'as $terms.bug list' =>
      'as $terms.bug list',
  },
  'admin/settings/edit.html.tmpl' => {
    'Default Preferences' =>
      'Default Preferences',
    'This lets you edit the default preferences values.' =>
      'This lets you edit the default preferences values.',
    'The Default Value displayed for each preference will apply to all users who do not choose their own value, and to anyone who is not logged in.' =>
      'The Default Value displayed for each preference will apply to all users who do not choose their own value, and to anyone who is not logged in.',
    'The \'Enabled\' checkbox controls whether or not this preference is available to users.' =>
      'The \'Enabled\' checkbox controls whether or not this preference is available to users.',
    'If it is checked, users will see this preference on their User Preferences page, and will be allowed to choose their own value if they desire.' =>
      'If it is checked, users will see this preference on their User Preferences page, and will be allowed to choose their own value if they desire.',
    'If it is not checked, this preference will not appear on the User Preference page, and the Default Value will automatically apply to everyone.' =>
      'If it is not checked, this preference will not appear on the User Preference page, and the Default Value will automatically apply to everyone.',
    'Enabled' =>
      'Enabled',
    'Preference Text' =>
      'Preference Text',
    'Default Value' =>
      'Default Value',
    'Submit Changes' =>
      'Submit Changes',
    'There are no preferences to edit.' =>
      'There are no preferences to edit.',
  },
  'admin/sudo.html.tmpl' => {
    'Begin sudo session' =>
      'Begin sudo session',
    'The <b>sudo</b> feature of $terms.Bugzilla allows you to impersonate a user for a short time While an sudo session is in progress, every action you perform will be taking place as if you had logged in as the user whom will be impersonating.' =>
      'The <b>sudo</b> feature of $terms.Bugzilla allows you to impersonate a user for a short time While an sudo session is in progress, every action you perform will be taking place as if you had logged in as the user whom will be impersonating.',
    'This is a very powerful feature; you should be very careful while using it. Your actions may be logged more carefully than normal.' =>
      'This is a very powerful feature; you should be very careful while using it. Your actions may be logged more carefully than normal.',
    'To begin, enter the login of' =>
      'To begin, enter the login of',
    'the <u>u</u>ser to impersonate' =>
      'the <u>u</u>ser to impersonate',
    'The username must be entered exactly. No matching will be performed.' =>
      'The username must be entered exactly. No matching will be performed.',
    'Next, please take a moment to explain' =>
      'Next, please take a moment to explain',
    'why you are doing this:' =>
      'why you are doing this:',
    'The message you enter here will be sent to the impersonated user by email. You may leave this empty if you wish, but they will still know that you are impersonating them.' =>
      'The message you enter here will be sent to the impersonated user by email. You may leave this empty if you wish, but they will still know that you are impersonating them.',
    'Finally, enter' =>
      'Finally, enter',
    'your $terms.Bugzilla password' =>
      'your $terms.Bugzilla password',
    'This is done for two reasons. First of all, it is done to reduce the chances of someone doing large amounts of damage using your already-logged-in account. Second, it is there to force you to take the time to consider if you really need to use this feature.' =>
      'This is done for two reasons. First of all, it is done to reduce the chances of someone doing large amounts of damage using your already-logged-in account. Second, it is there to force you to take the time to consider if you really need to use this feature.',
    'Begin Session' =>
      'Begin Session',
    'Click the button to begin the session:' =>
      'Click the button to begin the session:',
  },
  'admin/table.html.tmpl' => {
    'Yes' =>
      'Yes',
    'No' =>
      'No',
    '<i>&lt;none&gt;</i>' =>
      '<i>&lt;none&gt;</i>',
  },
  'admin/users/confirm-delete.html.tmpl' => {
    'Confirm deletion of user' =>
      'Confirm deletion of user',
    'Login name:' =>
      'Login name:',
    'Real name:' =>
      'Real name:',
    'Group set:' =>
      'Group set:',
    'None' =>
      'None',
    'Product responsibilities:' =>
      'Product responsibilities:',
    'You can\'t delete this user at this time because' =>
      'You can\'t delete this user at this time because',
    'has got responsibilities for at least one product.' =>
      'has got responsibilities for at least one product.',
    'Change this by clicking the product editing links above,' =>
      'Change this by clicking the product editing links above,',
    'For now, you can' =>
      'For now, you can',
    'The following deletions are <b>unsafe</b> and would generate referential integrity inconsistencies!' =>
      'The following deletions are <b>unsafe</b> and would generate referential integrity inconsistencies!',
    'has submitted' =>
      'has submitted',
    'one attachment' =>
      'one attachment',
    'attachments' =>
      'attachments',
    '. If you delete the user account, the database records will be inconsistent, resulting in' =>
      '. If you delete the user account, the database records will be inconsistent, resulting in',
    'this attachment' =>
      'this attachment',
    'these attachments' =>
      'these attachments',
    'not appearing in $terms.bugs any more.' =>
      'not appearing in $terms.bugs any more.',
    'has reported' =>
      'has reported',
    'one $terms.bug' =>
      'one $terms.bug',
    'this $terms.bug' =>
      'this $terms.bug',
    'these $terms.bugs' =>
      'these $terms.bugs',
    'not appearing in $terms.bug lists any more.' =>
      'not appearing in $terms.bug lists any more.',
    'has made' =>
      'has made',
    'a change on $terms.abug' =>
      'a change on $terms.abug',
    'changes on $terms.bugs' =>
      'changes on $terms.bugs',
    '. If you delete the user account, the $terms.bugs activity table in the database will be inconsistent, resulting in' =>
      '. If you delete the user account, the $terms.bugs activity table in the database will be inconsistent, resulting in',
    'this change' =>
      'this change',
    'these changes' =>
      'these changes',
    'not showing up in $terms.bug activity logs any more.' =>
      'not showing up in $terms.bug activity logs any more.',
    'has' =>
      'has',
    'set or requested' =>
      'set or requested',
    'a flag' =>
      'a flag',
    'flags' =>
      'flags',
    '. If you delete the user account, the flags table in the database will be inconsistent, resulting in' =>
      '. If you delete the user account, the flags table in the database will be inconsistent, resulting in',
    'this flag' =>
      'this flag',
    'these flags' =>
      'these flags',
    'not displaying correctly any more.' =>
      'not displaying correctly any more.',
    'commented' =>
      'commented',
    'once on $terms.abug' =>
      'once on $terms.abug',
    'times on $terms.bugs' =>
      'times on $terms.bugs',
    '. If you delete the user account, the comments table in the database will be inconsistent, resulting in' =>
      '. If you delete the user account, the comments table in the database will be inconsistent, resulting in',
    'this comment' =>
      'this comment',
    'these comments' =>
      'these comments',
    'not being visible any more.' =>
      'not being visible any more.',
    'a change on a other user\'s profile' =>
      'a change on a other user\'s profile',
    'changes on other users\' profiles' =>
      'changes on other users\' profiles',
    '. If you delete the user account, the user profiles activity table in the database will be inconsistent.' =>
      '. If you delete the user account, the user profiles activity table in the database will be inconsistent.',
    'The following deletions are <b>safe</b> and will not generate referential integrity inconsistencies.' =>
      'The following deletions are <b>safe</b> and will not generate referential integrity inconsistencies.',
    'is the assignee or the QA contact of' =>
      'is the assignee or the QA contact of',
    '. If you delete the user account, these roles will fall back to the default assignee or default QA contact.' =>
      '. If you delete the user account, these roles will fall back to the default assignee or default QA contact.',
    'is on the CC list of' =>
      'is on the CC list of',
    '. If you delete the user account, it will be removed from these CC lists.' =>
      '. If you delete the user account, it will be removed from these CC lists.',
    'is on the default CC list of' =>
      'is on the default CC list of',
    'one component' =>
      'one component',
    'components' =>
      'components',
    'The user\'s e-mail settings will be deleted along with the user account.' =>
      'The user\'s e-mail settings will be deleted along with the user account.',
    'has been' =>
      'has been',
    'asked to set' =>
      'asked to set',
    '. If you delete the user account,' =>
      '. If you delete the user account,',
    'will change to be unspecifically requested.' =>
      'will change to be unspecifically requested.',
    'a' =>
      'a',
    'named search' =>
      'named search',
    'named searches' =>
      'named searches',
    'This named search' =>
      'This named search',
    'These named searches' =>
      'These named searches',
    'will be deleted along with the user account.' =>
      'will be deleted along with the user account.',
    'Of these,' =>
      'Of these,',
    'are' =>
      'are',
    'one is' =>
      'one is',
    'shared.' =>
      'shared.',
    'Other users will not be able to use' =>
      'Other users will not be able to use',
    'these shared named searches' =>
      'these shared named searches',
    'this shared named search' =>
      'this shared named search',
    'any more.' =>
      'any more.',
    'The user\'s preference settings will be deleted along with the user account.' =>
      'The user\'s preference settings will be deleted along with the user account.',
    'has created' =>
      'has created',
    'a series' =>
      'a series',
    'series' =>
      'series',
    'This series' =>
      'This series',
    'These series' =>
      'These series',
    'a quip' =>
      'a quip',
    'quips' =>
      'quips',
    'this quip' =>
      'this quip',
    'these quips' =>
      'these quips',
    'will have no author anymore, but will remain available.' =>
      'will have no author anymore, but will remain available.',
    'has voted on' =>
      'has voted on',
    'this vote' =>
      'this vote',
    'these votes' =>
      'these votes',
    'is being watched by' =>
      'is being watched by',
    'a user' =>
      'a user',
    'users' =>
      'users',
    'watches' =>
      'watches',
    'This watching' =>
      'This watching',
    'These watchings' =>
      'These watchings',
    'will cease along with the deletion of the user account.' =>
      'will cease along with the deletion of the user account.',
    'has scheduled' =>
      'has scheduled',
    'a whine' =>
      'a whine',
    'whines' =>
      'whines',
    'This whine' =>
      'This whine',
    'These whines' =>
      'These whines',
    'is on the receiving end of' =>
      'is on the receiving end of',
    '. The corresponding schedules will be deleted along with the user account, but the whines themselves will be left unaltered.' =>
      '. The corresponding schedules will be deleted along with the user account, but the whines themselves will be left unaltered.',
    'Please be aware of the consequences of this before continuing.' =>
      'Please be aware of the consequences of this before continuing.',
    'Do you really want to delete this user account?' =>
      'Do you really want to delete this user account?',
    'Yes, delete' =>
      'Yes, delete',
    'If you do not want to delete the user account at this time,' =>
      'If you do not want to delete the user account at this time,',
    '<b>You cannot delete this user account</b> due to unsafe actions reported above. You can' =>
      '<b>You cannot delete this user account</b> due to unsafe actions reported above. You can',
    'edit the user' =>
      'edit the user',
    ', go' =>
      ', go',
    'back to the user list' =>
      'back to the user list',
    'add a new user' =>
      'add a new user',
    'or' =>
      'or',
    'find other users' =>
      'find other users',
  },
  'admin/users/create.html.tmpl' => {
    'Add user' =>
      'Add user',
    'Add' =>
      'Add',
    'You can also' =>
      'You can also',
    'find a user' =>
      'find a user',
    ', or' =>
      ', or',
    'go back to the user list' =>
      'go back to the user list',
  },
  'admin/users/edit.html.tmpl' => {
    'Edit user' =>
      'Edit user',
    'Group access:' =>
      'Group access:',
    'Can turn these bits on for other users' =>
      'Can turn these bits on for other users',
    'User is a member of these groups' =>
      'User is a member of these groups',
    'Product responsibilities:' =>
      'Product responsibilities:',
    '<em>none</em>' =>
      '<em>none</em>',
    'Last Login:' =>
      'Last Login:',
    '<em>never</em>' =>
      '<em>never</em>',
    'Save Changes' =>
      'Save Changes',
    'View Account History for ' =>
      'View Account History for ',
    'or' =>
      'or',
    'View Account History' =>
      'View Account History',
    'User is a member of any groups shown with a check or grey bar. A grey bar indicates indirect membership, either derived from other groups (marked with square brackets) or via regular expression (marked with \'*\').' =>
      'User is a member of any groups shown with a check or grey bar. A grey bar indicates indirect membership, either derived from other groups (marked with square brackets) or via regular expression (marked with \'*\').',
    'Square brackets around the bless checkbox indicate the ability to bless users (grant them membership in the group) as a result of membership in another group.' =>
      'Square brackets around the bless checkbox indicate the ability to bless users (grant them membership in the group) as a result of membership in another group.',
    'Delete User' =>
      'Delete User',
    'You can also' =>
      'You can also',
    'add a new user' =>
      'add a new user',
    'go' =>
      'go',
    'back to the user list' =>
      'back to the user list',
    'find other users' =>
      'find other users',
  },
  'admin/users/list.html.tmpl' => {
    'Select user' =>
      'Select user',
    'Edit user...' =>
      'Edit user...',
    'Real name' =>
      'Real name',
    'Last Login' =>
      'Last Login',
    'Account History' =>
      'Account History',
    'View' =>
      'View',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    'user' =>
      'user',
    'found.' =>
      'found.',
    'If you do not wish to modify a user account at this time, you can' =>
      'If you do not wish to modify a user account at this time, you can',
    'find other users' =>
      'find other users',
    'or' =>
      'or',
    'add a new user' =>
      'add a new user',
  },
  'admin/users/responsibilities.html.tmpl' => {
    'Product:' =>
      'Product:',
    'Component' =>
      'Component',
    'Default Assignee' =>
      'Default Assignee',
    'Default QA Contact' =>
      'Default QA Contact',
    'The user is involved in at least one product which you cannot see (and so is not listed above). You have to ask an administrator with enough privileges to edit this user\'s roles for these products.' =>
      'The user is involved in at least one product which you cannot see (and so is not listed above). You have to ask an administrator with enough privileges to edit this user\'s roles for these products.',
  },
  'admin/users/search.html.tmpl' => {
    'Search users' =>
      'Search users',
    'List users with' =>
      'List users with',
    'login name' =>
      'login name',
    'real name' =>
      'real name',
    'user id' =>
      'user id',
    'matching' =>
      'matching',
    'case-insensitive substring' =>
      'case-insensitive substring',
    'case-insensitive regexp' =>
      'case-insensitive regexp',
    'not (case-insensitive regexp)' =>
      'not (case-insensitive regexp)',
    'exact (find this user)' =>
      'exact (find this user)',
    'Search' =>
      'Search',
    'Restrict to users belonging to group' =>
      'Restrict to users belonging to group',
    'You can also' =>
      'You can also',
    'add a new user' =>
      'add a new user',
    ', or' =>
      ', or',
    'show the user list again' =>
      'show the user list again',
  },
  'admin/users/userdata.html.tmpl' => {
    'Login name:' =>
      'Login name:',
    'Impersonate this user' =>
      'Impersonate this user',
    'Real name:' =>
      'Real name:',
    'Password:' =>
      'Password:',
    '(Enter new password to change.)' =>
      '(Enter new password to change.)',
    '$terms.Bugmail Disabled:' =>
      '$terms.Bugmail Disabled:',
    '(This affects $terms.bug, flag and whine emails, not password-reset or other non-$terms.bug-related emails)' =>
      '(This affects $terms.bug, flag and whine emails, not password-reset or other non-$terms.bug-related emails)',
    'Disable text:' =>
      'Disable text:',
    '(If non-empty, then the account will be disabled, and this text should explain why.)' =>
      '(If non-empty, then the account will be disabled, and this text should explain why.)',
  },
  'admin/versions/confirm-delete.html.tmpl' => {
    'Delete Version of Product \'' =>
      'Delete Version of Product \'',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Version:' =>
      'Version:',
    'Version of Product:' =>
      'Version of Product:',
    'List of $terms.bugs targetted at version ' =>
      'List of $terms.bugs targetted at version ',
    'None' =>
      'None',
    'Confirmation' =>
      'Confirmation',
    'Sorry, there' =>
      'Sorry, there',
    'are' =>
      'are',
    'is' =>
      'is',
    'outstanding for this version. You must move' =>
      'outstanding for this version. You must move',
    'those $terms.bugs' =>
      'those $terms.bugs',
    'that $terms.bug' =>
      'that $terms.bug',
    'to another version before you can delete this one.' =>
      'to another version before you can delete this one.',
    'Do you really want to delete this version?' =>
      'Do you really want to delete this version?',
    'Yes, delete' =>
      'Yes, delete',
  },
  'admin/versions/edit.html.tmpl' => {
    'Edit Version \'' =>
      'Edit Version \'',
    '\' of product \'' =>
      '\' of product \'',
    'Add Version to Product \'' =>
      'Add Version to Product \'',
    'This page allows you to add a new version to product \'' =>
      'This page allows you to add a new version to product \'',
    'Version:' =>
      'Version:',
    'Sortkey:' =>
      'Sortkey:',
    'Enabled For $terms.Bugs:' =>
      'Enabled For $terms.Bugs:',
    'Save Changes' =>
      'Save Changes',
    'Add' =>
      'Add',
  },
  'admin/versions/footer.html.tmpl' => {
    'Add a version to product ' =>
      'Add a version to product ',
    'Add' =>
      'Add',
    'a version.' =>
      'a version.',
    'Edit Version ' =>
      'Edit Version ',
    'Edit version' =>
      'Edit version',
    'Edit other versions of product' =>
      'Edit other versions of product',
    'Edit product' =>
      'Edit product',
  },
  'admin/versions/list.html.tmpl' => {
    'Select version of product \'' =>
      'Select version of product \'',
    'Edit version...' =>
      'Edit version...',
    'Active' =>
      'Active',
    'Action' =>
      'Action',
    'Delete' =>
      'Delete',
    'Empty version (---)' =>
      'Empty version (---)',
    'disabled globally' =>
      'disabled globally',
    'Empty version (---) is' =>
      'Empty version (---) is',
    'in this product.' =>
      'in this product.',
    'Disable' =>
      'Disable',
    'Enable' =>
      'Enable',
    'empty version' =>
      'empty version',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/versions/select-product.html.tmpl' => {
    'Edit versions for which product?' =>
      'Edit versions for which product?',
    'Edit versions of...' =>
      'Edit versions of...',
    'Description' =>
      'Description',
    'Redisplay table with $terms.bug counts (slower)' =>
      'Redisplay table with $terms.bug counts (slower)',
  },
  'admin/workflow/comment.html.tmpl' => {
    'Comments Required on Status Transitions' =>
      'Comments Required on Status Transitions',
    'This page allows you to define which status transitions require a comment by the user doing the change.' =>
      'This page allows you to define which status transitions require a comment by the user doing the change.',
    'Note that it is generally far better to require a developer comment when resolving bugs than not. Few things are more annoying to bug database users than having a developer mark a bug "fixed" without any comment as to what the fix was (or even that it was truly fixed!)' =>
      'Note that it is generally far better to require a developer comment when resolving bugs than not. Few things are more annoying to bug database users than having a developer mark a bug "fixed" without any comment as to what the fix was (or even that it was truly fixed!)',
    'To' =>
      'To',
    'From' =>
      'From',
    '{Start}' =>
      '{Start}',
    'From ' =>
      'From ',
    'to ' =>
      'to ',
    'Commit Changes' =>
      'Commit Changes',
    'Cancel Changes' =>
      'Cancel Changes',
    'View Current Workflow' =>
      'View Current Workflow',
  },
  'admin/workflow/edit.html.tmpl' => {
    'Edit Workflow' =>
      'Edit Workflow',
    'This page allows you to define which status transitions are valid in your workflow. For compatibility with older versions of $terms.Bugzilla, reopening $terms.abug will only display either UNCONFIRMED or REOPENED (if allowed by your workflow) but not both. The decision depends on whether the $terms.bug has ever been confirmed or not. So it is a good idea to allow both transitions and let $terms.Bugzilla select the correct one.' =>
      'This page allows you to define which status transitions are valid in your workflow. For compatibility with older versions of $terms.Bugzilla, reopening $terms.abug will only display either UNCONFIRMED or REOPENED (if allowed by your workflow) but not both. The decision depends on whether the $terms.bug has ever been confirmed or not. So it is a good idea to allow both transitions and let $terms.Bugzilla select the correct one.',
    'To' =>
      'To',
    'From' =>
      'From',
    '{Start}' =>
      '{Start}',
    'From ' =>
      'From ',
    'to ' =>
      'to ',
    'When $terms.abug is marked as a duplicate of another one or is moved to another installation, the $terms.bug status is automatically set to <b>' =>
      'When $terms.abug is marked as a duplicate of another one or is moved to another installation, the $terms.bug status is automatically set to <b>',
    '</b>. All transitions to this $terms.bug status must then be valid (this is the reason why you cannot edit them above).' =>
      '</b>. All transitions to this $terms.bug status must then be valid (this is the reason why you cannot edit them above).',
    'Note: you can change this setting by visiting the' =>
      'Note: you can change this setting by visiting the',
    'Parameters' =>
      'Parameters',
    'page and editing the <i>duplicate_or_move_bug_status</i> parameter.' =>
      'page and editing the <i>duplicate_or_move_bug_status</i> parameter.',
    'Commit Changes' =>
      'Commit Changes',
    'Cancel Changes' =>
      'Cancel Changes',
    'View Comments Required on Status Transitions' =>
      'View Comments Required on Status Transitions',
  },
  'attachment/cancel-create-dupe.html.tmpl' => {
    'Already filed attachment' =>
      'Already filed attachment',
    'You already used the form to file' =>
      'You already used the form to file',
    'attachment' =>
      'attachment',
    'You can either' =>
      'You can either',
    'create a new attachment' =>
      'create a new attachment',
    'go back to $terms.bug ' =>
      'go back to $terms.bug ',
    'or' =>
      'or',
  },
  'attachment/choose.html.tmpl' => {
    'Locate attachment' =>
      'Locate attachment',
    'Access an attachment by entering its ID into the form below:' =>
      'Access an attachment by entering its ID into the form below:',
    'Attachment ID:' =>
      'Attachment ID:',
    'Details' =>
      'Details',
    'View' =>
      'View',
    'Or, access it from the list of attachments in its associated $terms.bug report:' =>
      'Or, access it from the list of attachments in its associated $terms.bug report:',
    '$terms.Bug ID:' =>
      '$terms.Bug ID:',
  },
  'attachment/confirm-delete.html.tmpl' => {
    'Delete Attachment' =>
      'Delete Attachment',
    'of $terms.Bug' =>
      'of $terms.Bug',
    'Property' =>
      'Property',
    'Value' =>
      'Value',
    'Attachment ID:' =>
      'Attachment ID:',
    'File name:' =>
      'File name:',
    'Description:' =>
      'Description:',
    'Contained in $terms.Bug:' =>
      'Contained in $terms.Bug:',
    'Creator:' =>
      'Creator:',
    'Creation Date:' =>
      'Creation Date:',
    'Confirmation' =>
      'Confirmation',
    'The content of this attachment will be deleted in an <b>irreversible</b> way.' =>
      'The content of this attachment will be deleted in an <b>irreversible</b> way.',
    'Do you really want to delete this attachment?' =>
      'Do you really want to delete this attachment?',
    'Reason of the deletion:' =>
      'Reason of the deletion:',
    'Yes, delete' =>
      'Yes, delete',
    'No, cancel this deletion and return to' =>
      'No, cancel this deletion and return to',
  },
  'attachment/content-types.html.tmpl' => {
    'Plain text (text/plain)' =>
      'Plain text (text/plain)',
    'HTML source (text/html)' =>
      'HTML source (text/html)',
    'XML source (application/xml)' =>
      'XML source (application/xml)',
    'GIF image (image/gif)' =>
      'GIF image (image/gif)',
    'JPEG image (image/jpeg)' =>
      'JPEG image (image/jpeg)',
    'PNG image (image/png)' =>
      'PNG image (image/png)',
    'Binary file (application/octet-stream)' =>
      'Binary file (application/octet-stream)',
  },
  'attachment/create.html.tmpl' => {
    'Create New Attachment for $terms.Bug #' =>
      'Create New Attachment for $terms.Bug #',
    'Create New Attachment for' =>
      'Create New Attachment for',
    'Obsoletes:' =>
      'Obsoletes:',
    '<em>(optional) Check each existing attachment made obsolete by your new attachment.</em>' =>
      '<em>(optional) Check each existing attachment made obsolete by your new attachment.</em>',
    '[no attachments can be made obsolete]' =>
      '[no attachments can be made obsolete]',
    'Reassignment:' =>
      'Reassignment:',
    '<em>If you want to assign this $terms.bug to yourself, check the box below.</em>' =>
      '<em>If you want to assign this $terms.bug to yourself, check the box below.</em>',
    'take $terms.bug' =>
      'take $terms.bug',
    'Change bug status to:' =>
      'Change bug status to:',
    '(current)' =>
      '(current)',
    'resolved&nbsp;as&nbsp;' =>
      'resolved&nbsp;as&nbsp;',
    'duplicate' =>
      'duplicate',
    'of' =>
      'of',
    'edit' =>
      'edit',
    'Hours Worked:' =>
      'Hours Worked:',
    'Comment:' =>
      'Comment:',
    '<em>(optional) Add a comment about this attachment to the $terms.bug.</em>' =>
      '<em>(optional) Add a comment about this attachment to the $terms.bug.</em>',
    'Silent' =>
      'Silent',
    'Privacy:' =>
      'Privacy:',
    'Make attachment and comment private (visible only to members of the <strong>' =>
      'Make attachment and comment private (visible only to members of the <strong>',
    '</strong> group)' =>
      '</strong> group)',
    'Submit' =>
      'Submit',
    'Preview comment' =>
      'Preview comment',
  },
  'attachment/createformcontents.html.tmpl' => {
    'Attachment text:' =>
      'Attachment text:',
    'Attach file' =>
      'Attach file',
    'Enter text' =>
      'Enter text',
    'Paste image from clipboard' =>
      'Paste image from clipboard',
    'File' =>
      'File',
    '<em>Enter the path to the file on your computer.</em>' =>
      '<em>Enter the path to the file on your computer.</em>',
    '<em>Enter or paste attachment text here:</em>' =>
      '<em>Enter or paste attachment text here:</em>',
    'Paste again' =>
      'Paste again',
    'Please enable' =>
      'Please enable',
    'Java' =>
      'Java',
    'Applet support in your browser.' =>
      'Applet support in your browser.',
    'BigFile:' =>
      'BigFile:',
    'Big File - Stored locally and may be purged' =>
      'Big File - Stored locally and may be purged',
    'Description' =>
      'Description',
    '<em>Describe the attachment briefly.</em>' =>
      '<em>Describe the attachment briefly.</em>',
    'Content Type:' =>
      'Content Type:',
    '<em>If the attachment is a patch, check the box below.</em>' =>
      '<em>If the attachment is a patch, check the box below.</em>',
    'patch' =>
      'patch',
    '<em>Otherwise, choose a method for determining the content type.</em>' =>
      '<em>Otherwise, choose a method for determining the content type.</em>',
    'auto-detect' =>
      'auto-detect',
    'select from list' =>
      'select from list',
    'enter manually' =>
      'enter manually',
  },
  'attachment/delete_reason.txt.tmpl' => {
    'The content of attachment' =>
      'The content of attachment',
    'has been deleted by' =>
      'has been deleted by',
    'who provided the following reason:' =>
      'who provided the following reason:',
    'without providing any reason.' =>
      'without providing any reason.',
    'The token used to delete this attachment was generated at' =>
      'The token used to delete this attachment was generated at',
  },
  'attachment/diff-file.html.tmpl' => {
    '&nbsp;lines)' =>
      '&nbsp;lines)',
    'Added' =>
      'Added',
    'Removed' =>
      'Removed',
    '&nbsp;Lines&nbsp;' =>
      '&nbsp;Lines&nbsp;',
    'Line&nbsp;' =>
      'Line&nbsp;',
    'Link&nbsp;Here' =>
      'Link&nbsp;Here',
  },
  'attachment/diff-footer.html.tmpl' => {
    'Return to' =>
      'Return to',
  },
  'attachment/diff-header.html.tmpl' => {
    'Attachment #' =>
      'Attachment #',
    'for $terms.bug #' =>
      'for $terms.bug #',
    'Interdiff of #' =>
      'Interdiff of #',
    'and #' =>
      'and #',
    'Diff Between #' =>
      'Diff Between #',
    'for' =>
      'for',
    'View' =>
      'View',
    'Details' =>
      'Details',
    'Raw&nbsp;Unified' =>
      'Raw&nbsp;Unified',
    '| Return to' =>
      '| Return to',
    'Differences between' =>
      'Differences between',
    'Diff' =>
      'Diff',
    'and this patch' =>
      'and this patch',
    'Raw Unified' =>
      'Raw Unified',
    'Collapse All' =>
      'Collapse All',
    'Expand All' =>
      'Expand All',
    'Context:' =>
      'Context:',
    '(<strong>Patch</strong> /' =>
      '(<strong>Patch</strong> /',
    'Patch' =>
      'Patch',
    '<strong>File</strong> /' =>
      '<strong>File</strong> /',
    'File' =>
      'File',
    'Warning:' =>
      'Warning:',
    'this difference between two patches may show things in the wrong places due to a limitation in $terms.Bugzilla when comparing patches with different sets of files.' =>
      'this difference between two patches may show things in the wrong places due to a limitation in $terms.Bugzilla when comparing patches with different sets of files.',
    'this difference between two patches may be inaccurate due to a limitation in $terms.Bugzilla when comparing patches made against different revisions.' =>
      'this difference between two patches may be inaccurate due to a limitation in $terms.Bugzilla when comparing patches made against different revisions.',
  },
  'attachment/edit.html.tmpl' => {
    'Attachment' =>
      'Attachment',
    'Details for $terms.Bug' =>
      'Details for $terms.Bug',
    'Details for' =>
      'Details for',
    'Description:' =>
      'Description:',
    'Filename:' =>
      'Filename:',
    'MIME Type:' =>
      'MIME Type:',
    'Size:' =>
      'Size:',
    '<em>deleted</em>' =>
      '<em>deleted</em>',
    'Creator:' =>
      'Creator:',
    'patch' =>
      'patch',
    'Is Patch:' =>
      'Is Patch:',
    'obsolete' =>
      'obsolete',
    'Is Obsolete:' =>
      'Is Obsolete:',
    'private (only visible to <strong>' =>
      'private (only visible to <strong>',
    'Is Private:' =>
      'Is Private:',
    'Comment (on the $terms.bug):' =>
      'Comment (on the $terms.bug):',
    'Silent' =>
      'Silent',
    'Submit' =>
      'Submit',
    'Preview' =>
      'Preview',
    '<b>The content of this attachment has been deleted.</b>' =>
      '<b>The content of this attachment has been deleted.</b>',
    '<b> The attachment is not viewable in your browser due to security restrictions enabled by $terms.Bugzilla. </b>' =>
      '<b> The attachment is not viewable in your browser due to security restrictions enabled by $terms.Bugzilla. </b>',
    '<b> In order to view the attachment, you first have to' =>
      '<b> In order to view the attachment, you first have to',
    'download it' =>
      'download it',
    '<b>You cannot view the attachment while viewing its details because your browser does not support IFRAMEs.' =>
      '<b>You cannot view the attachment while viewing its details because your browser does not support IFRAMEs.',
    'View the attachment on a separate page' =>
      'View the attachment on a separate page',
    'Edit Attachment As Comment' =>
      'Edit Attachment As Comment',
    'Undo Edit As Comment' =>
      'Undo Edit As Comment',
    'Redo Edit As Comment' =>
      'Redo Edit As Comment',
    'View Attachment As Diff' =>
      'View Attachment As Diff',
    'View Attachment As Raw' =>
      'View Attachment As Raw',
    '<b> Attachment is not viewable in your browser because its MIME type (' =>
      '<b> Attachment is not viewable in your browser because its MIME type (',
    ') is not one that your browser is able to display. </b>' =>
      ') is not one that your browser is able to display. </b>',
    'Download the attachment' =>
      'Download the attachment',
    'Online-view' =>
      'Online-view',
    'Actions:' =>
      'Actions:',
    'View' =>
      'View',
    'Diff' =>
      'Diff',
    'Delete' =>
      'Delete',
    'Attachments on' =>
      'Attachments on',
  },
  'attachment/list.html.tmpl' => {
    'Attachments' =>
      'Attachments',
    'Download all in ZIP' =>
      'Download all in ZIP',
    'View the content of the attachment' =>
      'View the content of the attachment',
    'patch)' =>
      'patch)',
    '(<em>deleted</em>)' =>
      '(<em>deleted</em>)',
    'Go to the comment associated with the attachment' =>
      'Go to the comment associated with the attachment',
    '<i>no flags</i>' =>
      '<i>no flags</i>',
    'Details' =>
      'Details',
    'Online-view' =>
      'Online-view',
    'Diff' =>
      'Diff',
    'Show Obsolete' =>
      'Show Obsolete',
    'View All' =>
      'View All',
    'Add an attachment' =>
      'Add an attachment',
    'Add multiple' =>
      'Add multiple',
    '(proposed patch, testcase, etc.)' =>
      '(proposed patch, testcase, etc.)',
  },
  'attachment/midair.html.tmpl' => {
    'Mid-air collision!' =>
      'Mid-air collision!',
    'Mid-air collision detected!' =>
      'Mid-air collision detected!',
    'Someone else has made changes to' =>
      'Someone else has made changes to',
    'attachment' =>
      'attachment',
    'of' =>
      'of',
    'at the same time you were trying to. The changes made were:' =>
      'at the same time you were trying to. The changes made were:',
    'Your comment was:' =>
      'Your comment was:',
    'You have the following choices:' =>
      'You have the following choices:',
    'Submit my changes anyway' =>
      'Submit my changes anyway',
    'This will cause all of the above changes to be overwritten.' =>
      'This will cause all of the above changes to be overwritten.',
    'Throw away my changes, and' =>
      'Throw away my changes, and',
    'revisit attachment' =>
      'revisit attachment',
  },
  'attachment/show-multiple-simple.html.tmpl' => {
    'No attachments' =>
      'No attachments',
  },
  'attachment/show-multiple.html.tmpl' => {
    'View All Attachments for' =>
      'View All Attachments for',
    'View All Attachments for $terms.Bug' =>
      'View All Attachments for $terms.Bug',
    '<b>Attachment #' =>
      '<b>Attachment #',
    '<i>patch</i>' =>
      '<i>patch</i>',
    '<i>no flags</i>' =>
      '<i>no flags</i>',
    'Details' =>
      'Details',
    '<b>You cannot view the attachment on this page because your browser does not support IFRAMEs.' =>
      '<b>You cannot view the attachment on this page because your browser does not support IFRAMEs.',
    'View the attachment on a separate page' =>
      'View the attachment on a separate page',
    '<b> Attachment cannot be viewed because its MIME type is not text/*, image/*, or application/vnd.mozilla.*.' =>
      '<b> Attachment cannot be viewed because its MIME type is not text/*, image/*, or application/vnd.mozilla.*.',
    'Download the attachment instead' =>
      'Download the attachment instead',
  },
  'bug/activity/show.html.tmpl' => {
    'Changes made to $terms.bug ' =>
      'Changes made to $terms.bug ',
    'Activity log for $terms.bug ' =>
      'Activity log for $terms.bug ',
    'Back to $terms.bug ' =>
      'Back to $terms.bug ',
  },
  'bug/activity/table.html.tmpl' => {
    'There used to be an issue in' =>
      'There used to be an issue in',
    'Bugzilla' =>
      'Bugzilla',
    'which caused activity data to be lost if there were a large number of cc\'s or dependencies. That has been fixed, but some data was already lost in your activity table that could not be regenerated. The changes that the script could not reliably determine are prefixed by \'?\'.' =>
      'which caused activity data to be lost if there were a large number of cc\'s or dependencies. That has been fixed, but some data was already lost in your activity table that could not be regenerated. The changes that the script could not reliably determine are prefixed by \'?\'.',
    'Who' =>
      'Who',
    'When' =>
      'When',
    'What' =>
      'What',
    'Removed' =>
      'Removed',
    'Added' =>
      'Added',
    'Attachment #' =>
      'Attachment #',
    'Comment #' =>
      'Comment #',
    'Description' =>
      'Description',
    'Show full text' =>
      'Show full text',
    'No changes have been made to this $terms.bug yet.' =>
      'No changes have been made to this $terms.bug yet.',
  },
  'bug/checkaccess.html.tmpl' => {
    ' - Check access' =>
      ' - Check access',
    'Everyone' =>
      'Everyone',
    'can see' =>
      'can see',
    'User login (email)' =>
      'User login (email)',
    'User name' =>
      'User name',
    'Back to $terms.bug form' =>
      'Back to $terms.bug form',
  },
  'bug/choose.html.tmpl' => {
    'Search by $terms.bug number' =>
      'Search by $terms.bug number',
    'You may find a single $terms.bug by entering its $terms.bug id here:' =>
      'You may find a single $terms.bug by entering its $terms.bug id here:',
    'Show Me This $terms.Bug' =>
      'Show Me This $terms.Bug',
  },
  'bug/comment-preview-div.html.tmpl' => {
    'Hide preview' =>
      'Hide preview',
  },
  'bug/comment-preview-text.html.tmpl' => {
    'Show full text' =>
      'Show full text',
  },
  'bug/comments.html.tmpl' => {
    'Collapse All Comments' =>
      'Collapse All Comments',
    'Expand All Comments' =>
      'Expand All Comments',
    'Description' =>
      'Description',
    'Comment ' =>
      'Comment ',
    'Comment is worktime-only' =>
      'Comment is worktime-only',
    'Comment is not worktime-only' =>
      'Comment is not worktime-only',
    'normal' =>
      'normal',
    'worktime-only' =>
      'worktime-only',
    'Private' =>
      'Private',
    'Edit' =>
      'Edit',
    'img' =>
      'img',
    'Additional hours worked: ' =>
      'Additional hours worked: ',
    'h' =>
      'h',
    'Additional hours worked:' =>
      'Additional hours worked:',
  },
  'bug/create/comment-guided.txt.tmpl' => {
    'User-Agent:' =>
      'User-Agent:',
    'Build Identifier:' =>
      'Build Identifier:',
    'Choose one...' =>
      'Choose one...',
    'Reproducible:' =>
      'Reproducible:',
    'Steps to Reproduce:' =>
      'Steps to Reproduce:',
    'Actual Results:' =>
      'Actual Results:',
    'Expected Results:' =>
      'Expected Results:',
  },
  'bug/create/confirm-create-dupe.html.tmpl' => {
    'Already filed $terms.bug' =>
      'Already filed $terms.bug',
    'You already used the form to file' =>
      'You already used the form to file',
    'You are highly encouraged to visit' =>
      'You are highly encouraged to visit',
    'If you are sure you used the same form to submit a new $terms.bug, click \'File $terms.bug again\'.' =>
      'If you are sure you used the same form to submit a new $terms.bug, click \'File $terms.bug again\'.',
    'File $terms.bug again' =>
      'File $terms.bug again',
  },
  'bug/create/create-guided.html.tmpl' => {
    'Enter $terms.ABug' =>
      'Enter $terms.ABug',
    'This is a template used on mozilla.org. This template, and the comment-guided.txt.tmpl template that formats the data submitted via the form in this template, are included as a demo of what it\'s possible to do with custom templates in general, and custom $terms.bug entry templates in particular. As much of the text will not apply, you should alter it if you want to use this form on your $terms.Bugzilla installation.' =>
      'This is a template used on mozilla.org. This template, and the comment-guided.txt.tmpl template that formats the data submitted via the form in this template, are included as a demo of what it\'s possible to do with custom templates in general, and custom $terms.bug entry templates in particular. As much of the text will not apply, you should alter it if you want to use this form on your $terms.Bugzilla installation.',
    'Step 1 of 3 - has your $terms.bug already been reported?' =>
      'Step 1 of 3 - has your $terms.bug already been reported?',
    'Please don\'t skip this step - half of all $terms.bugs filed are reported already.' =>
      'Please don\'t skip this step - half of all $terms.bugs filed are reported already.',
    'Check the two lists of frequently-reported $terms.bugs:' =>
      'Check the two lists of frequently-reported $terms.bugs:',
    'Firefox' =>
      'Firefox',
    'All-time Top 100' =>
      'All-time Top 100',
    '(loaded initially) |' =>
      '(loaded initially) |',
    'Hot in the last two weeks' =>
      'Hot in the last two weeks',
    'If your $terms.bug isn\'t there, search $terms.Bugzilla by entering a few key words having to do with your $terms.bug in this box. For example:' =>
      'If your $terms.bug isn\'t there, search $terms.Bugzilla by entering a few key words having to do with your $terms.bug in this box. For example:',
    '<b>pop3 mail</b>' =>
      '<b>pop3 mail</b>',
    'or' =>
      'or',
    '<b>copy paste</b>' =>
      '<b>copy paste</b>',
    '. The results will appear above.' =>
      '. The results will appear above.',
    'Mozilla Application Suite' =>
      'Mozilla Application Suite',
    'Camino' =>
      'Camino',
    'Search' =>
      'Search',
    'Look through the search results. If you get the' =>
      'Look through the search results. If you get the',
    'message, $terms.Bugzilla found no $terms.bugs that match. Check for typing mistakes, or try fewer or different keywords. If you find $terms.abug that looks the same as yours, please add any useful extra information you have to it, rather than opening a new one.' =>
      'message, $terms.Bugzilla found no $terms.bugs that match. Check for typing mistakes, or try fewer or different keywords. If you find $terms.abug that looks the same as yours, please add any useful extra information you have to it, rather than opening a new one.',
    'Step 2 of 3 - give information' =>
      'Step 2 of 3 - give information',
    'If you\'ve tried a few searches and your $terms.bug really isn\'t in there, tell us all about it.' =>
      'If you\'ve tried a few searches and your $terms.bug really isn\'t in there, tell us all about it.',
    '<b>Product</b>' =>
      '<b>Product</b>',
    '<b>Component</b>' =>
      '<b>Component</b>',
    'General' =>
      'General',
    'Select a component to see its description here.' =>
      'Select a component to see its description here.',
    'The area where the problem occurs. To pick the right component, you could use the same one as similar $terms.bugs you found in your search, or read the full list of' =>
      'The area where the problem occurs. To pick the right component, you could use the same one as similar $terms.bugs you found in your search, or read the full list of',
    'component descriptions' =>
      'component descriptions',
    '(opens in new window) if you need more help.' =>
      '(opens in new window) if you need more help.',
    'Macintosh' =>
      'Macintosh',
    'All' =>
      'All',
    'Other' =>
      'Other',
    '<b>Hardware Platform</b>' =>
      '<b>Hardware Platform</b>',
    'Windows 2000' =>
      'Windows 2000',
    'Windows XP' =>
      'Windows XP',
    'Windows Vista' =>
      'Windows Vista',
    'Windows 7' =>
      'Windows 7',
    'Mac OS X' =>
      'Mac OS X',
    'Linux' =>
      'Linux',
    '<b>Operating System</b>' =>
      '<b>Operating System</b>',
    'Firefox|Camino|Mozilla Application Suite' =>
      'Firefox|Camino|Mozilla Application Suite',
    'Gecko/(\\d+)' =>
      'Gecko/(\\d+)',
    '<b>Build Identifier</b>' =>
      '<b>Build Identifier</b>',
    'This should identify the exact version of the product you were using. If the above field is blank or you know it is incorrect, copy the version text from the product\'s Help | About menu (for browsers this will begin with "Mozilla/5.0..."). If the product won\'t start, instead paste the complete URL you downloaded it from.' =>
      'This should identify the exact version of the product you were using. If the above field is blank or you know it is incorrect, copy the version text from the product\'s Help | About menu (for browsers this will begin with "Mozilla/5.0..."). If the product won\'t start, instead paste the complete URL you downloaded it from.',
    '<b>URL</b>' =>
      '<b>URL</b>',
    'URL that demonstrates the problem you are seeing (optional).' =>
      'URL that demonstrates the problem you are seeing (optional).',
    '<b>IMPORTANT</b>: if the problem is with a broken web page, you need to report it' =>
      '<b>IMPORTANT</b>: if the problem is with a broken web page, you need to report it',
    'a different way' =>
      'a different way',
    '<b>Summary</b>' =>
      '<b>Summary</b>',
    'A sentence which summarises the problem. Please be descriptive and use lots of keywords.' =>
      'A sentence which summarises the problem. Please be descriptive and use lots of keywords.',
    'Bad example' =>
      'Bad example',
    ': mail crashed' =>
      ': mail crashed',
    'Good example' =>
      'Good example',
    ': crash if I close the mail window while checking for new POP mail' =>
      ': crash if I close the mail window while checking for new POP mail',
    '<b>Details</b>' =>
      '<b>Details</b>',
    'Expand on the Summary. Please be as specific as possible about what is wrong.' =>
      'Expand on the Summary. Please be as specific as possible about what is wrong.',
    ': Mozilla crashed. You suck!' =>
      ': Mozilla crashed. You suck!',
    ': After a crash which happened when I was sorting in the Bookmark Manager,' =>
      ': After a crash which happened when I was sorting in the Bookmark Manager,',
    'all of my top-level bookmark folders beginning with the letters Q to Z are no longer present.' =>
      'all of my top-level bookmark folders beginning with the letters Q to Z are no longer present.',
    '<b>Reproducibility</b>' =>
      '<b>Reproducibility</b>',
    'Happens every time.' =>
      'Happens every time.',
    'Happens sometimes, but not always.' =>
      'Happens sometimes, but not always.',
    'Haven\'t tried to reproduce it.' =>
      'Haven\'t tried to reproduce it.',
    'Tried, but couldn\'t reproduce it.' =>
      'Tried, but couldn\'t reproduce it.',
    '<b>Steps to Reproduce</b>' =>
      '<b>Steps to Reproduce</b>',
    '1.\\n2.\\n3.' =>
      '1.\\n2.\\n3.',
    'Describe how to reproduce the problem, step by step. Include any special setup steps.' =>
      'Describe how to reproduce the problem, step by step. Include any special setup steps.',
    '<b>Actual Results</b>' =>
      '<b>Actual Results</b>',
    'What happened after you performed the steps above?' =>
      'What happened after you performed the steps above?',
    '<b>Expected Results</b>' =>
      '<b>Expected Results</b>',
    'What should the software have done instead?' =>
      'What should the software have done instead?',
    '<b>Additional Information</b>' =>
      '<b>Additional Information</b>',
    'Add any additional information you feel may be relevant to this $terms.bug, such as the <b>theme</b> you were using (does the $terms.bug still occur with the default theme?), a <b>' =>
      'Add any additional information you feel may be relevant to this $terms.bug, such as the <b>theme</b> you were using (does the $terms.bug still occur with the default theme?), a <b>',
    'Talkback crash ID' =>
      'Talkback crash ID',
    '</b>, or special information about <b>your computer\'s configuration</b>. Any information longer than a few lines, such as a <b>stack trace</b> or <b>HTML testcase</b>, should be added using the "Add an Attachment" link on the $terms.bug, after it is filed. If you believe that it\'s relevant, please also include your build configuration, obtained by typing' =>
      '</b>, or special information about <b>your computer\'s configuration</b>. Any information longer than a few lines, such as a <b>stack trace</b> or <b>HTML testcase</b>, should be added using the "Add an Attachment" link on the $terms.bug, after it is filed. If you believe that it\'s relevant, please also include your build configuration, obtained by typing',
    'into your URL bar.' =>
      'into your URL bar.',
    'If you are reporting a crash, note the module in which the software crashed (e.g.,' =>
      'If you are reporting a crash, note the module in which the software crashed (e.g.,',
    'Application Violation in gkhtml.dll' =>
      'Application Violation in gkhtml.dll',
    '<b>Severity</b>' =>
      '<b>Severity</b>',
    'Critical: The software crashes, hangs, or causes you to lose data.' =>
      'Critical: The software crashes, hangs, or causes you to lose data.',
    'Major: A major feature is broken.' =>
      'Major: A major feature is broken.',
    'Normal: It\'s $terms.abug that should be fixed.' =>
      'Normal: It\'s $terms.abug that should be fixed.',
    'Minor: Minor loss of function, and there\'s an easy workaround.' =>
      'Minor: Minor loss of function, and there\'s an easy workaround.',
    'Trivial: A cosmetic problem, such as a misspelled word or misaligned text.' =>
      'Trivial: A cosmetic problem, such as a misspelled word or misaligned text.',
    'Enhancement: Request for new feature or enhancement.' =>
      'Enhancement: Request for new feature or enhancement.',
    'Say how serious the problem is, or if your $terms.bug is a request for a new feature.' =>
      'Say how serious the problem is, or if your $terms.bug is a request for a new feature.',
    'Step 3 of 3 - submit the $terms.bug report' =>
      'Step 3 of 3 - submit the $terms.bug report',
    'Submit $terms.Bug Report ' =>
      'Submit $terms.Bug Report ',
    'That\'s it! Thanks very much. You\'ll be notified by email about any progress that is made on fixing your $terms.bug.' =>
      'That\'s it! Thanks very much. You\'ll be notified by email about any progress that is made on fixing your $terms.bug.',
    'Please be warned that we get a lot of $terms.bug reports filed - it may take quite a while to get around to yours. You can help the process by making sure your $terms.bug is complete and easy to understand, and by quickly replying to any questions which may arrive by email.' =>
      'Please be warned that we get a lot of $terms.bug reports filed - it may take quite a while to get around to yours. You can help the process by making sure your $terms.bug is complete and easy to understand, and by quickly replying to any questions which may arrive by email.',
  },
  'bug/create/create.html.tmpl' => {
    'Enter $terms.Bug:' =>
      'Enter $terms.Bug:',
    'new bug' =>
      'new bug',
    'Product:' =>
      'Product:',
    'Component' =>
      'Component',
    'Required Field' =>
      'Required Field',
    'Summary' =>
      'Summary',
    'Description' =>
      'Description',
    '+++ This $terms.bug was initially created as a clone of $terms.Bug #' =>
      '+++ This $terms.bug was initially created as a clone of $terms.Bug #',
    'comment' =>
      'comment',
    'Preview comment' =>
      'Preview comment',
    'Make description private (visible only to members of the <strong>' =>
      'Make description private (visible only to members of the <strong>',
    '</strong> group)' =>
      '</strong> group)',
    'Attachment:' =>
      'Attachment:',
    'Add an attachment' =>
      'Add an attachment',
    'Add multiple' =>
      'Add multiple',
    'Don' =>
      'Don',
    'Add single attachment' =>
      'Add single attachment',
    'Add multiple attachments' =>
      'Add multiple attachments',
    'Keywords' =>
      'Keywords',
    'Whiteboard:' =>
      'Whiteboard:',
    '<strong>Only users in all of the selected groups can view this $terms.bug:</strong>' =>
      '<strong>Only users in all of the selected groups can view this $terms.bug:</strong>',
    '(Leave all boxes unchecked to make this a public $terms.bug.)' =>
      '(Leave all boxes unchecked to make this a public $terms.bug.)',
    'Severity:' =>
      'Severity:',
    'Priority:' =>
      'Priority:',
    'URL:' =>
      'URL:',
    'We\'ve made a guess at your' =>
      'We\'ve made a guess at your',
    'platform. Please check it' =>
      'platform. Please check it',
    'operating system. Please check it' =>
      'operating system. Please check it',
    'operating system and platform. Please check them' =>
      'operating system and platform. Please check them',
    'and make any corrections if necessary.' =>
      'and make any corrections if necessary.',
    'Assign To' =>
      'Assign To',
    '(Leave blank to assign to component\'s default assignee)' =>
      '(Leave blank to assign to component\'s default assignee)',
    'QA Contact:' =>
      'QA Contact:',
    '(Leave blank to assign to default qa contact)' =>
      '(Leave blank to assign to default qa contact)',
    'CC:' =>
      'CC:',
    'Initial State' =>
      'Initial State',
    '$terms.Bug alias:' =>
      '$terms.Bug alias:',
    'Depends on:' =>
      'Depends on:',
    'Blocks:' =>
      'Blocks:',
    'Estimated Hours:' =>
      'Estimated Hours:',
    '<b>Hours Worked:</b>' =>
      '<b>Hours Worked:</b>',
    'Deadline:' =>
      'Deadline:',
    '(YYYY-MM-DD)' =>
      '(YYYY-MM-DD)',
    'Submit $terms.Bug' =>
      'Submit $terms.Bug',
    'Remember values as bookmarkable template' =>
      'Remember values as bookmarkable template',
  },
  'bug/create/make-template.html.tmpl' => {
    'Bookmarks are your friend' =>
      'Bookmarks are your friend',
    'Template constructed' =>
      'Template constructed',
    'You can bookmark this link: &ldquo;' =>
      'You can bookmark this link: &ldquo;',
    '$terms.Bug entry template' =>
      '$terms.Bug entry template',
    '&rdquo;. This bookmark will bring up the <em>Enter $terms.Bug</em> page with the fields initialized as you\'ve requested.' =>
      '&rdquo;. This bookmark will bring up the <em>Enter $terms.Bug</em> page with the fields initialized as you\'ve requested.',
  },
  'bug/dependency-graph.html.tmpl' => {
    'Dependency Graph' =>
      'Dependency Graph',
    ' for $terms.bug ' =>
      ' for $terms.bug ',
    ' for $terms.bug <a href="show_bug.cgi?id=$bug_id">$bug_id</a>' =>
      ' for $terms.bug <a href="show_bug.cgi?id=$bug_id">$bug_id</a>',
    'Bug states:' =>
      'Bug states:',
    'NEW' =>
      'NEW',
    'ASSIGNED' =>
      'ASSIGNED',
    'RESOLVED' =>
      'RESOLVED',
    'VERIFIED' =>
      'VERIFIED',
    'CLOSED' =>
      'CLOSED',
    'REOPENED' =>
      'REOPENED',
    'Timed out.' =>
      'Timed out.',
    'Dependency graph' =>
      'Dependency graph',
    '$terms.Bug numbers' =>
      '$terms.Bug numbers',
    'Display:' =>
      'Display:',
    'Show only $terms.bugs specified in the query' =>
      'Show only $terms.bugs specified in the query',
    'Restrict to $terms.bugs having a direct relationship with entered $terms.bugs' =>
      'Restrict to $terms.bugs having a direct relationship with entered $terms.bugs',
    'Show all $terms.bugs having any relationship with entered $terms.bugs' =>
      'Show all $terms.bugs having any relationship with entered $terms.bugs',
    'Show all open $terms.bugs having any relationship with entered $terms.bugs' =>
      'Show all open $terms.bugs having any relationship with entered $terms.bugs',
    'Change Parameters' =>
      'Change Parameters',
  },
  'bug/dependency-tree.html.tmpl' => {
    'Dependency tree for $terms.Bug ' =>
      'Dependency tree for $terms.Bug ',
    'Dependency tree for $terms.Bug <a href="show_bug.cgi?id=$bugid">$bugid</a>' =>
      'Dependency tree for $terms.Bug <a href="show_bug.cgi?id=$bugid">$bugid</a>',
    'depends on' =>
      'depends on',
    'does not depend on any $terms.bugs.' =>
      'does not depend on any $terms.bugs.',
    'blocks' =>
      'blocks',
    'does not block any $terms.bugs.' =>
      'does not block any $terms.bugs.',
    'open' =>
      'open',
    'Up to' =>
      'Up to',
    'level' =>
      'level',
    'deep |' =>
      'deep |',
    'view as $terms.bug list' =>
      'view as $terms.bug list',
    'change several' =>
      'change several',
    'Already displayed above; click to locate' =>
      'Already displayed above; click to locate',
    'Click to expand or contract this portion of the tree. Hold down the Ctrl key while clicking to expand or contract all subtrees.' =>
      'Click to expand or contract this portion of the tree. Hold down the Ctrl key while clicking to expand or contract all subtrees.',
    'See dependency tree for $terms.bug ' =>
      'See dependency tree for $terms.bug ',
    'assigned to' =>
      'assigned to',
    '; Target: ' =>
      '; Target: ',
    'Show' =>
      'Show',
    'Hide' =>
      'Hide',
    'Resolved' =>
      'Resolved',
    'Max Depth:' =>
      'Max Depth:',
    'Change' =>
      'Change',
    '&nbsp;Unlimited&nbsp;' =>
      '&nbsp;Unlimited&nbsp;',
  },
  'bug/edit.html.tmpl' => {
    'Bug_$BUG' =>
      'Bug_$BUG',
    'Wiki' =>
      'Wiki',
    'edit' =>
      'edit',
    'a name for the $terms.bug that can be used in place of its ID number, e.g. when adding it to a list of dependencies' =>
      'a name for the $terms.bug that can be used in place of its ID number, e.g. when adding it to a list of dependencies',
    'Alias' =>
      'Alias',
    '<u>S</u>ummary' =>
      '<u>S</u>ummary',
    'Status' =>
      'Status',
    'of' =>
      'of',
    '<u>I</u>mportance' =>
      '<u>I</u>mportance',
    'width: auto' =>
      'width: auto',
    '(search)' =>
      '(search)',
    'with' =>
      'with',
    'vote' =>
      'vote',
    'votes' =>
      'votes',
    'OS/Platform:' =>
      'OS/Platform:',
    'Assigned To' =>
      'Assigned To',
    'Reset Assignee to default' =>
      'Reset Assignee to default',
    '<u>Q</u>A Contact:' =>
      '<u>Q</u>A Contact:',
    'Reset QA Contact to default (' =>
      'Reset QA Contact to default (',
    '<u>U</u>RL' =>
      '<u>U</u>RL',
    '<u>W</u>hiteboard:' =>
      '<u>W</u>hiteboard:',
    '<u>K</u>eywords' =>
      '<u>K</u>eywords',
    'Edit' =>
      'Edit',
    'Depends&nbsp;on' =>
      'Depends&nbsp;on',
    'Blockers completed <b>~' =>
      'Blockers completed <b>~',
    '%</b>, last changed <b>' =>
      '%</b>, last changed <b>',
    '<u>B</u>locks' =>
      '<u>B</u>locks',
    'Show dependency' =>
      'Show dependency',
    'tree' =>
      'tree',
    'graph' =>
      'graph',
    '<b>Only users in all of the selected groups can view this $terms.bug:</b>' =>
      '<b>Only users in all of the selected groups can view this $terms.bug:</b>',
    'Unchecking all boxes makes this a more public $terms.bug.' =>
      'Unchecking all boxes makes this a more public $terms.bug.',
    'Only members of a group can change the visibility of $terms.abug for that group.' =>
      'Only members of a group can change the visibility of $terms.abug for that group.',
    'Also allow' =>
      'Also allow',
    'Allow' =>
      'Allow',
    'to view this $terms.bug:</b>' =>
      'to view this $terms.bug:</b>',
    'Allow reporter to view this $terms.bug' =>
      'Allow reporter to view this $terms.bug',
    'Allow CC List users to view this $terms.bug' =>
      'Allow CC List users to view this $terms.bug',
    'The assignee' =>
      'The assignee',
    'and QA contact' =>
      'and QA contact',
    'can always see $terms.abug, and this section does not take effect unless the $terms.bug is restricted to at least one group.' =>
      'can always see $terms.abug, and this section does not take effect unless the $terms.bug is restricted to at least one group.',
    'List users who can see this bug' =>
      'List users who can see this bug',
    'Reported:' =>
      'Reported:',
    'by' =>
      'by',
    'Modified:' =>
      'Modified:',
    'History' =>
      'History',
    'CC List:' =>
      'CC List:',
    'including you' =>
      'including you',
    'Add me to CC list' =>
      'Add me to CC list',
    '<b>Add</b>:' =>
      '<b>Add</b>:',
    'Remove selected CCs' =>
      'Remove selected CCs',
    'Orig. Est.' =>
      'Orig. Est.',
    'Current Est.' =>
      'Current Est.',
    'Hours Worked' =>
      'Hours Worked',
    'Hours Left' =>
      'Hours Left',
    '%Complete' =>
      '%Complete',
    'Gain' =>
      'Gain',
    'Deadline' =>
      'Deadline',
    '(YYYY-MM-DD)' =>
      '(YYYY-MM-DD)',
    'Summarize time (including time for $terms.bugs blocking this $terms.bug)' =>
      'Summarize time (including time for $terms.bugs blocking this $terms.bug)',
    '<b>Additional <u>C</u>omments</b>' =>
      '<b>Additional <u>C</u>omments</b>',
    'Private' =>
      'Private',
    'Silent' =>
      'Silent',
    'Worktime only' =>
      'Worktime only',
    'Note' =>
      'Note',
    'You need to' =>
      'You need to',
    'log in' =>
      'log in',
    'before you can comment on or make changes to this $terms.bug.' =>
      'before you can comment on or make changes to this $terms.bug.',
    'Look for $terms.Bug in:' =>
      'Look for $terms.Bug in:',
    'Preview' =>
      'Preview',
    'Save Changes' =>
      'Save Changes',
    'Scrum card' =>
      'Scrum card',
  },
  'bug/field.html.tmpl' => {
    'edit' =>
      'edit',
    '(search)' =>
      '(search)',
    'Remove' =>
      'Remove',
    'Add $terms.Bug URLs:' =>
      'Add $terms.Bug URLs:',
    'None' =>
      'None',
  },
  'bug/format_comment.txt.tmpl' => {
    '*** This $terms.bug has been marked as a duplicate of $terms.bug' =>
      '*** This $terms.bug has been marked as a duplicate of $terms.bug',
    'has been marked as a duplicate of this $terms.bug. ***' =>
      'has been marked as a duplicate of this $terms.bug. ***',
    '*** This $terms.bug has been confirmed by popular vote. ***' =>
      '*** This $terms.bug has been confirmed by popular vote. ***',
    '$terms.Bug moved to' =>
      '$terms.Bug moved to',
    '. If the move succeeded,' =>
      '. If the move succeeded,',
    'will receive a mail containing the number of the new $terms.bug in the other database. If all went well, please paste in a link to the new $terms.bug. Otherwise, reopen this $terms.bug.' =>
      'will receive a mail containing the number of the new $terms.bug in the other database. If all went well, please paste in a link to the new $terms.bug. Otherwise, reopen this $terms.bug.',
    'Created attachment' =>
      'Created attachment',
    'Comment on attachment' =>
      'Comment on attachment',
  },
  'bug/import/importxls.html.tmpl' => {
    'Excel import' =>
      'Excel import',
    'Mass Bug Import from Excel files' =>
      'Mass Bug Import from Excel files',
    'Excel format parse error occurred.' =>
      'Excel format parse error occurred.',
    'The supplied file does not contain any bug descriptions, or the sheet with selected name was not found.' =>
      'The supplied file does not contain any bug descriptions, or the sheet with selected name was not found.',
    'Unknown error: "' =>
      'Unknown error: "',
    ' for all bugs:' =>
      ' for all bugs:',
    'Select XLS/XLSX/CSV file to import:' =>
      'Select XLS/XLSX/CSV file to import:',
    'Enter sheet name to process' =>
      'Enter sheet name to process',
    'or CSV delimiter:' =>
      'or CSV delimiter:',
    'Maximum bug duplicate age:' =>
      'Maximum bug duplicate age:',
    'days' =>
      'days',
    'for all bugs:&nbsp;' =>
      'for all bugs:&nbsp;',
    'Add field value for all bugs' =>
      'Add field value for all bugs',
    'Parse File' =>
      'Parse File',
    'Empty sheet name means to process all sheets.' =>
      'Empty sheet name means to process all sheets.',
    '<b>Successfully imported' =>
      '<b>Successfully imported',
    'bugs' =>
      'bugs',
    'An import error occurred, no bugs were imported.' =>
      'An import error occurred, no bugs were imported.',
    'Import another Excel file' =>
      'Import another Excel file',
    '- You can bookmark this link as a template.' =>
      '- You can bookmark this link as a template.',
    'Select worksheet items to import as bugs' =>
      'Select worksheet items to import as bugs',
    'No bugs selected for importing!' =>
      'No bugs selected for importing!',
    '(mapped to' =>
      '(mapped to',
    'Don&apos;t map:' =>
      'Don&apos;t map:',
    'Import selected bugs / updates' =>
      'Import selected bugs / updates',
    'Silent' =>
      'Silent',
    'Back' =>
      'Back',
  },
  'bug/knob.html.tmpl' => {
    'resolved&nbsp;as&nbsp;' =>
      'resolved&nbsp;as&nbsp;',
    'search' =>
      'search',
    'duplicate' =>
      'duplicate',
    'of' =>
      'of',
    'edit' =>
      'edit',
    'Mark as Duplicate' =>
      'Mark as Duplicate',
  },
  'bug/navigate.html.tmpl' => {
    'Format For Printing' =>
      'Format For Printing',
    'XML' =>
      'XML',
    'Clone This $terms.Bug' =>
      'Clone This $terms.Bug',
    'Top of page' =>
      'Top of page',
    '<b>$terms.Bug List:</b>' =>
      '<b>$terms.Bug List:</b>',
    'of' =>
      'of',
    'First' =>
      'First',
    'Last' =>
      'Last',
    'Prev' =>
      'Prev',
    'Next' =>
      'Next',
    '(This $terms.bug is not in your last search results)' =>
      '(This $terms.bug is not in your last search results)',
    'Show last search results' =>
      'Show last search results',
    'No search results available' =>
      'No search results available',
  },
  'bug/process/confirm-duplicate.html.tmpl' => {
    'Duplicate Warning' =>
      'Duplicate Warning',
    'When marking $terms.abug as a duplicate, the reporter of the duplicate is normally added to the CC list of the original. The permissions on' =>
      'When marking $terms.abug as a duplicate, the reporter of the duplicate is normally added to the CC list of the original. The permissions on',
    '(the original) are currently set such that the reporter would not normally be able to see it.' =>
      '(the original) are currently set such that the reporter would not normally be able to see it.',
    '<b>Adding the reporter to the CC list of' =>
      '<b>Adding the reporter to the CC list of',
    'will immediately' =>
      'will immediately',
    'might, in the future,' =>
      'might, in the future,',
    'allow him/her access to view this $terms.bug.</b> Do you wish to do this?' =>
      'allow him/her access to view this $terms.bug.</b> Do you wish to do this?',
    'Yes, add the reporter to CC list on' =>
      'Yes, add the reporter to CC list on',
    'No, do not add the reporter to CC list on' =>
      'No, do not add the reporter to CC list on',
    'Throw away my changes, and revisit $terms.bug ' =>
      'Throw away my changes, and revisit $terms.bug ',
    'Submit' =>
      'Submit',
  },
  'bug/process/failed-checkers.html.tmpl' => {
    'Внесённые' =>
      'Внесённые',
    'в' =>
      'в',
    'изменения не удовлетворяют следующим проверкам:' =>
      'изменения не удовлетворяют следующим проверкам:',
    'обязательная' =>
      'обязательная',
    'рекомендательная' =>
      'рекомендательная',
    'защита от изменений' =>
      'защита от изменений',
    'проверка новых значений' =>
      'проверка новых значений',
  },
  'bug/process/midair.html.tmpl' => {
    'Mid-air collision!' =>
      'Mid-air collision!',
    'Mid-air collision detected!' =>
      'Mid-air collision detected!',
    'Someone else has made changes to' =>
      'Someone else has made changes to',
    'at the same time you were trying to. The changes made were:' =>
      'at the same time you were trying to. The changes made were:',
    'Added the comment(s):' =>
      'Added the comment(s):',
    'Your comment was:' =>
      'Your comment was:',
    'You have the following choices:' =>
      'You have the following choices:',
    'Submit my changes anyway' =>
      'Submit my changes anyway',
    ', except for the added comment(s)' =>
      ', except for the added comment(s)',
    'This will cause conflicting changes to be overwritten with yours' =>
      'This will cause conflicting changes to be overwritten with yours',
    'Submit only my new comment' =>
      'Submit only my new comment',
    'revisit $terms.bug ' =>
      'revisit $terms.bug ',
    'Throw away my changes, and' =>
      'Throw away my changes, and',
  },
  'bug/process/results.html.tmpl' => {
    'Changes submitted for ' =>
      'Changes submitted for ',
    'Duplicate notation added to ' =>
      'Duplicate notation added to ',
    'Checking for dependency changes on ' =>
      'Checking for dependency changes on ',
    ' confirmed by number of votes' =>
      ' confirmed by number of votes',
    ' has been added to the database' =>
      ' has been added to the database',
    ' has been moved to another database' =>
      ' has been moved to another database',
    'Flag ' =>
      'Flag ',
    'Votes removed from ' =>
      'Votes removed from ',
    ' in accordance with new product settings' =>
      ' in accordance with new product settings',
    'Email sent to' =>
      'Email sent to',
    'Excluding' =>
      'Excluding',
    'Your changes marked as Silent. No mail is sent.' =>
      'Your changes marked as Silent. No mail is sent.',
    'no one' =>
      'no one',
    '(list of e-mails not available)' =>
      '(list of e-mails not available)',
  },
  'bug/process/unsubscribe.html.tmpl' => {
    'Removing you from CC list of bug #' =>
      'Removing you from CC list of bug #',
    'OK, you are removed from CC list of bug #' =>
      'OK, you are removed from CC list of bug #',
    'You are not in the CC list of bug #' =>
      'You are not in the CC list of bug #',
  },
  'bug/process/verify-checkers.html.tmpl' => {
    'Изменения не удовлетворяют проверкам' =>
      'Изменения не удовлетворяют проверкам',
    'Я знаю, что делаю! Внести изменения!' =>
      'Я знаю, что делаю! Внести изменения!',
    'Либо нажмите <b>' =>
      'Либо нажмите <b>',
    'Назад' =>
      'Назад',
    '</b> и внесите другие, корректные изменения.' =>
      '</b> и внесите другие, корректные изменения.',
    'Изменения блокированы. Нажмите <b>' =>
      'Изменения блокированы. Нажмите <b>',
    '</b> и внесите корректные изменения.' =>
      '</b> и внесите корректные изменения.',
  },
  'bug/process/verify-field-values.html.tmpl' => {
    'Verify Field Values' =>
      'Verify Field Values',
    'Verify' =>
      'Verify',
    'Value' =>
      'Value',
    '"</b> of the field <b>"' =>
      '"</b> of the field <b>"',
    'incorrect for the value <b>"' =>
      'incorrect for the value <b>"',
    '"</b> of controlling field <b>"' =>
      '"</b> of controlling field <b>"',
    'Please set the correct values for these fields now:' =>
      'Please set the correct values for these fields now:',
    'Verify $terms.Bug Group' =>
      'Verify $terms.Bug Group',
    'These groups are not legal for the \'' =>
      'These groups are not legal for the \'',
    '\' product or you are not allowed to restrict $terms.bugs to these groups. $terms.Bugs will no longer be restricted to these groups and may become public if no other group applies:' =>
      '\' product or you are not allowed to restrict $terms.bugs to these groups. $terms.Bugs will no longer be restricted to these groups and may become public if no other group applies:',
    'These groups are optional. You can decide to restrict $terms.bugs to one or more of the following groups:' =>
      'These groups are optional. You can decide to restrict $terms.bugs to one or more of the following groups:',
    'These groups are mandatory and $terms.bugs will be automatically restricted to these groups:' =>
      'These groups are mandatory and $terms.bugs will be automatically restricted to these groups:',
    'Commit' =>
      'Commit',
    'Cancel and Return to' =>
      'Cancel and Return to',
    'the last search results' =>
      'the last search results',
  },
  'bug/process/verify-flags.html.tmpl' => {
    'Verify flag requests' =>
      'Verify flag requests',
    'Please, verify flags:' =>
      'Please, verify flags:',
    'Who' =>
      'Who',
    'What' =>
      'What',
    'Requestee' =>
      'Requestee',
    'Status' =>
      'Status',
    'Commit' =>
      'Commit',
  },
  'bug/process/verify-worktime.html.tmpl' => {
    'Verify working time' =>
      'Verify working time',
    'Please, verify working time:' =>
      'Please, verify working time:',
    'Hours Worked:' =>
      'Hours Worked:',
    'Commit' =>
      'Commit',
  },
  'bug/show-header.html.tmpl' => {
    'Last modified: ' =>
      'Last modified: ',
  },
  'bug/show-multiple.html.tmpl' => {
    'Full Text $terms.Bug Listing' =>
      'Full Text $terms.Bug Listing',
    'Short Format' =>
      'Short Format',
    'You\'d have more luck if you gave me some $terms.bug numbers.' =>
      'You\'d have more luck if you gave me some $terms.bug numbers.',
    '\' is not a valid $terms.bug number' =>
      '\' is not a valid $terms.bug number',
    'nor a known $terms.bug alias' =>
      'nor a known $terms.bug alias',
    'You are not allowed to view this $terms.bug.' =>
      'You are not allowed to view this $terms.bug.',
    'This $terms.bug cannot be found.' =>
      'This $terms.bug cannot be found.',
    'Time tracking:' =>
      'Time tracking:',
    'Gain' =>
      'Gain',
    'Attachments:' =>
      'Attachments:',
    'Description' =>
      'Description',
    'Flags' =>
      'Flags',
    '<i>none</i>' =>
      '<i>none</i>',
    'Flags:' =>
      'Flags:',
  },
  'bug/summarize-time.html.tmpl' => {
    'Time Summary ' =>
      'Time Summary ',
    'for ' =>
      'for ',
    ' (and $terms.bugs blocking it)' =>
      ' (and $terms.bugs blocking it)',
    ' $terms.bugs selected)' =>
      ' $terms.bugs selected)',
    'to' =>
      'to',
    'Full summary (no period specified)' =>
      'Full summary (no period specified)',
    'Total of' =>
      'Total of',
    'h remains from original estimate of' =>
      'h remains from original estimate of',
    'h' =>
      'h',
    '(deadline' =>
      '(deadline',
    'hours worked' =>
      'hours worked',
    'inactive $terms.bugs' =>
      'inactive $terms.bugs',
    '<b>Total</b>:' =>
      '<b>Total</b>:',
    'Estimated:' =>
      'Estimated:',
    'Remaining:' =>
      'Remaining:',
    '<b>Not set</b>' =>
      '<b>Not set</b>',
    'Deadline:' =>
      'Deadline:',
    'Inactive $terms.bugs' =>
      'Inactive $terms.bugs',
    '<b>Totals</b>' =>
      '<b>Totals</b>',
    'No time allocated during the specified period.' =>
      'No time allocated during the specified period.',
    'The end date specified occurs before the start date, which doesn\'t make sense; the dates below have therefore been swapped.' =>
      'The end date specified occurs before the start date, which doesn\'t make sense; the dates below have therefore been swapped.',
    'Period <u>s</u>tarting' =>
      'Period <u>s</u>tarting',
    '&nbsp; <b>and' =>
      '&nbsp; <b>and',
    '<u>e</u>nding' =>
      '<u>e</u>nding',
    'Summarize' =>
      'Summarize',
    '(Dates are optional, and in YYYY-MM-DD format)' =>
      '(Dates are optional, and in YYYY-MM-DD format)',
    '<b>Group by</b>:' =>
      '<b>Group by</b>:',
    '$terms.Bug <u>N</u>umber' =>
      '$terms.Bug <u>N</u>umber',
    '<u>D</u>eveloper' =>
      '<u>D</u>eveloper',
    '<b>Format</b>' =>
      '<b>Format</b>',
    'HTML Report' =>
      'HTML Report',
    'Split by <u>m</u>onth' =>
      'Split by <u>m</u>onth',
    'De<u>t</u>ailed summaries' =>
      'De<u>t</u>ailed summaries',
    'Also show <u>i</u>nactive $terms.bugs' =>
      'Also show <u>i</u>nactive $terms.bugs',
    'Use my <u>a</u>ctivity' =>
      'Use my <u>a</u>ctivity',
  },
  'bug/votes/delete-all.html.tmpl' => {
    'Remove your votes?' =>
      'Remove your votes?',
    'You are about to remove all of your $terms.bug votes. Are you sure you wish to remove your vote from every $terms.bug you\'ve voted on?' =>
      'You are about to remove all of your $terms.bug votes. Are you sure you wish to remove your vote from every $terms.bug you\'ve voted on?',
    'Yes, delete all my votes' =>
      'Yes, delete all my votes',
    'No, go back and review my votes' =>
      'No, go back and review my votes',
    'Submit' =>
      'Submit',
  },
  'bug/votes/list-for-bug.html.tmpl' => {
    'Show Votes' =>
      'Show Votes',
    'Who' =>
      'Who',
    'Number of votes' =>
      'Number of votes',
    'Total votes:' =>
      'Total votes:',
  },
  'bug/votes/list-for-user.html.tmpl' => {
    'Change Votes' =>
      'Change Votes',
    'Show Votes' =>
      'Show Votes',
    'The changes to your votes have been saved.' =>
      'The changes to your votes have been saved.',
    'Votes' =>
      'Votes',
    'Summary' =>
      'Summary',
    '($terms.bug list)' =>
      '($terms.bug list)',
    '(Note: only' =>
      '(Note: only',
    'vote' =>
      'vote',
    'allowed per $terms.bug in this product.)' =>
      'allowed per $terms.bug in this product.)',
    'Enter New Vote here &rarr;' =>
      'Enter New Vote here &rarr;',
    'used out of' =>
      'used out of',
    'allowed.' =>
      'allowed.',
    'Change My Votes' =>
      'Change My Votes',
    'or' =>
      'or',
    'view all as $terms.bug list' =>
      'view all as $terms.bug list',
    'To change your votes,' =>
      'To change your votes,',
    ' or ' =>
      ' or ',
    'type in new numbers (using zero to mean no votes)' =>
      'type in new numbers (using zero to mean no votes)',
    'change the checkbox' =>
      'change the checkbox',
    'and then click <b>Change My Votes</b>.' =>
      'and then click <b>Change My Votes</b>.',
    'View all as $terms.bug list' =>
      'View all as $terms.bug list',
    'You are' =>
      'You are',
    'This user is' =>
      'This user is',
    'currently not voting on any $terms.bugs.' =>
      'currently not voting on any $terms.bugs.',
    'Help with voting' =>
      'Help with voting',
  },
  'email/lockout.txt.tmpl' => {
    '[$terms.Bugzilla] Account Lock-Out:' =>
      '[$terms.Bugzilla] Account Lock-Out:',
    'The IP address' =>
      'The IP address',
    'failed too many login attempts (' =>
      'failed too many login attempts (',
    ') for the account' =>
      ') for the account',
    'The login attempts occurred at these times:' =>
      'The login attempts occurred at these times:',
    'This IP will be able to log in again using this account at' =>
      'This IP will be able to log in again using this account at',
  },
  'email/newchangedmail.txt.tmpl' => {
    '[BLOCKER] ' =>
      '[BLOCKER] ',
    '[CRITICAL] ' =>
      '[CRITICAL] ',
    '(prod:' =>
      '(prod:',
    ', pri:' =>
      ', pri:',
    ', sev:' =>
      ', sev:',
    ', miles:' =>
      ', miles:',
    'Bug' =>
      'Bug',
    'depends on bug' =>
      'depends on bug',
    ', which changed state.' =>
      ', which changed state.',
    'summary:' =>
      'summary:',
    'changed:' =>
      'changed:',
    'What    ' =>
      'What    ',
    'Removed' =>
      'Removed',
    'Added' =>
      'Added',
    '--- Comment #' =>
      '--- Comment #',
    'from' =>
      'from',
    'Configure $terms.bugmail:' =>
      'Configure $terms.bugmail:',
    'You are receiving this mail because:' =>
      'You are receiving this mail because:',
    'You are the assignee for the $terms.bug.' =>
      'You are the assignee for the $terms.bug.',
    'You reported the $terms.bug.' =>
      'You reported the $terms.bug.',
    'You are the QA contact for the $terms.bug.' =>
      'You are the QA contact for the $terms.bug.',
    'You are on the CC list for the $terms.bug.' =>
      'You are on the CC list for the $terms.bug.',
    'Remove yourself from the CC list' =>
      'Remove yourself from the CC list',
    'You are a voter for the $terms.bug.' =>
      'You are a voter for the $terms.bug.',
    'You are watching all $terms.bug changes.' =>
      'You are watching all $terms.bug changes.',
    'You are watching the assignee of the $terms.bug.' =>
      'You are watching the assignee of the $terms.bug.',
    'You are watching the reporter.' =>
      'You are watching the reporter.',
    'You are watching the QA contact of the $terms.bug.' =>
      'You are watching the QA contact of the $terms.bug.',
    'You are watching someone on the CC list of the $terms.bug.' =>
      'You are watching someone on the CC list of the $terms.bug.',
    'You are watching a voter for the $terms.bug.' =>
      'You are watching a voter for the $terms.bug.',
    '&nbsp;Bug' =>
      '&nbsp;Bug',
    'Comment #' =>
      'Comment #',
    'depends on' =>
      'depends on',
    'bug' =>
      'bug',
    'What' =>
      'What',
    'Description' =>
      'Description',
    'Configure $terms.bugmail' =>
      'Configure $terms.bugmail',
  },
  'email/sanitycheck.txt.tmpl' => {
    '[$terms.Bugzilla] Sanity Check Results' =>
      '[$terms.Bugzilla] Sanity Check Results',
    'Below can you read the sanity check results.' =>
      'Below can you read the sanity check results.',
    'Some errors have been found.' =>
      'Some errors have been found.',
    'No errors have been found.' =>
      'No errors have been found.',
  },
  'email/sudo.txt.tmpl' => {
    '[$terms.Bugzilla] Your account ' =>
      '[$terms.Bugzilla] Your account ',
    ' is being impersonated' =>
      ' is being impersonated',
    'has used the \'sudo\' feature to access $terms.Bugzilla using your account.' =>
      'has used the \'sudo\' feature to access $terms.Bugzilla using your account.',
    'provided the following reason for doing this:' =>
      'provided the following reason for doing this:',
    'did not provide a reason for doing this.' =>
      'did not provide a reason for doing this.',
    'If you feel that this action was inappropriate, please contact' =>
      'If you feel that this action was inappropriate, please contact',
    '. For more information on this feature, visit' =>
      '. For more information on this feature, visit',
  },
  'email/votes-removed.txt.tmpl' => {
    ' - Some or all of your votes have been removed.' =>
      ' - Some or all of your votes have been removed.',
    'Some or all of your votes have been removed from $terms.bug' =>
      'Some or all of your votes have been removed from $terms.bug',
    'You had' =>
      'You had',
    'vote' =>
      'vote',
    'votes' =>
      'votes',
    'on this $terms.bug, but' =>
      'on this $terms.bug, but',
    'have been removed.' =>
      'have been removed.',
    'You still have' =>
      'You still have',
    'on this $terms.bug.' =>
      'on this $terms.bug.',
    'You have no more votes remaining on this $terms.bug.' =>
      'You have no more votes remaining on this $terms.bug.',
    'Reason:' =>
      'Reason:',
    'This $terms.bug has been moved to a different product.' =>
      'This $terms.bug has been moved to a different product.',
    'The rules for voting on this product has changed; you had too many votes for a single $terms.bug.' =>
      'The rules for voting on this product has changed; you had too many votes for a single $terms.bug.',
    'The rules for voting on this product has changed; you had too many total votes, so all votes have been removed.' =>
      'The rules for voting on this product has changed; you had too many total votes, so all votes have been removed.',
  },
  'email/whine.txt.tmpl' => {
    'Your $terms.Bugzilla $terms.bug list needs attention.' =>
      'Your $terms.Bugzilla $terms.bug list needs attention.',
    '[This e-mail has been automatically generated.]' =>
      '[This e-mail has been automatically generated.]',
    'You have one or more $terms.bugs assigned to you in the $terms.Bugzilla $terms.bug tracking system (' =>
      'You have one or more $terms.bugs assigned to you in the $terms.Bugzilla $terms.bug tracking system (',
    ') that require attention.' =>
      ') that require attention.',
    'All of these $terms.bugs are in the NEW or REOPENED state, and have not been touched in' =>
      'All of these $terms.bugs are in the NEW or REOPENED state, and have not been touched in',
    'days or more. You need to take a look at them, and decide on an initial action.' =>
      'days or more. You need to take a look at them, and decide on an initial action.',
    'Generally, this means one of three things:' =>
      'Generally, this means one of three things:',
    '(1) You decide this $terms.bug is really quick to deal with (like, it\'s INVALID), and so you get rid of it immediately. (2) You decide the $terms.bug doesn\'t belong to you, and you reassign it to someone else. (Hint: if you don\'t know who to reassign it to, make sure that the Component field seems reasonable, and then use the "Reset Assignee to default" option.) (3) You decide the $terms.bug belongs to you, but you can\'t solve it this moment. Accept the $terms.bug by setting the status to ASSIGNED.' =>
      '(1) You decide this $terms.bug is really quick to deal with (like, it\'s INVALID), and so you get rid of it immediately. (2) You decide the $terms.bug doesn\'t belong to you, and you reassign it to someone else. (Hint: if you don\'t know who to reassign it to, make sure that the Component field seems reasonable, and then use the "Reset Assignee to default" option.) (3) You decide the $terms.bug belongs to you, but you can\'t solve it this moment. Accept the $terms.bug by setting the status to ASSIGNED.',
    'To get a list of all NEW/REOPENED $terms.bugs, you can use this URL (bookmark it if you like!):' =>
      'To get a list of all NEW/REOPENED $terms.bugs, you can use this URL (bookmark it if you like!):',
    'Or, you can use the general query page, at' =>
      'Or, you can use the general query page, at',
    'Appended below are the individual URLs to get to all of your NEW $terms.bugs that haven\'t been touched for' =>
      'Appended below are the individual URLs to get to all of your NEW $terms.bugs that haven\'t been touched for',
    'days or more.' =>
      'days or more.',
    'You will get this message once a day until you\'ve dealt with these $terms.bugs!' =>
      'You will get this message once a day until you\'ve dealt with these $terms.bugs!',
  },
  'extensions/BmpConvert/hook/global/messages-messages.html.tmpl' => {
    '<b>Note:</b> $terms.Bugzilla automatically converted your BMP image file to a compressed PNG format.' =>
      '<b>Note:</b> $terms.Bugzilla automatically converted your BMP image file to a compressed PNG format.',
  },
  'extensions/Example/admin/params/example.html.tmpl' => {
    'Example Extension' =>
      'Example Extension',
    'Configure example extension' =>
      'Configure example extension',
    'Example string' =>
      'Example string',
  },
  'extensions/Example/hook/admin/sanitycheck/messages-statuses.html.tmpl' => {
    '<em>EXAMPLE PLUGIN</em> - Checking for non-Australian users.' =>
      '<em>EXAMPLE PLUGIN</em> - Checking for non-Australian users.',
    'User &lt;' =>
      'User &lt;',
    '&gt; isn\'t Australian.' =>
      '&gt; isn\'t Australian.',
    'Edit this user' =>
      'Edit this user',
    'Fix these users' =>
      'Fix these users',
    '<em>EXAMPLE PLUGIN</em> - OK, would now make users Australian.' =>
      '<em>EXAMPLE PLUGIN</em> - OK, would now make users Australian.',
    '<em>EXAMPLE PLUGIN</em> - Users would now be Australian.' =>
      '<em>EXAMPLE PLUGIN</em> - Users would now be Australian.',
  },
  'extensions/Example/hook/global/user-error-errors.html.tmpl' => {
    'Example Error Title' =>
      'Example Error Title',
    'This is the error message! It contains <em>some html</em>.' =>
      'This is the error message! It contains <em>some html</em>.',
  },
  'extensions/Example/pages/example.html.tmpl' => {
    'Example Page' =>
      'Example Page',
    'Here\'s what you passed me:' =>
      'Here\'s what you passed me:',
  },
  'extensions/hook-readme.txt.tmpl' => {
    'Template hooks go in this directory. Template hooks are called in normal $terms.Bugzilla templates like [' =>
      'Template hooks go in this directory. Template hooks are called in normal $terms.Bugzilla templates like [',
    'ugzilla::Extension" from the main $terms.Bugzilla directory to see that documentation.)' =>
      'ugzilla::Extension" from the main $terms.Bugzilla directory to see that documentation.)',
  },
  'extensions/license.txt.tmpl' => {
    '$terms.Bugzilla Extension. # # The Initial Developer of the Original Code is YOUR NAME # Portions created by the Initial Developer are Copyright (C)' =>
      '$terms.Bugzilla Extension. # # The Initial Developer of the Original Code is YOUR NAME # Portions created by the Initial Developer are Copyright (C)',
  },
  'flag/list.html.tmpl' => {
    'Flags:' =>
      'Flags:',
    'Requestee:' =>
      'Requestee:',
    '<b>Flags:</b>' =>
      '<b>Flags:</b>',
  },
  'global/choose-classification.html.tmpl' => {
    'Enter $terms.Bug' =>
      'Enter $terms.Bug',
    'Choose a classification for the new $terms.bug' =>
      'Choose a classification for the new $terms.bug',
    'Browse' =>
      'Browse',
    'Select a classification to browse' =>
      'Select a classification to browse',
    'Choose the classification' =>
      'Choose the classification',
    'All' =>
      'All',
    'Show all products' =>
      'Show all products',
    'enter_bug\\.cgi' =>
      'enter_bug\\.cgi',
    'See also:' =>
      'See also:',
    'Mass bug import from Excel files' =>
      'Mass bug import from Excel files',
  },
  'global/choose-product.html.tmpl' => {
    'Enter $terms.Bug' =>
      'Enter $terms.Bug',
    'Choose a product for the new $terms.bug' =>
      'Choose a product for the new $terms.bug',
    'Browse' =>
      'Browse',
    'Select a product to browse' =>
      'Select a product to browse',
    'Choose a Product' =>
      'Choose a Product',
    'describecomponents\\.cgi' =>
      'describecomponents\\.cgi',
    'Select other classification' =>
      'Select other classification',
    'enter_bug\\.cgi' =>
      'enter_bug\\.cgi',
    'See also:' =>
      'See also:',
    'Mass bug import from Excel files' =>
      'Mass bug import from Excel files',
  },
  'global/code-error-page.html.tmpl' => {
    'Произошла внутренняя ошибка Bugzilla.' =>
      'Произошла внутренняя ошибка Bugzilla.',
    'Отчёт об ошибке автоматически отправлен' =>
      'Отчёт об ошибке автоматически отправлен',
    'В ближайшее время она будет исправлена. Можете не закрывать вкладку и чуть позже нажать F5 (обновить страницу).' =>
      'В ближайшее время она будет исправлена. Можете не закрывать вкладку и чуть позже нажать F5 (обновить страницу).',
    'Пожалуйста, сохраните эту страницу и отправьте её по адресу' =>
      'Пожалуйста, сохраните эту страницу и отправьте её по адресу',
    'с информацией о том, какие Ваши действия привели к ошибке и пожеланиями об исправлении.' =>
      'с информацией о том, какие Ваши действия привели к ошибке и пожеланиями об исправлении.',
    'Извините нас.' =>
      'Извините нас.',
    'Дополнительные данные:' =>
      'Дополнительные данные:',
  },
  'global/code-error.html.tmpl' => {
    'Internal Error' =>
      'Internal Error',
    'Internal error' =>
      'Internal error',
    'An internal error has occurred, but $terms.Bugzilla doesn\'t know what <b>' =>
      'An internal error has occurred, but $terms.Bugzilla doesn\'t know what <b>',
    '</b> means.' =>
      '</b> means.',
    'Searching for $terms.bugs' =>
      'Searching for $terms.bugs',
    '$terms.Bug lists' =>
      '$terms.Bug lists',
    'I don\'t recognize the value (<em>' =>
      'I don\'t recognize the value (<em>',
    '</em>) of the <em>action</em> variable.' =>
      '</em>) of the <em>action</em> variable.',
    'Local Storage Disabled' =>
      'Local Storage Disabled',
    'You cannot store attachments locally. This feature is disabled.' =>
      'You cannot store attachments locally. This feature is disabled.',
    'Attachment URL Disabled' =>
      'Attachment URL Disabled',
    'You cannot attach a URL. This feature is currently disabled.' =>
      'You cannot attach a URL. This feature is currently disabled.',
    'Invalid Email Address' =>
      'Invalid Email Address',
    'We received an email address (<b>' =>
      'We received an email address (<b>',
    '</b>) that didn\'t pass our syntax checking for a legal email address, when trying to create or update your account.' =>
      '</b>) that didn\'t pass our syntax checking for a legal email address, when trying to create or update your account.',
    'A legal address must contain exactly one \'@\', and at least one \'.\' after the @.' =>
      'A legal address must contain exactly one \'@\', and at least one \'.\' after the @.',
    'It must also not contain any of these special characters:' =>
      'It must also not contain any of these special characters:',
    ', or any whitespace.' =>
      ', or any whitespace.',
    'The result value of' =>
      'The result value of',
    'was not handled by the login code.' =>
      'was not handled by the login code.',
    'Invalid Page ID' =>
      'Invalid Page ID',
    'The ID' =>
      'The ID',
    'is not a valid page identifier.' =>
      'is not a valid page identifier.',
    'Bad argument' =>
      'Bad argument',
    'sent to' =>
      'sent to',
    'function.' =>
      'function.',
    'Trying to retrieve $terms.bug' =>
      'Trying to retrieve $terms.bug',
    'returned the error' =>
      'returned the error',
    'Setting up Charting' =>
      'Setting up Charting',
    'Charts for the <em>' =>
      'Charts for the <em>',
    '</em> product are not available yet because no charting data has been collected for it since it was created.' =>
      '</em> product are not available yet because no charting data has been collected for it since it was created.',
    'No charting data has been collected yet.' =>
      'No charting data has been collected yet.',
    'Please wait a day and try again. If you\'re seeing this message after a day, then you should contact' =>
      'Please wait a day and try again. If you\'re seeing this message after a day, then you should contact',
    'and reference this error.' =>
      'and reference this error.',
    'The chart data file' =>
      'The chart data file',
    'is corrupt.' =>
      'is corrupt.',
    'One of the directories' =>
      'One of the directories',
    'and' =>
      'and',
    'does not exist.' =>
      'does not exist.',
    'Unable to open the chart datafile' =>
      'Unable to open the chart datafile',
    'Failed adding the column' =>
      'Failed adding the column',
    ': You cannot add a NOT NULL column with no default to an existing table unless you specify something for the' =>
      ': You cannot add a NOT NULL column with no default to an existing table unless you specify something for the',
    'argument.' =>
      'argument.',
    'You cannot alter the' =>
      'You cannot alter the',
    'column to be NOT NULL without specifying a default or something for $set_nulls_to, because there are NULL values currently in it.' =>
      'column to be NOT NULL without specifying a default or something for $set_nulls_to, because there are NULL values currently in it.',
    'You tried to set the' =>
      'You tried to set the',
    'extra_data' =>
      'extra_data',
    'field to \'' =>
      'field to \'',
    '\' but comments of type' =>
      '\' but comments of type',
    'do not accept an' =>
      'do not accept an',
    'Comments of type' =>
      'Comments of type',
    'require an' =>
      'require an',
    'argument to be set.' =>
      'argument to be set.',
    'require a numeric' =>
      'require a numeric',
    '\' is not a valid comment type.' =>
      '\' is not a valid comment type.',
    'Name conflict: Cannot rename' =>
      'Name conflict: Cannot rename',
    'to' =>
      'to',
    'because' =>
      'because',
    'already exists.' =>
      'already exists.',
    'Every cookie must have a value.' =>
      'Every cookie must have a value.',
    '$terms.Bugzilla did not receive an email address from the environment.' =>
      '$terms.Bugzilla did not receive an email address from the environment.',
    'This means that the \'' =>
      'This means that the \'',
    '\' environment variable was empty or did not exist.' =>
      '\' environment variable was empty or did not exist.',
    'You need to set the "auth_env_email" parameter to the name of the environment variable that will contain the user\'s email address.' =>
      'You need to set the "auth_env_email" parameter to the name of the environment variable that will contain the user\'s email address.',
    'from' =>
      'from',
    'is not a subclass of' =>
      'is not a subclass of',
    'returned' =>
      'returned',
    ', which is not a valid name for an extension. Extensions must return their name, not' =>
      ', which is not a valid name for an extension. Extensions must return their name, not',
    'or a number. See the documentation of' =>
      'or a number. See the documentation of',
    'Bugzilla::Extension' =>
      'Bugzilla::Extension',
    'for details.' =>
      'for details.',
    'We did not find a' =>
      'We did not find a',
    'NAME' =>
      'NAME',
    'method in' =>
      'method in',
    '(loaded from' =>
      '(loaded from',
    '). This means that the extension has one or more of the following problems:' =>
      '). This means that the extension has one or more of the following problems:',
    'did not define a' =>
      'did not define a',
    'package.' =>
      'package.',
    'method (or the' =>
      'method (or the',
    'method returned an empty string).' =>
      'method returned an empty string).',
    'The external ID \'' =>
      'The external ID \'',
    '\' already exists in the database for \'' =>
      '\' already exists in the database for \'',
    '\', but your account source says that \'' =>
      '\', but your account source says that \'',
    '\' has that ID.' =>
      '\' has that ID.',
    'When you call a class method on' =>
      'When you call a class method on',
    ', you must call' =>
      ', you must call',
    'to generate the right class (you can\'t call class methods directly on Bugzilla::Field::Choice).' =>
      'to generate the right class (you can\'t call class methods directly on Bugzilla::Field::Choice).',
    'Field Type Not Specified' =>
      'Field Type Not Specified',
    'You must specify a type when creating a custom field.' =>
      'You must specify a type when creating a custom field.',
    'Your form submission got corrupted somehow. The <em>content method</em> field, which specifies how the content type gets determined, should have been either <em>autodetect</em>, <em>list</em>, or <em>manual</em>, but was instead <em>' =>
      'Your form submission got corrupted somehow. The <em>content method</em> field, which specifies how the content type gets determined, should have been either <em>autodetect</em>, <em>list</em>, or <em>manual</em>, but was instead <em>',
    'Attempted to add $terms.bug to the \'' =>
      'Attempted to add $terms.bug to the \'',
    '\' group, which is not used for $terms.bugs.' =>
      '\' group, which is not used for $terms.bugs.',
    'The attachment number of one of the attachments you wanted to obsolete,' =>
      'The attachment number of one of the attachments you wanted to obsolete,',
    ', is invalid.' =>
      ', is invalid.',
    'Invalid Field Type' =>
      'Invalid Field Type',
    'The type <em>' =>
      'The type <em>',
    '</em> is not a valid field type.' =>
      '</em> is not a valid field type.',
    'Invalid Dimensions' =>
      'Invalid Dimensions',
    'The width or height specified is not a positive integer.' =>
      'The width or height specified is not a positive integer.',
    'Invalid Feature Name' =>
      'Invalid Feature Name',
    'is not a valid feature name. See' =>
      'is not a valid feature name. See',
    'in' =>
      'in',
    'for valid names.' =>
      'for valid names.',
    'Invalid Flag Association' =>
      'Invalid Flag Association',
    'Some flags do not belong to' =>
      'Some flags do not belong to',
    'attachment' =>
      'attachment',
    'Invalid Series' =>
      'Invalid Series',
    'The series_id' =>
      'The series_id',
    'is not valid. It may be that this series has been deleted.' =>
      'is not valid. It may be that this series has been deleted.',
    'There is no such group:' =>
      'There is no such group:',
    '. Check your $webservergroup setting in' =>
      '. Check your $webservergroup setting in',
    'Attachment' =>
      'Attachment',
    ') is attached to $terms.bug' =>
      ') is attached to $terms.bug',
    ', but you tried to flag it as obsolete while creating a new attachment to $terms.bug' =>
      ', but you tried to flag it as obsolete while creating a new attachment to $terms.bug',
    'The' =>
      'The',
    'feature is not available in this $terms.Bugzilla.' =>
      'feature is not available in this $terms.Bugzilla.',
    'If you would like to enable this feature, please run' =>
      'If you would like to enable this feature, please run',
    'to see how to install the necessary requirements for this feature.' =>
      'to see how to install the necessary requirements for this feature.',
    'Object Not Recognized' =>
      'Object Not Recognized',
    'Flags cannot be set for objects of type' =>
      'Flags cannot be set for objects of type',
    '. They can only be set for $terms.bugs and attachments.' =>
      '. They can only be set for $terms.bugs and attachments.',
    'Flag not Requestable from Specific Person' =>
      'Flag not Requestable from Specific Person',
    'You can\'t ask a specific person for <em>' =>
      'You can\'t ask a specific person for <em>',
    'The flag status <em>' =>
      'The flag status <em>',
    'for flag ID #' =>
      'for flag ID #',
    'is invalid.' =>
      'is invalid.',
    'Inactive Flag Type' =>
      'Inactive Flag Type',
    'The flag type' =>
      'The flag type',
    'is inactive and cannot be used to create new flags.' =>
      'is inactive and cannot be used to create new flags.',
    'There is no flag type with the ID <em>' =>
      'There is no flag type with the ID <em>',
    'The target type was neither <em>$terms.bug</em> nor <em>attachment</em> but rather <em>' =>
      'The target type was neither <em>$terms.bug</em> nor <em>attachment</em> but rather <em>',
    'The keyword ID <em>' =>
      'The keyword ID <em>',
    '</em> couldn\'t be found.' =>
      '</em> couldn\'t be found.',
    'Invalid User' =>
      'Invalid User',
    'There is no user account' =>
      'There is no user account',
    'with ID <em>' =>
      'with ID <em>',
    'with login name <em>' =>
      'with login name <em>',
    'given.' =>
      'given.',
    'Job Queue Failure' =>
      'Job Queue Failure',
    'Inserting a' =>
      'Inserting a',
    'job into the Job Queue failed with the following error:' =>
      'job into the Job Queue failed with the following error:',
    'Failed to bind to the LDAP server. The error message was:' =>
      'Failed to bind to the LDAP server. The error message was:',
    'The specified LDAP attribute' =>
      'The specified LDAP attribute',
    'was not found.' =>
      'was not found.',
    'Could not connect to the LDAP server(s)' =>
      'Could not connect to the LDAP server(s)',
    'Could not start TLS with LDAP server:' =>
      'Could not start TLS with LDAP server:',
    'An error occurred while trying to search LDAP for &quot;' =>
      'An error occurred while trying to search LDAP for &quot;',
    'Unable to find user in LDAP' =>
      'Unable to find user in LDAP',
    'The LDAP server for authentication has not been defined.' =>
      'The LDAP server for authentication has not been defined.',
    'From' =>
      'From',
    'There was an error sending mail from \'' =>
      'There was an error sending mail from \'',
    '\' to \'' =>
      '\' to \'',
    'No $terms.bug ID was given.' =>
      'No $terms.bug ID was given.',
    'Having inserted a series into the database, no series_id was returned for it. Series:' =>
      'Having inserted a series into the database, no series_id was returned for it. Series:',
    'A valid quipid is needed.' =>
      'A valid quipid is needed.',
    'You cannot set the resolution of $terms.abug to MOVED without moving the $terms.bug.' =>
      'You cannot set the resolution of $terms.abug to MOVED without moving the $terms.bug.',
    '$terms.Bug Cannot Be Confirmed' =>
      '$terms.Bug Cannot Be Confirmed',
    'There is no valid transition to an open confirmed state.' =>
      'There is no valid transition to an open confirmed state.',
    'Invalid Parameter' =>
      'Invalid Parameter',
    'is not a valid parameter for the' =>
      'is not a valid parameter for the',
    'Invalid parameter' =>
      'Invalid parameter',
    'passed to' =>
      'passed to',
    ': It must be numeric.' =>
      ': It must be numeric.',
    'Missing Parameter' =>
      'Missing Parameter',
    'The function' =>
      'The function',
    'requires a' =>
      'requires a',
    'argument, and that argument was not set.' =>
      'argument, and that argument was not set.',
    'requires that you set one of the following parameters:' =>
      'requires that you set one of the following parameters:',
    'Missing Group Controls' =>
      'Missing Group Controls',
    'New settings must be defined to edit group controls for the' =>
      'New settings must be defined to edit group controls for the',
    'group.' =>
      'group.',
    'Illegal Group Control' =>
      'Illegal Group Control',
    '\' is not a legal value for the \'' =>
      '\' is not a legal value for the \'',
    '\' field.' =>
      '\' field.',
    'was called' =>
      'was called',
    'with the argument' =>
      'with the argument',
    ', which is' =>
      ', which is',
    'outside the package. This function may only be called from a subclass of' =>
      'outside the package. This function may only be called from a subclass of',
    'An error occurred while preparing for a RADIUS authentication request:' =>
      'An error occurred while preparing for a RADIUS authentication request:',
    'The group field <em>' =>
      'The group field <em>',
    '</em> is invalid.' =>
      '</em> is invalid.',
    '</em> is not a valid value for' =>
      '</em> is not a valid value for',
    'the horizontal axis' =>
      'the horizontal axis',
    'the vertical axis' =>
      'the vertical axis',
    'the multiple tables/images' =>
      'the multiple tables/images',
    'a report axis' =>
      'a report axis',
    'field.' =>
      'field.',
    'To create a new setting, you must supply a setting name, a list of value/sortindex pairs, and the default value.' =>
      'To create a new setting, you must supply a setting name, a list of value/sortindex pairs, and the default value.',
    'The setting name <em>' =>
      'The setting name <em>',
    '</em> is not a valid option. Setting names must begin with a letter, and contain only letters, digits, or the symbols \'_\', \'-\', \'.\', or \':\'.' =>
      '</em> is not a valid option. Setting names must begin with a letter, and contain only letters, digits, or the symbols \'_\', \'-\', \'.\', or \':\'.',
    'There is no such Setting subclass as' =>
      'There is no such Setting subclass as',
    'The value "' =>
      'The value "',
    '" is not in the list of legal values for the <em>' =>
      '" is not in the list of legal values for the <em>',
    '</em> setting.' =>
      '</em> setting.',
    'Something is seriously wrong with the token generation system.' =>
      'Something is seriously wrong with the token generation system.',
    'Template with invalid file name found in hook call:' =>
      'Template with invalid file name found in hook call:',
    'I was unable to retrieve your old password from the database.' =>
      'I was unable to retrieve your old password from the database.',
    'Form field' =>
      'Form field',
    'was not defined.' =>
      'was not defined.',
    'Unknown action' =>
      'Unknown action',
    'I could not figure out what you wanted to do.' =>
      'I could not figure out what you wanted to do.',
    'The requested method \'' =>
      'The requested method \'',
    '\' was not found.' =>
      '\' was not found.',
    '\' is not a valid usage mode.' =>
      '\' is not a valid usage mode.',
    'Attachment Must Be Patch' =>
      'Attachment Must Be Patch',
    'Attachment #' =>
      'Attachment #',
    'must be a patch.' =>
      'must be a patch.',
    'Attempted to end transaction without starting one first.' =>
      'Attempted to end transaction without starting one first.',
    'SQL query generator internal error' =>
      'SQL query generator internal error',
    'There is an internal error in the SQL query generation code, creating queries with implicit JOIN.' =>
      'There is an internal error in the SQL query generation code, creating queries with implicit JOIN.',
    'Invalid setting for post_bug_submit_action' =>
      'Invalid setting for post_bug_submit_action',
    'Invalid setting for remind_me_about_worktime' =>
      'Invalid setting for remind_me_about_worktime',
    'Invalid setting for remind_me_about_worktime_newbug' =>
      'Invalid setting for remind_me_about_worktime_newbug',
    'Invalid setting for remind_me_about_flags' =>
      'Invalid setting for remind_me_about_flags',
    'Generic code error:' =>
      'Generic code error:',
  },
  'global/common-links.html.tmpl' => {
    'Home' =>
      'Home',
    'New' =>
      'New',
    'Browse' =>
      'Browse',
    'Search' =>
      'Search',
    'Quicksearch Help' =>
      'Quicksearch Help',
    'Reports' =>
      'Reports',
    'My Requests' =>
      'My Requests',
    'Requests' =>
      'Requests',
    'Preferences' =>
      'Preferences',
    'Administration' =>
      'Administration',
    'Log&nbsp;out' =>
      'Log&nbsp;out',
    'Logged&nbsp;in&nbsp;as' =>
      'Logged&nbsp;in&nbsp;as',
    '(<b>impersonating' =>
      '(<b>impersonating',
    'end session' =>
      'end session',
    'New&nbsp;Account' =>
      'New&nbsp;Account',
    'Help' =>
      'Help',
  },
  'global/confirm-action.html.tmpl' => {
    'Suspicious Action' =>
      'Suspicious Action',
    'Your changes have been rejected because you exceeded the time limit of' =>
      'Your changes have been rejected because you exceeded the time limit of',
    'days before submitting your changes to' =>
      'days before submitting your changes to',
    '. Your page may have been displayed for too long, or old changes have been resubmitted by accident.' =>
      '. Your page may have been displayed for too long, or old changes have been resubmitted by accident.',
    'It looks like you didn\'t come from the right page. One reason could be that you entered the URL in the address bar of your web browser directly, which should be safe. Another reason could be that you clicked on a URL which redirected you here <b>without your consent</b>.' =>
      'It looks like you didn\'t come from the right page. One reason could be that you entered the URL in the address bar of your web browser directly, which should be safe. Another reason could be that you clicked on a URL which redirected you here <b>without your consent</b>.',
    'You submitted changes to' =>
      'You submitted changes to',
    'with an invalid token, which may indicate that someone tried to abuse you, for instance by making you click on a URL which redirected you here <b>without your consent</b>.' =>
      'with an invalid token, which may indicate that someone tried to abuse you, for instance by making you click on a URL which redirected you here <b>without your consent</b>.',
    'Are you sure you want to commit these changes?' =>
      'Are you sure you want to commit these changes?',
    'Yes, Confirm Changes' =>
      'Yes, Confirm Changes',
    'No, throw away these changes' =>
      'No, throw away these changes',
    '(you will be redirected to the home page).' =>
      '(you will be redirected to the home page).',
  },
  'global/confirm-user-match.html.tmpl' => {
    'Default CC List' =>
      'Default CC List',
    'Default Assignee' =>
      'Default Assignee',
    'Default QA Contact' =>
      'Default QA Contact',
    'CC List' =>
      'CC List',
    'Requester' =>
      'Requester',
    'Requestee' =>
      'Requestee',
    'Watch List' =>
      'Watch List',
    'Worktime user' =>
      'Worktime user',
    'Confirm Match' =>
      'Confirm Match',
    '$terms.Bugzilla cannot make a conclusive match for one or more of the names and/or email addresses you entered on the previous page.' =>
      '$terms.Bugzilla cannot make a conclusive match for one or more of the names and/or email addresses you entered on the previous page.',
    'Please examine the lists of potential matches below and select the ones you want,' =>
      'Please examine the lists of potential matches below and select the ones you want,',
    '$terms.Bugzilla is configured to require verification whenever you enter a name or partial email address.' =>
      '$terms.Bugzilla is configured to require verification whenever you enter a name or partial email address.',
    'Below are the names/addresses you entered and the matched accounts. Please confirm that they are correct,' =>
      'Below are the names/addresses you entered and the matched accounts. Please confirm that they are correct,',
    'or go back to the previous page to revise the names you entered.' =>
      'or go back to the previous page to revise the names you entered.',
    'Match Failed' =>
      'Match Failed',
    '$terms.Bugzilla was unable to make any match at all for one or more of the names and/or email addresses you entered on the previous page.' =>
      '$terms.Bugzilla was unable to make any match at all for one or more of the names and/or email addresses you entered on the previous page.',
    '<b>Note: You are currently logged out. Only exact matches against e-mail addresses will be performed.</b>' =>
      '<b>Note: You are currently logged out. Only exact matches against e-mail addresses will be performed.</b>',
    'Please go back and try other names or email addresses.' =>
      'Please go back and try other names or email addresses.',
    'matches multiple users.' =>
      'matches multiple users.',
    'Please go back and try again with a more specific name/address.' =>
      'Please go back and try again with a more specific name/address.',
    'matched more than the maximum of' =>
      'matched more than the maximum of',
    'users:' =>
      'users:',
    'matched:' =>
      'matched:',
    'matched <b>' =>
      'matched <b>',
    'was too short for substring match (minimum 3 characters)' =>
      'was too short for substring match (minimum 3 characters)',
    'did not match anything' =>
      'did not match anything',
    'Continue' =>
      'Continue',
    'requestee' =>
      'requestee',
  },
  'global/docslinks.html.tmpl' => {
    'Related documentation' =>
      'Related documentation',
  },
  'global/header.html.tmpl' => {
    'skins/contrib/' =>
      'skins/contrib/',
    '/IE-fixes.css' =>
      '/IE-fixes.css',
    'Atom feed' =>
      'Atom feed',
    'Mark news as read' =>
      'Mark news as read',
    'Close' =>
      'Close',
  },
  'global/hidden-fields.html.tmpl' => {
    'We were unable to store the file you uploaded because of incomplete information in the form you just submitted. Because we are unable to retain the file between form submissions, you must re-attach the file in addition to completing the remaining missing information above.' =>
      'We were unable to store the file you uploaded because of incomplete information in the form you just submitted. Because we are unable to retain the file between form submissions, you must re-attach the file in addition to completing the remaining missing information above.',
    'Please re-attach the file <b>' =>
      'Please re-attach the file <b>',
    '</b> in the field below:' =>
      '</b> in the field below:',
  },
  'global/message.html.tmpl' => {
    '$terms.Bugzilla Message' =>
      '$terms.Bugzilla Message',
  },
  'global/messages.html.tmpl' => {
    'Attachment #' =>
      'Attachment #',
    'to' =>
      'to',
    'created' =>
      'created',
    '<b>Note:</b> $terms.Bugzilla automatically detected the content type <em>' =>
      '<b>Note:</b> $terms.Bugzilla automatically detected the content type <em>',
    '</em> for this attachment. If this is incorrect, correct the value by editing the attachment\'s' =>
      '</em> for this attachment. If this is incorrect, correct the value by editing the attachment\'s',
    'details' =>
      'details',
    'Changes Submitted to Attachment ' =>
      'Changes Submitted to Attachment ',
    ' of $terms.Bug ' =>
      ' of $terms.Bug ',
    'Changes to' =>
      'Changes to',
    'attachment' =>
      'attachment',
    'of' =>
      'of',
    'submitted' =>
      'submitted',
    'The next $terms.bug in your list is $terms.bug' =>
      'The next $terms.bug in your list is $terms.bug',
    'The' =>
      'The',
    'field has been set to zero automatically as part of closing this $terms.bug or moving it from one closed state to another.' =>
      'field has been set to zero automatically as part of closing this $terms.bug or moving it from one closed state to another.',
    'CC list restricted to group <em>' =>
      'CC list restricted to group <em>',
    '</em> removed.' =>
      '</em> removed.',
    'The $terms.bug was created successfully, but attachment creation failed. Please add your attachment by clicking the "Add an Attachment" link below.' =>
      'The $terms.bug was created successfully, but attachment creation failed. Please add your attachment by clicking the "Add an Attachment" link below.',
    'Active values updated.' =>
      'Active values updated.',
    'Changes to default preferences have been saved.' =>
      'Changes to default preferences have been saved.',
    'No changes made.' =>
      'No changes made.',
    'Field(s) X are now visible for this ' =>
      'Field(s) X are now visible for this ',
    'Field(s) X are now invisible for this ' =>
      'Field(s) X are now invisible for this ',
    'Field(s) X will be copied during clone of ' =>
      'Field(s) X will be copied during clone of ',
    ' with this ' =>
      ' with this ',
    'Field(s) X will not be copied during clone of ' =>
      'Field(s) X will not be copied during clone of ',
    'Field(s) X may now be empty in this ' =>
      'Field(s) X may now be empty in this ',
    'Field(s) X are now mandatory in this ' =>
      'Field(s) X are now mandatory in this ',
    'Default X updated for this ' =>
      'Default X updated for this ',
    'Default X deleted for this ' =>
      'Default X deleted for this ',
    'Custom Field Created' =>
      'Custom Field Created',
    'The new custom field \'' =>
      'The new custom field \'',
    '\' has been successfully created.' =>
      '\' has been successfully created.',
    'Custom Field Deleted' =>
      'Custom Field Deleted',
    'The custom field \'' =>
      'The custom field \'',
    '\' has been successfully deleted.' =>
      '\' has been successfully deleted.',
    'Custom Field Updated' =>
      'Custom Field Updated',
    'Properties of the \'' =>
      'Properties of the \'',
    '\' field have been successfully updated.' =>
      '\' field have been successfully updated.',
    'The user account' =>
      'The user account',
    'has been created successfully.' =>
      'has been created successfully.',
    'You may want to edit the group settings now, using the form below.' =>
      'You may want to edit the group settings now, using the form below.',
    'User Account Creation Canceled' =>
      'User Account Creation Canceled',
    'The creation of the user account' =>
      'The creation of the user account',
    'has been canceled.' =>
      'has been canceled.',
    'User ' =>
      'User ',
    ' updated' =>
      ' updated',
    'The following changes have been made to the user account' =>
      'The following changes have been made to the user account',
    'The login is now' =>
      'The login is now',
    'The real name has been updated.' =>
      'The real name has been updated.',
    'A new password has been set.' =>
      'A new password has been set.',
    'The disable text has been modified.' =>
      'The disable text has been modified.',
    '$terms.Bugmail has been disabled.' =>
      '$terms.Bugmail has been disabled.',
    '$terms.Bugmail has been enabled.' =>
      '$terms.Bugmail has been enabled.',
    'The account has been added to the' =>
      'The account has been added to the',
    'group' =>
      'group',
    'The account has been removed from the' =>
      'The account has been removed from the',
    'The account has been granted rights to bless the' =>
      'The account has been granted rights to bless the',
    'The account has been denied rights to bless the' =>
      'The account has been denied rights to bless the',
    ' not changed' =>
      ' not changed',
    'You didn\'t request any changes to the user\'s account' =>
      'You didn\'t request any changes to the user\'s account',
    ' deleted' =>
      ' deleted',
    'has been deleted successfully.' =>
      'has been deleted successfully.',
    'is disabled, so you cannot change its password.' =>
      'is disabled, so you cannot change its password.',
    'Access to $terms.bugs in the' =>
      'Access to $terms.bugs in the',
    'product' =>
      'product',
    'Administration of the' =>
      'Administration of the',
    'Adding field to search page...' =>
      'Adding field to search page...',
    'Click here if the page does not redisplay automatically.' =>
      'Click here if the page does not redisplay automatically.',
    'Search updated' =>
      'Search updated',
    'Your search named' =>
      'Your search named',
    'has been updated.' =>
      'has been updated.',
    'OK, you now have a new default search. You may also bookmark the result of any individual search.' =>
      'OK, you now have a new default search. You may also bookmark the result of any individual search.',
    'Search created' =>
      'Search created',
    'OK, you have a new search named' =>
      'OK, you have a new search named',
    'Search is gone' =>
      'Search is gone',
    'Go back to the search page.' =>
      'Go back to the search page.',
    'OK, the <b>' =>
      'OK, the <b>',
    '</b> search is gone.' =>
      '</b> search is gone.',
    '$terms.Bugs on this list are sorted by relevance, with the most relevant $terms.bugs at the top.' =>
      '$terms.Bugs on this list are sorted by relevance, with the most relevant $terms.bugs at the top.',
    'Change columns' =>
      'Change columns',
    'Resubmitting your search with new columns... Click' =>
      'Resubmitting your search with new columns... Click',
    'here' =>
      'here',
    'if the page does not automatically refresh.' =>
      'if the page does not automatically refresh.',
    'New Classification Created' =>
      'New Classification Created',
    'The <em>' =>
      'The <em>',
    '</em> classification has been created.' =>
      '</em> classification has been created.',
    'Classification Deleted' =>
      'Classification Deleted',
    '</em> classification has been deleted.' =>
      '</em> classification has been deleted.',
    'Classification Updated' =>
      'Classification Updated',
    'Changes to the <em>' =>
      'Changes to the <em>',
    '</em> classification have been saved:' =>
      '</em> classification have been saved:',
    'Name updated to \'' =>
      'Name updated to \'',
    'Description updated to \'' =>
      'Description updated to \'',
    'Description removed' =>
      'Description removed',
    'Sortkey updated to \'' =>
      'Sortkey updated to \'',
    'No changes made to <em>' =>
      'No changes made to <em>',
    'Component Created' =>
      'Component Created',
    'The component <em>' =>
      'The component <em>',
    '</em> has been created.' =>
      '</em> has been created.',
    'Component Deleted' =>
      'Component Deleted',
    '</em> has been deleted.' =>
      '</em> has been deleted.',
    'All $terms.bugs being in this component and all references to them have also been deleted.' =>
      'All $terms.bugs being in this component and all references to them have also been deleted.',
    'Component Updated' =>
      'Component Updated',
    'Changes to the component <em>' =>
      'Changes to the component <em>',
    '</em> have been saved.' =>
      '</em> have been saved.',
    'Default assignee updated to \'' =>
      'Default assignee updated to \'',
    'Default QA contact updated to \'' =>
      'Default QA contact updated to \'',
    'Default QA contact deleted' =>
      'Default QA contact deleted',
    'Default CC list updated to' =>
      'Default CC list updated to',
    'Default CC list deleted' =>
      'Default CC list deleted',
    'Wiki URL updated to \'' =>
      'Wiki URL updated to \'',
    'Component is now' =>
      'Component is now',
    'for bug entry.' =>
      'for bug entry.',
    'Cancel Request to Change Email Address' =>
      'Cancel Request to Change Email Address',
    'The request to change the email address for your account to' =>
      'The request to change the email address for your account to',
    'The request to change the email address for the account' =>
      'The request to change the email address for the account',
    'has been canceled. Your old account settings have been reinstated.' =>
      'has been canceled. Your old account settings have been reinstated.',
    'An extension named' =>
      'An extension named',
    'has been created in' =>
      'has been created in',
    '. Make sure you change "YOUR NAME" and "YOUR EMAIL ADDRESS" in the code to your name and your email address.' =>
      '. Make sure you change "YOUR NAME" and "YOUR EMAIL ADDRESS" in the code to your name and your email address.',
    'New Field Value Created' =>
      'New Field Value Created',
    'The value <em>' =>
      'The value <em>',
    '</em> has been added as a valid choice for the <em>' =>
      '</em> has been added as a valid choice for the <em>',
    '</em>) field.' =>
      '</em>) field.',
    'You should now visit the' =>
      'You should now visit the',
    'status workflow page' =>
      'status workflow page',
    'to include your new $terms.bug status.' =>
      'to include your new $terms.bug status.',
    'Field Value Deleted' =>
      'Field Value Deleted',
    '</em> of the <em>' =>
      '</em> of the <em>',
    '</em>) field has been deleted.' =>
      '</em>) field has been deleted.',
    'Field Value Updated' =>
      'Field Value Updated',
    '</em> value of the <em>' =>
      '</em> value of the <em>',
    '</em>) field has been changed:' =>
      '</em>) field has been changed:',
    'Field value updated to <em>' =>
      'Field value updated to <em>',
    '(Note that this value is the default for this field. All references to the default value will now point to this new value.)' =>
      '(Note that this value is the default for this field. All references to the default value will now point to this new value.)',
    'Sortkey updated to <em>' =>
      'Sortkey updated to <em>',
    'It is now' =>
      'It is now',
    'enabled' =>
      'enabled',
    'disabled' =>
      'disabled',
    'for selection.' =>
      'for selection.',
    'It is now an' =>
      'It is now an',
    '"Assigned" (in-progress)' =>
      '"Assigned" (in-progress)',
    'normal' =>
      'normal',
    'state.' =>
      'state.',
    'a confirmed' =>
      'a confirmed',
    'an unconfirmed' =>
      'an unconfirmed',
    'It only appears when' =>
      'It only appears when',
    'is set to' =>
      'is set to',
    ' or ' =>
      ' or ',
    'It now always appears, no matter what' =>
      'It now always appears, no matter what',
    'is set to.' =>
      'is set to.',
    'No changes made to the field value <em>' =>
      'No changes made to the field value <em>',
    'Some flags didn\'t apply in the new product/component and have been cleared.' =>
      'Some flags didn\'t apply in the new product/component and have been cleared.',
    'Flag Creation Failure' =>
      'Flag Creation Failure',
    'An error occured while validating flags:' =>
      'An error occured while validating flags:',
    'New Group Created' =>
      'New Group Created',
    'The group <em>' =>
      'The group <em>',
    'Group Deleted' =>
      'Group Deleted',
    'Group Membership Removed' =>
      'Group Membership Removed',
    'Explicit membership to the <em>' =>
      'Explicit membership to the <em>',
    '</em> group removed' =>
      '</em> group removed',
    'for users matching \'' =>
      'for users matching \'',
    'No users are being affected by your action.' =>
      'No users are being affected by your action.',
    'The following changes have been made to the \'' =>
      'The following changes have been made to the \'',
    '\' group:' =>
      '\' group:',
    'The name was changed to \'' =>
      'The name was changed to \'',
    'The description was updated.' =>
      'The description was updated.',
    'The regular expression was updated.' =>
      'The regular expression was updated.',
    'The group will now be used for $terms.bugs.' =>
      'The group will now be used for $terms.bugs.',
    'The group will no longer be used for $terms.bugs.' =>
      'The group will no longer be used for $terms.bugs.',
    'The group icon URL has been updated.' =>
      'The group icon URL has been updated.',
    'The following groups are now members of this group:' =>
      'The following groups are now members of this group:',
    'The following groups are no longer members of this group:' =>
      'The following groups are no longer members of this group:',
    'This group is now a member of the following groups:' =>
      'This group is now a member of the following groups:',
    'This group is no longer a member of the following groups:' =>
      'This group is no longer a member of the following groups:',
    'The following groups may now add users to this group:' =>
      'The following groups may now add users to this group:',
    'The following groups may no longer add users to this group:' =>
      'The following groups may no longer add users to this group:',
    'This group may now add users to the following groups:' =>
      'This group may now add users to the following groups:',
    'This group may no longer add users to the following groups:' =>
      'This group may no longer add users to the following groups:',
    'The following groups can now see users in this group:' =>
      'The following groups can now see users in this group:',
    'The following groups may no longer see users in this group:' =>
      'The following groups may no longer see users in this group:',
    'This group may now see users in the following groups:' =>
      'This group may now see users in the following groups:',
    'This group may no longer see users in the following groups:' =>
      'This group may no longer see users in the following groups:',
    'You didn\'t request any change for the \'' =>
      'You didn\'t request any change for the \'',
    '\' group.' =>
      '\' group.',
    'The custom sort order specified contains one or more invalid column names: <em>' =>
      'The custom sort order specified contains one or more invalid column names: <em>',
    '</em>. They have been removed from the sort list.' =>
      '</em>. They have been removed from the sort list.',
    'jobs in the queue.' =>
      'jobs in the queue.',
    'New Keyword Created' =>
      'New Keyword Created',
    'The keyword <em>' =>
      'The keyword <em>',
    'Keyword Deleted' =>
      'Keyword Deleted',
    '</em> keyword has been deleted.' =>
      '</em> keyword has been deleted.',
    'Keyword Updated' =>
      'Keyword Updated',
    '</em> keyword have been saved:' =>
      '</em> keyword have been saved:',
    'Keyword renamed to <em>' =>
      'Keyword renamed to <em>',
    'Description updated to <em>' =>
      'Description updated to <em>',
    'Logged Out' =>
      'Logged Out',
    'Log in again.' =>
      'Log in again.',
    '<b>Your login has been forgotten</b>. The cookie that was remembering your login is now gone. You will be prompted for a login the next time it is required.' =>
      '<b>Your login has been forgotten</b>. The cookie that was remembering your login is now gone. You will be prompted for a login the next time it is required.',
    '$terms.Bugzilla Login Changed' =>
      '$terms.Bugzilla Login Changed',
    'Your $terms.Bugzilla login has been changed.' =>
      'Your $terms.Bugzilla login has been changed.',
    'Component created:' =>
      'Component created:',
    '(in' =>
      '(in',
    'Creating $terms.bugs...' =>
      'Creating $terms.bugs...',
    'New custom field:' =>
      'New custom field:',
    'Product created:' =>
      'Product created:',
    'Reading $terms.bugs...' =>
      'Reading $terms.bugs...',
    'Reading products...' =>
      'Reading products...',
    'Reading users...' =>
      'Reading users...',
    'Converting $terms.bug values to be appropriate for $terms.Bugzilla...' =>
      'Converting $terms.bug values to be appropriate for $terms.Bugzilla...',
    'User created:' =>
      'User created:',
    'Password:' =>
      'Password:',
    'value created:' =>
      'value created:',
    'Milestone Created' =>
      'Milestone Created',
    'The milestone <em>' =>
      'The milestone <em>',
    'Milestone Deleted' =>
      'Milestone Deleted',
    'Milestone Updated' =>
      'Milestone Updated',
    'Changes to the milestone <em>' =>
      'Changes to the milestone <em>',
    'Milestone name updated to <em>' =>
      'Milestone name updated to <em>',
    'Milestone' =>
      'Milestone',
    'for $terms.bugs' =>
      'for $terms.bugs',
    'No changes made to milestone <em>' =>
      'No changes made to milestone <em>',
    'Parameters Updated' =>
      'Parameters Updated',
    'Changed <em>' =>
      'Changed <em>',
    '<strong>You must now re-run checksetup.pl.</strong>' =>
      '<strong>You must now re-run checksetup.pl.</strong>',
    '$terms.Bugzilla has now been shut down. To re-enable the system, clear the <em>shutdownhtml</em> field.' =>
      '$terms.Bugzilla has now been shut down. To re-enable the system, clear the <em>shutdownhtml</em> field.',
    'Cancel Request to Change Password' =>
      'Cancel Request to Change Password',
    'Your request has been canceled.' =>
      'Your request has been canceled.',
    'Request to Change Password' =>
      'Request to Change Password',
    'A token for changing your password has been emailed to you. Follow the instructions in that email to change your password.' =>
      'A token for changing your password has been emailed to you. Follow the instructions in that email to change your password.',
    'Password Changed' =>
      'Password Changed',
    'Your password has been changed.' =>
      'Your password has been changed.',
    'Flag Type \'' =>
      'Flag Type \'',
    '\' Created' =>
      '\' Created',
    'The flag type <em>' =>
      'The flag type <em>',
    '\' Changes Saved' =>
      '\' Changes Saved',
    'Your changes to the flag type <em>' =>
      'Your changes to the flag type <em>',
    '\' Deleted' =>
      '\' Deleted',
    '\' Deactivated' =>
      '\' Deactivated',
    '</em> has been deactivated.' =>
      '</em> has been deactivated.',
    'Enter the e-mail address of the administrator:' =>
      'Enter the e-mail address of the administrator:',
    'Enter the real name of the administrator:' =>
      'Enter the real name of the administrator:',
    'Enter a password for the administrator account:' =>
      'Enter a password for the administrator account:',
    'is now set up as an administrator.' =>
      'is now set up as an administrator.',
    'Looks like we don\'t have an administrator set up yet. Either this is your first time using $terms.Bugzilla, or your administrator\'s privileges might have accidentally been deleted.' =>
      'Looks like we don\'t have an administrator set up yet. Either this is your first time using $terms.Bugzilla, or your administrator\'s privileges might have accidentally been deleted.',
    'Adding new column \'' =>
      'Adding new column \'',
    '\' to the \'' =>
      '\' to the \'',
    '\' table...' =>
      '\' table...',
    'Deleting the \'' =>
      'Deleting the \'',
    '\' column from the \'' =>
      '\' column from the \'',
    'Renaming column \'' =>
      'Renaming column \'',
    '\' to \'' =>
      '\' to \'',
    'Please retype the password to verify:' =>
      'Please retype the password to verify:',
    'Creating default classification \'' =>
      'Creating default classification \'',
    'Creating initial dummy product \'' =>
      'Creating initial dummy product \'',
    'Fixing file permissions...' =>
      'Fixing file permissions...',
    'Adding foreign key:' =>
      'Adding foreign key:',
    'Dropping foreign key:' =>
      'Dropping foreign key:',
    'ERROR: There are invalid values for the' =>
      'ERROR: There are invalid values for the',
    'column in the' =>
      'column in the',
    'table. (These values do not exist in the' =>
      'table. (These values do not exist in the',
    'table, in the' =>
      'table, in the',
    'column.) Before continuing with checksetup, you will need to fix these values, either by deleting these rows from the database, or changing the values of' =>
      'column.) Before continuing with checksetup, you will need to fix these values, either by deleting these rows from the database, or changing the values of',
    'in' =>
      'in',
    'to point to valid values in' =>
      'to point to valid values in',
    '. The bad values from the' =>
      '. The bad values from the',
    'column are:' =>
      'column are:',
    'WARNING: There were invalid values in' =>
      'WARNING: There were invalid values in',
    'that have been' =>
      'that have been',
    'deleted' =>
      'deleted',
    'set to NULL' =>
      'set to NULL',
    'Creating group' =>
      'Creating group',
    'Adding a new user setting called \'' =>
      'Adding a new user setting called \'',
    'Dropping the \'' =>
      'Dropping the \'',
    'Renaming the \'' =>
      'Renaming the \'',
    '\' table to \'' =>
      '\' table to \'',
    'Now that you have installed $terms.Bugzilla, you should visit the \'Parameters\' page (linked in the footer of the Administrator account) to ensure it is set up as you wish - this includes setting the \'urlbase\' option to the correct URL.' =>
      'Now that you have installed $terms.Bugzilla, you should visit the \'Parameters\' page (linked in the footer of the Administrator account) to ensure it is set up as you wish - this includes setting the \'urlbase\' option to the correct URL.',
    'Enter a new password for' =>
      'Enter a new password for',
    'New password set.' =>
      'New password set.',
    '**************************************************************************** WARNING! You have not entered a value for the "webservergroup" parameter in localconfig. This means that certain files and directories which need to be editable by both you and the web server must be world writable, and other files (including the localconfig file which stores your database password) must be world readable. This means that _anyone_ who can obtain local access to this machine can do whatever they want to your $terms.Bugzilla installation, and is probably also able to run arbitrary Perl code as the user that the web server runs as. You really, really, really need to change this setting. ****************************************************************************' =>
      '**************************************************************************** WARNING! You have not entered a value for the "webservergroup" parameter in localconfig. This means that certain files and directories which need to be editable by both you and the web server must be world writable, and other files (including the localconfig file which stores your database password) must be world readable. This means that _anyone_ who can obtain local access to this machine can do whatever they want to your $terms.Bugzilla installation, and is probably also able to run arbitrary Perl code as the user that the web server runs as. You really, really, really need to change this setting. ****************************************************************************',
    'Warning: you have entered a value for the "webservergroup" parameter in localconfig, but you are not either a) running this script as' =>
      'Warning: you have entered a value for the "webservergroup" parameter in localconfig, but you are not either a) running this script as',
    '; or b) a member of this group. This can cause permissions problems and decreased security. If you experience problems running $terms.Bugzilla scripts, log in as' =>
      '; or b) a member of this group. This can cause permissions problems and decreased security. If you experience problems running $terms.Bugzilla scripts, log in as',
    'and re-run this script, become a member of the group, or remove the value of the "webservergroup" parameter.' =>
      'and re-run this script, become a member of the group, or remove the value of the "webservergroup" parameter.',
    'Warning: You have set webservergroup in' =>
      'Warning: You have set webservergroup in',
    'Please understand that this does not bring you any security when running under Windows. Verify that the file permissions in your $terms.Bugzilla directory are suitable for your system. Avoid unnecessary write access.' =>
      'Please understand that this does not bring you any security when running under Windows. Verify that the file permissions in your $terms.Bugzilla directory are suitable for your system. Avoid unnecessary write access.',
    'Product Created' =>
      'Product Created',
    'The product <em>' =>
      'The product <em>',
    '</em> has been created. You will need to' =>
      '</em> has been created. You will need to',
    'add at least one component' =>
      'add at least one component',
    'before anyone can enter $terms.bugs against this product.' =>
      'before anyone can enter $terms.bugs against this product.',
    'Product Deleted' =>
      'Product Deleted',
    '</em> and all its versions, components, milestones and group controls have been deleted.' =>
      '</em> and all its versions, components, milestones and group controls have been deleted.',
    'All $terms.bugs being in this product and all references to them have also been deleted.' =>
      'All $terms.bugs being in this product and all references to them have also been deleted.',
    '$terms.Bugzilla Component Descriptions' =>
      '$terms.Bugzilla Component Descriptions',
    '</em> does not exist or you don\'t have access to it. The following is a list of the products you can choose from.' =>
      '</em> does not exist or you don\'t have access to it. The following is a list of the products you can choose from.',
    'OK, you have a new saved report named <em>' =>
      'OK, you have a new saved report named <em>',
    'OK, the <em>' =>
      'OK, the <em>',
    '</em> report is gone.' =>
      '</em> report is gone.',
    'The saved report <em>' =>
      'The saved report <em>',
    '</em> has been updated.' =>
      '</em> has been updated.',
    'All Open' =>
      'All Open',
    'All Closed' =>
      'All Closed',
    '-All-' =>
      '-All-',
    'Sudo session started' =>
      'Sudo session started',
    'The sudo session has been started. For the next 6 hours, or until you end the session, everything you do you do as the user you are impersonating (' =>
      'The sudo session has been started. For the next 6 hours, or until you end the session, everything you do you do as the user you are impersonating (',
    'Sudo session complete' =>
      'Sudo session complete',
    'The sudo session has been ended. From this point forward, everything you do you do as yourself.' =>
      'The sudo session has been ended. From this point forward, everything you do you do as yourself.',
    'Series Created' =>
      'Series Created',
    'The series <em>' =>
      'The series <em>',
    '</em> has been created. Note that you may need to wait up to' =>
      '</em> has been created. Note that you may need to wait up to',
    'days before there will be enough data for a chart of this series to be produced.' =>
      'days before there will be enough data for a chart of this series to be produced.',
    'Series Deleted' =>
      'Series Deleted',
    '$terms.Bugzilla is Down' =>
      '$terms.Bugzilla is Down',
    'For security reasons, you have been logged out automatically. The cookie that was remembering your login is now gone.' =>
      'For security reasons, you have been logged out automatically. The cookie that was remembering your login is now gone.',
    'Some flags could not be set. Please check your changes.' =>
      'Some flags could not be set. Please check your changes.',
    'You entered a username that did not match any known $terms.Bugzilla users, so we have instead left the' =>
      'You entered a username that did not match any known $terms.Bugzilla users, so we have instead left the',
    'field blank.' =>
      'field blank.',
    'You entered a username that matched more than one user, so we have instead left the' =>
      'You entered a username that matched more than one user, so we have instead left the',
    'Version Created' =>
      'Version Created',
    'The version <em>' =>
      'The version <em>',
    '</em> of product <em>' =>
      '</em> of product <em>',
    'Version Deleted' =>
      'Version Deleted',
    'Version Updated' =>
      'Version Updated',
    'Changes to the version <em>' =>
      'Changes to the version <em>',
    'Version renamed to <em>' =>
      'Version renamed to <em>',
    'Version' =>
      'Version',
    'No changes made to version <em>' =>
      'No changes made to version <em>',
    'The workflow has been updated.' =>
      'The workflow has been updated.',
    'Message \'' =>
      'Message \'',
    '\' is unknown.' =>
      '\' is unknown.',
    'If you are a $terms.Bugzilla end-user seeing this message, please save this page and send it to' =>
      'If you are a $terms.Bugzilla end-user seeing this message, please save this page and send it to',
  },
  'global/site-navigation.html.tmpl' => {
    'Dependency Tree' =>
      'Dependency Tree',
    'Dependency Graph' =>
      'Dependency Graph',
    'Votes (' =>
      'Votes (',
    '$terms.Bug Activity' =>
      '$terms.Bug Activity',
    'Printer-Friendly Version' =>
      'Printer-Friendly Version',
    'My $terms.Bugs' =>
      'My $terms.Bugs',
  },
  'global/useful-links.html.tmpl' => {
    'Saved Searches:' =>
      'Saved Searches:',
    'My $terms.Bugs' =>
      'My $terms.Bugs',
    'TodayWorktime' =>
      'TodayWorktime',
    'Shared by ' =>
      'Shared by ',
    'Saved Reports:' =>
      'Saved Reports:',
  },
  'global/user-error-page.html.tmpl' => {
    'Please press <b>' =>
      'Please press <b>',
    'Back' =>
      'Back',
    '</b> and try again.' =>
      '</b> and try again.',
    'Alternatively, you can' =>
      'Alternatively, you can',
    'forget' =>
      'forget',
    'or' =>
      'or',
    'edit' =>
      'edit',
    'the saved search \'' =>
      'the saved search \'',
  },
  'global/user-error.html.tmpl' => {
    'Error' =>
      'Error',
    'Error string not found' =>
      'Error string not found',
    'The user error string' =>
      'The user error string',
    'was not found. Please send email to' =>
      'was not found. Please send email to',
    'describing the steps taken to obtain this message.' =>
      'describing the steps taken to obtain this message.',
    'Account Creation Disabled' =>
      'Account Creation Disabled',
    'User account creation has been disabled.' =>
      'User account creation has been disabled.',
    'New accounts must be created by an administrator. The maintainer is' =>
      'New accounts must be created by an administrator. The maintainer is',
    'Account Creation Restricted' =>
      'Account Creation Restricted',
    'User account creation has been restricted.' =>
      'User account creation has been restricted.',
    'Contact your administrator or the maintainer (' =>
      'Contact your administrator or the maintainer (',
    ') for information about creating an account.' =>
      ') for information about creating an account.',
    'Account Disabled' =>
      'Account Disabled',
    'Your account is disabled' =>
      'Your account is disabled',
    'If you believe your account should be restored, please send email to' =>
      'If you believe your account should be restored, please send email to',
    'explaining why.' =>
      'explaining why.',
    'Account Already Exists' =>
      'Account Already Exists',
    'There is already an account with' =>
      'There is already an account with',
    'the login name' =>
      'the login name',
    'that login name.' =>
      'that login name.',
    'Account Locked' =>
      'Account Locked',
    'Your IP (' =>
      'Your IP (',
    ') has been locked out of this account until' =>
      ') has been locked out of this account until',
    ', as you have exceeded the maximum number of login attempts.' =>
      ', as you have exceeded the maximum number of login attempts.',
    'Invalid Characters In Alias' =>
      'Invalid Characters In Alias',
    'The alias you entered, <em>' =>
      'The alias you entered, <em>',
    '</em>, contains one or more commas or spaces. Aliases cannot contain commas or spaces because those characters are used to separate aliases from each other in lists. Please choose an alias that does not contain commas and spaces.' =>
      '</em>, contains one or more commas or spaces. Aliases cannot contain commas or spaces because those characters are used to separate aliases from each other in lists. Please choose an alias that does not contain commas and spaces.',
    'Alias In Use' =>
      'Alias In Use',
    'has already taken the alias <em>' =>
      'has already taken the alias <em>',
    '</em>. Please choose another one.' =>
      '</em>. Please choose another one.',
    'Alias Is Numeric' =>
      'Alias Is Numeric',
    'You tried to give this $terms.bug the alias <em>' =>
      'You tried to give this $terms.bug the alias <em>',
    '</em>, but aliases cannot be merely numbers, since they could then be confused with $terms.bug IDs. Please choose an alias containing at least one letter.' =>
      '</em>, but aliases cannot be merely numbers, since they could then be confused with $terms.bug IDs. Please choose an alias containing at least one letter.',
    'Alias Too Long' =>
      'Alias Too Long',
    '$terms.Bug aliases cannot be longer than 255 characters. Please choose a shorter alias.' =>
      '$terms.Bug aliases cannot be longer than 255 characters. Please choose a shorter alias.',
    'Can\'t create accounts' =>
      'Can\'t create accounts',
    'This site is using an authentication scheme which does not permit account creation. Please contact an administrator to get a new account created.' =>
      'This site is using an authentication scheme which does not permit account creation. Please contact an administrator to get a new account created.',
    'Authorization Required' =>
      'Authorization Required',
    'Group Security' =>
      'Group Security',
    'Sorry,' =>
      'Sorry,',
    'you aren\'t a member of the \'' =>
      'you aren\'t a member of the \'',
    '\' group,' =>
      '\' group,',
    'and' =>
      'and',
    'you don\'t have permissions to add or remove people from a group,' =>
      'you don\'t have permissions to add or remove people from a group,',
    'there are visibility restrictions on certain user groups,' =>
      'there are visibility restrictions on certain user groups,',
    'and so' =>
      'and so',
    'you are not authorized to' =>
      'you are not authorized to',
    'add new' =>
      'add new',
    'add, modify or delete' =>
      'add, modify or delete',
    'administrative pages' =>
      'administrative pages',
    'attachment #' =>
      'attachment #',
    'this attachment' =>
      'this attachment',
    'the "New Charts" feature' =>
      'the "New Charts" feature',
    'classifications' =>
      'classifications',
    'components' =>
      'components',
    'custom fields' =>
      'custom fields',
    'field values' =>
      'field values',
    'flag types' =>
      'flag types',
    'group access' =>
      'group access',
    'groups' =>
      'groups',
    'keywords' =>
      'keywords',
    'milestones' =>
      'milestones',
    'multiple $terms.bugs at once' =>
      'multiple $terms.bugs at once',
    'parameters' =>
      'parameters',
    'products' =>
      'products',
    'quips' =>
      'quips',
    'whine reports' =>
      'whine reports',
    'a sanity check' =>
      'a sanity check',
    'settings' =>
      'settings',
    'a sudo session' =>
      'a sudo session',
    'time-tracking summary reports' =>
      'time-tracking summary reports',
    'the user' =>
      'the user',
    'with ID \'' =>
      'with ID \'',
    'you specified' =>
      'you specified',
    'users' =>
      'users',
    'versions' =>
      'versions',
    'the workflow' =>
      'the workflow',
    'Attachment Deletion Disabled' =>
      'Attachment Deletion Disabled',
    'Attachment deletion is disabled on this installation.' =>
      'Attachment deletion is disabled on this installation.',
    'Illegal Attachment URL' =>
      'Illegal Attachment URL',
    '</em> is not a legal URL for attachments. It must start either with http://, https:// or ftp://.' =>
      '</em> is not a legal URL for attachments. It must start either with http://, https:// or ftp://.',
    'Attachment Removed' =>
      'Attachment Removed',
    'The attachment you are attempting to access has been removed.' =>
      'The attachment you are attempting to access has been removed.',
    'Access Denied' =>
      'Access Denied',
    'You are not authorized to access $terms.bug #' =>
      'You are not authorized to access $terms.bug #',
    'in the' =>
      'in the',
    'product' =>
      'product',
    'Creating an account' =>
      'Creating an account',
    '. To see this $terms.bug, you must first' =>
      '. To see this $terms.bug, you must first',
    'log in to an account' =>
      'log in to an account',
    'with the appropriate permissions.' =>
      'with the appropriate permissions.',
    'Invalid $terms.Bug URL' =>
      'Invalid $terms.Bug URL',
    'is not a valid URL to $terms.abug.' =>
      'is not a valid URL to $terms.abug.',
    'URLs must start with "http" or "https".' =>
      'URLs must start with "http" or "https".',
    'You must specify a full URL.' =>
      'You must specify a full URL.',
    'URLs should point to one of:' =>
      'URLs should point to one of:',
    'in a $terms.Bugzilla installation.' =>
      'in a $terms.Bugzilla installation.',
    'There is no valid $terms.bug id in that URL.' =>
      'There is no valid $terms.bug id in that URL.',
    '$terms.Bug URLs can not be longer than' =>
      '$terms.Bug URLs can not be longer than',
    'characters long.' =>
      'characters long.',
    'is too long.' =>
      'is too long.',
    'Parameters Required' =>
      'Parameters Required',
    'Searching for $terms.bugs' =>
      'Searching for $terms.bugs',
    '$terms.Bug lists' =>
      '$terms.Bug lists',
    'You may not search, or create saved searches, without any search terms.' =>
      'You may not search, or create saved searches, without any search terms.',
    'Can\'t delete special status' =>
      'Can\'t delete special status',
    'This status is used as \'duplicate_or_move_bug_status\' parameter and cannot be deleted.' =>
      'This status is used as \'duplicate_or_move_bug_status\' parameter and cannot be deleted.',
    'CC Group Restriction' =>
      'CC Group Restriction',
    'User' =>
      'User',
    'is restricted to watch this bug.' =>
      'is restricted to watch this bug.',
    'Chart Too Large' =>
      'Chart Too Large',
    'Sorry, but 2000 x 2000 is the maximum size for a chart.' =>
      'Sorry, but 2000 x 2000 is the maximum size for a chart.',
    'is not a valid comment id.' =>
      'is not a valid comment id.',
    'You tried to modify the privacy of comment id' =>
      'You tried to modify the privacy of comment id',
    ', but that is not a valid comment on this $terms.bug.' =>
      ', but that is not a valid comment on this $terms.bug.',
    'You can only edit the description of a $terms.bug or your own comments to it.' =>
      'You can only edit the description of a $terms.bug or your own comments to it.',
    'You tried to modify the type of comment id' =>
      'You tried to modify the type of comment id',
    ', but that is either not a valid comment on this $terms.bug, or it\'s not yours, or it has special type.' =>
      ', but that is either not a valid comment on this $terms.bug, or it\'s not yours, or it has special type.',
    'Comment id' =>
      'Comment id',
    'is private.' =>
      'is private.',
    'Comment Required' =>
      'Comment Required',
    'You have to specify a' =>
      'You have to specify a',
    '<b>comment</b> when changing the status of $terms.abug from' =>
      '<b>comment</b> when changing the status of $terms.abug from',
    'to' =>
      'to',
    'description for this $terms.bug.' =>
      'description for this $terms.bug.',
    '<b>comment</b> on this change.' =>
      '<b>comment</b> on this change.',
    'Comment Too Long' =>
      'Comment Too Long',
    'Comments cannot be longer than' =>
      'Comments cannot be longer than',
    'characters.' =>
      'characters.',
    'Classification Not Enabled' =>
      'Classification Not Enabled',
    'Sorry, classification is not enabled.' =>
      'Sorry, classification is not enabled.',
    'Classification Name Too Long' =>
      'Classification Name Too Long',
    'The name of a classification is limited to' =>
      'The name of a classification is limited to',
    'characters. \'' =>
      'characters. \'',
    '\' is too long (' =>
      '\' is too long (',
    'characters).' =>
      'characters).',
    'You Must Supply A Classification Name' =>
      'You Must Supply A Classification Name',
    'You must enter a classification name.' =>
      'You must enter a classification name.',
    'Classification Already Exists' =>
      'Classification Already Exists',
    'A classification with the name \'' =>
      'A classification with the name \'',
    '\' already exists.' =>
      '\' already exists.',
    'Invalid Sortkey for Classification' =>
      'Invalid Sortkey for Classification',
    'The sortkey \'' =>
      'The sortkey \'',
    '\' is invalid. It must be an integer between 0 and' =>
      '\' is invalid. It must be an integer between 0 and',
    'Default Classification Can Not Be Deleted' =>
      'Default Classification Can Not Be Deleted',
    'You can not delete the default classification' =>
      'You can not delete the default classification',
    'Sorry, there are products for this classification. You must reassign those products to another classification before you can delete this one.' =>
      'Sorry, there are products for this classification. You must reassign those products to another classification before you can delete this one.',
    'Component Already Exists' =>
      'Component Already Exists',
    'The <em>' =>
      'The <em>',
    '</em> product already has a component named <em>' =>
      '</em> product already has a component named <em>',
    'Blank Component Description Not Allowed' =>
      'Blank Component Description Not Allowed',
    'You must enter a non-blank description for this component.' =>
      'You must enter a non-blank description for this component.',
    'Blank Component Name Not Allowed' =>
      'Blank Component Name Not Allowed',
    'You must enter a name for this new component.' =>
      'You must enter a name for this new component.',
    'Component has $terms.Bugs' =>
      'Component has $terms.Bugs',
    'There are' =>
      'There are',
    '$terms.bugs entered for this component! You must reassign those $terms.bugs to another component before you can delete this one.' =>
      '$terms.bugs entered for this component! You must reassign those $terms.bugs to another component before you can delete this one.',
    'Component Name Is Too Long' =>
      'Component Name Is Too Long',
    'The name of a component is limited to' =>
      'The name of a component is limited to',
    'Component Requires Default Assignee' =>
      'Component Requires Default Assignee',
    'A default assignee is required for this component.' =>
      'A default assignee is required for this component.',
    'Unknown Custom Field' =>
      'Unknown Custom Field',
    'There is no custom field with the name \'' =>
      'There is no custom field with the name \'',
    'Custom Field Not Disabled' =>
      'Custom Field Not Disabled',
    'The custom field \'' =>
      'The custom field \'',
    '\' is not disabled. Please disable a custom field before attempting to delete it.' =>
      '\' is not disabled. Please disable a custom field before attempting to delete it.',
    'Custom Field Has Contents' =>
      'Custom Field Has Contents',
    '\' cannot be deleted because at least one $terms.bug has a non empty value for this field.' =>
      '\' cannot be deleted because at least one $terms.bug has a non empty value for this field.',
    'Dependency Loop Detected' =>
      'Dependency Loop Detected',
    'The following $terms.bug(s) would appear on both the "depends on" and "blocks" parts of the dependency tree if these changes are committed:' =>
      'The following $terms.bug(s) would appear on both the "depends on" and "blocks" parts of the dependency tree if these changes are committed:',
    '. This would create a circular dependency, which is not allowed.' =>
      '. This would create a circular dependency, which is not allowed.',
    'You can\'t make $terms.abug block itself or depend on itself.' =>
      'You can\'t make $terms.abug block itself or depend on itself.',
    'Duplicate $terms.Bug Id Required' =>
      'Duplicate $terms.Bug Id Required',
    'You must specify $terms.abug id to mark this $terms.bug as a duplicate of.' =>
      'You must specify $terms.abug id to mark this $terms.bug as a duplicate of.',
    'Cannot mark $terms.bugs as duplicates' =>
      'Cannot mark $terms.bugs as duplicates',
    'You cannot mark $terms.bugs as duplicates when changing several $terms.bugs at once.' =>
      'You cannot mark $terms.bugs as duplicates when changing several $terms.bugs at once.',
    'Loop detected among duplicates' =>
      'Loop detected among duplicates',
    'You cannot mark $terms.bug' =>
      'You cannot mark $terms.bug',
    'as a duplicate of' =>
      'as a duplicate of',
    'itself' =>
      'itself',
    ', because it would create a duplicate loop' =>
      ', because it would create a duplicate loop',
    'Email Change Already In Progress' =>
      'Email Change Already In Progress',
    'Email change already in progress; please check your email.' =>
      'Email change already in progress; please check your email.',
    'Email Address Confirmation Failed' =>
      'Email Address Confirmation Failed',
    'Email address confirmation failed.' =>
      'Email address confirmation failed.',
    'Your message did not contain any text.$terms.Bugzilla does not accept HTML-only email, or HTML email with attachments.' =>
      'Your message did not contain any text.$terms.Bugzilla does not accept HTML-only email, or HTML email with attachments.',
    'The group description can not be empty' =>
      'The group description can not be empty',
    'You must enter a description for the group.' =>
      'You must enter a description for the group.',
    'The group name can not be empty' =>
      'The group name can not be empty',
    'You must enter a name for the group.' =>
      'You must enter a name for the group.',
    'Permission Denied' =>
      'Permission Denied',
    'Sorry, either the product <em>' =>
      'Sorry, either the product <em>',
    '</em> does not exist or you aren\'t authorized to enter $terms.abug into it.' =>
      '</em> does not exist or you aren\'t authorized to enter $terms.abug into it.',
    'You must specify a name for your extension, as an argument to this script.' =>
      'You must specify a name for your extension, as an argument to this script.',
    'The first letter of your extension\'s name must be a capital letter. (You specified \'' =>
      'The first letter of your extension\'s name must be a capital letter. (You specified \'',
    'The following missing fields:' =>
      'The following missing fields:',
    'are required to enter new bugs.' =>
      'are required to enter new bugs.',
    'Can\'t use' =>
      'Can\'t use',
    'as a field name.' =>
      'as a field name.',
    'The query text you specified cannot be handled by Bugzilla full-text search engine.' =>
      'The query text you specified cannot be handled by Bugzilla full-text search engine.',
    'Subquery search operator ("In Search Results") can only be applied to fields of type "Bug ID". "' =>
      'Subquery search operator ("In Search Results") can only be applied to fields of type "Bug ID". "',
    '" is not a Bug ID field.' =>
      '" is not a Bug ID field.',
    'Can\'t create field of a useless type' =>
      'Can\'t create field of a useless type',
    'It is impossible to create "' =>
      'It is impossible to create "',
    '" fields, because functionality of this type is hard-coded to a single builtin field.' =>
      '" fields, because functionality of this type is hard-coded to a single builtin field.',
    'Field Already Exists' =>
      'Field Already Exists',
    'The field \'' =>
      'The field \'',
    ') already exists. Please choose another name.' =>
      ') already exists. Please choose another name.',
    'Field Can\'t Control Itself' =>
      'Field Can\'t Control Itself',
    'The' =>
      'The',
    'field can\'t be set to control itself.' =>
      'field can\'t be set to control itself.',
    'Invalid Field Type Selected' =>
      'Invalid Field Type Selected',
    'Only drop-down and multi-select fields can be used to control the visibility/values of other fields.' =>
      'Only drop-down and multi-select fields can be used to control the visibility/values of other fields.',
    'is not the right type of field.' =>
      'is not the right type of field.',
    'Only Custom Fields May Be Deleted' =>
      'Only Custom Fields May Be Deleted',
    'Field' =>
      'Field',
    'is non-custom and therefore may not be deleted.' =>
      'is non-custom and therefore may not be deleted.',
    'Invalid Direct Field selected' =>
      'Invalid Direct Field selected',
    'Each field of type "' =>
      'Each field of type "',
    '" must correspond to one, and only one field of type "' =>
      '" must correspond to one, and only one field of type "',
    '" and represent its "reverse relation". For example, it may be "Internal Bugs" for the corresponding "External Bug" field.' =>
      '" and represent its "reverse relation". For example, it may be "Internal Bugs" for the corresponding "External Bug" field.',
    'Duplicate Reverse Field' =>
      'Duplicate Reverse Field',
    'It is prohibited to create more than one field of type "' =>
      'It is prohibited to create more than one field of type "',
    '" corresponding to a single "' =>
      '" corresponding to a single "',
    '" type field.' =>
      '" type field.',
    'Cannot seem to handle' =>
      'Cannot seem to handle',
    'together.' =>
      'together.',
    'There is no' =>
      'There is no',
    'named \'' =>
      'named \'',
    '\' in product' =>
      '\' in product',
    '\' is invalid.' =>
      '\' is invalid.',
    'A legal' =>
      'A legal',
    'was not set.' =>
      'was not set.',
    'can not be searched for changes.' =>
      'can not be searched for changes.',
    'Invalid Field Name' =>
      'Invalid Field Name',
    '\' is not a valid name for a field. A name may contain only letters, numbers, and the underscore character.' =>
      '\' is not a valid name for a field. A name may contain only letters, numbers, and the underscore character.',
    'Invalid Sortkey for Field' =>
      'Invalid Sortkey for Field',
    'The sortkey' =>
      'The sortkey',
    'that you have provided for this field is not a valid positive integer.' =>
      'that you have provided for this field is not a valid positive integer.',
    'Missing Description for Field' =>
      'Missing Description for Field',
    'You must enter a description for this field.' =>
      'You must enter a description for this field.',
    'Missing Name for Field' =>
      'Missing Name for Field',
    'You must enter a name for this field.' =>
      'You must enter a name for this field.',
    'Missing ' =>
      'Missing ',
    'You must enter a non-empty' =>
      'You must enter a non-empty',
    'for this $terms.bug.' =>
      'for this $terms.bug.',
    'Invalid Value Control Field' =>
      'Invalid Value Control Field',
    'Only Drop-Down or Multi-Select fields can have a field that controls their values.' =>
      'Only Drop-Down or Multi-Select fields can have a field that controls their values.',
    'Specified Field Does Not Exist' =>
      'Specified Field Does Not Exist',
    '\' does not exist or cannot be edited with this interface.' =>
      '\' does not exist or cannot be edited with this interface.',
    'Field Value Already Exists' =>
      'Field Value Already Exists',
    'The value \'' =>
      'The value \'',
    '\' already exists for the' =>
      '\' already exists for the',
    'field.' =>
      'field.',
    'Value Controls Other Fields' =>
      'Value Controls Other Fields',
    'You cannot delete the' =>
      'You cannot delete the',
    '\' because' =>
      '\' because',
    'it controls the visibility of the following fields:' =>
      'it controls the visibility of the following fields:',
    ' and ' =>
      ' and ',
    'it controls the visibility of the following field values:' =>
      'it controls the visibility of the following field values:',
    'Specified Field Value Is Default' =>
      'Specified Field Value Is Default',
    '\' is the default value for the \'' =>
      '\' is the default value for the \'',
    '\' field and cannot be deleted. You have to first change the default value for this field.' =>
      '\' field and cannot be deleted. You have to first change the default value for this field.',
    'Field Value Is Too Long' =>
      'Field Value Is Too Long',
    'The value of a field is limited to' =>
      'The value of a field is limited to',
    'Invalid Field Value Sortkey' =>
      'Invalid Field Value Sortkey',
    '\' for the' =>
      '\' for the',
    'field is not a valid (positive) number.' =>
      'field is not a valid (positive) number.',
    'You Cannot Delete This Field Value' =>
      'You Cannot Delete This Field Value',
    'You cannot delete the value \'' =>
      'You cannot delete the value \'',
    '\' from the' =>
      '\' from the',
    'field, because there are still' =>
      'field, because there are still',
    '$terms.bugs using it.' =>
      '$terms.bugs using it.',
    'Undefined Value Not Allowed' =>
      'Undefined Value Not Allowed',
    'You must specify a value.' =>
      'You must specify a value.',
    'No File Specified' =>
      'No File Specified',
    'You did not specify a file to attach.' =>
      'You did not specify a file to attach.',
    'File Too Large' =>
      'File Too Large',
    'The file you are trying to attach is' =>
      'The file you are trying to attach is',
    'kilobytes (KB) in size. Attachments cannot be more than' =>
      'kilobytes (KB) in size. Attachments cannot be more than',
    'KB.' =>
      'KB.',
    'We recommend that you store your attachment elsewhere and then insert the URL to it in a comment, or in the URL field for this $terms.bug.' =>
      'We recommend that you store your attachment elsewhere and then insert the URL to it in a comment, or in the URL field for this $terms.bug.',
    'Alternately, if your attachment is an image, you could convert it to a compressible format like JPG or PNG and try again.' =>
      'Alternately, if your attachment is an image, you could convert it to a compressible format like JPG or PNG and try again.',
    'Flag Requestee Needs Privileges' =>
      'Flag Requestee Needs Privileges',
    'does not have permission to set the <em>' =>
      'does not have permission to set the <em>',
    '</em> flag. Please select a user who is a member of the <em>' =>
      '</em> flag. Please select a user who is a member of the <em>',
    '</em> group.' =>
      '</em> group.',
    'Flag Requestee Not Authorized' =>
      'Flag Requestee Not Authorized',
    'Administering Flags' =>
      'Administering Flags',
    'An overview on Flags' =>
      'An overview on Flags',
    'Using Flags' =>
      'Using Flags',
    'You asked' =>
      'You asked',
    'for' =>
      'for',
    'on $terms.bug' =>
      'on $terms.bug',
    ', attachment' =>
      ', attachment',
    ', but that $terms.bug has been restricted to users in certain groups, and the user you asked isn\'t in all the groups to which the $terms.bug has been restricted. Please choose someone else to ask, or make the $terms.bug accessible to users on its CC: list and add that user to the list.' =>
      ', but that $terms.bug has been restricted to users in certain groups, and the user you asked isn\'t in all the groups to which the $terms.bug has been restricted. Please choose someone else to ask, or make the $terms.bug accessible to users on its CC: list and add that user to the list.',
    ', but that attachment is restricted to users in the' =>
      ', but that attachment is restricted to users in the',
    'group, and the user you asked isn\'t in that group. Please choose someone else to ask, or ask an administrator to add the user to the group.' =>
      'group, and the user you asked isn\'t in that group. Please choose someone else to ask, or ask an administrator to add the user to the group.',
    'Flag Type CC List Invalid' =>
      'Flag Type CC List Invalid',
    'The CC list' =>
      'The CC list',
    'must be less than 200 characters long.' =>
      'must be less than 200 characters long.',
    'Product Missing' =>
      'Product Missing',
    'A component was selected without a product being selected.' =>
      'A component was selected without a product being selected.',
    'Flag Type Description Invalid' =>
      'Flag Type Description Invalid',
    'The description must be less than 32K.' =>
      'The description must be less than 32K.',
    'Flag Type Name Invalid' =>
      'Flag Type Name Invalid',
    'The name <em>' =>
      'The name <em>',
    '</em> must be 1-50 characters long and must not contain any spaces or commas.' =>
      '</em> must be 1-50 characters long and must not contain any spaces or commas.',
    'You cannot have several <em>' =>
      'You cannot have several <em>',
    '</em> flags for this' =>
      '</em> flags for this',
    'attachment' =>
      'attachment',
    'Flag Modification Denied' =>
      'Flag Modification Denied',
    'You tried to' =>
      'You tried to',
    'grant' =>
      'grant',
    'deny' =>
      'deny',
    'clear' =>
      'clear',
    'request' =>
      'request',
    '. Only a user with the required permissions may make this change.' =>
      '. Only a user with the required permissions may make this change.',
    'Format Not Found' =>
      'Format Not Found',
    'The requested format <em>' =>
      'The requested format <em>',
    '</em> does not exist with a content type of <em>' =>
      '</em> does not exist with a content type of <em>',
    'Flag Type Sort Key Invalid' =>
      'Flag Type Sort Key Invalid',
    'The sort key must be an integer between 0 and 32767 inclusive. It cannot be <em>' =>
      'The sort key must be an integer between 0 and 32767 inclusive. It cannot be <em>',
    'Text Too Long' =>
      'Text Too Long',
    'The text you entered is too long (' =>
      'The text you entered is too long (',
    'characters, above the maximum length allowed of' =>
      'characters, above the maximum length allowed of',
    'characters):' =>
      'characters):',
    'Cannot Delete Group' =>
      'Cannot Delete Group',
    '</em> group cannot be deleted because there are' =>
      '</em> group cannot be deleted because there are',
    'records' =>
      'records',
    'in the database which refer to it. All references to this group must be removed before you can remove it.' =>
      'in the database which refer to it. All references to this group must be removed before you can remove it.',
    'Cannot Add/Remove That Group' =>
      'Cannot Add/Remove That Group',
    'You tried to add or remove group id' =>
      'You tried to add or remove group id',
    'from $terms.bug' =>
      'from $terms.bug',
    ', but you do not have permissions to do so.' =>
      ', but you do not have permissions to do so.',
    'The group already exists' =>
      'The group already exists',
    'The group' =>
      'The group',
    'already exists.' =>
      'already exists.',
    'Group not deletable' =>
      'Group not deletable',
    'The group \'' =>
      'The group \'',
    '\' and \'' =>
      '\' and \'',
    '\' is used by the \'' =>
      '\' is used by the \'',
    '. In order to delete this group, you first have to change the' =>
      '. In order to delete this group, you first have to change the',
    'to make' =>
      'to make',
    'point to another group.' =>
      'point to another group.',
    'You tried to remove $terms.bug' =>
      'You tried to remove $terms.bug',
    'from group id' =>
      'from group id',
    ', but $terms.bugs in the \'' =>
      ', but $terms.bugs in the \'',
    '\' product can not be removed from that group.' =>
      '\' product can not be removed from that group.',
    'You tried to restrict $terms.bug' =>
      'You tried to restrict $terms.bug',
    'to to group id' =>
      'to to group id',
    '\' product can not be restricted to that group.' =>
      '\' product can not be restricted to that group.',
    'Group not specified' =>
      'Group not specified',
    'No group was specified.' =>
      'No group was specified.',
    'System Groups not deletable' =>
      'System Groups not deletable',
    '</em> is a system group. This group cannot be deleted.' =>
      '</em> is a system group. This group cannot be deleted.',
    'Unknown Group' =>
      'Unknown Group',
    'does not exist. Please specify a valid group name. Create it first if necessary!' =>
      'does not exist. Please specify a valid group name. Create it first if necessary!',
    'Your Search Makes No Sense' =>
      'Your Search Makes No Sense',
    'The <em>At least ___ votes</em> field must be a simple number. You entered' =>
      'The <em>At least ___ votes</em> field must be a simple number. You entered',
    ', which isn\'t.' =>
      ', which isn\'t.',
    'Unauthorized Action' =>
      'Unauthorized Action',
    'You are not authorized to edit attachment' =>
      'You are not authorized to edit attachment',
    'You are not authorized to edit attachments on $terms.bug' =>
      'You are not authorized to edit attachments on $terms.bug',
    'The only legal values for the <em>Attachment is patch</em> field are 0 and 1.' =>
      'The only legal values for the <em>Attachment is patch</em> field are 0 and 1.',
    'Illegal $terms.Bug Status Change' =>
      'Illegal $terms.Bug Status Change',
    'You are not allowed to assign $terms.bugs to other people.' =>
      'You are not allowed to assign $terms.bugs to other people.',
    'Unconfirmed states are disabled in this product.' =>
      'Unconfirmed states are disabled in this product.',
    'You are not allowed to change the $terms.bug status from' =>
      'You are not allowed to change the $terms.bug status from',
    'You are not allowed to file new $terms.bugs with the' =>
      'You are not allowed to file new $terms.bugs with the',
    'status.' =>
      'status.',
    'Not allowed' =>
      'Not allowed',
    'You tried to change the <strong>' =>
      'You tried to change the <strong>',
    '</strong> field' =>
      '</strong> field',
    'from <em>' =>
      'from <em>',
    'to <em>' =>
      'to <em>',
    ', but only' =>
      ', but only',
    'the assignee' =>
      'the assignee',
    'or reporter' =>
      'or reporter',
    'of the $terms.bug, or' =>
      'of the $terms.bug, or',
    'a user with the required permissions may change that field.' =>
      'a user with the required permissions may change that field.',
    '</strong> field but only a user allowed to edit both related $terms.bugs may change that field.' =>
      '</strong> field but only a user allowed to edit both related $terms.bugs may change that field.',
    'The <em>Changed in last ___ days</em> field must be a simple number. You entered' =>
      'The <em>Changed in last ___ days</em> field must be a simple number. You entered',
    'Illegal Date' =>
      'Illegal Date',
    '\' is not a legal date.' =>
      '\' is not a legal date.',
    'Please use the format \'' =>
      'Please use the format \'',
    'Invalid Email Address' =>
      'Invalid Email Address',
    'The e-mail address you entered (<b>' =>
      'The e-mail address you entered (<b>',
    '</b>) didn\'t pass our syntax checking for a legal email address.' =>
      '</b>) didn\'t pass our syntax checking for a legal email address.',
    'A legal address must contain exactly one \'@\', and at least one \'.\' after the @.' =>
      'A legal address must contain exactly one \'@\', and at least one \'.\' after the @.',
    'It must also not contain any of these special characters:' =>
      'It must also not contain any of these special characters:',
    ', or any whitespace.' =>
      ', or any whitespace.',
    'Too Frequent' =>
      'Too Frequent',
    'Unless you are an administrator, you may not create series which are run more often than once every' =>
      'Unless you are an administrator, you may not create series which are run more often than once every',
    'days.' =>
      'days.',
    'Your Group Control Combination Is Illegal' =>
      'Your Group Control Combination Is Illegal',
    'Assigning Group Controls to Products' =>
      'Assigning Group Controls to Products',
    'Your group control combination for group &quot;' =>
      'Your group control combination for group &quot;',
    '&quot; is illegal.' =>
      '&quot; is illegal.',
    'The only legal values for the <em>Attachment is obsolete</em> field are 0 and 1.' =>
      'The only legal values for the <em>Attachment is obsolete</em> field are 0 and 1.',
    'Illegal Search Name' =>
      'Illegal Search Name',
    'The name of your search cannot contain any of the following characters: &lt;, &gt;, &amp;.' =>
      'The name of your search cannot contain any of the following characters: &lt;, &gt;, &amp;.',
    'Group security' =>
      'Group security',
    'Reporting' =>
      'Reporting',
    'You are not authorized to create series.' =>
      'You are not authorized to create series.',
    'You are not authorized to edit this series. To do this, you must either be its creator, or an administrator.' =>
      'You are not authorized to edit this series. To do this, you must either be its creator, or an administrator.',
    'Illegal Time' =>
      'Illegal Time',
    '\' is not a legal time.' =>
      '\' is not a legal time.',
    'Illegal Regular Expression' =>
      'Illegal Regular Expression',
    'The regular expression you provided' =>
      'The regular expression you provided',
    'is not valid. The error was:' =>
      'is not valid. The error was:',
    'Illegal User ID' =>
      'Illegal User ID',
    'User ID \'' =>
      'User ID \'',
    '\' is not valid integer.' =>
      '\' is not valid integer.',
    'The value(s) "' =>
      'The value(s) "',
    '" of field "' =>
      '" of field "',
    '" are incorrect for the value "' =>
      '" are incorrect for the value "',
    '" of controlling field "' =>
      '" of controlling field "',
    'We don\'t have enough data points to make a graph (yet).' =>
      'We don\'t have enough data points to make a graph (yet).',
    'Invalid Attachment ID' =>
      'Invalid Attachment ID',
    'The attachment id' =>
      'The attachment id',
    'is invalid.' =>
      'is invalid.',
    'Invalid $terms.Bug ID' =>
      'Invalid $terms.Bug ID',
    'does not exist.' =>
      'does not exist.',
    'Invalid' =>
      'Invalid',
    'Missing' =>
      'Missing',
    '$terms.Bug ID' =>
      '$terms.Bug ID',
    '\' is not a valid $terms.bug number' =>
      '\' is not a valid $terms.bug number',
    'nor an alias to $terms.abug' =>
      'nor an alias to $terms.abug',
    'The \'' =>
      'The \'',
    '\' field cannot be empty.' =>
      '\' field cannot be empty.',
    'You must enter a valid $terms.bug number!' =>
      'You must enter a valid $terms.bug number!',
    'Invalid \'Changed Since\'' =>
      'Invalid \'Changed Since\'',
    'The \'changed since\' value, \'' =>
      'The \'changed since\' value, \'',
    '\', must be an integer >= 0.' =>
      '\', must be an integer >= 0.',
    'Invalid Content-Type' =>
      'Invalid Content-Type',
    'The content type <em>' =>
      'The content type <em>',
    '</em> is invalid. Valid types must be of the form <em>foo/bar</em> where <em>foo</em> is one of <em>' =>
      '</em> is invalid. Valid types must be of the form <em>foo/bar</em> where <em>foo</em> is one of <em>',
    'Invalid Context' =>
      'Invalid Context',
    'The context' =>
      'The context',
    'is invalid (must be a number, "file" or "patch").' =>
      'is invalid (must be a number, "file" or "patch").',
    'Invalid Datasets' =>
      'Invalid Datasets',
    'Invalid datasets <em>' =>
      'Invalid datasets <em>',
    '</em>. Only digits, letters and colons are allowed.' =>
      '</em>. Only digits, letters and colons are allowed.',
    'Invalid Format' =>
      'Invalid Format',
    'The format "' =>
      'The format "',
    '" is invalid (must be one of' =>
      '" is invalid (must be one of',
    'Invalid group ID' =>
      'Invalid group ID',
    'The group you specified doesn\'t exist.' =>
      'The group you specified doesn\'t exist.',
    'Invalid group name' =>
      'Invalid group name',
    'The group you specified,' =>
      'The group you specified,',
    ', is not valid here.' =>
      ', is not valid here.',
    'Invalid Max Rows' =>
      'Invalid Max Rows',
    'The maximum number of rows, \'' =>
      'The maximum number of rows, \'',
    '\', must be a positive integer.' =>
      '\', must be a positive integer.',
    'Invalid Parameter' =>
      'Invalid Parameter',
    'The new value for' =>
      'The new value for',
    'is invalid:' =>
      'is invalid:',
    'Invalid Product Name' =>
      'Invalid Product Name',
    'The product name \'' =>
      'The product name \'',
    '\' is invalid or does not exist.' =>
      '\' is invalid or does not exist.',
    'Invalid regular expression' =>
      'Invalid regular expression',
    'The regular expression you entered is invalid.' =>
      'The regular expression you entered is invalid.',
    'Invalid User Group' =>
      'Invalid User Group',
    'Users' =>
      'Users',
    'are' =>
      'are',
    'is' =>
      'is',
    'not able to edit the' =>
      'not able to edit the',
    'for $terms.bug \'' =>
      'for $terms.bug \'',
    'and may not be included on a new $terms.bug.' =>
      'and may not be included on a new $terms.bug.',
    'for at least one $terms.bug being changed.' =>
      'for at least one $terms.bug being changed.',
    'Invalid Username' =>
      'Invalid Username',
    'The name' =>
      'The name',
    'is not a valid username. Either you misspelled it, or the person has not registered for a $terms.Bugzilla account.' =>
      'is not a valid username. Either you misspelled it, or the person has not registered for a $terms.Bugzilla account.',
    'Invalid Username Or Password' =>
      'Invalid Username Or Password',
    'The username or password you entered is not valid.' =>
      'The username or password you entered is not valid.',
    'If you do not enter the correct password after' =>
      'If you do not enter the correct password after',
    'more attempt(s), you will be locked out of this account for' =>
      'more attempt(s), you will be locked out of this account for',
    'minutes.' =>
      'minutes.',
    'For security reasons, you may only use JSON-RPC with the POST HTTP method.' =>
      'For security reasons, you may only use JSON-RPC with the POST HTTP method.',
    'Blank Keyword Description Not Allowed' =>
      'Blank Keyword Description Not Allowed',
    'You must enter a non-blank description for the keyword.' =>
      'You must enter a non-blank description for the keyword.',
    'Local File Too Large' =>
      'Local File Too Large',
    'Local file uploads must not exceed' =>
      'Local file uploads must not exceed',
    'MB in size.' =>
      'MB in size.',
    'Login Name Required' =>
      'Login Name Required',
    'You must enter a login name when requesting to change your password.' =>
      'You must enter a login name when requesting to change your password.',
    'You can\'t use %user% without being logged in, because %user% refers to your login name, which we don\'t know.' =>
      'You can\'t use %user% without being logged in, because %user% refers to your login name, which we don\'t know.',
    'You must log in before using this part of $terms.Bugzilla.' =>
      'You must log in before using this part of $terms.Bugzilla.',
    'The file' =>
      'The file',
    'contains configuration variables that must be set before continuing with the migration.' =>
      'contains configuration variables that must be set before continuing with the migration.',
    '\' is not a valid type of $terms.bug-tracker to migrate from. See the contents of the' =>
      '\' is not a valid type of $terms.bug-tracker to migrate from. See the contents of the',
    'directory for a list of valid $terms.bug-trackers.' =>
      'directory for a list of valid $terms.bug-trackers.',
    'Milestone Already Exists' =>
      'Milestone Already Exists',
    'Administering products' =>
      'Administering products',
    'About Milestones' =>
      'About Milestones',
    'The milestone \'' =>
      'The milestone \'',
    '\' already exists for product \'' =>
      '\' already exists for product \'',
    'Blank Milestone Name Not Allowed' =>
      'Blank Milestone Name Not Allowed',
    'Blank and "---" milestone names are not allowed. If you want an empty milestone for bugs in your product, just' =>
      'Blank and "---" milestone names are not allowed. If you want an empty milestone for bugs in your product, just',
    'enable empty value for the Target Milestone field' =>
      'enable empty value for the Target Milestone field',
    'in it.' =>
      'in it.',
    'Milestone Name Is Too Long' =>
      'Milestone Name Is Too Long',
    'The name of a milestone is limited to' =>
      'The name of a milestone is limited to',
    'Milestone Required' =>
      'Milestone Required',
    'You must select a target milestone for $terms.bug' =>
      'You must select a target milestone for $terms.bug',
    'if you are going to accept it. Part of accepting $terms.abug is giving an estimate of when it will be fixed.' =>
      'if you are going to accept it. Part of accepting $terms.abug is giving an estimate of when it will be fixed.',
    'Invalid Milestone Sortkey' =>
      'Invalid Milestone Sortkey',
    '\' is not in the range' =>
      '\' is not in the range',
    '&le; sortkey &le;' =>
      '&le; sortkey &le;',
    'Misarranged Dates' =>
      'Misarranged Dates',
    'Your start date (' =>
      'Your start date (',
    ') is after your end date (' =>
      ') is after your end date (',
    'Missing Attachment Description' =>
      'Missing Attachment Description',
    'You must enter a description for the attachment.' =>
      'You must enter a description for the attachment.',
    'Missing Category' =>
      'Missing Category',
    'You did not specify a category for this series.' =>
      'You did not specify a category for this series.',
    'Missing Component' =>
      'Missing Component',
    'Creating a component' =>
      'Creating a component',
    'Sorry, the product <em>' =>
      'Sorry, the product <em>',
    '</em> has to have at least one component in order for you to enter $terms.abug into it.' =>
      '</em> has to have at least one component in order for you to enter $terms.abug into it.',
    'Create a new component' =>
      'Create a new component',
    'Please contact' =>
      'Please contact',
    'and ask them to add a component to this product.' =>
      'and ask them to add a component to this product.',
    'Missing Content-Type' =>
      'Missing Content-Type',
    'You asked $terms.Bugzilla to auto-detect the content type, but your browser did not specify a content type when uploading the file, so you must enter a content type manually.' =>
      'You asked $terms.Bugzilla to auto-detect the content type, but your browser did not specify a content type when uploading the file, so you must enter a content type manually.',
    'Missing Content-Type Determination Method' =>
      'Missing Content-Type Determination Method',
    'You must choose a method for determining the content type, either <em>auto-detect</em>, <em>select from list</em>, or <em>enter manually</em>.' =>
      'You must choose a method for determining the content type, either <em>auto-detect</em>, <em>select from list</em>, or <em>enter manually</em>.',
    'Missing Cookie' =>
      'Missing Cookie',
    'Sorry, I seem to have lost the cookie that recorded the results of your last search. I\'m afraid you will have to start again from the' =>
      'Sorry, I seem to have lost the cookie that recorded the results of your last search. I\'m afraid you will have to start again from the',
    'search page' =>
      'search page',
    'No Datasets Selected' =>
      'No Datasets Selected',
    'You must specify one or more datasets to plot.' =>
      'You must specify one or more datasets to plot.',
    'Missing Frequency' =>
      'Missing Frequency',
    'You did not specify a valid frequency for this series.' =>
      'You did not specify a valid frequency for this series.',
    'Missing Name' =>
      'Missing Name',
    'You did not specify a name for this series.' =>
      'You did not specify a name for this series.',
    'Missing Search' =>
      'Missing Search',
    'The search named <em>' =>
      'The search named <em>',
    'has not been made visible to you.' =>
      'has not been made visible to you.',
    'Resolution Required' =>
      'Resolution Required',
    'A valid resolution is required to mark $terms.bugs as' =>
      'A valid resolution is required to mark $terms.bugs as',
    '$terms.Bug Moving Disabled' =>
      '$terms.Bug Moving Disabled',
    'Sorry, $terms.bug moving has been disabled. If you need to move $terms.abug, please contact' =>
      'Sorry, $terms.bug moving has been disabled. If you need to move $terms.abug, please contact',
    'Missing Subcategory' =>
      'Missing Subcategory',
    'You did not specify a subcategory for this series.' =>
      'You did not specify a subcategory for this series.',
    'No Worktime In Selected Bug' =>
      'No Worktime In Selected Bug',
    'You are trying to move or split Hours Worked by in ratio taken from' =>
      'You are trying to move or split Hours Worked by in ratio taken from',
    ', bug there is no working time entered' =>
      ', bug there is no working time entered',
    'by user' =>
      'by user',
    'between' =>
      'between',
    'after' =>
      'after',
    'before' =>
      'before',
    'Quip Required' =>
      'Quip Required',
    'About quips' =>
      'About quips',
    'Please enter a quip in the text field.' =>
      'Please enter a quip in the text field.',
    'New Password Missing' =>
      'New Password Missing',
    'You must enter a new password.' =>
      'You must enter a new password.',
    'No Axes Defined' =>
      'No Axes Defined',
    'You didn\'t define any axes to plot.' =>
      'You didn\'t define any axes to plot.',
    'No $terms.Bugs Selected' =>
      'No $terms.Bugs Selected',
    'You apparently didn\'t choose any $terms.bugs' =>
      'You apparently didn\'t choose any $terms.bugs',
    'to modify.' =>
      'to modify.',
    'to view.' =>
      'to view.',
    'You didn\'t choose any $terms.bugs to' =>
      'You didn\'t choose any $terms.bugs to',
    'add to' =>
      'add to',
    'remove from' =>
      'remove from',
    'the' =>
      'the',
    'tag.' =>
      'tag.',
    'Delete Tag?' =>
      'Delete Tag?',
    'This will remove all $terms.bugs from the <em>' =>
      'This will remove all $terms.bugs from the <em>',
    '</em> tag. This will delete the tag completely. Click' =>
      '</em> tag. This will delete the tag completely. Click',
    'here' =>
      'here',
    'if you really want to delete it.' =>
      'if you really want to delete it.',
    'No Tag Selected' =>
      'No Tag Selected',
    'You didn\'t select a tag from which to remove $terms.bugs.' =>
      'You didn\'t select a tag from which to remove $terms.bugs.',
    'No Initial $terms.Bug Status' =>
      'No Initial $terms.Bug Status',
    'No $terms.bug status is available on $terms.bug creation. Please report the problem to' =>
      'No $terms.bug status is available on $terms.bug creation. Please report the problem to',
    'No New Quips' =>
      'No New Quips',
    'Controlling quip usage' =>
      'Controlling quip usage',
    'This site does not permit the addition of new quips.' =>
      'This site does not permit the addition of new quips.',
    'No Page Specified' =>
      'No Page Specified',
    'You did not specify the id of a page to display.' =>
      'You did not specify the id of a page to display.',
    'No Products' =>
      'No Products',
    'Setting up a product' =>
      'Setting up a product',
    'Adding components to products' =>
      'Adding components to products',
    'Groups security' =>
      'Groups security',
    'Either no products have been defined to enter $terms.bugs against or you have not been given access to any.' =>
      'Either no products have been defined to enter $terms.bugs against or you have not been given access to any.',
    'No valid action specified' =>
      'No valid action specified',
    'Cannot edit' =>
      'Cannot edit',
    ': no valid action was specified.' =>
      ': no valid action was specified.',
    'Numeric Value Required' =>
      'Numeric Value Required',
    '\' in the <em>' =>
      '\' in the <em>',
    '</em> field is not a numeric value.' =>
      '</em> field is not a numeric value.',
    'Number Too Large' =>
      'Number Too Large',
    '</em> field is more than the maximum allowable value of \'' =>
      '</em> field is more than the maximum allowable value of \'',
    'Number Too Small' =>
      'Number Too Small',
    '</em> field is less than the minimum allowable value of \'' =>
      '</em> field is less than the minimum allowable value of \'',
    'Not Specified' =>
      'Not Specified',
    'You must select/enter a' =>
      'You must select/enter a',
    'with the id \'' =>
      'with the id \'',
    'in the \'' =>
      'in the \'',
    '\' product' =>
      '\' product',
    'Either you mis-typed the name or that user has not yet registered for a $terms.Bugzilla account.' =>
      'Either you mis-typed the name or that user has not yet registered for a $terms.Bugzilla account.',
    'Incorrect Old Password' =>
      'Incorrect Old Password',
    'You did not enter your old password correctly.' =>
      'You did not enter your old password correctly.',
    'Old Password Required' =>
      'Old Password Required',
    'You must enter your old password to change your email address.' =>
      'You must enter your old password to change your email address.',
    'Password Change Requests Not Allowed' =>
      'Password Change Requests Not Allowed',
    'The system is not configured to allow password change requests.' =>
      'The system is not configured to allow password change requests.',
    'Passwords Don\'t Match' =>
      'Passwords Don\'t Match',
    'The two passwords you entered did not match.' =>
      'The two passwords you entered did not match.',
    'New Password Required' =>
      'New Password Required',
    'Your password is currently less than' =>
      'Your password is currently less than',
    'characters long, which is the new minimum length required for passwords. You must' =>
      'characters long, which is the new minimum length required for passwords. You must',
    'request a new password' =>
      'request a new password',
    'in order to log in again.' =>
      'in order to log in again.',
    'Password Too Short' =>
      'Password Too Short',
    'The password must be at least' =>
      'The password must be at least',
    'kilobytes (KB) in size. Patches cannot be more than' =>
      'kilobytes (KB) in size. Patches cannot be more than',
    'KB in size. Try splitting your patch into several pieces.' =>
      'KB in size. Try splitting your patch into several pieces.',
    'Either the product' =>
      'Either the product',
    'with the id' =>
      'with the id',
    'does not exist or you don\'t have access to it.' =>
      'does not exist or you don\'t have access to it.',
    'Specified Product Does Not Exist' =>
      'Specified Product Does Not Exist',
    'The product \'' =>
      'The product \'',
    '\' does not exist.' =>
      '\' does not exist.',
    'Illegal Group' =>
      'Illegal Group',
    'is not an active $terms.bug group and so you cannot edit group controls for it.' =>
      'is not an active $terms.bug group and so you cannot edit group controls for it.',
    'Votes Must Be Non-negative' =>
      'Votes Must Be Non-negative',
    'Setting up the voting feature' =>
      'Setting up the voting feature',
    '\' is an invalid value for the <em>' =>
      '\' is an invalid value for the <em>',
    'Votes Per User' =>
      'Votes Per User',
    'Maximum Votes Per $terms.Bug' =>
      'Maximum Votes Per $terms.Bug',
    'Votes To Confirm' =>
      'Votes To Confirm',
    '</em> field, which should contain a non-negative number.' =>
      '</em> field, which should contain a non-negative number.',
    'You have requested the product name "' =>
      'You have requested the product name "',
    '", did you mean "' =>
      '", did you mean "',
    'Product name already exists' =>
      'Product name already exists',
    'Product name differs only in case' =>
      'Product name differs only in case',
    '\' differs from existing product \'' =>
      '\' differs from existing product \'',
    '\' only in case.' =>
      '\' only in case.',
    'Product name too long' =>
      'Product name too long',
    'The name of a product is limited to' =>
      'The name of a product is limited to',
    'Product Access Denied' =>
      'Product Access Denied',
    'You are not allowed to edit properties of product \'' =>
      'You are not allowed to edit properties of product \'',
    'Blank Product Name Not Allowed' =>
      'Blank Product Name Not Allowed',
    'You must enter a name for the product.' =>
      'You must enter a name for the product.',
    'Product closed for $terms.Bug Entry' =>
      'Product closed for $terms.Bug Entry',
    'Sorry, entering $terms.abug into the product <em>' =>
      'Sorry, entering $terms.abug into the product <em>',
    '</em> has been disabled.' =>
      '</em> has been disabled.',
    'Product Edit Access Denied' =>
      'Product Edit Access Denied',
    'You are not permitted to edit $terms.bugs in product' =>
      'You are not permitted to edit $terms.bugs in product',
    'Product has $terms.Bugs' =>
      'Product has $terms.Bugs',
    '$terms.bugs entered for this product! You must move those $terms.bugs to another product before you can delete this one.' =>
      '$terms.bugs entered for this product! You must move those $terms.bugs to another product before you can delete this one.',
    'Product needs Description' =>
      'Product needs Description',
    'You must enter a description for this product.' =>
      'You must enter a description for this product.',
    'No Product Specified' =>
      'No Product Specified',
    'Administering components' =>
      'Administering components',
    'Administering milestones' =>
      'Administering milestones',
    'Administering versions' =>
      'Administering versions',
    'No product specified when trying to edit components, milestones, versions or product.' =>
      'No product specified when trying to edit components, milestones, versions or product.',
    'Search Name Already In Use' =>
      'Search Name Already In Use',
    '</em> is already used by another saved search. You first have to' =>
      '</em> is already used by another saved search. You first have to',
    'delete' =>
      'delete',
    'it if you really want to use this name.' =>
      'it if you really want to use this name.',
    'No Search Name Specified' =>
      'No Search Name Specified',
    'You must enter a name for your search.' =>
      'You must enter a name for your search.',
    'Query Name Too Long' =>
      'Query Name Too Long',
    'The name of the query must be less than' =>
      'The name of the query must be less than',
    'QuickSearch Error' =>
      'QuickSearch Error',
    'There is a problem with your search:' =>
      'There is a problem with your search:',
    'is not a valid field name.' =>
      'is not a valid field name.',
    'matches more than one field:' =>
      'matches more than one field:',
    'The legal field names are' =>
      'The legal field names are',
    'listed here' =>
      'listed here',
    'Illegal Reassignment' =>
      'Illegal Reassignment',
    'To reassign $terms.abug, you must provide an address for the new assignee.' =>
      'To reassign $terms.abug, you must provide an address for the new assignee.',
    'No Report Name Specified' =>
      'No Report Name Specified',
    'You must enter a name for your report.' =>
      'You must enter a name for your report.',
    'Report Access Denied' =>
      'Report Access Denied',
    'You cannot access this report.' =>
      'You cannot access this report.',
    'Component Needed' =>
      'Component Needed',
    'To file this $terms.bug, you must first choose a component. If necessary, just guess.' =>
      'To file this $terms.bug, you must first choose a component. If necessary, just guess.',
    'New Password Needed' =>
      'New Password Needed',
    'You cannot change your password without choosing a new one.' =>
      'You cannot change your password without choosing a new one.',
    'Summary Needed' =>
      'Summary Needed',
    'You must enter a summary for this $terms.bug.' =>
      'You must enter a summary for this $terms.bug.',
    'is closed, so you cannot clear its resolution.' =>
      'is closed, so you cannot clear its resolution.',
    'Resolution Not Allowed' =>
      'Resolution Not Allowed',
    'You cannot set a resolution for open $terms.bugs.' =>
      'You cannot set a resolution for open $terms.bugs.',
    'Saved Search In Use' =>
      'Saved Search In Use',
    'About Whining' =>
      'About Whining',
    'The saved search <em>' =>
      'The saved search <em>',
    '</em> is being used by' =>
      '</em> is being used by',
    'Whining events' =>
      'Whining events',
    'with the following subjects:' =>
      'with the following subjects:',
    'Correctness Checks' =>
      'Correctness Checks',
    'Illegal Search' =>
      'Illegal Search',
    'The "content" field can only be used with "matches" search and the "matches" search can only be used with the "content" field.' =>
      'The "content" field can only be used with "matches" search and the "matches" search can only be used with the "content" field.',
    'The "Time Since Assignee Touched" field can only be compared to numbers with "' =>
      'The "Time Since Assignee Touched" field can only be compared to numbers with "',
    '" or ">=" operators.' =>
      '" or ">=" operators.',
    'Series Already Exists' =>
      'Series Already Exists',
    'A series named <em>' =>
      'A series named <em>',
    '</em> already exists.' =>
      '</em> already exists.',
    'Sorry - sidebar.cgi currently only supports Mozilla based web browsers.' =>
      'Sorry - sidebar.cgi currently only supports Mozilla based web browsers.',
    'Upgrade today' =>
      'Upgrade today',
    'still has' =>
      'still has',
    'unresolved' =>
      'unresolved',
    'dependency' =>
      'dependency',
    'dependencies' =>
      'dependencies',
    '. Show' =>
      '. Show',
    'Dependency Tree' =>
      'Dependency Tree',
    'open $terms.bugs which have unresolved dependencies.' =>
      'open $terms.bugs which have unresolved dependencies.',
    'has' =>
      'has',
    'open' =>
      'open',
    'dependency.' =>
      'dependency.',
    'dependencies.' =>
      'dependencies.',
    'Invalid Sudo Cookie' =>
      'Invalid Sudo Cookie',
    'Your sudo cookie is invalid. Either it expired or you didn\'t start a sudo session correctly. Refresh the page or load another page to continue what you are doing as yourself.' =>
      'Your sudo cookie is invalid. Either it expired or you didn\'t start a sudo session correctly. Refresh the page or load another page to continue what you are doing as yourself.',
    'Impersonation Not Authorized' =>
      'Impersonation Not Authorized',
    'You are not allowed to impersonate users.' =>
      'You are not allowed to impersonate users.',
    'You are not allowed to impersonate' =>
      'You are not allowed to impersonate',
    'The user you tried to impersonate doesn\'t exist.' =>
      'The user you tried to impersonate doesn\'t exist.',
    'Session In Progress' =>
      'Session In Progress',
    'A sudo session (impersonating' =>
      'A sudo session (impersonating',
    ') is in progress. End that session (using the link in the footer) before starting a new one.' =>
      ') is in progress. End that session (using the link in the footer) before starting a new one.',
    'Password Required' =>
      'Password Required',
    'Your $terms.Bugzilla password is required to begin a sudo session. Please' =>
      'Your $terms.Bugzilla password is required to begin a sudo session. Please',
    'go back' =>
      'go back',
    'and enter your password.' =>
      'and enter your password.',
    'Preparation Required' =>
      'Preparation Required',
    'You may not start a sudo session directly. Please' =>
      'You may not start a sudo session directly. Please',
    'start your session normally' =>
      'start your session normally',
    'User Protected' =>
      'User Protected',
    'The user' =>
      'The user',
    'may not be impersonated by sudoers.' =>
      'may not be impersonated by sudoers.',
    'Illegal Vote' =>
      'Illegal Vote',
    'You may only use at most' =>
      'You may only use at most',
    'votes for a single $terms.bug in the' =>
      'votes for a single $terms.bug in the',
    'product, but you are trying to use' =>
      'product, but you are trying to use',
    'You tried to use' =>
      'You tried to use',
    'votes in the' =>
      'votes in the',
    'product, which exceeds the maximum of' =>
      'product, which exceeds the maximum of',
    'votes for this product.' =>
      'votes for this product.',
    'Token Does Not Exist' =>
      'Token Does Not Exist',
    'The token you submitted does not exist, has expired, or has been canceled.' =>
      'The token you submitted does not exist, has expired, or has been canceled.',
    'Too Soon For New Token' =>
      'Too Soon For New Token',
    'You have requested' =>
      'You have requested',
    'a password' =>
      'a password',
    'an account' =>
      'an account',
    'token too recently to request another. Please wait a while and try again.' =>
      'token too recently to request another. Please wait a while and try again.',
    'Unknown Keyword' =>
      'Unknown Keyword',
    'is not a known keyword. The legal keyword names are' =>
      'is not a known keyword. The legal keyword names are',
    'Unknown Tab' =>
      'Unknown Tab',
    'is not a legal tab name.' =>
      'is not a legal tab name.',
    'Version Already Exists' =>
      'Version Already Exists',
    'The version \'' =>
      'The version \'',
    'Blank Version Name Not Allowed' =>
      'Blank Version Name Not Allowed',
    'Blank, "---" and "unspecified" version names are not allowed. If you want an empty version for bugs in your product, just' =>
      'Blank, "---" and "unspecified" version names are not allowed. If you want an empty version for bugs in your product, just',
    'enable empty value for the Version field' =>
      'enable empty value for the Version field',
    'Unknown action' =>
      'Unknown action',
    'I could not figure out what you wanted to do.' =>
      'I could not figure out what you wanted to do.',
    'Deletion not activated' =>
      'Deletion not activated',
    'User administration' =>
      'User administration',
    'Sorry, the deletion of user accounts is not allowed.' =>
      'Sorry, the deletion of user accounts is not allowed.',
    'Can\'t Delete User Account' =>
      'Can\'t Delete User Account',
    'The user you want to delete is set up as the default $terms.bug assignee' =>
      'The user you want to delete is set up as the default $terms.bug assignee',
    'or QA contact' =>
      'or QA contact',
    'for at least one component. For this reason, you cannot delete the account at this time.' =>
      'for at least one component. For this reason, you cannot delete the account at this time.',
    'User Access By Id Denied' =>
      'User Access By Id Denied',
    'Logged-out users cannot use the "ids" argument to this function to access any user information.' =>
      'Logged-out users cannot use the "ids" argument to this function to access any user information.',
    'User-Matching Denied' =>
      'User-Matching Denied',
    'Logged-out users cannot use the "match" argument to this function to access any user information.' =>
      'Logged-out users cannot use the "match" argument to this function to access any user information.',
    'You must enter a login name for the new user.' =>
      'You must enter a login name for the new user.',
    'Match Failed' =>
      'Match Failed',
    'does not exist or you are not allowed to see that user.' =>
      'does not exist or you are not allowed to see that user.',
    'No Conclusive Match' =>
      'No Conclusive Match',
    '$terms.Bugzilla cannot make a conclusive match for one or more of the names and/or email addresses you entered for the' =>
      '$terms.Bugzilla cannot make a conclusive match for one or more of the names and/or email addresses you entered for the',
    'field(s).' =>
      'field(s).',
    'User Not In Insidergroup' =>
      'User Not In Insidergroup',
    'Sorry, but you are not allowed to (un)mark comments or attachments as private.' =>
      'Sorry, but you are not allowed to (un)mark comments or attachments as private.',
    'Only use non-negative numbers for your $terms.bug votes.' =>
      'Only use non-negative numbers for your $terms.bug votes.',
    'Wrong Token' =>
      'Wrong Token',
    'That token cannot be used to cancel an email address change.' =>
      'That token cannot be used to cancel an email address change.',
    'That token cannot be used to change your password.' =>
      'That token cannot be used to change your password.',
    'That token cannot be used to change your email address.' =>
      'That token cannot be used to change your email address.',
    'That token cannot be used to create a user account.' =>
      'That token cannot be used to create a user account.',
    '" is not a valid value for a &lt;' =>
      '" is not a valid value for a &lt;',
    '&gt; field. (See the XML-RPC specification for details.)' =>
      '&gt; field. (See the XML-RPC specification for details.)',
    'File Is Empty' =>
      'File Is Empty',
    'The file you are trying to attach is empty, does not exist, or you don\'t have permission to read it.' =>
      'The file you are trying to attach is empty, does not exist, or you don\'t have permission to read it.',
    'user' =>
      'user',
    'component' =>
      'component',
    'version' =>
      'version',
    'milestone' =>
      'milestone',
    'status' =>
      'status',
    'flag' =>
      'flag',
    'flagtype' =>
      'flagtype',
    'field' =>
      'field',
    'group' =>
      'group',
    'classification' =>
      'classification',
    'saved search' =>
      'saved search',
  },
  'index.html.tmpl' => {
    '$terms.Bugzilla Main Page' =>
      '$terms.Bugzilla Main Page',
    'Main Page' =>
      'Main Page',
    'version $constants.BUGZILLA_VERSION' =>
      'version $constants.BUGZILLA_VERSION',
    'Enter $terms.abug # or some search terms' =>
      'Enter $terms.abug # or some search terms',
    'Please enter one or more search terms first.' =>
      'Please enter one or more search terms first.',
    'is no longer supported. You are highly encouraged to upgrade in order to keep your system secure.' =>
      'is no longer supported. You are highly encouraged to upgrade in order to keep your system secure.',
    'A new $terms.Bugzilla version (' =>
      'A new $terms.Bugzilla version (',
    ') is available at' =>
      ') is available at',
    'Release date:' =>
      'Release date:',
    'This message is only shown to logged in users with admin privs. You can configure this notification from the' =>
      'This message is only shown to logged in users with admin privs. You can configure this notification from the',
    'Parameters' =>
      'Parameters',
    'page.' =>
      'page.',
    'The local XML file \'' =>
      'The local XML file \'',
    '\' cannot be created. Please make sure the web server can write in this directory and that you can access the web. If you are behind a proxy, set the' =>
      '\' cannot be created. Please make sure the web server can write in this directory and that you can access the web. If you are behind a proxy, set the',
    'parameter correctly.' =>
      'parameter correctly.',
    '\' cannot be updated. Please make sure the web server can edit this file.' =>
      '\' cannot be updated. Please make sure the web server can edit this file.',
    '\' cannot be read. Please make sure this file has the correct rights set on it.' =>
      '\' cannot be read. Please make sure this file has the correct rights set on it.',
    '\' has an invalid XML format. Please delete it and try accessing this page again.' =>
      '\' has an invalid XML format. Please delete it and try accessing this page again.',
    '\' is not a valid notification parameter. Please check this parameter in the' =>
      '\' is not a valid notification parameter. Please check this parameter in the',
    'Welcome to $terms.Bugzilla' =>
      'Welcome to $terms.Bugzilla',
    'File $terms.aBug' =>
      'File $terms.aBug',
    'Search' =>
      'Search',
    'User Preferences' =>
      'User Preferences',
    'Open a New Account' =>
      'Open a New Account',
    'Log In' =>
      'Log In',
    'Quick Search' =>
      'Quick Search',
    'Quick Search help' =>
      'Quick Search help',
    'Install the Quick Search plugin' =>
      'Install the Quick Search plugin',
    '$terms.Bugzilla User\'s Guide' =>
      '$terms.Bugzilla User\'s Guide',
    'Release Notes' =>
      'Release Notes',
  },
  'list/change-columns.html.tmpl' => {
    'Change Columns' =>
      'Change Columns',
    'Select the columns you wish to appear in your $terms.bug lists. Note that this feature requires cookies to work.' =>
      'Select the columns you wish to appear in your $terms.bug lists. Note that this feature requires cookies to work.',
    'Summary (first 60 characters)' =>
      'Summary (first 60 characters)',
    'Full Summary' =>
      'Full Summary',
    'Assignee Realname' =>
      'Assignee Realname',
    'Reporter Realname' =>
      'Reporter Realname',
    'QA Contact Realname' =>
      'QA Contact Realname',
    'Available Columns' =>
      'Available Columns',
    'Selected Columns' =>
      'Selected Columns',
    'Normal headers (prettier)' =>
      'Normal headers (prettier)',
    'Stagger headers (often makes list more compact)' =>
      'Stagger headers (often makes list more compact)',
    'Save this column list for search \'' =>
      'Save this column list for search \'',
    'In the "' =>
      'In the "',
    '" column, show working time for user:' =>
      '" column, show working time for user:',
    'between' =>
      'between',
    'and' =>
      'and',
    '(YYYY-MM-DD or relative dates)' =>
      '(YYYY-MM-DD or relative dates)',
    'Reset to $terms.Bugzilla default' =>
      'Reset to $terms.Bugzilla default',
  },
  'list/edit-multiple.html.tmpl' => {
    '--do_not_change--' =>
      '--do_not_change--',
    'Uncheck All' =>
      'Uncheck All',
    'Check All' =>
      'Check All',
    'To change multiple $terms.bugs:' =>
      'To change multiple $terms.bugs:',
    'Check the $terms.bugs you want to change above.' =>
      'Check the $terms.bugs you want to change above.',
    'Make your changes in the form fields below. If the change you are making requires an explanation, include it in the comments box.' =>
      'Make your changes in the form fields below. If the change you are making requires an explanation, include it in the comments box.',
    'Click the <em>Commit</em> button.' =>
      'Click the <em>Commit</em> button.',
    'Estimated Hours:' =>
      'Estimated Hours:',
    'Deadline (YYYY-MM-DD):' =>
      'Deadline (YYYY-MM-DD):',
    'Remaining Hours:' =>
      'Remaining Hours:',
    'Assignee:' =>
      'Assignee:',
    'Reset Assignee to default' =>
      'Reset Assignee to default',
    'QA Contact:' =>
      'QA Contact:',
    'Reset QA Contact to default' =>
      'Reset QA Contact to default',
    'CC List:' =>
      'CC List:',
    'Add these to the CC List' =>
      'Add these to the CC List',
    'Remove these from the CC List' =>
      'Remove these from the CC List',
    'Keywords' =>
      'Keywords',
    'Add these keywords' =>
      'Add these keywords',
    'Delete these keywords' =>
      'Delete these keywords',
    'Make the keywords be exactly this list' =>
      'Make the keywords be exactly this list',
    'Depends On:' =>
      'Depends On:',
    'Add these IDs' =>
      'Add these IDs',
    'Delete these IDs' =>
      'Delete these IDs',
    'Blocks:' =>
      'Blocks:',
    '<b>Status Whiteboard:</b>' =>
      '<b>Status Whiteboard:</b>',
    'Additional Comments:' =>
      'Additional Comments:',
    'Make comment private (visible only to members of the <strong>' =>
      'Make comment private (visible only to members of the <strong>',
    '</strong> group)' =>
      '</strong> group)',
    'Silent' =>
      'Silent',
    '<b>Groups:</b>' =>
      '<b>Groups:</b>',
    'Don\'t' =>
      'Don\'t',
    'change' =>
      'change',
    'this group' =>
      'this group',
    'restriction' =>
      'restriction',
    'Remove' =>
      'Remove',
    'from this' =>
      'from this',
    'group' =>
      'group',
    'Add' =>
      'Add',
    'to this' =>
      'to this',
    'Group Name:' =>
      'Group Name:',
    '(Note: $terms.Bugs may not be added to' =>
      '(Note: $terms.Bugs may not be added to',
    'inactive groups' =>
      'inactive groups',
    ', only removed.)' =>
      ', only removed.)',
    '<b>Status:</b>' =>
      '<b>Status:</b>',
    'Commit' =>
      'Commit',
    'move-button-text' =>
      'move-button-text',
  },
  'list/list-simple.html.tmpl' => {
    '$terms.Bug List' =>
      '$terms.Bug List',
  },
  'list/list.html.tmpl' => {
    '$terms.Bug List' =>
      '$terms.Bug List',
    '$terms.Bugzilla would like to put a random quip here, but no one has entered any.' =>
      '$terms.Bugzilla would like to put a random quip here, but no one has entered any.',
    'This list is too long for $terms.Bugzilla\'s little mind; the Next/Prev/First/Last buttons won\'t appear on individual $terms.bugs.' =>
      'This list is too long for $terms.Bugzilla\'s little mind; the Next/Prev/First/Last buttons won\'t appear on individual $terms.bugs.',
    'found.' =>
      'found.',
    'Display Bug ID list' =>
      'Display Bug ID list',
    'Create new $terms.bug from search parameters' =>
      'Create new $terms.bug from search parameters',
    'Bug ID list:' =>
      'Bug ID list:',
    'One $terms.bug found.' =>
      'One $terms.bug found.',
    '$terms.bugs found.' =>
      '$terms.bugs found.',
    'Create new $terms.bug with the same fields' =>
      'Create new $terms.bug with the same fields',
    'File a new $terms.bug in a different product' =>
      'File a new $terms.bug in a different product',
    'Edit this search' =>
      'Edit this search',
    'Start a new search' =>
      'Start a new search',
    'Long Format' =>
      'Long Format',
    'XML' =>
      'XML',
    'Time Summary' =>
      'Time Summary',
    'Graph' =>
      'Graph',
    'SCRUM' =>
      'SCRUM',
    'CSV' =>
      'CSV',
    'Print' =>
      'Print',
    'Buglist&nbsp;Feed' =>
      'Buglist&nbsp;Feed',
    'Activity&nbsp;Feed' =>
      'Activity&nbsp;Feed',
    'iCalendar' =>
      'iCalendar',
    'Change&nbsp;Columns' =>
      'Change&nbsp;Columns',
    'Change&nbsp;Several&nbsp;$terms.Bugs&nbsp;at&nbsp;Once' =>
      'Change&nbsp;Several&nbsp;$terms.Bugs&nbsp;at&nbsp;Once',
    'Fix Worktime' =>
      'Fix Worktime',
    'Send&nbsp;Mail&nbsp;to&nbsp;$terms.Bug&nbsp;Assignees' =>
      'Send&nbsp;Mail&nbsp;to&nbsp;$terms.Bug&nbsp;Assignees',
    'Edit&nbsp;Search' =>
      'Edit&nbsp;Search',
    'Summary&nbsp;Report' =>
      'Summary&nbsp;Report',
    'Forget&nbsp;Search&nbsp;\'' =>
      'Forget&nbsp;Search&nbsp;\'',
    'Remember search' =>
      'Remember search',
    'as' =>
      'as',
    'Query executed in' =>
      'Query executed in',
    'seconds. Page generated in $_query_template_time seconds.' =>
      'seconds. Page generated in $_query_template_time seconds.',
    'File a new $terms.bug' =>
      'File a new $terms.bug',
    'in the "' =>
      'in the "',
    '" product' =>
      '" product',
  },
  'list/quips.html.tmpl' => {
    '$terms.Bugzilla Quip System' =>
      '$terms.Bugzilla Quip System',
    'Add your own clever headline' =>
      'Add your own clever headline',
    'Your quip \'' =>
      'Your quip \'',
    '\' has been added.' =>
      '\' has been added.',
    'It will be used as soon as it gets approved.' =>
      'It will be used as soon as it gets approved.',
    'The quip \'' =>
      'The quip \'',
    '\' has been deleted.' =>
      '\' has been deleted.',
    'quips approved and' =>
      'quips approved and',
    'quips unapproved' =>
      'quips unapproved',
    '$terms.Bugzilla will pick a random quip for the headline on each $terms.bug list.' =>
      '$terms.Bugzilla will pick a random quip for the headline on each $terms.bug list.',
    'You can extend the quip list. Type in something clever or funny or boring (but not obscene or offensive, please) and bonk on the button.' =>
      'You can extend the quip list. Type in something clever or funny or boring (but not obscene or offensive, please) and bonk on the button.',
    'Note that your quip has to be approved before it is used.' =>
      'Note that your quip has to be approved before it is used.',
    'Add This Quip' =>
      'Add This Quip',
    'No new entries may be submitted at this time.' =>
      'No new entries may be submitted at this time.',
    'Existing quips:' =>
      'Existing quips:',
    'Edit existing quips:' =>
      'Edit existing quips:',
    '<strong>Note:</strong> Only approved quips will be shown. If the parameter \'quip_list_entry_control\' is set to' =>
      '<strong>Note:</strong> Only approved quips will be shown. If the parameter \'quip_list_entry_control\' is set to',
    ', entered quips are automatically approved.' =>
      ', entered quips are automatically approved.',
    'Quip' =>
      'Quip',
    'Author' =>
      'Author',
    'Action' =>
      'Action',
    'Approved' =>
      'Approved',
    'Unknown' =>
      'Unknown',
    'Delete' =>
      'Delete',
    'Uncheck All' =>
      'Uncheck All',
    'Check All' =>
      'Check All',
    'Save Changes' =>
      'Save Changes',
    'Those who like their wisdom in large doses can' =>
      'Those who like their wisdom in large doses can',
    'view' =>
      'view',
    'and edit' =>
      'and edit',
    'the whole quip list' =>
      'the whole quip list',
  },
  'list/server-push.html.tmpl' => {
    '$terms.Bugzilla is pondering your search' =>
      '$terms.Bugzilla is pondering your search',
    'Please stand by ...' =>
      'Please stand by ...',
  },
  'list/table.html.tmpl' => {
    'ID' =>
      'ID',
    'Apply' =>
      'Apply',
    'No values found' =>
      'No values found',
    'Filter' =>
      'Filter',
    '[SEC]' =>
      '[SEC]',
    '<b>Totals</b>' =>
      '<b>Totals</b>',
  },
  'pages/attach-multiple.html.tmpl' => {
    'Detect automatically' =>
      'Detect automatically',
    'Patch' =>
      'Patch',
    'clear' =>
      'clear',
    'Create Multiple Attachments to $terms.Bug' =>
      'Create Multiple Attachments to $terms.Bug',
    'Save Changes' =>
      'Save Changes',
    'Submit Bug' =>
      'Submit Bug',
    'Additional file selection boxes will appear as you select more files. Press <b>Save Changes</b> when you\'re finished.' =>
      'Additional file selection boxes will appear as you select more files. Press <b>Save Changes</b> when you\'re finished.',
    'File' =>
      'File',
    'Description' =>
      'Description',
    'Content type' =>
      'Content type',
  },
  'pages/bug-writing.html.tmpl' => {
    '$terms.Bug Writing Guidelines' =>
      '$terms.Bug Writing Guidelines',
    'Effective $terms.bug reports are the most likely to be fixed. These guidelines explain how to write such reports.' =>
      'Effective $terms.bug reports are the most likely to be fixed. These guidelines explain how to write such reports.',
    'Principles' =>
      'Principles',
    'Be precise' =>
      'Be precise',
    'Be clear - explain it so others can reproduce the $terms.bug' =>
      'Be clear - explain it so others can reproduce the $terms.bug',
    'One $terms.bug per report' =>
      'One $terms.bug per report',
    'No $terms.bug is too trivial to report - small $terms.bugs may hide big $terms.bugs' =>
      'No $terms.bug is too trivial to report - small $terms.bugs may hide big $terms.bugs',
    'Clearly separate fact from speculation' =>
      'Clearly separate fact from speculation',
    'Preliminaries' =>
      'Preliminaries',
    'Reproduce your $terms.bug using a recent build of the software, to see whether it has already been fixed.' =>
      'Reproduce your $terms.bug using a recent build of the software, to see whether it has already been fixed.',
    'Search' =>
      'Search',
    '$terms.Bugzilla, to see whether your $terms.bug has already been reported.' =>
      '$terms.Bugzilla, to see whether your $terms.bug has already been reported.',
    'Reporting a New $terms.Bug' =>
      'Reporting a New $terms.Bug',
    'If you have reproduced the $terms.bug in a recent build and no-one else appears to have reported it, then:' =>
      'If you have reproduced the $terms.bug in a recent build and no-one else appears to have reported it, then:',
    'Choose "' =>
      'Choose "',
    'Enter a new $terms.bug' =>
      'Enter a new $terms.bug',
    'Select the product in which you\'ve found the $terms.bug' =>
      'Select the product in which you\'ve found the $terms.bug',
    'Fill out the form. Here is some help understanding it:' =>
      'Fill out the form. Here is some help understanding it:',
    '<b>Component:</b> In which sub-part of the software does it exist?' =>
      '<b>Component:</b> In which sub-part of the software does it exist?',
    'This field is required. Click the word "Component" to see a description of each component. If none seems appropriate, look for a "General" component.' =>
      'This field is required. Click the word "Component" to see a description of each component. If none seems appropriate, look for a "General" component.',
    '<b>OS:</b> On which operating system (OS) did you find it? (e.g. Linux, Windows XP, Mac OS X.)' =>
      '<b>OS:</b> On which operating system (OS) did you find it? (e.g. Linux, Windows XP, Mac OS X.)',
    'If you know the $terms.bug happens on more than one type of operating system, choose <em>All</em>. If your OS isn\'t listed, choose <em>Other</em>.' =>
      'If you know the $terms.bug happens on more than one type of operating system, choose <em>All</em>. If your OS isn\'t listed, choose <em>Other</em>.',
    '<b>Summary:</b> How would you describe the $terms.bug, in approximately 60 or fewer characters?' =>
      '<b>Summary:</b> How would you describe the $terms.bug, in approximately 60 or fewer characters?',
    'A good summary should <b>quickly and uniquely identify $terms.abug report</b>. It should explain the problem, not your suggested solution.' =>
      'A good summary should <b>quickly and uniquely identify $terms.abug report</b>. It should explain the problem, not your suggested solution.',
    'Good: "' =>
      'Good: "',
    'Cancelling a File Copy dialog crashes File Manager' =>
      'Cancelling a File Copy dialog crashes File Manager',
    'Bad: "' =>
      'Bad: "',
    'Software crashes' =>
      'Software crashes',
    'Browser should work with my web site' =>
      'Browser should work with my web site',
    '<b>Description:</b> The details of your problem report, including:' =>
      '<b>Description:</b> The details of your problem report, including:',
    '<b>Overview:</b> More detailed restatement of summary.' =>
      '<b>Overview:</b> More detailed restatement of summary.',
    'Drag-selecting any page crashes Mac builds in the NSGetFactory function.' =>
      'Drag-selecting any page crashes Mac builds in the NSGetFactory function.',
    '<b>Steps to Reproduce:</b> Minimized, easy-to-follow steps that will trigger the $terms.bug. Include any special setup steps.' =>
      '<b>Steps to Reproduce:</b> Minimized, easy-to-follow steps that will trigger the $terms.bug. Include any special setup steps.',
    '1) View any web page. (I used the default sample page, resource:/res/samples/test0.html) 2) Drag-select the page. (Specifically, while holding down the mouse button, drag the mouse pointer downwards from any point in the browser\'s content region to the bottom of the browser\'s content region.)' =>
      '1) View any web page. (I used the default sample page, resource:/res/samples/test0.html) 2) Drag-select the page. (Specifically, while holding down the mouse button, drag the mouse pointer downwards from any point in the browser\'s content region to the bottom of the browser\'s content region.)',
    '<b>Actual Results:</b> What the application did after performing the above steps.' =>
      '<b>Actual Results:</b> What the application did after performing the above steps.',
    'The application crashed.' =>
      'The application crashed.',
    '<b>Expected Results:</b> What the application should have done, were the $terms.bug not present.' =>
      '<b>Expected Results:</b> What the application should have done, were the $terms.bug not present.',
    'The window should scroll downwards. Scrolled content should be selected. (Or, at least, the application should not crash.)' =>
      'The window should scroll downwards. Scrolled content should be selected. (Or, at least, the application should not crash.)',
    '<b>Build Date &amp; Platform:</b> Date and platform of the build in which you first encountered the $terms.bug.' =>
      '<b>Build Date &amp; Platform:</b> Date and platform of the build in which you first encountered the $terms.bug.',
    'Build 2006-08-10 on Mac OS 10.4.3' =>
      'Build 2006-08-10 on Mac OS 10.4.3',
    '<b>Additional Builds and Platforms:</b> Whether or not the $terms.bug takes place on other platforms (or browsers, if applicable).' =>
      '<b>Additional Builds and Platforms:</b> Whether or not the $terms.bug takes place on other platforms (or browsers, if applicable).',
    'Doesn\'t Occur On Build 2006-08-10 on Windows XP Home (Service Pack 2)' =>
      'Doesn\'t Occur On Build 2006-08-10 on Windows XP Home (Service Pack 2)',
    '<b>Additional Information:</b> Any other useful information.' =>
      '<b>Additional Information:</b> Any other useful information.',
    'For crashing $terms.bugs:' =>
      'For crashing $terms.bugs:',
    '<b>Windows:</b> Note the type of the crash, and the module that the application crashed in (e.g. access violation in apprunner.exe).' =>
      '<b>Windows:</b> Note the type of the crash, and the module that the application crashed in (e.g. access violation in apprunner.exe).',
    '<b>Mac OS X:</b> Attach the "Crash Reporter" log that appears upon crash. Only include the section directly below the crashing thread, usually titled "Thread 0 Crashed". Please do not paste the entire log!' =>
      '<b>Mac OS X:</b> Attach the "Crash Reporter" log that appears upon crash. Only include the section directly below the crashing thread, usually titled "Thread 0 Crashed". Please do not paste the entire log!',
    'Double-check your report for errors and omissions, then press "Commit". Your $terms.bug report will now be in the $terms.Bugzilla database.' =>
      'Double-check your report for errors and omissions, then press "Commit". Your $terms.bug report will now be in the $terms.Bugzilla database.',
  },
  'pages/fields.html.tmpl' => {
    'A $terms.Bug\'s Life Cycle' =>
      'A $terms.Bug\'s Life Cycle',
    'The <b>status</b> and <b>resolution</b> fields define and track the life cycle of $terms.abug.' =>
      'The <b>status</b> and <b>resolution</b> fields define and track the life cycle of $terms.abug.',
    'STATUS' =>
      'STATUS',
    'RESOLUTION' =>
      'RESOLUTION',
    'The <b>status</b> field indicates the general health of a $terms.bug. Only certain status transitions are allowed.' =>
      'The <b>status</b> field indicates the general health of a $terms.bug. Only certain status transitions are allowed.',
    'The <b>resolution</b> field indicates what happened to this $terms.bug.' =>
      'The <b>resolution</b> field indicates what happened to this $terms.bug.',
    '<b>UNCONFIRMED</b>' =>
      '<b>UNCONFIRMED</b>',
    'This $terms.bug has recently been added to the database. Nobody has validated that this $terms.bug is true. Users who have the "canconfirm" permission set may confirm this $terms.bug, changing its state to NEW. Or, it may be directly resolved and marked RESOLVED.' =>
      'This $terms.bug has recently been added to the database. Nobody has validated that this $terms.bug is true. Users who have the "canconfirm" permission set may confirm this $terms.bug, changing its state to NEW. Or, it may be directly resolved and marked RESOLVED.',
    '<b>NEW</b>' =>
      '<b>NEW</b>',
    'This $terms.bug has recently been added to the assignee\'s list of $terms.bugs and must be processed. $terms.Bugs in this state may be accepted, and become <b>ASSIGNED</b>, passed on to someone else, and remain <b>NEW</b>, or resolved and marked <b>RESOLVED</b>.' =>
      'This $terms.bug has recently been added to the assignee\'s list of $terms.bugs and must be processed. $terms.Bugs in this state may be accepted, and become <b>ASSIGNED</b>, passed on to someone else, and remain <b>NEW</b>, or resolved and marked <b>RESOLVED</b>.',
    '<b>ASSIGNED</b>' =>
      '<b>ASSIGNED</b>',
    'This $terms.bug is not yet resolved, but is assigned to the proper person. From here $terms.bugs can be given to another person and become <b>NEW</b>, or resolved and become <b>RESOLVED</b>.' =>
      'This $terms.bug is not yet resolved, but is assigned to the proper person. From here $terms.bugs can be given to another person and become <b>NEW</b>, or resolved and become <b>RESOLVED</b>.',
    '<b>REOPENED</b>' =>
      '<b>REOPENED</b>',
    'This $terms.bug was once resolved, but the resolution was deemed incorrect. For example, a <b>WORKSFORME</b> $terms.bug is <b>REOPENED</b> when more information shows up and the $terms.bug is now reproducible. From here $terms.bugs are either marked <b>ASSIGNED</b> or <b>RESOLVED</b>.' =>
      'This $terms.bug was once resolved, but the resolution was deemed incorrect. For example, a <b>WORKSFORME</b> $terms.bug is <b>REOPENED</b> when more information shows up and the $terms.bug is now reproducible. From here $terms.bugs are either marked <b>ASSIGNED</b> or <b>RESOLVED</b>.',
    'No resolution yet. All $terms.bugs which are in one of these "open" states have the resolution set to blank. All other $terms.bugs will be marked with one of the following resolutions.' =>
      'No resolution yet. All $terms.bugs which are in one of these "open" states have the resolution set to blank. All other $terms.bugs will be marked with one of the following resolutions.',
    '<b>RESOLVED</b>' =>
      '<b>RESOLVED</b>',
    'A resolution has been taken, and it is awaiting verification by QA. From here $terms.bugs are either re-opened and become <b>REOPENED</b>, are marked <b>VERIFIED</b>, or are closed for good and marked <b>CLOSED</b>.' =>
      'A resolution has been taken, and it is awaiting verification by QA. From here $terms.bugs are either re-opened and become <b>REOPENED</b>, are marked <b>VERIFIED</b>, or are closed for good and marked <b>CLOSED</b>.',
    '<b>VERIFIED</b>' =>
      '<b>VERIFIED</b>',
    'QA has looked at the $terms.bug and the resolution and agrees that the appropriate resolution has been taken. $terms.Bugs remain in this state until the product they were reported against actually ships, at which point they become <b>CLOSED</b>.' =>
      'QA has looked at the $terms.bug and the resolution and agrees that the appropriate resolution has been taken. $terms.Bugs remain in this state until the product they were reported against actually ships, at which point they become <b>CLOSED</b>.',
    '<b>CLOSED</b>' =>
      '<b>CLOSED</b>',
    'The $terms.bug is considered dead, the resolution is correct. Any zombie $terms.bugs who choose to walk the earth again must do so by becoming <b>REOPENED</b>.' =>
      'The $terms.bug is considered dead, the resolution is correct. Any zombie $terms.bugs who choose to walk the earth again must do so by becoming <b>REOPENED</b>.',
    '<b>FIXED</b>' =>
      '<b>FIXED</b>',
    'A fix for this $terms.bug is checked into the tree and tested.' =>
      'A fix for this $terms.bug is checked into the tree and tested.',
    '<b>INVALID</b>' =>
      '<b>INVALID</b>',
    'The problem described is not $terms.abug.' =>
      'The problem described is not $terms.abug.',
    '<b>WONTFIX</b>' =>
      '<b>WONTFIX</b>',
    'The problem described is $terms.abug which will never be fixed.' =>
      'The problem described is $terms.abug which will never be fixed.',
    '<b>DUPLICATE</b>' =>
      '<b>DUPLICATE</b>',
    'The problem is a duplicate of an existing $terms.bug. Marking $terms.abug duplicate requires the $terms.bug# of the duplicating $terms.bug and will at least put that $terms.bug number in the description field.' =>
      'The problem is a duplicate of an existing $terms.bug. Marking $terms.abug duplicate requires the $terms.bug# of the duplicating $terms.bug and will at least put that $terms.bug number in the description field.',
    '<b>WORKSFORME</b>' =>
      '<b>WORKSFORME</b>',
    'All attempts at reproducing this $terms.bug were futile, and reading the code produces no clues as to why the described behavior would occur. If more information appears later, the $terms.bug can be reopened.' =>
      'All attempts at reproducing this $terms.bug were futile, and reading the code produces no clues as to why the described behavior would occur. If more information appears later, the $terms.bug can be reopened.',
    '<b>MOVED</b>' =>
      '<b>MOVED</b>',
    'The problem was specific to a related product whose $terms.bugs are tracked in another $terms.bug database. The $terms.bug has been moved to that database.' =>
      'The problem was specific to a related product whose $terms.bugs are tracked in another $terms.bug database. The $terms.bug has been moved to that database.',
    'Importance' =>
      'Importance',
    'The importance of $terms.abug is described as the combination of its' =>
      'The importance of $terms.abug is described as the combination of its',
    'priority' =>
      'priority',
    'and' =>
      'and',
    'severity' =>
      'severity',
    ', as described below.' =>
      ', as described below.',
    'Priority' =>
      'Priority',
    'This field describes the importance and order in which $terms.abug should be fixed compared to other $terms.bugs. This field is utilized by the programmers/engineers to prioritize their work to be done.' =>
      'This field describes the importance and order in which $terms.abug should be fixed compared to other $terms.bugs. This field is utilized by the programmers/engineers to prioritize their work to be done.',
    'Severity' =>
      'Severity',
    'This field describes the impact of $terms.abug.' =>
      'This field describes the impact of $terms.abug.',
    'blocker' =>
      'blocker',
    'Blocks development and/or testing work' =>
      'Blocks development and/or testing work',
    'critical' =>
      'critical',
    'crashes, loss of data, severe memory leak' =>
      'crashes, loss of data, severe memory leak',
    'major' =>
      'major',
    'major loss of function' =>
      'major loss of function',
    'normal' =>
      'normal',
    'regular issue, some loss of functionality under specific circumstances' =>
      'regular issue, some loss of functionality under specific circumstances',
    'minor' =>
      'minor',
    'minor loss of function, or other problem where easy workaround is present' =>
      'minor loss of function, or other problem where easy workaround is present',
    'trivial' =>
      'trivial',
    'cosmetic problem like misspelled words or misaligned text' =>
      'cosmetic problem like misspelled words or misaligned text',
    'enhancement' =>
      'enhancement',
    'Request for enhancement' =>
      'Request for enhancement',
    'Platform' =>
      'Platform',
    'This is the hardware platform against which the $terms.bug was reported. Legal platforms include:' =>
      'This is the hardware platform against which the $terms.bug was reported. Legal platforms include:',
    'All (happens on all platforms; cross-platform $terms.bug)' =>
      'All (happens on all platforms; cross-platform $terms.bug)',
    'Macintosh' =>
      'Macintosh',
    'PC' =>
      'PC',
    '<b>Note:</b> When searching, selecting the option <em>All</em> does not select $terms.bugs assigned against any platform. It merely selects $terms.bugs that are marked as occurring on all platforms, i.e. are designated <em>All</em>.' =>
      '<b>Note:</b> When searching, selecting the option <em>All</em> does not select $terms.bugs assigned against any platform. It merely selects $terms.bugs that are marked as occurring on all platforms, i.e. are designated <em>All</em>.',
    'Operating System' =>
      'Operating System',
    'This is the operating system against which the $terms.bug was reported. Legal operating systems include:' =>
      'This is the operating system against which the $terms.bug was reported. Legal operating systems include:',
    'All (happens on all operating systems; cross-platform $terms.bug)' =>
      'All (happens on all operating systems; cross-platform $terms.bug)',
    'Windows' =>
      'Windows',
    'Mac OS' =>
      'Mac OS',
    'Linux' =>
      'Linux',
    'Sometimes the operating system implies the platform, but not always. For example, Linux can run on PC and Macintosh and others.' =>
      'Sometimes the operating system implies the platform, but not always. For example, Linux can run on PC and Macintosh and others.',
    'Assigned To' =>
      'Assigned To',
    'This is the person in charge of resolving the $terms.bug. Every time this field changes, the status changes to <b>NEW</b> to make it easy to see which new $terms.bugs have appeared on a person\'s list.' =>
      'This is the person in charge of resolving the $terms.bug. Every time this field changes, the status changes to <b>NEW</b> to make it easy to see which new $terms.bugs have appeared on a person\'s list.',
    'The default status for queries is set to NEW, ASSIGNED and REOPENED. When searching for $terms.bugs that have been resolved or verified, remember to set the status field appropriately.' =>
      'The default status for queries is set to NEW, ASSIGNED and REOPENED. When searching for $terms.bugs that have been resolved or verified, remember to set the status field appropriately.',
    'See Also' =>
      'See Also',
    'This allows you to refer to $terms.bugs in other installations. You can enter a URL to a $terms.bug in the "Add $terms.Bug URLs" field to note that that $terms.bug is related to this one. You can enter multiple URLs at once by separating them with a comma.' =>
      'This allows you to refer to $terms.bugs in other installations. You can enter a URL to a $terms.bug in the "Add $terms.Bug URLs" field to note that that $terms.bug is related to this one. You can enter multiple URLs at once by separating them with a comma.',
    'You should normally use this field to refer to $terms.bugs in <em>other</em> installations. For $terms.bugs in this installation, it is better to use the "Depends On" and "Blocks" fields.' =>
      'You should normally use this field to refer to $terms.bugs in <em>other</em> installations. For $terms.bugs in this installation, it is better to use the "Depends On" and "Blocks" fields.',
  },
  'pages/quicksearch.html.tmpl' => {
    '$terms.Bugzilla QuickSearch' =>
      '$terms.Bugzilla QuickSearch',
    'Type in one or more words (or pieces of words) to search for:' =>
      'Type in one or more words (or pieces of words) to search for:',
    'Search' =>
      'Search',
    'The Basics' =>
      'The Basics',
    'If you just put a word or series of words in the search box, $terms.Bugzilla will search the' =>
      'If you just put a word or series of words in the search box, $terms.Bugzilla will search the',
    'and' =>
      'and',
    'fields for your word or words.' =>
      'fields for your word or words.',
    'Typing just a <strong>number</strong> in the search box will take you directly to the $terms.bug with that ID.' =>
      'Typing just a <strong>number</strong> in the search box will take you directly to the $terms.bug with that ID.',
    'Also, just typing the <strong>alias</strong> of $terms.abug will take you to that $terms.bug.' =>
      'Also, just typing the <strong>alias</strong> of $terms.abug will take you to that $terms.bug.',
    'Adding more terms <strong>narrows down</strong> the search, it does not expand it. (In other words, $terms.Bugzilla searches for $terms.bugs that match <em>all</em> your criteria, not $terms.bugs that match <em>any</em> of your criteria.)' =>
      'Adding more terms <strong>narrows down</strong> the search, it does not expand it. (In other words, $terms.Bugzilla searches for $terms.bugs that match <em>all</em> your criteria, not $terms.bugs that match <em>any</em> of your criteria.)',
    'Searching is <strong>case-insensitive</strong>. So' =>
      'Searching is <strong>case-insensitive</strong>. So',
    'table' =>
      'table',
    'Table' =>
      'Table',
    ', and' =>
      ', and',
    'TABLE' =>
      'TABLE',
    'are all the same.' =>
      'are all the same.',
    '$terms.Bugzilla does not just search for the exact word you put in, but also for any word that <strong>contains</strong> that word. So, for example, searching for "cat" would also find $terms.bugs that contain it as part of other words&mdash;for example, $terms.abug mentioning "<strong>cat</strong>ch" or "certifi<strong>cat</strong>e". It will not find partial words in the' =>
      '$terms.Bugzilla does not just search for the exact word you put in, but also for any word that <strong>contains</strong> that word. So, for example, searching for "cat" would also find $terms.bugs that contain it as part of other words&mdash;for example, $terms.abug mentioning "<strong>cat</strong>ch" or "certifi<strong>cat</strong>e". It will not find partial words in the',
    'or' =>
      'or',
    'fields, though&mdash;only full words are matched, there.' =>
      'fields, though&mdash;only full words are matched, there.',
    'By default, only <strong>open</strong> $terms.bugs are searched. If you want to know how to also search closed $terms.bugs, see the' =>
      'By default, only <strong>open</strong> $terms.bugs are searched. If you want to know how to also search closed $terms.bugs, see the',
    'Advanced Shortcuts' =>
      'Advanced Shortcuts',
    'section.' =>
      'section.',
    'If you want to search <strong>specific fields</strong>, you do it like' =>
      'If you want to search <strong>specific fields</strong>, you do it like',
    'field:value' =>
      'field:value',
    ', where' =>
      ', where',
    'field' =>
      'field',
    'is one of the' =>
      'is one of the',
    'field names' =>
      'field names',
    'lower down in this document and' =>
      'lower down in this document and',
    'value' =>
      'value',
    'is the value you want to search for in that field. If you put commas in the' =>
      'is the value you want to search for in that field. If you put commas in the',
    ', then it is interpreted as a list of values, and $terms.bugs that match <em>any</em> of those values will be searched for.' =>
      ', then it is interpreted as a list of values, and $terms.bugs that match <em>any</em> of those values will be searched for.',
    'You may also want to read up on the' =>
      'You may also want to read up on the',
    'Advanced Features' =>
      'Advanced Features',
    'Fields You Can Search On' =>
      'Fields You Can Search On',
    'You can specify any of these fields like' =>
      'You can specify any of these fields like',
    'in the search box, to search on them. You can also abbreviate the field name, as long as your abbreviation matches only one field name. So, for example, searching on' =>
      'in the search box, to search on them. You can also abbreviate the field name, as long as your abbreviation matches only one field name. So, for example, searching on',
    'stat:NEW' =>
      'stat:NEW',
    'will find all $terms.bugs in the' =>
      'will find all $terms.bugs in the',
    'NEW' =>
      'NEW',
    'status. Some fields have multiple names, and you can use any of those names to search for them.' =>
      'status. Some fields have multiple names, and you can use any of those names to search for them.',
    'For custom fields, they can be used and abbreviated based on the part of their name <em>after</em> the' =>
      'For custom fields, they can be used and abbreviated based on the part of their name <em>after</em> the',
    'if you\'d like, in addition to their standard name starting with' =>
      'if you\'d like, in addition to their standard name starting with',
    '. So for example,' =>
      '. So for example,',
    'can be referred to as' =>
      'can be referred to as',
    ', also. However, if this causes a conflict between the standard $terms.Bugzilla field names and the custom field names, the standard field names always take precedence.' =>
      ', also. However, if this causes a conflict between the standard $terms.Bugzilla field names and the custom field names, the standard field names always take precedence.',
    'Field' =>
      'Field',
    'Field Name(s) For Search' =>
      'Field Name(s) For Search',
    'If you want to search for a <strong>phrase</strong> or something that contains spaces, you can put it in quotes, like:' =>
      'If you want to search for a <strong>phrase</strong> or something that contains spaces, you can put it in quotes, like:',
    '"this is a phrase"' =>
      '"this is a phrase"',
    '. You can also use quotes to search for characters that would otherwise be interpreted specially by quicksearch. For example,' =>
      '. You can also use quotes to search for characters that would otherwise be interpreted specially by quicksearch. For example,',
    '"this|thing"' =>
      '"this|thing"',
    'would search for the literal phrase <em>this|thing</em>.' =>
      'would search for the literal phrase <em>this|thing</em>.',
    'You can use <strong>AND</strong>, <strong>NOT</strong>, and <strong>OR</strong> in searches. You can also use' =>
      'You can use <strong>AND</strong>, <strong>NOT</strong>, and <strong>OR</strong> in searches. You can also use',
    'to mean "NOT", and' =>
      'to mean "NOT", and',
    'to mean "OR". There is no special character for "AND", because by default any search terms that are separated by a space are joined by an "AND". Examples:' =>
      'to mean "OR". There is no special character for "AND", because by default any search terms that are separated by a space are joined by an "AND". Examples:',
    '<strong>NOT</strong>:' =>
      '<strong>NOT</strong>:',
    'Use' =>
      'Use',
    '<strong>-</strong><em>summary:foo</em>' =>
      '<strong>-</strong><em>summary:foo</em>',
    'to exclude $terms.bugs with' =>
      'to exclude $terms.bugs with',
    'foo' =>
      'foo',
    'in the summary.' =>
      'in the summary.',
    '<em>NOT summary:foo</em>' =>
      '<em>NOT summary:foo</em>',
    'would have the same effect.' =>
      'would have the same effect.',
    '<strong>AND</strong>:' =>
      '<strong>AND</strong>:',
    '<em>foo bar</em>' =>
      '<em>foo bar</em>',
    'searches for $terms.bugs that contains both' =>
      'searches for $terms.bugs that contains both',
    'bar' =>
      'bar',
    '<em>foo AND bar</em>' =>
      '<em>foo AND bar</em>',
    '<strong>OR</strong>:' =>
      '<strong>OR</strong>:',
    '<em>foo<strong>|</strong>bar</em>' =>
      '<em>foo<strong>|</strong>bar</em>',
    'would search for $terms.bugs that contain' =>
      'would search for $terms.bugs that contain',
    'OR' =>
      'OR',
    '<em>foo OR bar</em>' =>
      '<em>foo OR bar</em>',
    'OR has higher precedence than AND; AND is the top level operation. For example:' =>
      'OR has higher precedence than AND; AND is the top level operation. For example:',
    'Searching for <em>' =>
      'Searching for <em>',
    'url|location bar|field -focus' =>
      'url|location bar|field -focus',
    '</em> means (' =>
      '</em> means (',
    'url' =>
      'url',
    'location' =>
      'location',
    ') AND (' =>
      ') AND (',
    ') AND (NOT' =>
      ') AND (NOT',
    'focus' =>
      'focus',
    'In addition to using' =>
      'In addition to using',
    'to search specific fields, there are certain characters or words that you can use as a "shortcut" for searching certain fields:' =>
      'to search specific fields, there are certain characters or words that you can use as a "shortcut" for searching certain fields:',
    'Shortcut(s)' =>
      'Shortcut(s)',
    'Make the <strong>first word</strong> of your search the name of any status, or even an abbreviation of any status, and $terms.bugs in that status will be searched. <strong>' =>
      'Make the <strong>first word</strong> of your search the name of any status, or even an abbreviation of any status, and $terms.bugs in that status will be searched. <strong>',
    'ALL' =>
      'ALL',
    '</strong> is a special shortcut that means "all statuses". <strong>' =>
      '</strong> is a special shortcut that means "all statuses". <strong>',
    'OPEN' =>
      'OPEN',
    '</strong> is a special shortcut that means "all open statuses".' =>
      '</strong> is a special shortcut that means "all open statuses".',
    'Make the <strong>first word</strong> of your search the name of any resolution, or even an abbreviation of any resolution, and $terms.bugs with that resolution will be searched. For example, making' =>
      'Make the <strong>first word</strong> of your search the name of any resolution, or even an abbreviation of any resolution, and $terms.bugs with that resolution will be searched. For example, making',
    'FIX' =>
      'FIX',
    'the first word of your search will find all $terms.bugs with a resolution of' =>
      'the first word of your search will find all $terms.bugs with a resolution of',
    'FIXED' =>
      'FIXED',
    '"<strong>P1</strong>" (as a word anywhere in the search) means "find $terms.bugs with the highest priority. "P2" means the second-highest priority, and so on.' =>
      '"<strong>P1</strong>" (as a word anywhere in the search) means "find $terms.bugs with the highest priority. "P2" means the second-highest priority, and so on.',
    'Searching for "<strong>P1-P3</strong>" will find $terms.bugs in any of the three highest priorities, and so on.' =>
      'Searching for "<strong>P1-P3</strong>" will find $terms.bugs in any of the three highest priorities, and so on.',
    '<strong>@</strong><em>value</em>' =>
      '<strong>@</strong><em>value</em>',
    '<strong>:</strong><em>value</em>' =>
      '<strong>:</strong><em>value</em>',
    '<strong>!</strong><em>value</em>' =>
      '<strong>!</strong><em>value</em>',
    'flagtypes.name' =>
      'flagtypes.name',
    '<em>flag</em><strong>?</strong><em>requestee</em>' =>
      '<em>flag</em><strong>?</strong><em>requestee</em>',
    '<strong>#</strong><em>value</em>' =>
      '<strong>#</strong><em>value</em>',
    '<strong>[</strong><em>value</em>' =>
      '<strong>[</strong><em>value</em>',
  },
  'pages/release-notes.html.tmpl' => {
    '$terms.Bugzilla 3.6 Release Notes' =>
      '$terms.Bugzilla 3.6 Release Notes',
    'Table of Contents' =>
      'Table of Contents',
    'Introduction' =>
      'Introduction',
    'Updates in this 3.6.x Release' =>
      'Updates in this 3.6.x Release',
    'Minimum Requirements' =>
      'Minimum Requirements',
    'New Features and Improvements' =>
      'New Features and Improvements',
    'Outstanding Issues' =>
      'Outstanding Issues',
    'Notes On Upgrading From a Previous Version' =>
      'Notes On Upgrading From a Previous Version',
    'Code Changes Which May Affect Customizations' =>
      'Code Changes Which May Affect Customizations',
    'Release Notes for Previous Versions' =>
      'Release Notes for Previous Versions',
    'Welcome to $terms.Bugzilla 3.6! The focus of the 3.6 release is on improving usability and "polishing up" all our features (by adding some pieces that were "missing" or always wanted), although we also have a few great new features for you, as well!' =>
      'Welcome to $terms.Bugzilla 3.6! The focus of the 3.6 release is on improving usability and "polishing up" all our features (by adding some pieces that were "missing" or always wanted), although we also have a few great new features for you, as well!',
    'If you\'re upgrading, make sure to read' =>
      'If you\'re upgrading, make sure to read',
    '. If you are upgrading from a release before 3.4, make sure to read the release notes for all the' =>
      '. If you are upgrading from a release before 3.4, make sure to read the release notes for all the',
    'previous versions' =>
      'previous versions',
    'in between your version and this one, <strong>particularly the Upgrading section of each version\'s release notes</strong>.' =>
      'in between your version and this one, <strong>particularly the Upgrading section of each version\'s release notes</strong>.',
    'We would like to thank' =>
      'We would like to thank',
    'Canonical Ltd.' =>
      'Canonical Ltd.',
    'ITA Software' =>
      'ITA Software',
    ', the' =>
      ', the',
    'IBM Linux Technology Center' =>
      'IBM Linux Technology Center',
    'Red Hat' =>
      'Red Hat',
    ', and' =>
      ', and',
    'Novell' =>
      'Novell',
    'for funding the development of various features and improvements in this release of $terms.Bugzilla.' =>
      'for funding the development of various features and improvements in this release of $terms.Bugzilla.',
    'This release fixes several security issues, some of which are <strong>highly critical</strong>. See the' =>
      'This release fixes several security issues, some of which are <strong>highly critical</strong>. See the',
    'Security Advisory' =>
      'Security Advisory',
    'for details.' =>
      'for details.',
    'In addition, the following important fixes/changes have been made in this release:' =>
      'In addition, the following important fixes/changes have been made in this release:',
    'Due to one of the security fixes, $terms.Bugzilla 3.6.4 now requires a newer version of the CGI.pm Perl module than previous releases of $terms.Bugzilla did. When you run' =>
      'Due to one of the security fixes, $terms.Bugzilla 3.6.4 now requires a newer version of the CGI.pm Perl module than previous releases of $terms.Bugzilla did. When you run',
    'checksetup.pl' =>
      'checksetup.pl',
    ', it will inform you how to upgrade your CGI.pm module.' =>
      ', it will inform you how to upgrade your CGI.pm module.',
    'When replying to a comment with a link like "attachment 1234 [details]", the "[details]" link will no longer be duplicated in your reply. (' =>
      'When replying to a comment with a link like "attachment 1234 [details]", the "[details]" link will no longer be duplicated in your reply. (',
    'Using Quicksearch no longer requires that the' =>
      'Using Quicksearch no longer requires that the',
    'List::MoreUtils' =>
      'List::MoreUtils',
    'module be installed. (' =>
      'module be installed. (',
    'When using' =>
      'When using',
    ', information about products now includes' =>
      ', information about products now includes',
    'allows_unconfirmed' =>
      'allows_unconfirmed',
    'When using tabular reports, any value whose name started with a period or an underscore wasn\'t being displayed. (' =>
      'When using tabular reports, any value whose name started with a period or an underscore wasn\'t being displayed. (',
    'This release fixes various important security issues. See the' =>
      'This release fixes various important security issues. See the',
    'Clicking the "Submit only my new comment" button on the mid-air collision page will no longer result in a "Form field longdesclength was not defined" error. (' =>
      'Clicking the "Submit only my new comment" button on the mid-air collision page will no longer result in a "Form field longdesclength was not defined" error. (',
    'Saving a search with either of the deadline fields set to "Now" would cause that deadline field to be removed from the saved search. (' =>
      'Saving a search with either of the deadline fields set to "Now" would cause that deadline field to be removed from the saved search. (',
    'Searching for $terms.bugs "with at least X votes" was instead returning $terms.bugs with <em>exactly</em> that many votes. (' =>
      'Searching for $terms.bugs "with at least X votes" was instead returning $terms.bugs with <em>exactly</em> that many votes. (',
    'Typing something like "P1-5" in the quicksearch box should have been searching the' =>
      'Typing something like "P1-5" in the quicksearch box should have been searching the',
    'field, but it was not. (' =>
      'field, but it was not. (',
    'Users who had passwords less than 6 characters long couldn\'t log in. Such users could only exist before 3.6, so it looked like after upgrading to 3.6, certain users couldn\'t log in. (' =>
      'Users who had passwords less than 6 characters long couldn\'t log in. Such users could only exist before 3.6, so it looked like after upgrading to 3.6, certain users couldn\'t log in. (',
    'Loading' =>
      'Loading',
    'should now be faster, particularly on installations that have many flags. (' =>
      'should now be faster, particularly on installations that have many flags. (',
    'and' =>
      'and',
    'Non-english templates were not being precompiled by checksetup.pl, leading to reduced performance for localized $terms.Bugzilla installations. (' =>
      'Non-english templates were not being precompiled by checksetup.pl, leading to reduced performance for localized $terms.Bugzilla installations. (',
    'This release fixes various security issues. See the' =>
      'This release fixes various security issues. See the',
    '$terms.Bugzilla installations running on older versions of IIS will no longer experience the "Undef to trick_taint" errors that would sometimes occur. (' =>
      '$terms.Bugzilla installations running on older versions of IIS will no longer experience the "Undef to trick_taint" errors that would sometimes occur. (',
    'Email notifications were missing the dates that comments were made. (' =>
      'Email notifications were missing the dates that comments were made. (',
    'Putting a phrase in quotes in the Quicksearch box now works properly, again. (' =>
      'Putting a phrase in quotes in the Quicksearch box now works properly, again. (',
    'Quicksearch was usually (incorrectly) being limited to 200 results. (' =>
      'Quicksearch was usually (incorrectly) being limited to 200 results. (',
    'On Windows,' =>
      'On Windows,',
    'install-module.pl' =>
      'install-module.pl',
    'can now properly install DateTime and certain other Perl modules that didn\'t install properly before. (' =>
      'can now properly install DateTime and certain other Perl modules that didn\'t install properly before. (',
    'Searching "keywords" for "contains none of the words" or "does not match regular expression" now works properly. (' =>
      'Searching "keywords" for "contains none of the words" or "does not match regular expression" now works properly. (',
    'Doing' =>
      'Doing',
    'collectstats.pl --regenerate' =>
      'collectstats.pl --regenerate',
    'now works on installations using PostgreSQL. (' =>
      'now works on installations using PostgreSQL. (',
    'The "Field Values" administrative control panel was sometimes denying admins the ability to delete field values when there was no reason to deny the deletion. (' =>
      'The "Field Values" administrative control panel was sometimes denying admins the ability to delete field values when there was no reason to deny the deletion. (',
    'Eliminate the "uninitialized value" warnings that would happen when editing a product\'s components. (' =>
      'Eliminate the "uninitialized value" warnings that would happen when editing a product\'s components. (',
    'The updating of bugs_fulltext that happens during' =>
      'The updating of bugs_fulltext that happens during',
    'for upgrades to 3.6 should now be MUCH faster. (' =>
      'for upgrades to 3.6 should now be MUCH faster. (',
    'email_in.pl' =>
      'email_in.pl',
    'was not allowing the setting of time-tracking fields via inbound emails. (' =>
      'was not allowing the setting of time-tracking fields via inbound emails. (',
    'This release fixes two security issues. See the' =>
      'This release fixes two security issues. See the',
    'Using the "Change Columns" page would sometimes result in a plain-text page instead of HTML. (' =>
      'Using the "Change Columns" page would sometimes result in a plain-text page instead of HTML. (',
    'Extensions that have only templates and no code are now working. (' =>
      'Extensions that have only templates and no code are now working. (',
    'has been fixed so that it installs modules properly on both new and old versions of Perl. (' =>
      'has been fixed so that it installs modules properly on both new and old versions of Perl. (',
    'It is now possible to upgrade from 3.4 to 3.6 when using Oracle. (' =>
      'It is now possible to upgrade from 3.4 to 3.6 when using Oracle. (',
    'Editing a field value\'s name (using the Field Values admin control panel) wasn\'t working if the value was set as the default for that field. (' =>
      'Editing a field value\'s name (using the Field Values admin control panel) wasn\'t working if the value was set as the default for that field. (',
    'If you had the' =>
      'If you had the',
    'noresolveonopenblockers' =>
      'noresolveonopenblockers',
    'parameter set, $terms.bugs couldn\'t be edited at all if they were marked FIXED and had any open blockers. (The parameter is only supposed to prevent <em>changing</em> $terms.bugs to FIXED, not modifying already-FIXED $terms.bugs.) (' =>
      'parameter set, $terms.bugs couldn\'t be edited at all if they were marked FIXED and had any open blockers. (The parameter is only supposed to prevent <em>changing</em> $terms.bugs to FIXED, not modifying already-FIXED $terms.bugs.) (',
    'Some minor issues with Perl 5.12 were fixed (mostly warnings that Perl 5.12 was throwing). $terms.Bugzilla now supports Perl 5.12.' =>
      'Some minor issues with Perl 5.12 were fixed (mostly warnings that Perl 5.12 was throwing). $terms.Bugzilla now supports Perl 5.12.',
    'Any requirements that are new since 3.4.5 will look like' =>
      'Any requirements that are new since 3.4.5 will look like',
    'this' =>
      'this',
    'Perl' =>
      'Perl',
    'For MySQL Users' =>
      'For MySQL Users',
    'For PostgreSQL Users' =>
      'For PostgreSQL Users',
    'For Oracle Users' =>
      'For Oracle Users',
    'Required Perl Modules' =>
      'Required Perl Modules',
    'Optional Perl Modules' =>
      'Optional Perl Modules',
    'Perl v5.8.1' =>
      'Perl v5.8.1',
    'CGI.pm' =>
      'CGI.pm',
    'The following perl modules, if installed, enable various features of $terms.Bugzilla:' =>
      'The following perl modules, if installed, enable various features of $terms.Bugzilla:',
    'JSON-RPC' =>
      'JSON-RPC',
    'Test-Taint' =>
      'Test-Taint',
    'Math-Random-Secure' =>
      'Math-Random-Secure',
    'Chart' =>
      'Chart',
    'General Usability Improvements' =>
      'General Usability Improvements',
    'New Extensions System' =>
      'New Extensions System',
    'Improved Quicksearch' =>
      'Improved Quicksearch',
    'Simple "Browse" Interface' =>
      'Simple "Browse" Interface',
    'SUExec Support' =>
      'SUExec Support',
    'Experimental mod_perl Support on Windows' =>
      'Experimental mod_perl Support on Windows',
    'Send Attachments by Email' =>
      'Send Attachments by Email',
    'JSON-RPC Interface' =>
      'JSON-RPC Interface',
    'Migration From Other $terms.Bug-Trackers' =>
      'Migration From Other $terms.Bug-Trackers',
    'Other Enhancements and Changes' =>
      'Other Enhancements and Changes',
    'A' =>
      'A',
    'scientific usability study' =>
      'scientific usability study',
    'was done on $terms.Bugzilla by researchers from Carnegie-Mellon University. As a result of this study,' =>
      'was done on $terms.Bugzilla by researchers from Carnegie-Mellon University. As a result of this study,',
    'several usability issues' =>
      'several usability issues',
    'were prioritized to be fixed, based on specific data from the study.' =>
      'were prioritized to be fixed, based on specific data from the study.',
    'As a result, you will see many small improvements in $terms.Bugzilla\'s usability, such as using Javascript to validate certain forms before they are submitted, standardizing the words that we use in the user interface, being clearer about what $terms.Bugzilla needs from the user, and other changes, all of which are also listed individually in this New Features section.' =>
      'As a result, you will see many small improvements in $terms.Bugzilla\'s usability, such as using Javascript to validate certain forms before they are submitted, standardizing the words that we use in the user interface, being clearer about what $terms.Bugzilla needs from the user, and other changes, all of which are also listed individually in this New Features section.',
    'Work continues on improving usability for the next release of $terms.Bugzilla, but the results of the research have already had an impact on this 3.6 release.' =>
      'Work continues on improving usability for the next release of $terms.Bugzilla, but the results of the research have already had an impact on this 3.6 release.',
    '$terms.Bugzilla has a brand-new Extensions system. The system is consistent, fast, and' =>
      '$terms.Bugzilla has a brand-new Extensions system. The system is consistent, fast, and',
    'fully documented' =>
      'fully documented',
    '. It makes it possible to easily extend $terms.Bugzilla\'s code and user interface to add new features or change existing features. There\'s even' =>
      '. It makes it possible to easily extend $terms.Bugzilla\'s code and user interface to add new features or change existing features. There\'s even',
    'a script' =>
      'a script',
    'that will create the basic layout of an extension for you, to help you get started. For more information about the new system, see the' =>
      'that will create the basic layout of an extension for you, to help you get started. For more information about the new system, see the',
    'Extensions documentation' =>
      'Extensions documentation',
    'If you had written any extensions using $terms.Bugzilla\'s previous extensions system, there is' =>
      'If you had written any extensions using $terms.Bugzilla\'s previous extensions system, there is',
    'a script to help convert old extensions into the new format' =>
      'a script to help convert old extensions into the new format',
    'The "quicksearch" box that appears on the front page of $terms.Bugzilla and in the header/footer of every page is now simplified and made more powerful. There is a' =>
      'The "quicksearch" box that appears on the front page of $terms.Bugzilla and in the header/footer of every page is now simplified and made more powerful. There is a',
    'link next to the box that will take you to the simplified' =>
      'link next to the box that will take you to the simplified',
    'Quicksearch Help' =>
      'Quicksearch Help',
    ', which describes every single feature of the system in a simple layout, including new features such as the ability to use partial field names when searching.' =>
      ', which describes every single feature of the system in a simple layout, including new features such as the ability to use partial field names when searching.',
    'Quicksearch should also be much faster than it was before, particularly on large installations.' =>
      'Quicksearch should also be much faster than it was before, particularly on large installations.',
    'Note that in order to implement the new quicksearch, certain old and rarely-used features had to be removed:' =>
      'Note that in order to implement the new quicksearch, certain old and rarely-used features had to be removed:',
    '<b>+</b> as a prefix to mean "search additional resolutions", and <b>+</b> as a prefix to mean "search just the summary". You can instead use' =>
      '<b>+</b> as a prefix to mean "search additional resolutions", and <b>+</b> as a prefix to mean "search just the summary". You can instead use',
    'summary:' =>
      'summary:',
    'to explicitly search summaries.' =>
      'to explicitly search summaries.',
    'Searching the Severity field if you type something that matches the first few characters of a severity. You can explicitly search the Severity field if you want to find $terms.bugs by severity.' =>
      'Searching the Severity field if you type something that matches the first few characters of a severity. You can explicitly search the Severity field if you want to find $terms.bugs by severity.',
    'Searching the Priority field if you typed something that exactly matched the name of a priority. You can explicitly search the Priority field if you want to find $terms.bugs by priority.' =>
      'Searching the Priority field if you typed something that exactly matched the name of a priority. You can explicitly search the Priority field if you want to find $terms.bugs by priority.',
    'Searching the Platform and OS fields if you typed in one of a certain hard-coded list of strings (like "pc", "windows", etc.). You can explicitly search these fields, instead, if you want to find $terms.bugs with a specific Platform or OS set.' =>
      'Searching the Platform and OS fields if you typed in one of a certain hard-coded list of strings (like "pc", "windows", etc.). You can explicitly search these fields, instead, if you want to find $terms.bugs with a specific Platform or OS set.',
    'There is now a "Browse" link in the header of each $terms.Bugzilla page that presents a very basic interface that allows users to simply browse through all open $terms.bugs in particular components.' =>
      'There is now a "Browse" link in the header of each $terms.Bugzilla page that presents a very basic interface that allows users to simply browse through all open $terms.bugs in particular components.',
    '$terms.Bugzilla can now be run in Apache\'s "SUExec" mode, which is what control panel software like cPanel and Plesk use (so $terms.Bugzilla should now be much easier to install on shared hosting). SUExec support shows up as an option in the' =>
      '$terms.Bugzilla can now be run in Apache\'s "SUExec" mode, which is what control panel software like cPanel and Plesk use (so $terms.Bugzilla should now be much easier to install on shared hosting). SUExec support shows up as an option in the',
    'localconfig' =>
      'localconfig',
    'file during installation.' =>
      'file during installation.',
    'There is now experimental support for running $terms.Bugzilla under mod_perl on Windows, for a significant performance enhancement (in exchange for using more memory).' =>
      'There is now experimental support for running $terms.Bugzilla under mod_perl on Windows, for a significant performance enhancement (in exchange for using more memory).',
    'The' =>
      'The',
    'email_in' =>
      'email_in',
    'script now supports attaching multiple attachments to $terms.abug by email, both when filing and when updating $terms.abug.' =>
      'script now supports attaching multiple attachments to $terms.abug by email, both when filing and when updating $terms.abug.',
    '$terms.Bugzilla now has support for the' =>
      '$terms.Bugzilla now has support for the',
    'WebServices protocol via' =>
      'WebServices protocol via',
    '. The JSON-RPC interface is experimental in this release--if you want any fundamental changes in how it works,' =>
      '. The JSON-RPC interface is experimental in this release--if you want any fundamental changes in how it works,',
    'let us know' =>
      'let us know',
    ', for the next release of $terms.Bugzilla.' =>
      ', for the next release of $terms.Bugzilla.',
    '$terms.Bugzilla 3.6 comes with a new script,' =>
      '$terms.Bugzilla 3.6 comes with a new script,',
    'migrate.pl' =>
      'migrate.pl',
    ', which allows migration from other $terms.bug-tracking systems. Among the various features of the migration system are:' =>
      ', which allows migration from other $terms.bug-tracking systems. Among the various features of the migration system are:',
    'It is non-destructive--you can migrate into an existing $terms.Bugzilla installation without destroying any data in the installation.' =>
      'It is non-destructive--you can migrate into an existing $terms.Bugzilla installation without destroying any data in the installation.',
    'It has a "dry-run" mode so you can test your migration before actually running it.' =>
      'It has a "dry-run" mode so you can test your migration before actually running it.',
    'It is relatively easy to write new migrators for new systems, if you know Perl. The basic migration framework does most of the work for you, you just have to provide it with the data from your $terms.bug-tracker. See the' =>
      'It is relatively easy to write new migrators for new systems, if you know Perl. The basic migration framework does most of the work for you, you just have to provide it with the data from your $terms.bug-tracker. See the',
    'Bugzilla::Migrate' =>
      'Bugzilla::Migrate',
    'documentation and see our current migrator,' =>
      'documentation and see our current migrator,',
    'Bugzilla/Migrate/GNATS.pm' =>
      'Bugzilla/Migrate/GNATS.pm',
    'for information on how to make your own migrator.' =>
      'for information on how to make your own migrator.',
    'The first migrator that has been implemented is for the GNATS $terms.bug-tracking system. We\'d love to see migrators for other systems! If you want to contribute a new migrator, see our' =>
      'The first migrator that has been implemented is for the GNATS $terms.bug-tracking system. We\'d love to see migrators for other systems! If you want to contribute a new migrator, see our',
    'development process' =>
      'development process',
    'for details on how to get code into $terms.Bugzilla.' =>
      'for details on how to get code into $terms.Bugzilla.',
    'Thanks to' =>
      'Thanks to',
    'Lambda Research' =>
      'Lambda Research',
    'for funding the initial development of this feature.' =>
      'for funding the initial development of this feature.',
    'Enhancements for Users' =>
      'Enhancements for Users',
    '<b>$terms.Bug Filing:</b> When filing $terms.abug, $terms.Bugzilla now visually indicates which fields are mandatory.' =>
      '<b>$terms.Bug Filing:</b> When filing $terms.abug, $terms.Bugzilla now visually indicates which fields are mandatory.',
    '<b>$terms.Bug Filing:</b> "Bookmarkable templates" now support the "alias" and "estimated hours" fields.' =>
      '<b>$terms.Bug Filing:</b> "Bookmarkable templates" now support the "alias" and "estimated hours" fields.',
    '<b>$terms.Bug Editing:</b> In previous versions of $terms.Bugzilla, if you added a private comment to $terms.abug, then <em>none</em> of the changes that you made at that time were sent to users who couldn\'t see the private comment. Now, for users who can\'t see private comments, public changes are sent, but the private comment is excluded from their email notification.' =>
      '<b>$terms.Bug Editing:</b> In previous versions of $terms.Bugzilla, if you added a private comment to $terms.abug, then <em>none</em> of the changes that you made at that time were sent to users who couldn\'t see the private comment. Now, for users who can\'t see private comments, public changes are sent, but the private comment is excluded from their email notification.',
    '<b>$terms.Bug Editing:</b> The controls for groups now appear to the right of the attachment and time-tracking tables, when editing $terms.abug.' =>
      '<b>$terms.Bug Editing:</b> The controls for groups now appear to the right of the attachment and time-tracking tables, when editing $terms.abug.',
    '<b>$terms.Bug Editing:</b> The "Collapse All Comments" and "Expand All Comments" links now appear to the right of the comment list instead of above it.' =>
      '<b>$terms.Bug Editing:</b> The "Collapse All Comments" and "Expand All Comments" links now appear to the right of the comment list instead of above it.',
    '<b>$terms.Bug Editing:</b> The See Also field now supports URLs for Google Code Issues and the Debian B' =>
      '<b>$terms.Bug Editing:</b> The See Also field now supports URLs for Google Code Issues and the Debian B',
    'ug-Tracking System.' =>
      'ug-Tracking System.',
    '<b>$terms.Bug Editing:</b> There have been significant performance improvements in' =>
      '<b>$terms.Bug Editing:</b> There have been significant performance improvements in',
    '(the script that displays the $terms.bug-editing form), particularly for $terms.bugs that have lots of comments or attachments.' =>
      '(the script that displays the $terms.bug-editing form), particularly for $terms.bugs that have lots of comments or attachments.',
    '<b>Attachments:</b> The "Details" page of an attachment now displays itself as uneditable if you can\'t edit the fields there.' =>
      '<b>Attachments:</b> The "Details" page of an attachment now displays itself as uneditable if you can\'t edit the fields there.',
    '<b>Attachments:</b> We now make sure that there is a Description specified for an attachment, using JavaScript, before the form is submitted.' =>
      '<b>Attachments:</b> We now make sure that there is a Description specified for an attachment, using JavaScript, before the form is submitted.',
    '<b>Attachments:</b> There is now a link back to the $terms.bug at the bottom of the "Details" page for an attachment.' =>
      '<b>Attachments:</b> There is now a link back to the $terms.bug at the bottom of the "Details" page for an attachment.',
    '<b>Attachments:</b> When you click on an "attachment 12345" link in a comment, if the attachment is a patch, you will now see the formatted "Diff" view instead of the raw patch.' =>
      '<b>Attachments:</b> When you click on an "attachment 12345" link in a comment, if the attachment is a patch, you will now see the formatted "Diff" view instead of the raw patch.',
    '<b>Attachments</b>: For text attachments, we now let the browser auto-detect the character encoding, instead of forcing the browser to always assume the attachment is in UTF-8.' =>
      '<b>Attachments</b>: For text attachments, we now let the browser auto-detect the character encoding, instead of forcing the browser to always assume the attachment is in UTF-8.',
    '<b>Search:</b> You can now display $terms.bug flags as a column in search results.' =>
      '<b>Search:</b> You can now display $terms.bug flags as a column in search results.',
    '<b>Search:</b> When viewing search results, you can see which columns are being sorted on, and which direction the sort is on, as indicated by arrows next to the column headers.' =>
      '<b>Search:</b> When viewing search results, you can see which columns are being sorted on, and which direction the sort is on, as indicated by arrows next to the column headers.',
    '<b>Search:</b> You can now search the Deadline field using relative dates (like "1d", "2w", etc.).' =>
      '<b>Search:</b> You can now search the Deadline field using relative dates (like "1d", "2w", etc.).',
    '<b>Search:</b> The iCalendar format of search results now includes a PRIORITY field.' =>
      '<b>Search:</b> The iCalendar format of search results now includes a PRIORITY field.',
    '<b>Search:</b> It is no longer an error to enter an invalid search order in a search URL--$terms.Bugzilla will simply warn you that some of your order options are invalid.' =>
      '<b>Search:</b> It is no longer an error to enter an invalid search order in a search URL--$terms.Bugzilla will simply warn you that some of your order options are invalid.',
    '<b>Search:</b> When there are no search results, some helpful links are displayed, offering actions you might want to take.' =>
      '<b>Search:</b> When there are no search results, some helpful links are displayed, offering actions you might want to take.',
    '<b>Search:</b> For those who like to make their own' =>
      '<b>Search:</b> For those who like to make their own',
    'URLs (and for people working on customizations),' =>
      'URLs (and for people working on customizations),',
    'now accepts nearly every valid field in $terms.Bugzilla as a direct URL parameter, like' =>
      'now accepts nearly every valid field in $terms.Bugzilla as a direct URL parameter, like',
    '&amp;field=value' =>
      '&amp;field=value',
    '<b>Requests:</b> When viewing the "My Requests" page, you can now see the lists as a normal search result by clicking a link at the bottom of each table.' =>
      '<b>Requests:</b> When viewing the "My Requests" page, you can now see the lists as a normal search result by clicking a link at the bottom of each table.',
    '<b>Requests:</b> When viewing the "My Requests" page, if you are using Classifications, the Product drop-down will be grouped by Classification.' =>
      '<b>Requests:</b> When viewing the "My Requests" page, if you are using Classifications, the Product drop-down will be grouped by Classification.',
    '<b>Inbound Email:</b> When filing $terms.abug by email, if the product that you are filing the $terms.bug into has some groups set as Default for you, the $terms.bug will now be placed into those groups automatically.' =>
      '<b>Inbound Email:</b> When filing $terms.abug by email, if the product that you are filing the $terms.bug into has some groups set as Default for you, the $terms.bug will now be placed into those groups automatically.',
    '<b>Inbound Email:</b> The field names that can be used when creating $terms.bugs by email now exactly matches the set of valid parameters to the' =>
      '<b>Inbound Email:</b> The field names that can be used when creating $terms.bugs by email now exactly matches the set of valid parameters to the',
    'B' =>
      'B',
    'ug.create WebService function' =>
      'ug.create WebService function',
    '. You can still use most of the old field names that 3.4 and earlier used for inbound emails, though, for backwards-compatibility.' =>
      '. You can still use most of the old field names that 3.4 and earlier used for inbound emails, though, for backwards-compatibility.',
    'If there are multiple languages available for your $terms.Bugzilla, you can now select what language you want $terms.Bugzilla displayed in using links at the top of every page.' =>
      'If there are multiple languages available for your $terms.Bugzilla, you can now select what language you want $terms.Bugzilla displayed in using links at the top of every page.',
    'When creating a new account, you will be automatically logged in after setting your password.' =>
      'When creating a new account, you will be automatically logged in after setting your password.',
    'There is no longer a maximum password length for accounts.' =>
      'There is no longer a maximum password length for accounts.',
    'In the Dusk skin, it\'s now easier to see links.' =>
      'In the Dusk skin, it\'s now easier to see links.',
    'In the Whining system, you can now choose to receive emails even if there are no $terms.bugs that match your searches.' =>
      'In the Whining system, you can now choose to receive emails even if there are no $terms.bugs that match your searches.',
    'The arrows in dependency graphs now point the other way, so that $terms.bugs point at their dependencies.' =>
      'The arrows in dependency graphs now point the other way, so that $terms.bugs point at their dependencies.',
    '<b>New Charts:</b> You can now convert an existing Saved Search into a data series for New Charts.' =>
      '<b>New Charts:</b> You can now convert an existing Saved Search into a data series for New Charts.',
    '<b>New Charts:</b> There is now an interface that allows you to delete data series.' =>
      '<b>New Charts:</b> There is now an interface that allows you to delete data series.',
    '<b>New Charts:</b> When deleting a product, you now have the option to delete the data series that are associated with that product.' =>
      '<b>New Charts:</b> When deleting a product, you now have the option to delete the data series that are associated with that product.',
    'Enhancements for Administrators and Developers' =>
      'Enhancements for Administrators and Developers',
    'Depending on how your workflow is set up, it is now possible to have both UNCONFIRMED and REOPENED show up as status choices for a closed $terms.bug. If you only want one or the other to show up, you should edit your status workflow appropriately (possibly by removing or disabling the REOPENED status).' =>
      'Depending on how your workflow is set up, it is now possible to have both UNCONFIRMED and REOPENED show up as status choices for a closed $terms.bug. If you only want one or the other to show up, you should edit your status workflow appropriately (possibly by removing or disabling the REOPENED status).',
    'You can now "disable" field values so that they don\'t show up as choices on $terms.abug unless they are already set as the value for that $terms.bug. This doesn\'t work for the per-product field values (component, target_milestone, and version) yet, though.' =>
      'You can now "disable" field values so that they don\'t show up as choices on $terms.abug unless they are already set as the value for that $terms.bug. This doesn\'t work for the per-product field values (component, target_milestone, and version) yet, though.',
    'Users are now locked out of their accounts for 30 minutes after trying five bad passwords in a row during login. Every time a user is locked out like this, the user in the "maintainer" parameter will get an email.' =>
      'Users are now locked out of their accounts for 30 minutes after trying five bad passwords in a row during login. Every time a user is locked out like this, the user in the "maintainer" parameter will get an email.',
    'The minimum length allowed for a password is now 6 characters.' =>
      'The minimum length allowed for a password is now 6 characters.',
    'UNCONFIRMED' =>
      'UNCONFIRMED',
    'status being enabled in a product is now unrelated to the voting parameters. Instead, there is a checkbox to enable the' =>
      'status being enabled in a product is now unrelated to the voting parameters. Instead, there is a checkbox to enable the',
    'status in a product.' =>
      'status in a product.',
    'Information about duplicates is now stored in the database instead of being stored in the' =>
      'Information about duplicates is now stored in the database instead of being stored in the',
    'data/' =>
      'data/',
    'directory. On large installations this could save several hundred megabytes of disk space.' =>
      'directory. On large installations this could save several hundred megabytes of disk space.',
    '<b>Installation:</b> When installing $terms.Bugzilla, the "maintainer" parameter will be automatically set to the administrator that was created by' =>
      '<b>Installation:</b> When installing $terms.Bugzilla, the "maintainer" parameter will be automatically set to the administrator that was created by',
    '<b>Installation:</b>' =>
      '<b>Installation:</b>',
    'now prints out certain errors in a special color so that you know that something needs to be done.' =>
      'now prints out certain errors in a special color so that you know that something needs to be done.',
    'is now <em>much</em> faster at upgrading installations, particularly older installations. Also, it\'s been made faster to run for the case where it\'s not doing an upgrade.' =>
      'is now <em>much</em> faster at upgrading installations, particularly older installations. Also, it\'s been made faster to run for the case where it\'s not doing an upgrade.',
    '<b>Installation:</b> If you install $terms.Bugzilla using the tarball, the' =>
      '<b>Installation:</b> If you install $terms.Bugzilla using the tarball, the',
    'module from CPAN is now included in the' =>
      'module from CPAN is now included in the',
    'lib/' =>
      'lib/',
    'dir. If you would rather use the CGI.pm from your global Perl installation, you can delete' =>
      'dir. If you would rather use the CGI.pm from your global Perl installation, you can delete',
    'and the' =>
      'and the',
    'CGI' =>
      'CGI',
    'directory from the' =>
      'directory from the',
    'directory.' =>
      'directory.',
    'When editing a group, you can now specify that members of a group are allowed to grant others membership in that group itself.' =>
      'When editing a group, you can now specify that members of a group are allowed to grant others membership in that group itself.',
    'The ability to compress BMP attachments to PNGs is now an Extension. To enable the feature, remove the file' =>
      'The ability to compress BMP attachments to PNGs is now an Extension. To enable the feature, remove the file',
    'extensions/BmpConvert/disabled' =>
      'extensions/BmpConvert/disabled',
    'and then run checksetup.pl.' =>
      'and then run checksetup.pl.',
    'The default list of values for the Priority field are now clear English words instead of P1, P2, etc.' =>
      'The default list of values for the Priority field are now clear English words instead of P1, P2, etc.',
    'There is now a system in place so that all field values can be localized. See the' =>
      'There is now a system in place so that all field values can be localized. See the',
    'value_descs' =>
      'value_descs',
    'variable in' =>
      'variable in',
    'now returns an ETag header and understands the If-None-Match header in HTTP requests.' =>
      'now returns an ETag header and understands the If-None-Match header in HTTP requests.',
    'The XML format of' =>
      'The XML format of',
    'now returns more information: the numeric id of each comment, whether an attachment is a URL, the modification time of an attachment, the numeric id of a flag, and the numeric id of a flag\'s type.' =>
      'now returns more information: the numeric id of each comment, whether an attachment is a URL, the modification time of an attachment, the numeric id of a flag, and the numeric id of a flag\'s type.',
    '<b>Parameters:</b> Parameters that aren\'t actually required are no longer in the "Required" section of the Parameters page. Instead, some are in the new "General" section, and some are in the new "Advanced" section.' =>
      '<b>Parameters:</b> Parameters that aren\'t actually required are no longer in the "Required" section of the Parameters page. Instead, some are in the new "General" section, and some are in the new "Advanced" section.',
    '<b>Parameters:</b> The old' =>
      '<b>Parameters:</b> The old',
    'ssl' =>
      'ssl',
    'parameter has been changed to' =>
      'parameter has been changed to',
    'ssl_redirect' =>
      'ssl_redirect',
    ', and can only be turned "on" or "off". If "on", then all users will be forcibly redirected to SSL whenever they access $terms.Bugzilla. When the parameter is off, no SSL-related redirects will occur (even if the user directly accesses $terms.Bugzilla via SSL, they will <em>not</em> be redirected to a non-SSL page).' =>
      ', and can only be turned "on" or "off". If "on", then all users will be forcibly redirected to SSL whenever they access $terms.Bugzilla. When the parameter is off, no SSL-related redirects will occur (even if the user directly accesses $terms.Bugzilla via SSL, they will <em>not</em> be redirected to a non-SSL page).',
    '<b>Parameters:</b> In the Advanced parameters, there is a new parameter,' =>
      '<b>Parameters:</b> In the Advanced parameters, there is a new parameter,',
    'inbound_proxies' =>
      'inbound_proxies',
    '. If your $terms.Bugzilla is behind a proxy, you should set this parameter to the IP address of that proxy. Then, $terms.Bugzilla will "believe" any "X-Forwarded-For" header sent from that proxy, and correctly use the X-Forwarded-For as the end user\'s IP, instead of believing that all traffic is coming from the proxy.' =>
      '. If your $terms.Bugzilla is behind a proxy, you should set this parameter to the IP address of that proxy. Then, $terms.Bugzilla will "believe" any "X-Forwarded-For" header sent from that proxy, and correctly use the X-Forwarded-For as the end user\'s IP, instead of believing that all traffic is coming from the proxy.',
    '<b>Removed Parameter:</b> The' =>
      '<b>Removed Parameter:</b> The',
    'loginnetmask' =>
      'loginnetmask',
    'parameter has been removed. Since $terms.Bugzilla sends secure cookies, it\'s no longer necessary to always restrict logins to a specific IP or block of addresses.' =>
      'parameter has been removed. Since $terms.Bugzilla sends secure cookies, it\'s no longer necessary to always restrict logins to a specific IP or block of addresses.',
    'quicksearch_comment_cutoff' =>
      'quicksearch_comment_cutoff',
    'parameter is gone. Quicksearch now always searches comments; however, it uses a much faster algorithm to do it.' =>
      'parameter is gone. Quicksearch now always searches comments; however, it uses a much faster algorithm to do it.',
    'usermatchmode' =>
      'usermatchmode',
    'parameter has been removed. User-matching is now <em>always</em> done.' =>
      'parameter has been removed. User-matching is now <em>always</em> done.',
    'useentrygroupdefault' =>
      'useentrygroupdefault',
    'parameter has been removed. $terms.Bugzilla now always behaves as though that parameter were off.' =>
      'parameter has been removed. $terms.Bugzilla now always behaves as though that parameter were off.',
    't/001compile.t' =>
      't/001compile.t',
    'test should now always pass, no matter what configuration of optional modules you do or don\'t have installed.' =>
      'test should now always pass, no matter what configuration of optional modules you do or don\'t have installed.',
    'New script:' =>
      'New script:',
    'contrib/console.pl' =>
      'contrib/console.pl',
    ', which allows you to have a "command line" into $terms.Bugzilla by inputting Perl code or using a few custom commands.' =>
      ', which allows you to have a "command line" into $terms.Bugzilla by inputting Perl code or using a few custom commands.',
    'WebService Changes' =>
      'WebService Changes',
    'The WebService now returns all dates and times in the UTC timezone.' =>
      'The WebService now returns all dates and times in the UTC timezone.',
    'ugzilla.time' =>
      'ugzilla.time',
    'now acts as though the $terms.Bugzilla server were in the UTC timezone, always. If you want to write clients that are compatible across all $terms.Bugzilla versions, check the timezone from' =>
      'now acts as though the $terms.Bugzilla server were in the UTC timezone, always. If you want to write clients that are compatible across all $terms.Bugzilla versions, check the timezone from',
    'ugzilla.timezone' =>
      'ugzilla.timezone',
    'or' =>
      'or',
    ', and always input times in that timezone and expect times to be returned in that format.' =>
      ', and always input times in that timezone and expect times to be returned in that format.',
    'You can now log in by passing' =>
      'You can now log in by passing',
    'Bugzilla_login' =>
      'Bugzilla_login',
    'Bugzilla_password' =>
      'Bugzilla_password',
    'as arguments to any WebService function. See the' =>
      'as arguments to any WebService function. See the',
    'Bugzilla::WebService' =>
      'Bugzilla::WebService',
    'documentation for details.' =>
      'documentation for details.',
    'New Method:' =>
      'New Method:',
    'ug.attachments' =>
      'ug.attachments',
    'which allows getting information about attachments.' =>
      'which allows getting information about attachments.',
    'ug.fields' =>
      'ug.fields',
    ', which gets information about all the fields that $terms.abug can have in $terms.Bugzilla, include custom fields and legal values for all fields. The' =>
      ', which gets information about all the fields that $terms.abug can have in $terms.Bugzilla, include custom fields and legal values for all fields. The',
    'ug.legal_values' =>
      'ug.legal_values',
    'method is now deprecated.' =>
      'method is now deprecated.',
    'In the' =>
      'In the',
    'ug.add_comment' =>
      'ug.add_comment',
    'method, the "private" parameter has been renamed to "is_private" (for consistency with other methods). You can still use "private", though, for backwards-compatibility.' =>
      'method, the "private" parameter has been renamed to "is_private" (for consistency with other methods). You can still use "private", though, for backwards-compatibility.',
    'The WebService now has Perl\'s "taint mode" turned on. This means that it validates all data passed in before sending it to the database. Also, all parameter names are validated, and if you pass in a parameter whose name contains anything other than letters, numbers, or underscores, that parameter will be ignored. Mostly this just affects customizers--$terms.Bugzilla\'s WebService is not functionally affected by these changes.' =>
      'The WebService now has Perl\'s "taint mode" turned on. This means that it validates all data passed in before sending it to the database. Also, all parameter names are validated, and if you pass in a parameter whose name contains anything other than letters, numbers, or underscores, that parameter will be ignored. Mostly this just affects customizers--$terms.Bugzilla\'s WebService is not functionally affected by these changes.',
    'In previous versions of $terms.Bugzilla, error messages were sent word-wrapped to the client, from the WebService. Error messages are now sent as one unbroken line.' =>
      'In previous versions of $terms.Bugzilla, error messages were sent word-wrapped to the client, from the WebService. Error messages are now sent as one unbroken line.',
    ': Tabs in comments will be converted to four spaces, due to a b' =>
      ': Tabs in comments will be converted to four spaces, due to a b',
    'ug in Perl as of Perl 5.8.8.' =>
      'ug in Perl as of Perl 5.8.8.',
    ': If you rename or remove a keyword that is in use on $terms.bugs, you will need to rebuild the "keyword cache" by running' =>
      ': If you rename or remove a keyword that is in use on $terms.bugs, you will need to rebuild the "keyword cache" by running',
    'and choosing the option to rebuild the cache when it asks. Otherwise keywords may not show up properly in search results.' =>
      'and choosing the option to rebuild the cache when it asks. Otherwise keywords may not show up properly in search results.',
    ': When changing multiple $terms.bugs at the same time, there is no "mid-air collision" protection.' =>
      ': When changing multiple $terms.bugs at the same time, there is no "mid-air collision" protection.',
    ': The support for restricting access to particular Categories of New Charts is not complete. You should treat the \'chartgroup\' Param as the only access mechanism available.' =>
      ': The support for restricting access to particular Categories of New Charts is not complete. You should treat the \'chartgroup\' Param as the only access mechanism available.',
    'However, charts migrated from Old Charts will be restricted to the groups that are marked MANDATORY for the corresponding Product. There is currently no way to change this restriction, and the groupings will not be updated if the group configuration for the Product changes.' =>
      'However, charts migrated from Old Charts will be restricted to the groups that are marked MANDATORY for the corresponding Product. There is currently no way to change this restriction, and the groupings will not be updated if the group configuration for the Product changes.',
    'When upgrading to 3.6,' =>
      'When upgrading to 3.6,',
    'will create foreign keys for many columns in the database. Before doing this, it will check the database for consistency. If there are an unresolvable consistency problems, it will tell you what table and column in the database contain the bad values, and which values are bad. If you don\'t know what else to do, you can always delete the database records which contain the bad values by logging in to your database and running the following command:' =>
      'will create foreign keys for many columns in the database. Before doing this, it will check the database for consistency. If there are an unresolvable consistency problems, it will tell you what table and column in the database contain the bad values, and which values are bad. If you don\'t know what else to do, you can always delete the database records which contain the bad values by logging in to your database and running the following command:',
    'DELETE FROM' =>
      'DELETE FROM',
    'table' =>
      'table',
    'WHERE' =>
      'WHERE',
    'column' =>
      'column',
    'IN (' =>
      'IN (',
    'Just replace "table" and "column" with the name of the table and column that' =>
      'Just replace "table" and "column" with the name of the table and column that',
    'mentions, and "1, 2, 3, 4" with the invalid values that' =>
      'mentions, and "1, 2, 3, 4" with the invalid values that',
    'prints out.' =>
      'prints out.',
    'Remember that you should always back up your database before doing an upgrade.' =>
      'Remember that you should always back up your database before doing an upgrade.',
    'There is no longer a SendBugMail method in the templates, and bugmail is no longer sent by processing a template. Instead, it is sent by using' =>
      'There is no longer a SendBugMail method in the templates, and bugmail is no longer sent by processing a template. Instead, it is sent by using',
    'Bugzilla::BugMail::Send' =>
      'Bugzilla::BugMail::Send',
    'Comments are now represented as a' =>
      'Comments are now represented as a',
    'Bugzilla::Comment' =>
      'Bugzilla::Comment',
    'object instead of just being hashes.' =>
      'object instead of just being hashes.',
    'In previous versions of $terms.Bugzilla, the template for displaying $terms.abug required a lot of extra variables that are now global template variables instead.' =>
      'In previous versions of $terms.Bugzilla, the template for displaying $terms.abug required a lot of extra variables that are now global template variables instead.',
    'You can now check if optional modules are installed by using' =>
      'You can now check if optional modules are installed by using',
    'Bugzilla-&gt;feature' =>
      'Bugzilla-&gt;feature',
    'in Perl code or' =>
      'in Perl code or',
    'feature_enabled' =>
      'feature_enabled',
    'in template code.' =>
      'in template code.',
    'All of the various template header information required to display the $terms.bug form is now in one template,' =>
      'All of the various template header information required to display the $terms.bug form is now in one template,',
    'You should now use' =>
      'You should now use',
    'display_value' =>
      'display_value',
    'instead of' =>
      'instead of',
    'get_status' =>
      'get_status',
    'get_resolution' =>
      'get_resolution',
    'in templates.' =>
      'in templates.',
    'should be used anywhere that a &lt;select&gt;-type field has its values displayed.' =>
      'should be used anywhere that a &lt;select&gt;-type field has its values displayed.',
    'Долбанутое решение убрано.' =>
      'Долбанутое решение убрано.',
    '$terms.Bugzilla 3.4 Release Notes' =>
      '$terms.Bugzilla 3.4 Release Notes',
    'Updates in this 3.4.x Release' =>
      'Updates in this 3.4.x Release',
    'This is $terms.Bugzilla 3.4! $terms.Bugzilla 3.4 brings a lot of great enhancements for $terms.Bugzilla over previous versions, with various improvements to the user interface, lots of interesting new features, and many long-standing requests finally being addressed.' =>
      'This is $terms.Bugzilla 3.4! $terms.Bugzilla 3.4 brings a lot of great enhancements for $terms.Bugzilla over previous versions, with various improvements to the user interface, lots of interesting new features, and many long-standing requests finally being addressed.',
    '. If you are upgrading from a release before 3.2, make sure to read the release notes for all the' =>
      '. If you are upgrading from a release before 3.2, make sure to read the release notes for all the',
    'for funding development of one new feature, and NASA for funding development of several new features through the' =>
      'for funding development of one new feature, and NASA for funding development of several new features through the',
    'San Jose State University Foundation' =>
      'San Jose State University Foundation',
    'Updates In This 3.4.x Release' =>
      'Updates In This 3.4.x Release',
    'When doing a search that involves "not equals" or "does not contain the string" or similar "negative" search types, the search description that appears at the top of the resulting $terms.bug list will indicate that the search was of that type. (' =>
      'When doing a search that involves "not equals" or "does not contain the string" or similar "negative" search types, the search description that appears at the top of the resulting $terms.bug list will indicate that the search was of that type. (',
    'In Internet Explorer, users couldn\'t easily mark a RESOLVED DUPLICATE $terms.bug as REOPENED, due to a JavaScript error. (' =>
      'In Internet Explorer, users couldn\'t easily mark a RESOLVED DUPLICATE $terms.bug as REOPENED, due to a JavaScript error. (',
    'If you use a "bookmarkable template" to pre-fill forms on the $terms.bug-filing page, and you have custom fields that are only supposed to appear (or only supposed to have certain values) based on the values of other fields, those custom fields will now work properly. (' =>
      'If you use a "bookmarkable template" to pre-fill forms on the $terms.bug-filing page, and you have custom fields that are only supposed to appear (or only supposed to have certain values) based on the values of other fields, those custom fields will now work properly. (',
    'If you have a custom field that\'s only supposed to appear when a $terms.bug\'s resolution is FIXED, it will now behave properly on the $terms.bug-editing form when a user sets the $terms.bug\'s status to RESOLVED. (' =>
      'If you have a custom field that\'s only supposed to appear when a $terms.bug\'s resolution is FIXED, it will now behave properly on the $terms.bug-editing form when a user sets the $terms.bug\'s status to RESOLVED. (',
    'If you are logged-out and using' =>
      'If you are logged-out and using',
    ', the Requester and Requestee fields no longer respect the' =>
      ', the Requester and Requestee fields no longer respect the',
    'usermatching' =>
      'usermatching',
    'parameter--they always require full usernames. (' =>
      'parameter--they always require full usernames. (',
    'If you tried to do a search with too many terms (resulting in a URL that was longer than about 7000 characters), Apache would return a 500 error instead of your search results. (' =>
      'If you tried to do a search with too many terms (resulting in a URL that was longer than about 7000 characters), Apache would return a 500 error instead of your search results. (',
    '$terms.Bugzilla would sometimes lose fields from your sort order when you added new fields to your sort order. (' =>
      '$terms.Bugzilla would sometimes lose fields from your sort order when you added new fields to your sort order. (',
    'The Atom format of search results would sometimes be missing the Reporter or Assignee field for some $terms.bugs. (' =>
      'The Atom format of search results would sometimes be missing the Reporter or Assignee field for some $terms.bugs. (',
    'This release contains fixes for multiple security issues. See the' =>
      'This release contains fixes for multiple security issues. See the',
    'Whining was failing if jobqueue.pl was enabled. (' =>
      'Whining was failing if jobqueue.pl was enabled. (',
    'The Assignee field was empty in Whine mails. (' =>
      'The Assignee field was empty in Whine mails. (',
    'Administrators can now successfully create user accounts using editusers.cgi when using the "Env" authentication method. (' =>
      'Administrators can now successfully create user accounts using editusers.cgi when using the "Env" authentication method. (',
    '$terms.Bugmail now uses the timezone of the recipient of the email, when displaying the time a comment was made, instead of the timezone of the person who made the change. (' =>
      '$terms.Bugmail now uses the timezone of the recipient of the email, when displaying the time a comment was made, instead of the timezone of the person who made the change. (',
    '"$terms.bug 1234" in comments sometimes would not become a link if word-wrapping happened between "$terms.bug" and the number. (' =>
      '"$terms.bug 1234" in comments sometimes would not become a link if word-wrapping happened between "$terms.bug" and the number. (',
    'Running checksetup.pl on Windows will no longer pop up an error box about OCI.dll. (' =>
      'Running checksetup.pl on Windows will no longer pop up an error box about OCI.dll. (',
    'This release contains a fix for a security issue. See the' =>
      'This release contains a fix for a security issue. See the',
    'Additionally, this release fixes a few minor $terms.bugs.' =>
      'Additionally, this release fixes a few minor $terms.bugs.',
    '$terms.Bugzilla installations running under mod_perl were leaking about 512K of RAM per page load. (' =>
      '$terms.Bugzilla installations running under mod_perl were leaking about 512K of RAM per page load. (',
    'Attachments with Unicode characters in their names were being downloaded with mangled names. (' =>
      'Attachments with Unicode characters in their names were being downloaded with mangled names. (',
    'Creating custom fields with Unicode in their database column name is now no longer allowed, as it would break $terms.Bugzilla. If you created such a custom field, you should delete it by first marking it obsolete and then clicking "Delete" in the custom field list, using' =>
      'Creating custom fields with Unicode in their database column name is now no longer allowed, as it would break $terms.Bugzilla. If you created such a custom field, you should delete it by first marking it obsolete and then clicking "Delete" in the custom field list, using',
    'Clicking "submit only my comment" on the "mid-air collisions" page was leading to a "Suspicious Action" warning. (' =>
      'Clicking "submit only my comment" on the "mid-air collisions" page was leading to a "Suspicious Action" warning. (',
    'The XML format of $terms.abug accidentally contained the word-wrapped content of comments instead of the unwrapped content. (' =>
      'The XML format of $terms.abug accidentally contained the word-wrapped content of comments instead of the unwrapped content. (',
    'You can now do' =>
      'You can now do',
    './install-module.pl --shell' =>
      './install-module.pl --shell',
    'to get a CPAN shell using the configuration of' =>
      'to get a CPAN shell using the configuration of',
    ', which allows you to do more advanced Perl module installation tasks. (' =>
      ', which allows you to do more advanced Perl module installation tasks. (',
    'This release contains fixes for multiple security issues, one of which is highly critical. See the' =>
      'This release contains fixes for multiple security issues, one of which is highly critical. See the',
    'Upgrades from older releases were sometimes failing during UTF-8 conversion with a foreign key error. (' =>
      'Upgrades from older releases were sometimes failing during UTF-8 conversion with a foreign key error. (',
    'Sorting $terms.bug lists on certain fields would result in an error. (' =>
      'Sorting $terms.bug lists on certain fields would result in an error. (',
    '$terms.Bug update emails had two or three blank lines at the top and between the various sections of the email. There is now only one blank line in each of those places, making these emails more compact. (' =>
      '$terms.Bug update emails had two or three blank lines at the top and between the various sections of the email. There is now only one blank line in each of those places, making these emails more compact. (',
    '$terms.Bug email notifications for new $terms.bugs incorrectly had a line saying that the description was "Comment 0". (' =>
      '$terms.Bug email notifications for new $terms.bugs incorrectly had a line saying that the description was "Comment 0". (',
    'Running' =>
      'Running',
    './collectstats.pl --regenerate' =>
      './collectstats.pl --regenerate',
    'is now much faster, on the order of 20x or 100x faster. (' =>
      'is now much faster, on the order of 20x or 100x faster. (',
    'For users of RHEL, CentOS, Fedora, etc. jobqueue.pl can now automatically be installed as a daemon by running' =>
      'For users of RHEL, CentOS, Fedora, etc. jobqueue.pl can now automatically be installed as a daemon by running',
    './jobqueue.pl install' =>
      './jobqueue.pl install',
    'as root. (' =>
      'as root. (',
    'XML-RPC interface responses had an incorrect Content-Length header and would sometimes be truncated, if they contained certain UTF-8 characters. (' =>
      'XML-RPC interface responses had an incorrect Content-Length header and would sometimes be truncated, if they contained certain UTF-8 characters. (',
    'Users who didn\'t have access to the time-tracking fields would get an empty $terms.bug update email when the time-tracking fields were changed. (' =>
      'Users who didn\'t have access to the time-tracking fields would get an empty $terms.bug update email when the time-tracking fields were changed. (',
    'In the New Charts, non-public series now no longer show up as selectable if you cannot access them. (' =>
      'In the New Charts, non-public series now no longer show up as selectable if you cannot access them. (',
    'This release contains an important security fix. See the' =>
      'This release contains an important security fix. See the',
    'Any requirements that are new since 3.2.3 will look like' =>
      'Any requirements that are new since 3.2.3 will look like',
    'MySQL v4.1.2' =>
      'MySQL v4.1.2',
    '<strong>perl module:</strong> DBD::mysql v4.00' =>
      '<strong>perl module:</strong> DBD::mysql v4.00',
    'PostgreSQL v8.00.0000' =>
      'PostgreSQL v8.00.0000',
    '<strong>perl module:</strong> DBD::Pg v1.45' =>
      '<strong>perl module:</strong> DBD::Pg v1.45',
    'Oracle v10.02.0' =>
      'Oracle v10.02.0',
    '<strong>perl module:</strong> DBD::Oracle v1.19' =>
      '<strong>perl module:</strong> DBD::Oracle v1.19',
    'Module' =>
      'Module',
    'Version' =>
      'Version',
    'Digest::SHA' =>
      'Digest::SHA',
    '(Any)' =>
      '(Any)',
    'Date::Format' =>
      'Date::Format',
    'DateTime' =>
      'DateTime',
    'DateTime::TimeZone' =>
      'DateTime::TimeZone',
    'DBI' =>
      'DBI',
    'Template' =>
      'Template',
    'Email::Send' =>
      'Email::Send',
    'Email::MIME' =>
      'Email::MIME',
    'Email::MIME::Encodings' =>
      'Email::MIME::Encodings',
    'Email::MIME::Modifier' =>
      'Email::MIME::Modifier',
    'URI' =>
      'URI',
    'Enables Feature' =>
      'Enables Feature',
    'LWP::UserAgent' =>
      'LWP::UserAgent',
    'Automatic Update Notifications' =>
      'Automatic Update Notifications',
    'Template::Plugin::GD::Image' =>
      'Template::Plugin::GD::Image',
    'Graphical Reports' =>
      'Graphical Reports',
    'GD::Text' =>
      'GD::Text',
    'GD::Graph' =>
      'GD::Graph',
    'GD' =>
      'GD',
    'Graphical Reports, New Charts, Old Charts' =>
      'Graphical Reports, New Charts, Old Charts',
    'Email::MIME::Attachment::Stripper' =>
      'Email::MIME::Attachment::Stripper',
    'Inbound Email' =>
      'Inbound Email',
    'Email::Reply' =>
      'Email::Reply',
    'Net::LDAP' =>
      'Net::LDAP',
    'LDAP Authentication' =>
      'LDAP Authentication',
    'TheSchwartz' =>
      'TheSchwartz',
    'Mail Queueing' =>
      'Mail Queueing',
    'Daemon::Generic' =>
      'Daemon::Generic',
    'HTML::Parser' =>
      'HTML::Parser',
    'More HTML in Product/Group Descriptions' =>
      'More HTML in Product/Group Descriptions',
    'HTML::Scrubber' =>
      'HTML::Scrubber',
    'XML::Twig' =>
      'XML::Twig',
    'Move $terms.Bugs Between Installations' =>
      'Move $terms.Bugs Between Installations',
    'MIME::Parser' =>
      'MIME::Parser',
    'Chart::Base' =>
      'Chart::Base',
    'New Charts, Old Charts' =>
      'New Charts, Old Charts',
    'Image::Magick' =>
      'Image::Magick',
    'Optionally Convert BMP Attachments to PNGs' =>
      'Optionally Convert BMP Attachments to PNGs',
    'PatchReader' =>
      'PatchReader',
    'Patch Viewer' =>
      'Patch Viewer',
    'Authen::Radius' =>
      'Authen::Radius',
    'RADIUS Authentication' =>
      'RADIUS Authentication',
    'Authen::SASL' =>
      'Authen::SASL',
    'SMTP Authentication' =>
      'SMTP Authentication',
    'SOAP::Lite' =>
      'SOAP::Lite',
    'XML-RPC Interface' =>
      'XML-RPC Interface',
    'mod_perl2' =>
      'mod_perl2',
    'mod_perl' =>
      'mod_perl',
    'Simple $terms.Bug Filing' =>
      'Simple $terms.Bug Filing',
    'New Home Page' =>
      'New Home Page',
    'Email Addresses Hidden From Logged-Out Users' =>
      'Email Addresses Hidden From Logged-Out Users',
    'Shorter Search URLs' =>
      'Shorter Search URLs',
    'Asynchronous Email Sending' =>
      'Asynchronous Email Sending',
    'Dates and Times Displayed In User\'s Time Zone' =>
      'Dates and Times Displayed In User\'s Time Zone',
    'Custom Fields That Only Appear When Another Field Has a Particular Value' =>
      'Custom Fields That Only Appear When Another Field Has a Particular Value',
    'Custom Fields Whose List of Values Change Depending on the Value of Another Field' =>
      'Custom Fields Whose List of Values Change Depending on the Value of Another Field',
    'New Custom Field Type: $terms.Bug ID' =>
      'New Custom Field Type: $terms.Bug ID',
    '"See Also" Field' =>
      '"See Also" Field',
    'Re-order Columns in Search Results' =>
      'Re-order Columns in Search Results',
    'Search Descriptions' =>
      'Search Descriptions',
    'When entering a new $terms.bug, the vast majority of fields are now hidden by default, which enormously simplifies the bug-filing form. You can click "Show Advanced Fields" to show all the fields, if you want them. $terms.Bugzilla remembers whether you last used the "Advanced" or "Simple" version of the $terms.bug-entry form, and will display the same version to you again next time you file $terms.abug.' =>
      'When entering a new $terms.bug, the vast majority of fields are now hidden by default, which enormously simplifies the bug-filing form. You can click "Show Advanced Fields" to show all the fields, if you want them. $terms.Bugzilla remembers whether you last used the "Advanced" or "Simple" version of the $terms.bug-entry form, and will display the same version to you again next time you file $terms.abug.',
    '$terms.Bugzilla\'s front page has been redesigned to be better at guiding new users into the activities that they most commonly want to do. Further enhancements to the home page are coming in future versions of $terms.Bugzilla.' =>
      '$terms.Bugzilla\'s front page has been redesigned to be better at guiding new users into the activities that they most commonly want to do. Further enhancements to the home page are coming in future versions of $terms.Bugzilla.',
    'To help prevent spam to $terms.Bugzilla users, all email addresses stored in $terms.Bugzilla are now displayed only if you are logged in. If you are logged out, only the part before the "@" of the email address is displayed. This includes $terms.bug lists, viewing $terms.bugs, the XML format of $terms.abug, and any other place in the web interface that an email address could appear.' =>
      'To help prevent spam to $terms.Bugzilla users, all email addresses stored in $terms.Bugzilla are now displayed only if you are logged in. If you are logged out, only the part before the "@" of the email address is displayed. This includes $terms.bug lists, viewing $terms.bugs, the XML format of $terms.abug, and any other place in the web interface that an email address could appear.',
    'Email addresses are not filtered out of $terms.bug comments. The WebService still returns full email addresses, even if you are logged out.' =>
      'Email addresses are not filtered out of $terms.bug comments. The WebService still returns full email addresses, even if you are logged out.',
    'When submitting a search, all the unused fields are now stripped from the URL, so search URLs are much more meaningful, and much shorter.' =>
      'When submitting a search, all the unused fields are now stripped from the URL, so search URLs are much more meaningful, and much shorter.',
    'The largest performance problem in former versions of $terms.Bugzilla was that when updating $terms.bugs, email would be sent immediately to every user who needed to be notified, and' =>
      'The largest performance problem in former versions of $terms.Bugzilla was that when updating $terms.bugs, email would be sent immediately to every user who needed to be notified, and',
    'would wait for the emails to be sent before continuing.' =>
      'would wait for the emails to be sent before continuing.',
    'Now $terms.Bugzilla is capable of queueing emails to be sent while $terms.abug is being updated, and sending them in the background. This requires the administrator to run a daemon that comes with $terms.Bugzilla, named' =>
      'Now $terms.Bugzilla is capable of queueing emails to be sent while $terms.abug is being updated, and sending them in the background. This requires the administrator to run a daemon that comes with $terms.Bugzilla, named',
    'jobqueue.pl' =>
      'jobqueue.pl',
    ', and to enable the' =>
      ', and to enable the',
    'use_mailer_queue' =>
      'use_mailer_queue',
    'parameter.' =>
      'parameter.',
    'Using the background email-sending daemon instead of sending mail directly should result in a very large speed-up for updating $terms.bugs, particularly on larger installations.' =>
      'Using the background email-sending daemon instead of sending mail directly should result in a very large speed-up for updating $terms.bugs, particularly on larger installations.',
    'Users can now select what time zone they are in and $terms.Bugzilla will adjust displayed times to be correct for their time zone. However, times the user inputs are unfortunately still in $terms.Bugzilla\'s time zone.' =>
      'Users can now select what time zone they are in and $terms.Bugzilla will adjust displayed times to be correct for their time zone. However, times the user inputs are unfortunately still in $terms.Bugzilla\'s time zone.',
    'When creating a new custom field (or updating the definition of an existing custom field), you can now say that "this field only appears when field X has value Y". (In the future, you will be able to select multiple values for "Y", so a field will appear when any one of those values is selected.)' =>
      'When creating a new custom field (or updating the definition of an existing custom field), you can now say that "this field only appears when field X has value Y". (In the future, you will be able to select multiple values for "Y", so a field will appear when any one of those values is selected.)',
    'This feature only hides fields--it doesn\'t make their values go away. So $terms.bugs will still show up in searches for that field\'s value, but the field won\'t appear in the user interface.' =>
      'This feature only hides fields--it doesn\'t make their values go away. So $terms.bugs will still show up in searches for that field\'s value, but the field won\'t appear in the user interface.',
    'This is a good way of making Product-specific fields.' =>
      'This is a good way of making Product-specific fields.',
    'When creating a drop-down or multiple-selection custom field, you can now specify that another field "controls the values" of this field. Then, when adding values to this field, you can say that a particular value only appears when the other field is set to a particular value.' =>
      'When creating a drop-down or multiple-selection custom field, you can now specify that another field "controls the values" of this field. Then, when adding values to this field, you can say that a particular value only appears when the other field is set to a particular value.',
    'Here\'s an example: Let\'s say that we create a field called "Colors", and we make the Product field "control the values" for Colors. Then we add Blue, Red, Black, and Yellow as legal values for the "Colors" field. Now we can say that "Blue" and "Red" only appear as valid choices in Product A, "Yellow" only appears in Product B, but "Black" <em>always</em> appears.' =>
      'Here\'s an example: Let\'s say that we create a field called "Colors", and we make the Product field "control the values" for Colors. Then we add Blue, Red, Black, and Yellow as legal values for the "Colors" field. Now we can say that "Blue" and "Red" only appear as valid choices in Product A, "Yellow" only appears in Product B, but "Black" <em>always</em> appears.',
    'One thing to note is that this feature only controls what values appear in the <em>user interface</em>. $terms.Bugzilla itself will still accept any combination of values as valid, in the backend.' =>
      'One thing to note is that this feature only controls what values appear in the <em>user interface</em>. $terms.Bugzilla itself will still accept any combination of values as valid, in the backend.',
    'You can now create a custom field that holds a reference to a single valid $terms.bug ID. In the future this will be enhanced to allow $terms.bugs to refer to each other via this field.' =>
      'You can now create a custom field that holds a reference to a single valid $terms.bug ID. In the future this will be enhanced to allow $terms.bugs to refer to each other via this field.',
    'We have added a new standard field called "See Also" to $terms.Bugzilla. In this field, you can put URLs to multiple $terms.bugs in any $terms.Bugzilla installation, to indicate that those $terms.bugs are related to this one. It also supports adding URLs to $terms.bugs in' =>
      'We have added a new standard field called "See Also" to $terms.Bugzilla. In this field, you can put URLs to multiple $terms.bugs in any $terms.Bugzilla installation, to indicate that those $terms.bugs are related to this one. It also supports adding URLs to $terms.bugs in',
    'Launchpad' =>
      'Launchpad',
    'Right now, the field just validates the URLs and then displays them, but in the future, it will grab information from the other installation about the $terms.bug and display it here, and possibly even update the other installation.' =>
      'Right now, the field just validates the URLs and then displays them, but in the future, it will grab information from the other installation about the $terms.bug and display it here, and possibly even update the other installation.',
    'If your installation does not need this field, you can hide it by disabling the' =>
      'If your installation does not need this field, you can hide it by disabling the',
    'use_see_also parameter' =>
      'use_see_also parameter',
    'There is a new interface for choosing what columns appear in search results, which allows you to change the order in which columns appear from left to right when viewing the $terms.bug list.' =>
      'There is a new interface for choosing what columns appear in search results, which allows you to change the order in which columns appear from left to right when viewing the $terms.bug list.',
    'When displaying search results, $terms.Bugzilla will now show a brief description of what you searched for, at the top of the $terms.bug list.' =>
      'When displaying search results, $terms.Bugzilla will now show a brief description of what you searched for, at the top of the $terms.bug list.',
    'You can now log in from every page, using the login form that appears in the header or footer when you click "Log In".' =>
      'You can now log in from every page, using the login form that appears in the header or footer when you click "Log In".',
    'When viewing $terms.abug, obsolete attachments are now hidden from the attachment list by default. You can show them by clicking "Show Obsolete" at the bottom of the attachment list.' =>
      'When viewing $terms.abug, obsolete attachments are now hidden from the attachment list by default. You can show them by clicking "Show Obsolete" at the bottom of the attachment list.',
    'In the Email Preferences, you can now choose to get email when a new $terms.bug report is filed and you have a particular role on it.' =>
      'In the Email Preferences, you can now choose to get email when a new $terms.bug report is filed and you have a particular role on it.',
    'When resolving a mid-air collision, you can now choose to submit only your comment.' =>
      'When resolving a mid-air collision, you can now choose to submit only your comment.',
    'You can now set the Blocks and Depends On field on the "Change Several $terms.Bugs At Once" page.' =>
      'You can now set the Blocks and Depends On field on the "Change Several $terms.Bugs At Once" page.',
    'If your installation uses the "insidergroup" feature, you can now add private comments on the "Change Several $terms.Bugs At Once" page.' =>
      'If your installation uses the "insidergroup" feature, you can now add private comments on the "Change Several $terms.Bugs At Once" page.',
    'When viewing a search result, you can now hover over any abbreviated field to see its full value.' =>
      'When viewing a search result, you can now hover over any abbreviated field to see its full value.',
    'When logging out, users are now redirected to the main page of $terms.Bugzilla instead of an empty page.' =>
      'When logging out, users are now redirected to the main page of $terms.Bugzilla instead of an empty page.',
    'When editing $terms.abug, text fields (except the comment box) now grow longer when you widen your browser window.' =>
      'When editing $terms.abug, text fields (except the comment box) now grow longer when you widen your browser window.',
    'When viewing $terms.abug, the Depends On and Blocks list will display $terms.abug\'s alias if it has one, instead of its id. Also, closed $terms.bugs will be sorted to the end of the list.' =>
      'When viewing $terms.abug, the Depends On and Blocks list will display $terms.abug\'s alias if it has one, instead of its id. Also, closed $terms.bugs will be sorted to the end of the list.',
    'If you use the time-tracking features of $terms.Bugzilla, and you enable the time-tracking related columns in a search result, then you will see a summary of the time-tracking data at the bottom of the search result.' =>
      'If you use the time-tracking features of $terms.Bugzilla, and you enable the time-tracking related columns in a search result, then you will see a summary of the time-tracking data at the bottom of the search result.',
    'For users of time-tracking, the' =>
      'For users of time-tracking, the',
    'page now contains more data.' =>
      'page now contains more data.',
    'When viewing an attachment\'s details page while you are logged-out, flags are no longer shown as editable.' =>
      'When viewing an attachment\'s details page while you are logged-out, flags are no longer shown as editable.',
    'Cloning $terms.abug will now retain the "Blocks" and "Depends On" fields from the $terms.bug being cloned.' =>
      'Cloning $terms.abug will now retain the "Blocks" and "Depends On" fields from the $terms.bug being cloned.',
    '$terms.Bugmail for new $terms.bugs will now indicate what security groups the $terms.bug has been restricted to.' =>
      '$terms.Bugmail for new $terms.bugs will now indicate what security groups the $terms.bug has been restricted to.',
    'You can now use any custom drop-down field as an axis for a tabular or graphical report.' =>
      'You can now use any custom drop-down field as an axis for a tabular or graphical report.',
    'X-Bugzilla-Type' =>
      'X-Bugzilla-Type',
    'header in emails sent by $terms.Bugzilla is now "new" for $terms.bugmail sent for newly-filed $terms.bugs, and "changed" for emails having to do with updated $terms.bugs.' =>
      'header in emails sent by $terms.Bugzilla is now "new" for $terms.bugmail sent for newly-filed $terms.bugs, and "changed" for emails having to do with updated $terms.bugs.',
    'Mails sent by the "Whining" system now contain the header' =>
      'Mails sent by the "Whining" system now contain the header',
    'X-Bugzilla-Type: whine' =>
      'X-Bugzilla-Type: whine',
    '$terms.bugmail now contains a X-Bugzilla-URL header to uniquely identify which $terms.Bugzilla installation the email came from.' =>
      '$terms.bugmail now contains a X-Bugzilla-URL header to uniquely identify which $terms.Bugzilla installation the email came from.',
    'If you input an invalid regular expression anywhere in $terms.Bugzilla, it will now tell you explicitly instead of failing cryptically.' =>
      'If you input an invalid regular expression anywhere in $terms.Bugzilla, it will now tell you explicitly instead of failing cryptically.',
    'duplicates.xul' =>
      'duplicates.xul',
    'page (which wasn\'t used by very many people) is now gone.' =>
      'page (which wasn\'t used by very many people) is now gone.',
    '$terms.Bugzilla now uses the SHA-256 algorithm (a variant of SHA-2) to encrypt passwords in the database, instead of using Unix\'s "crypt" function. This allows passwords longer than eight characters to actually be effective. Each user\'s password will be converted to SHA-256 the first time they log in after you upgrade to $terms.Bugzilla 3.4 or later.' =>
      '$terms.Bugzilla now uses the SHA-256 algorithm (a variant of SHA-2) to encrypt passwords in the database, instead of using Unix\'s "crypt" function. This allows passwords longer than eight characters to actually be effective. Each user\'s password will be converted to SHA-256 the first time they log in after you upgrade to $terms.Bugzilla 3.4 or later.',
    'If you are using database replication with $terms.Bugzilla, many more scripts now take advantage of the read-only slave (the "shadowdb"). It may be safe to open up' =>
      'If you are using database replication with $terms.Bugzilla, many more scripts now take advantage of the read-only slave (the "shadowdb"). It may be safe to open up',
    'to search-engine indexing by editing your' =>
      'to search-engine indexing by editing your',
    'robots.txt' =>
      'robots.txt',
    'file, now, if your $terms.Bugzilla is on fast-enough hardware.' =>
      'file, now, if your $terms.Bugzilla is on fast-enough hardware.',
    'The database now uses foreign keys to enforce the validity of relationships between tables. Not every single table has all its foreign keys yet, but most do.' =>
      'The database now uses foreign keys to enforce the validity of relationships between tables. Not every single table has all its foreign keys yet, but most do.',
    'Various parameters have been removed, in an effort to de-clutter the parameter interface and simplify $terms.Bugzilla\'s code. The parameters that were removed were: timezone, supportwatchers, maxpatchsize, commentonclearresolution, commentonreassignbycomponent, showallproducts. They have all been replaced with sensible default behaviors. (For example, user watching is now always enabled.)' =>
      'Various parameters have been removed, in an effort to de-clutter the parameter interface and simplify $terms.Bugzilla\'s code. The parameters that were removed were: timezone, supportwatchers, maxpatchsize, commentonclearresolution, commentonreassignbycomponent, showallproducts. They have all been replaced with sensible default behaviors. (For example, user watching is now always enabled.)',
    'When adding' =>
      'When adding',
    '&amp;debug=1' =>
      '&amp;debug=1',
    'to the end of a' =>
      'to the end of a',
    'URL, $terms.Bugzilla will now also do an EXPLAIN on the query, to help debug performance issues.' =>
      'URL, $terms.Bugzilla will now also do an EXPLAIN on the query, to help debug performance issues.',
    'When editing flag types in the administrative interface, you can now see how many flags of each type have been set.' =>
      'When editing flag types in the administrative interface, you can now see how many flags of each type have been set.',
    'Various functions have been added to the WebService:' =>
      'Various functions have been added to the WebService:',
    'ug.history' =>
      'ug.history',
    'ug.search' =>
      'ug.search',
    'ug.comments' =>
      'ug.comments',
    'ug.update_see_also' =>
      'ug.update_see_also',
    'User.get' =>
      'User.get',
    'is now deprecated).' =>
      'is now deprecated).',
    'For network efficiency, you can now limit which fields are returned from certain WebService functions, like' =>
      'For network efficiency, you can now limit which fields are returned from certain WebService functions, like',
    'There is now a "permissive" argument for the' =>
      'There is now a "permissive" argument for the',
    'ug.get' =>
      'ug.get',
    'WebService function, which causes it not to throw an error when you ask for $terms.bugs you can\'t see.' =>
      'WebService function, which causes it not to throw an error when you ask for $terms.bugs you can\'t see.',
    'method now returns many more fields.' =>
      'method now returns many more fields.',
    'method now returns the ID of the comment that was just added.' =>
      'method now returns the ID of the comment that was just added.',
    'method will now throw an error if you try to add a private comment but do not have the correct permissions. (In previous versions, it would just silently ignore the' =>
      'method will now throw an error if you try to add a private comment but do not have the correct permissions. (In previous versions, it would just silently ignore the',
    'private' =>
      'private',
    'argument if you didn\'t have the correct permissions.)' =>
      'argument if you didn\'t have the correct permissions.)',
    'Many WebService function parameters now take individual values in addition to arrays.' =>
      'Many WebService function parameters now take individual values in addition to arrays.',
    'The WebService now validates input types--it makes sure that dates are in the right format, that ints are actually ints, etc. It will throw an error if you send it invalid data. It also accepts empty ints, doubles, and dateTimes, and translates them to' =>
      'The WebService now validates input types--it makes sure that dates are in the right format, that ints are actually ints, etc. It will throw an error if you send it invalid data. It also accepts empty ints, doubles, and dateTimes, and translates them to',
    'undef' =>
      'undef',
    ': mod_perl support is currently not working on Windows machines.' =>
      ': mod_perl support is currently not working on Windows machines.',
    'When upgrading to 3.4,' =>
      'When upgrading to 3.4,',
    'now re-writes the' =>
      'now re-writes the',
    'file every time it runs, keeping the current values set (if there are any), but moving any unexpected variables into a file called' =>
      'file every time it runs, keeping the current values set (if there are any), but moving any unexpected variables into a file called',
    'localconfig.old' =>
      'localconfig.old',
    '. If you want to continue having custom varibles in' =>
      '. If you want to continue having custom varibles in',
    ', you will have to add them to the' =>
      ', you will have to add them to the',
    'LOCALCONFIG_VARS' =>
      'LOCALCONFIG_VARS',
    'constant in' =>
      'constant in',
    'Bugzilla::Install::Localconfig' =>
      'Bugzilla::Install::Localconfig',
    'Bugzilla::Object-&gt;update()' =>
      'Bugzilla::Object-&gt;update()',
    'now returns something different in list context than it does in scalar context.' =>
      'now returns something different in list context than it does in scalar context.',
    'Bugzilla::Object-&gt;check()' =>
      'Bugzilla::Object-&gt;check()',
    'now can take object ids in addition to names. Just pass in' =>
      'now can take object ids in addition to names. Just pass in',
    '{ id =&gt; $some_value }' =>
      '{ id =&gt; $some_value }',
    'Instead of being defined in' =>
      'Instead of being defined in',
    ', columns for search results are now defined in a subroutine called' =>
      ', columns for search results are now defined in a subroutine called',
    'COLUMNS' =>
      'COLUMNS',
    'in' =>
      'in',
    'Bugzilla::Search' =>
      'Bugzilla::Search',
    '. The data now mostly comes from the' =>
      '. The data now mostly comes from the',
    'fielddefs' =>
      'fielddefs',
    'table in the database. Search.pm now takes a list of column names from fielddefs for its' =>
      'table in the database. Search.pm now takes a list of column names from fielddefs for its',
    'fields' =>
      'fields',
    'argument instead of literal SQL columns.' =>
      'argument instead of literal SQL columns.',
    'Bugzilla::Field-&gt;legal_values' =>
      'Bugzilla::Field-&gt;legal_values',
    'now returns an array of' =>
      'now returns an array of',
    'Bugzilla::Field::Choice' =>
      'Bugzilla::Field::Choice',
    'objects instead of an array of strings. Bugzilla::Field::Choice will be used in more places, in the future.' =>
      'objects instead of an array of strings. Bugzilla::Field::Choice will be used in more places, in the future.',
    'We now use' =>
      'We now use',
    'Bugzilla::Bug-&gt;check()' =>
      'Bugzilla::Bug-&gt;check()',
    'ValidateBugId' =>
      'ValidateBugId',
    'groups' =>
      'groups',
    'bless_groups' =>
      'bless_groups',
    'methods in' =>
      'methods in',
    'Bugzilla::User' =>
      'Bugzilla::User',
    'now return an arrayref of' =>
      'now return an arrayref of',
    'Bugzilla::Group' =>
      'Bugzilla::Group',
    'objects instead of a hashref with group ids and group names.' =>
      'objects instead of a hashref with group ids and group names.',
    'Standard $terms.Bugzilla drop-down fields now have their type set to' =>
      'Standard $terms.Bugzilla drop-down fields now have their type set to',
    'FIELD_TYPE_SINGLE_SELECT' =>
      'FIELD_TYPE_SINGLE_SELECT',
    'in the fielddefs table.' =>
      'in the fielddefs table.',
    'Bugzilla-&gt;usage_mode' =>
      'Bugzilla-&gt;usage_mode',
    'now defaults to' =>
      'now defaults to',
    'USAGE_MODE_CMDLINE' =>
      'USAGE_MODE_CMDLINE',
    'if we are not running inside a web server.' =>
      'if we are not running inside a web server.',
    'We no longer delete environment variables like' =>
      'We no longer delete environment variables like',
    '$ENV{PATH}' =>
      '$ENV{PATH}',
    'automatically unless we\'re actually running in taint mode.' =>
      'automatically unless we\'re actually running in taint mode.',
    'We are now using YUI 2.6.0.' =>
      'We are now using YUI 2.6.0.',
    'In' =>
      'In',
    'the RDF format of config.cgi' =>
      'the RDF format of config.cgi',
    ', the "resource" attribute for flags now contains "flag.cgi" instead of "flags.cgi".' =>
      ', the "resource" attribute for flags now contains "flag.cgi" instead of "flags.cgi".',
    '$terms.Bugzilla 3.2 Release Notes' =>
      '$terms.Bugzilla 3.2 Release Notes',
    'Updates In This 3.2.x Release' =>
      'Updates In This 3.2.x Release',
    'Security Fixes In This 3.2.x Release' =>
      'Security Fixes In This 3.2.x Release',
    'How to Upgrade From An Older Version' =>
      'How to Upgrade From An Older Version',
    'Welcome to $terms.Bugzilla 3.2! This is our first major feature release since $terms.Bugzilla 3.0, and it brings a lot of great improvements and polish to the $terms.Bugzilla experience.' =>
      'Welcome to $terms.Bugzilla 3.2! This is our first major feature release since $terms.Bugzilla 3.0, and it brings a lot of great improvements and polish to the $terms.Bugzilla experience.',
    '. If you are upgrading from a release before 3.0, make sure to read the release notes for all the' =>
      '. If you are upgrading from a release before 3.0, make sure to read the release notes for all the',
    'in between your version and this one, <strong>particularly the "Notes For Upgraders" section of each version\'s release notes</strong>.' =>
      'in between your version and this one, <strong>particularly the "Notes For Upgraders" section of each version\'s release notes</strong>.',
    'Updates in this 3.2.x Release' =>
      'Updates in this 3.2.x Release',
    'This section describes what\'s changed in the most recent b' =>
      'This section describes what\'s changed in the most recent b',
    'ug-fix releases of $terms.Bugzilla after 3.2. We only list the most important fixes in each release. If you want a detailed list of <em>everything</em> that\'s changed in each version, you should use our' =>
      'ug-fix releases of $terms.Bugzilla after 3.2. We only list the most important fixes in each release. If you want a detailed list of <em>everything</em> that\'s changed in each version, you should use our',
    'Change Log Page' =>
      'Change Log Page',
    '$terms.Bugzilla is now compatible with MySQL 5.1.x versions 5.1.31 and greater. (' =>
      '$terms.Bugzilla is now compatible with MySQL 5.1.x versions 5.1.31 and greater. (',
    'On Windows, $terms.Bugzilla sometimes would send mangled emails (that would often fail to send). (' =>
      'On Windows, $terms.Bugzilla sometimes would send mangled emails (that would often fail to send). (',
    'recode.pl' =>
      'recode.pl',
    'would sometimes crash when trying to convert databases from older versions of $terms.Bugzilla. (' =>
      'would sometimes crash when trying to convert databases from older versions of $terms.Bugzilla. (',
    'Running a saved search with Unicode characters in its name would cause $terms.Bugzilla to crash. (' =>
      'Running a saved search with Unicode characters in its name would cause $terms.Bugzilla to crash. (',
    '$terms.Bugzilla clients like Mylyn can now update $terms.bugs again (the $terms.bug XML format now contains a "token" element that can be used when updating $terms.abug). (' =>
      '$terms.Bugzilla clients like Mylyn can now update $terms.bugs again (the $terms.bug XML format now contains a "token" element that can be used when updating $terms.abug). (',
    'For installations using the' =>
      'For installations using the',
    'shadowdb' =>
      'shadowdb',
    'parameter, $terms.Bugzilla was accidentally writing to the "tokens" table in the shadow database (instead of the master database) when using the "Change Several $terms.Bugs at Once" page. (' =>
      'parameter, $terms.Bugzilla was accidentally writing to the "tokens" table in the shadow database (instead of the master database) when using the "Change Several $terms.Bugs at Once" page. (',
    'This release also contains a security fix. See the' =>
      'This release also contains a security fix. See the',
    'Security Fixes Section' =>
      'Security Fixes Section',
    'This release fixes one security issue that is critical for installations running 3.2.1 under mod_perl. See the' =>
      'This release fixes one security issue that is critical for installations running 3.2.1 under mod_perl. See the',
    'Attachments, charts, and graphs would sometimes be garbled on Windows. (' =>
      'Attachments, charts, and graphs would sometimes be garbled on Windows. (',
    'Saving changes to parameters would sometimes fail silently (particularly on Windows when the web server didn\'t have the right permissions to update the' =>
      'Saving changes to parameters would sometimes fail silently (particularly on Windows when the web server didn\'t have the right permissions to update the',
    'params' =>
      'params',
    'file). $terms.Bugzilla will now throw an error in this case, telling you what is wrong. (' =>
      'file). $terms.Bugzilla will now throw an error in this case, telling you what is wrong. (',
    'If you were using the' =>
      'If you were using the',
    'usemenuforusers' =>
      'usemenuforusers',
    'parameter, and $terms.abug was assigned to (or had a QA Contact of) a disabled user, that field would be reset to the first user in the list when updating $terms.abug. (' =>
      'parameter, and $terms.abug was assigned to (or had a QA Contact of) a disabled user, that field would be reset to the first user in the list when updating $terms.abug. (',
    'PROJECT' =>
      'PROJECT',
    'environment variable to have multiple $terms.Bugzilla installations using one codebase, project-specific templates were being ignored. (' =>
      'environment variable to have multiple $terms.Bugzilla installations using one codebase, project-specific templates were being ignored. (',
    'Some versions of the SOAP::Lite Perl module had a b' =>
      'Some versions of the SOAP::Lite Perl module had a b',
    'ug that caused $terms.Bugzilla\'s XML-RPC service to break.' =>
      'ug that caused $terms.Bugzilla\'s XML-RPC service to break.',
    'now checks for these bad versions and will reject them. (' =>
      'now checks for these bad versions and will reject them. (',
    'The font sizes in various places were too small, when using the Classic skin. (' =>
      'The font sizes in various places were too small, when using the Classic skin. (',
    'This release fixes one security issue related to attachments. See the' =>
      'This release fixes one security issue related to attachments. See the',
    'This release contains several security fixes. One fix may break any automated scripts you have that are loading' =>
      'This release contains several security fixes. One fix may break any automated scripts you have that are loading',
    'directly. We recommend that you read the entire' =>
      'directly. We recommend that you read the entire',
    'for this release.' =>
      'for this release.',
    'Any requirements that are new since 3.0.5 will look like' =>
      'Any requirements that are new since 3.0.5 will look like',
    'v<strong>5.8.1</strong>' =>
      'v<strong>5.8.1</strong>',
    '<strong>perl module:</strong> DBD::mysql' =>
      '<strong>perl module:</strong> DBD::mysql',
    'v4.00' =>
      'v4.00',
    'Email Addresses Hidden From Logged-Out Users For Oracle Users' =>
      'Email Addresses Hidden From Logged-Out Users For Oracle Users',
    '3.21 (on Perl 5.8.x) or 3.33 (on Perl 5.10.x)' =>
      '3.21 (on Perl 5.8.x) or 3.33 (on Perl 5.10.x)',
    'File::Spec' =>
      'File::Spec',
    'Major UI Improvements' =>
      'Major UI Improvements',
    'New Default Skin: Dusk' =>
      'New Default Skin: Dusk',
    'Custom Status Workflow' =>
      'Custom Status Workflow',
    'New Custom Field Types' =>
      'New Custom Field Types',
    'Easier Installation' =>
      'Easier Installation',
    'Experimental Oracle Support' =>
      'Experimental Oracle Support',
    'Improved UTF-8 Support' =>
      'Improved UTF-8 Support',
    'Group Icons' =>
      'Group Icons',
    '$terms.Bugzilla 3.2 has had some UI assistance from the NASA Human-Computer Interaction department and the new' =>
      '$terms.Bugzilla 3.2 has had some UI assistance from the NASA Human-Computer Interaction department and the new',
    '$terms.Bugzilla User Interface Team' =>
      '$terms.Bugzilla User Interface Team',
    'In particular, you will notice a massively redesigned $terms.bug editing form, in addition to our' =>
      'In particular, you will notice a massively redesigned $terms.bug editing form, in addition to our',
    'new skin' =>
      'new skin',
    '$terms.Bugzilla 3.2 now ships with a skin called "Dusk" that is a bit more colorful than old default "Classic" skin.' =>
      '$terms.Bugzilla 3.2 now ships with a skin called "Dusk" that is a bit more colorful than old default "Classic" skin.',
    'Upgrading installations will still default to the "Classic" skin--administrators can change the default in the Default Preferences control panel. Users can also choose to use the old skin in their Preferences (or using the View :: Page Style menu in Firefox).' =>
      'Upgrading installations will still default to the "Classic" skin--administrators can change the default in the Default Preferences control panel. Users can also choose to use the old skin in their Preferences (or using the View :: Page Style menu in Firefox).',
    'The changes that $terms.Bugzilla required for Dusk made $terms.Bugzilla much easier to skin. See the' =>
      'The changes that $terms.Bugzilla required for Dusk made $terms.Bugzilla much easier to skin. See the',
    'Addons page' =>
      'Addons page',
    'for additional skins, or try making your own!' =>
      'for additional skins, or try making your own!',
    'You can now customize the list of statuses in $terms.Bugzilla, and transitions between them.' =>
      'You can now customize the list of statuses in $terms.Bugzilla, and transitions between them.',
    'You can also specify that a comment must be made on certain transitions.' =>
      'You can also specify that a comment must be made on certain transitions.',
    '$terms.Bugzilla 3.2 has support for three new types of custom fields:' =>
      '$terms.Bugzilla 3.2 has support for three new types of custom fields:',
    'Large Text: Adds a multi-line textbox to your $terms.bugs.' =>
      'Large Text: Adds a multi-line textbox to your $terms.bugs.',
    'Multiple Selection Box: Adds a box that allows you to choose multiple items from a list.' =>
      'Multiple Selection Box: Adds a box that allows you to choose multiple items from a list.',
    'Date/Time: Displays a date and time, along with a JavaScript calendar popup to make picking a date easier.' =>
      'Date/Time: Displays a date and time, along with a JavaScript calendar popup to make picking a date easier.',
    '$terms.Bugzilla now comes with a script called' =>
      '$terms.Bugzilla now comes with a script called',
    'that can automatically download and install all of the required Perl modules for $terms.Bugzilla. It stores them in a directory inside your $terms.Bugzilla installation, so you can use it even if you don\'t have administrator-level access to your machine, and without modifying your main Perl install.' =>
      'that can automatically download and install all of the required Perl modules for $terms.Bugzilla. It stores them in a directory inside your $terms.Bugzilla installation, so you can use it even if you don\'t have administrator-level access to your machine, and without modifying your main Perl install.',
    'will print out instructions for using' =>
      'will print out instructions for using',
    ', or you can read its' =>
      ', or you can read its',
    'documentation' =>
      'documentation',
    '$terms.Bugzilla 3.2 contains experimental support for using Oracle as its database. Some features of $terms.Bugzilla are known to be broken on Oracle, but hopefully will be working by our next major release.' =>
      '$terms.Bugzilla 3.2 contains experimental support for using Oracle as its database. Some features of $terms.Bugzilla are known to be broken on Oracle, but hopefully will be working by our next major release.',
    'The $terms.Bugzilla Project, as an open-source project, of course does not recommend the use of proprietary database solutions. However, if your organization requires that you use Oracle, this will allow you to use $terms.Bugzilla!' =>
      'The $terms.Bugzilla Project, as an open-source project, of course does not recommend the use of proprietary database solutions. However, if your organization requires that you use Oracle, this will allow you to use $terms.Bugzilla!',
    'The $terms.Bugzilla Project thanks Oracle Corp. for their extensive development contributions to $terms.Bugzilla which allowed this to happen!' =>
      'The $terms.Bugzilla Project thanks Oracle Corp. for their extensive development contributions to $terms.Bugzilla which allowed this to happen!',
    '$terms.Bugzilla 3.2 now has advanced UTF-8 support in its code, including correct handling for truncating and wrapping multi-byte languages. Major issues with multi-byte or unusual languages are now resolved, and $terms.Bugzilla should now be usable by users in every country with little (or at least much less) customization.' =>
      '$terms.Bugzilla 3.2 now has advanced UTF-8 support in its code, including correct handling for truncating and wrapping multi-byte languages. Major issues with multi-byte or unusual languages are now resolved, and $terms.Bugzilla should now be usable by users in every country with little (or at least much less) customization.',
    'Administrators can now specify that users who are in certain groups should have an icon appear next to their name whenever they comment. This is particularly useful for distinguishing developers from $terms.bug reporters.' =>
      'Administrators can now specify that users who are in certain groups should have an icon appear next to their name whenever they comment. This is particularly useful for distinguishing developers from $terms.bug reporters.',
    'These are either minor enhancements, or enhancements that have very short descriptions. Some of these are very useful, though!' =>
      'These are either minor enhancements, or enhancements that have very short descriptions. Some of these are very useful, though!',
    'Enhancements For Users' =>
      'Enhancements For Users',
    '<strong>$terms.Bugs</strong>: You can now reassign $terms.abug at the same time as you are changing its status.' =>
      '<strong>$terms.Bugs</strong>: You can now reassign $terms.abug at the same time as you are changing its status.',
    '<strong>$terms.Bugs</strong>: When entering $terms.abug, you will now see the description of a component when you select it.' =>
      '<strong>$terms.Bugs</strong>: When entering $terms.abug, you will now see the description of a component when you select it.',
    '<strong>$terms.Bugs</strong>: The $terms.bug view now contains some' =>
      '<strong>$terms.Bugs</strong>: The $terms.bug view now contains some',
    'Microformats' =>
      'Microformats',
    ', most notably for users\' names and email addresses.' =>
      ', most notably for users\' names and email addresses.',
    '<strong>$terms.Bugs</strong>: You can now remove a QA Contact from $terms.abug simply by clearing the QA Contact field.' =>
      '<strong>$terms.Bugs</strong>: You can now remove a QA Contact from $terms.abug simply by clearing the QA Contact field.',
    '<strong>$terms.Bugs</strong>: There is now a user preference that will allow you to exclude the quoted text when replying to comments.' =>
      '<strong>$terms.Bugs</strong>: There is now a user preference that will allow you to exclude the quoted text when replying to comments.',
    '<strong>$terms.Bugs</strong>: You can now expand or collapse individual comments in the $terms.bug view.' =>
      '<strong>$terms.Bugs</strong>: You can now expand or collapse individual comments in the $terms.bug view.',
    '<strong>Attachments</strong>: There is now "mid-air collision" protection when editing attachments.' =>
      '<strong>Attachments</strong>: There is now "mid-air collision" protection when editing attachments.',
    '<strong>Attachments</strong>: Patches in the Diff Viewer now show line numbers (' =>
      '<strong>Attachments</strong>: Patches in the Diff Viewer now show line numbers (',
    'Example' =>
      'Example',
    '<strong>Attachments</strong>: After creating or updating an attachment, you will be immediately shown the $terms.bug that the attachment is on.' =>
      '<strong>Attachments</strong>: After creating or updating an attachment, you will be immediately shown the $terms.bug that the attachment is on.',
    '<strong>Search</strong>: You can now reverse the sort of $terms.abug list by clicking on a column header again.' =>
      '<strong>Search</strong>: You can now reverse the sort of $terms.abug list by clicking on a column header again.',
    '<strong>Search</strong>: Atom feeds of $terms.bug lists now contain more fields.' =>
      '<strong>Search</strong>: Atom feeds of $terms.bug lists now contain more fields.',
    '<strong>Search</strong>: QuickSearch now supports searching flags and groups. It also now includes the OS field in the list of fields it searches by default.' =>
      '<strong>Search</strong>: QuickSearch now supports searching flags and groups. It also now includes the OS field in the list of fields it searches by default.',
    '<strong>Search</strong>: "Help" text can now appear on query.cgi for Internet Explorer and other non-Firefox browsers. (It always could appear for Firefox.)' =>
      '<strong>Search</strong>: "Help" text can now appear on query.cgi for Internet Explorer and other non-Firefox browsers. (It always could appear for Firefox.)',
    '$terms.Bugzilla now ships with an icon that will show up next to the URL in most browsers. If you want to replace it, it\'s in' =>
      '$terms.Bugzilla now ships with an icon that will show up next to the URL in most browsers. If you want to replace it, it\'s in',
    'images/favicon.ico' =>
      'images/favicon.ico',
    'You can now set the Deadline when using "Change Several $terms.Bugs At Once"' =>
      'You can now set the Deadline when using "Change Several $terms.Bugs At Once"',
    '<strong>Saved Searches</strong> now save their column list, so if you customize the list of columns and save your search, it will always contain those columns.' =>
      '<strong>Saved Searches</strong> now save their column list, so if you customize the list of columns and save your search, it will always contain those columns.',
    '<strong>Saved Searches</strong>: When you share a search, you can now see how many users have subscribed to it, on' =>
      '<strong>Saved Searches</strong>: When you share a search, you can now see how many users have subscribed to it, on',
    '<strong>Saved Searches</strong>: You can now see what group a shared search was shared to, on the list of available shared searches in' =>
      '<strong>Saved Searches</strong>: You can now see what group a shared search was shared to, on the list of available shared searches in',
    '<strong>Flags</strong>: If your installation uses drop-down user lists, the flag requestee box will now contain only users who are actually allowed to take requests.' =>
      '<strong>Flags</strong>: If your installation uses drop-down user lists, the flag requestee box will now contain only users who are actually allowed to take requests.',
    '<strong>Flags</strong>: If somebody makes a request to you, and you change the requestee to somebody else, the requester is no longer set to you. In other words, you can "redirect" requests and maintain the original requester.' =>
      '<strong>Flags</strong>: If somebody makes a request to you, and you change the requestee to somebody else, the requester is no longer set to you. In other words, you can "redirect" requests and maintain the original requester.',
    '<strong>Flags</strong>: Emails about flags now will thread properly in email clients to be a part of $terms.abug\'s thread.' =>
      '<strong>Flags</strong>: Emails about flags now will thread properly in email clients to be a part of $terms.abug\'s thread.',
    ', you can now add users to the CC list by just using' =>
      ', you can now add users to the CC list by just using',
    '@cc' =>
      '@cc',
    'as the field name.' =>
      'as the field name.',
    'Many pages (particularly administrative pages) now contain links to the relevant section of the $terms.Bugzilla Guide, so you can read the documentation for that page.' =>
      'Many pages (particularly administrative pages) now contain links to the relevant section of the $terms.Bugzilla Guide, so you can read the documentation for that page.',
    'Dependency Graphs should render more quickly, as they now (by default) only include the same $terms.bugs that you\'d see in the dependency tree.' =>
      'Dependency Graphs should render more quickly, as they now (by default) only include the same $terms.bugs that you\'d see in the dependency tree.',
    'Enhancements For Administrators' =>
      'Enhancements For Administrators',
    '<strong>Admin UI</strong>: Instead of having the Administration Control Panel links in the footer, there is now just one link called "Administration" that takes you to a page that links to all the administrative controls for $terms.Bugzilla.' =>
      '<strong>Admin UI</strong>: Instead of having the Administration Control Panel links in the footer, there is now just one link called "Administration" that takes you to a page that links to all the administrative controls for $terms.Bugzilla.',
    '<strong>Admin UI</strong>: Administrative pages no longer display confirmation pages, instead they redirect you to some useful page and display a message about what changed.' =>
      '<strong>Admin UI</strong>: Administrative pages no longer display confirmation pages, instead they redirect you to some useful page and display a message about what changed.',
    '<strong>Admin UI</strong>: The interface for editing group inheritance in' =>
      '<strong>Admin UI</strong>: The interface for editing group inheritance in',
    'is much clearer now.' =>
      'is much clearer now.',
    '<strong>Admin UI</strong>: When editing a user, you can now see all the components where that user is the Default Assignee or Default QA Contact.' =>
      '<strong>Admin UI</strong>: When editing a user, you can now see all the components where that user is the Default Assignee or Default QA Contact.',
    '<strong>Email</strong>: For installations that use SMTP to send mail (as opposed to Sendmail), $terms.Bugzilla now supports SMTP Authentication, so that it can log in to your mail server before sending messages.' =>
      '<strong>Email</strong>: For installations that use SMTP to send mail (as opposed to Sendmail), $terms.Bugzilla now supports SMTP Authentication, so that it can log in to your mail server before sending messages.',
    '<strong>Email</strong>: Using the "Test" mail delivery method now creates a valid mbox file to make testing easier.' =>
      '<strong>Email</strong>: Using the "Test" mail delivery method now creates a valid mbox file to make testing easier.',
    '<strong>Authentication</strong>: $terms.Bugzilla now correctly handles LDAP records which contain multiple email addresses. (The first email address in the list that is a valid $terms.Bugzilla account will be used, or if this is a new user, the first email address in the list will be used.)' =>
      '<strong>Authentication</strong>: $terms.Bugzilla now correctly handles LDAP records which contain multiple email addresses. (The first email address in the list that is a valid $terms.Bugzilla account will be used, or if this is a new user, the first email address in the list will be used.)',
    '<strong>Authentication</strong>: $terms.Bugzilla can now take a list of LDAP servers to try in order until it gets a successful connection.' =>
      '<strong>Authentication</strong>: $terms.Bugzilla can now take a list of LDAP servers to try in order until it gets a successful connection.',
    '<strong>Authentication</strong>: $terms.Bugzilla now supports RADIUS authentication.' =>
      '<strong>Authentication</strong>: $terms.Bugzilla now supports RADIUS authentication.',
    '<strong>Security</strong>: The login cookie is now created as "HTTPOnly" so that it can\'t be read by possibly malicious scripts. Also, if SSL is enabled on your installation, the login cookie is now only sent over SSL connections.' =>
      '<strong>Security</strong>: The login cookie is now created as "HTTPOnly" so that it can\'t be read by possibly malicious scripts. Also, if SSL is enabled on your installation, the login cookie is now only sent over SSL connections.',
    '<strong>Security</strong>: The' =>
      '<strong>Security</strong>: The',
    'parameter now protects every page a logged-in user accesses, when set to "authenticated sessions." Also, SSL is now enforced appropriately in the WebServices interface when the parameter is set.' =>
      'parameter now protects every page a logged-in user accesses, when set to "authenticated sessions." Also, SSL is now enforced appropriately in the WebServices interface when the parameter is set.',
    '<strong>Database</strong>: $terms.Bugzilla now uses transactions in the database instead of table locks. This should generally improve performance with many concurrent users. It also means if there is an unexpected error in the middle of a page, all database changes made during that page will be rolled back.' =>
      '<strong>Database</strong>: $terms.Bugzilla now uses transactions in the database instead of table locks. This should generally improve performance with many concurrent users. It also means if there is an unexpected error in the middle of a page, all database changes made during that page will be rolled back.',
    '<strong>Database</strong>: You no longer have to set' =>
      '<strong>Database</strong>: You no longer have to set',
    'max_packet_size' =>
      'max_packet_size',
    'in MySQL to add large attachments. However, you may need to set it manually if you restore a mysqldump into your database.' =>
      'in MySQL to add large attachments. However, you may need to set it manually if you restore a mysqldump into your database.',
    'New WebService functions:' =>
      'New WebService functions:',
    'Bugzilla.extensions' =>
      'Bugzilla.extensions',
    'You can now delete custom fields, but only if they have never been set on any $terms.bug.' =>
      'You can now delete custom fields, but only if they have never been set on any $terms.bug.',
    'There is now a' =>
      'There is now a',
    '--reset-password' =>
      '--reset-password',
    'argument to' =>
      'argument to',
    'that allows you to reset a user\'s password from the command line.' =>
      'that allows you to reset a user\'s password from the command line.',
    'There is now a script called' =>
      'There is now a script called',
    'sanitycheck.pl' =>
      'sanitycheck.pl',
    'that you can run from the command line. It works just like' =>
      'that you can run from the command line. It works just like',
    '. By default, it only outputs anything if there\'s an error, so it\'s ideal for administrators who want to run it nightly in a cron job.' =>
      '. By default, it only outputs anything if there\'s an error, so it\'s ideal for administrators who want to run it nightly in a cron job.',
    'strict_isolation' =>
      'strict_isolation',
    'parameter now prevents you from setting users who cannot see $terms.abug as a CC, Assignee, or QA Contact. Previously it only prevented you from adding users who could not <em>edit</em> the $terms.bug.' =>
      'parameter now prevents you from setting users who cannot see $terms.abug as a CC, Assignee, or QA Contact. Previously it only prevented you from adding users who could not <em>edit</em> the $terms.bug.',
    'Extensions can now add their own headers to the HTML &lt;head&gt; for things like custom CSS and so on.' =>
      'Extensions can now add their own headers to the HTML &lt;head&gt; for things like custom CSS and so on.',
    'has been templatized, meaning that the entire $terms.Bugzilla UI is now contained in templates.' =>
      'has been templatized, meaning that the entire $terms.Bugzilla UI is now contained in templates.',
    'When setting the' =>
      'When setting the',
    'sslbase' =>
      'sslbase',
    'parameter, you can now specify a port number in the URL.' =>
      'parameter, you can now specify a port number in the URL.',
    'When importing $terms.bugs using' =>
      'When importing $terms.bugs using',
    'importxml.pl' =>
      'importxml.pl',
    ', attachments will have their actual creator set as their creator, instead of the person who exported the $terms.bug from the other system.' =>
      ', attachments will have their actual creator set as their creator, instead of the person who exported the $terms.bug from the other system.',
    'The voting system is off by default in new installs. This is to prepare for the fact that it will be moved into an extension at some point in the future.' =>
      'The voting system is off by default in new installs. This is to prepare for the fact that it will be moved into an extension at some point in the future.',
    'shutdownhtml' =>
      'shutdownhtml',
    'parameter now works even when $terms.Bugzilla\'s database server is down.' =>
      'parameter now works even when $terms.Bugzilla\'s database server is down.',
    'Enhancements for Localizers (or Localized Installations)' =>
      'Enhancements for Localizers (or Localized Installations)',
    'The documentation can now be localized--in other words, you can have documentation installed for multiple languages at once and $terms.Bugzilla will link to the correct language in its internal documentation links.' =>
      'The documentation can now be localized--in other words, you can have documentation installed for multiple languages at once and $terms.Bugzilla will link to the correct language in its internal documentation links.',
    '$terms.Bugzilla no longer uses the' =>
      '$terms.Bugzilla no longer uses the',
    'languages' =>
      'languages',
    'parameter. Instead it reads the' =>
      'parameter. Instead it reads the',
    'template/' =>
      'template/',
    'directory to see which languages are available.' =>
      'directory to see which languages are available.',
    'Some of the messages printed by' =>
      'Some of the messages printed by',
    'can now be localized. See' =>
      'can now be localized. See',
    'template/en/default/setup/strings.txt.pl' =>
      'template/en/default/setup/strings.txt.pl',
    'Notes For Upgraders' =>
      'Notes For Upgraders',
    'If you upgrade by CVS, the' =>
      'If you upgrade by CVS, the',
    'extensions' =>
      'extensions',
    'skins/contrib' =>
      'skins/contrib',
    'directories are now in CVS instead of being created by' =>
      'directories are now in CVS instead of being created by',
    'If you do a' =>
      'If you do a',
    'cvs update' =>
      'cvs update',
    'from 3.0, you will be told that your directories are "in the way" and you should delete (or move) them and then do' =>
      'from 3.0, you will be told that your directories are "in the way" and you should delete (or move) them and then do',
    'again. Also, the' =>
      'again. Also, the',
    'docs' =>
      'docs',
    'directory has been restructured and after you' =>
      'directory has been restructured and after you',
    'you can delete the' =>
      'you can delete the',
    'docs/html' =>
      'docs/html',
    'docs/pdf' =>
      'docs/pdf',
    'docs/txt' =>
      'docs/txt',
    'docs/xml' =>
      'docs/xml',
    'directories.' =>
      'directories.',
    'If you are using MySQL, you should know that $terms.Bugzilla now uses InnoDB for all tables.' =>
      'If you are using MySQL, you should know that $terms.Bugzilla now uses InnoDB for all tables.',
    'will convert your tables automatically, but if you have InnoDB disabled, the upgrade will not be able to complete (and' =>
      'will convert your tables automatically, but if you have InnoDB disabled, the upgrade will not be able to complete (and',
    'will tell you so).' =>
      'will tell you so).',
    '<strong>You should also read the' =>
      '<strong>You should also read the',
    '$terms.Bugzilla 3.0 Notes For Upgraders section' =>
      '$terms.Bugzilla 3.0 Notes For Upgraders section',
    'of the' =>
      'of the',
    'previous release notes' =>
      'previous release notes',
    'if you are upgrading from a version before 3.0.</strong>' =>
      'if you are upgrading from a version before 3.0.</strong>',
    'Steps For Upgrading' =>
      'Steps For Upgrading',
    'Once you have read the notes above, see the' =>
      'Once you have read the notes above, see the',
    'Upgrading documentation' =>
      'Upgrading documentation',
    'for instructions on how to upgrade.' =>
      'for instructions on how to upgrade.',
    'More Hooks!' =>
      'More Hooks!',
    'Search.pm Rearchitecture' =>
      'Search.pm Rearchitecture',
    'lib Directory' =>
      'lib Directory',
    'Other Changes' =>
      'Other Changes',
    'There are more code hooks in 3.2 than there were in 3.0. See the documentation of' =>
      'There are more code hooks in 3.2 than there were in 3.0. See the documentation of',
    'Bugzilla::Hook' =>
      'Bugzilla::Hook',
    'for more details.' =>
      'for more details.',
    'Bugzilla/Search.pm' =>
      'Bugzilla/Search.pm',
    'has been heavily modified, to be much easier to read and use. It contains mostly the same code as it did in 3.0, but it has been moved around and reorganized significantly.' =>
      'has been heavily modified, to be much easier to read and use. It contains mostly the same code as it did in 3.0, but it has been moved around and reorganized significantly.',
    'As part of implementing' =>
      'As part of implementing',
    ', $terms.Bugzilla was given a local' =>
      ', $terms.Bugzilla was given a local',
    'lib' =>
      'lib',
    'directory which it searches for modules, in addition to the standard system path.' =>
      'directory which it searches for modules, in addition to the standard system path.',
    'This means that all $terms.Bugzilla scripts now start with' =>
      'This means that all $terms.Bugzilla scripts now start with',
    'use lib qw(. lib);' =>
      'use lib qw(. lib);',
    'as one of the first lines.' =>
      'as one of the first lines.',
    'You should now be using' =>
      'You should now be using',
    'get_status(\'NEW\')' =>
      'get_status(\'NEW\')',
    'status_descs.NEW' =>
      'status_descs.NEW',
    '[&#37;# version = 1.0 &#37;]' =>
      '[&#37;# version = 1.0 &#37;]',
    'comment at the top of every template file has been removed.' =>
      'comment at the top of every template file has been removed.',
    '$terms.Bugzilla 3.0.x Release Notes' =>
      '$terms.Bugzilla 3.0.x Release Notes',
    'Updates In This 3.0.x Release' =>
      'Updates In This 3.0.x Release',
    'Security Fixes In This Release' =>
      'Security Fixes In This Release',
    'Welcome to $terms.Bugzilla 3.0! It\'s been over eight years since we released $terms.Bugzilla 2.0, and everything has changed since then. Even just since our previous release, $terms.Bugzilla 2.22, we\'ve added a <em>lot</em> of new features. So enjoy the release, we\'re happy to bring it to you.' =>
      'Welcome to $terms.Bugzilla 3.0! It\'s been over eight years since we released $terms.Bugzilla 2.0, and everything has changed since then. Even just since our previous release, $terms.Bugzilla 2.22, we\'ve added a <em>lot</em> of new features. So enjoy the release, we\'re happy to bring it to you.',
    '. If you are upgrading from a release before 2.22, make sure to read the release notes for all the' =>
      '. If you are upgrading from a release before 2.22, make sure to read the release notes for all the',
    'in between your version and this one.' =>
      'in between your version and this one.',
    'Updates in this 3.0.x Release' =>
      'Updates in this 3.0.x Release',
    'ug-fix releases of $terms.Bugzilla after 3.0. We only list the most important fixes in each release. If you want a detailed list of <em>everything</em> that\'s changed in each version, you should use our' =>
      'ug-fix releases of $terms.Bugzilla after 3.0. We only list the most important fixes in each release. If you want a detailed list of <em>everything</em> that\'s changed in each version, you should use our',
    'Before 3.0.6, unexpected fatal WebService errors would result in a' =>
      'Before 3.0.6, unexpected fatal WebService errors would result in a',
    'faultCode' =>
      'faultCode',
    'that was a string instead of a number. (' =>
      'that was a string instead of a number. (',
    'If you created a product or component with the same name as one you previously deleted, it would fail with an error about the series table. (' =>
      'If you created a product or component with the same name as one you previously deleted, it would fail with an error about the series table. (',
    'See also the' =>
      'See also the',
    'section for information about a security issue fixed in this release.' =>
      'section for information about a security issue fixed in this release.',
    'If you don\'t have permission to set a flag, it will now appear unchangeable in the UI. (' =>
      'If you don\'t have permission to set a flag, it will now appear unchangeable in the UI. (',
    'If you were running mod_perl, $terms.Bugzilla was not correctly closing its connections to the database since 3.0.3, and so sometimes the DB would run out of connections. (' =>
      'If you were running mod_perl, $terms.Bugzilla was not correctly closing its connections to the database since 3.0.3, and so sometimes the DB would run out of connections. (',
    'The installation script is now clear about exactly which' =>
      'The installation script is now clear about exactly which',
    'Email::' =>
      'Email::',
    'modules are required in Perl, thus avoiding the problem where emails show up with a body like' =>
      'modules are required in Perl, thus avoiding the problem where emails show up with a body like',
    'SCALAR(0xBF126795)' =>
      'SCALAR(0xBF126795)',
    'is no longer case-sensitive for values of' =>
      'is no longer case-sensitive for values of',
    '@product' =>
      '@product',
    'section for information about security issues fixed in this release.' =>
      'section for information about security issues fixed in this release.',
    '$terms.Bugzilla administrators were not being correctly notified about new releases. (' =>
      '$terms.Bugzilla administrators were not being correctly notified about new releases. (',
    'There could be extra whitespace in email subject lines. (' =>
      'There could be extra whitespace in email subject lines. (',
    'The priority, severity, OS, and platform fields were always required by the' =>
      'The priority, severity, OS, and platform fields were always required by the',
    'ug.create' =>
      'ug.create',
    'WebService function, even if they had defaults specified. (' =>
      'WebService function, even if they had defaults specified. (',
    'Better threading of $terms.bugmail in some email clients. (' =>
      'Better threading of $terms.bugmail in some email clients. (',
    'There were many fixes to the Inbound Email Interface (' =>
      'There were many fixes to the Inbound Email Interface (',
    'checksetup.pl now handles UTF-8 conversion more reliably during upgrades. (' =>
      'checksetup.pl now handles UTF-8 conversion more reliably during upgrades. (',
    'Comments written in CJK languages are now correctly word-wrapped. (' =>
      'Comments written in CJK languages are now correctly word-wrapped. (',
    'All emails will now be sent in the correct language, when the user has chosen a language for emails. (' =>
      'All emails will now be sent in the correct language, when the user has chosen a language for emails. (',
    'On Windows, temporary files created when uploading attachments are now correctly deleted when the upload is complete. (' =>
      'On Windows, temporary files created when uploading attachments are now correctly deleted when the upload is complete. (',
    'now prints correct installation instructions for Windows users using Perl 5.10. (' =>
      'now prints correct installation instructions for Windows users using Perl 5.10. (',
    'mod_perl no longer compiles $terms.Bugzilla\'s code for each Apache process individually. It now compiles code only once and shares it among each Apache process. This greatly improves performance and highly decreases the memory footprint. (' =>
      'mod_perl no longer compiles $terms.Bugzilla\'s code for each Apache process individually. It now compiles code only once and shares it among each Apache process. This greatly improves performance and highly decreases the memory footprint. (',
    'You can now search for \'---\' (without quotes) in versions and milestones. (' =>
      'You can now search for \'---\' (without quotes) in versions and milestones. (',
    '$terms.Bugzilla should no longer break lines unnecessarily in email subjects. This was causing trouble with some email clients. (' =>
      '$terms.Bugzilla should no longer break lines unnecessarily in email subjects. This was causing trouble with some email clients. (',
    'If you had selected "I\'m added to or removed from this capacity" option for the "CC" role in your email preferences, you wouldn\'t get mail when more than one person was added to the CC list at once. (' =>
      'If you had selected "I\'m added to or removed from this capacity" option for the "CC" role in your email preferences, you wouldn\'t get mail when more than one person was added to the CC list at once. (',
    'Deleting a user account no longer deletes whines from another user who has the deleted account as addressee. The schedule is simply removed, but the whine itself is left intact. (' =>
      'Deleting a user account no longer deletes whines from another user who has the deleted account as addressee. The schedule is simply removed, but the whine itself is left intact. (',
    'contrib/merge-users.pl' =>
      'contrib/merge-users.pl',
    'now correctly merges all required fields when merging two user accounts. (' =>
      'now correctly merges all required fields when merging two user accounts. (',
    '$terms.Bugzilla no longer requires Apache::DBI to run under mod_perl. It caused troubles such as lost connections with the DB and didn\'t give any important performance gain. (' =>
      '$terms.Bugzilla no longer requires Apache::DBI to run under mod_perl. It caused troubles such as lost connections with the DB and didn\'t give any important performance gain. (',
    '$terms.Bugzilla should now work on Perl 5.9.5 (and thus the upcoming Perl 5.10.0). (' =>
      '$terms.Bugzilla should now work on Perl 5.9.5 (and thus the upcoming Perl 5.10.0). (',
    'section for information about an important security issue fixed in this release.' =>
      'section for information about an important security issue fixed in this release.',
    'For users of Firefox 2, the' =>
      'For users of Firefox 2, the',
    'user interface should no longer "collapse" after you modify $terms.abug. (' =>
      'user interface should no longer "collapse" after you modify $terms.abug. (',
    'If you can bless a group, and you share a saved search with that group, it will no longer automatically appear in all of that group\'s footers unless you specifically request that it automatically appear in their footers. (' =>
      'If you can bless a group, and you share a saved search with that group, it will no longer automatically appear in all of that group\'s footers unless you specifically request that it automatically appear in their footers. (',
    'There is now a parameter to allow users to perform searches without any search terms. (In other words, to search for just a Product and Status on the Simple Search page.) The parameter is called' =>
      'There is now a parameter to allow users to perform searches without any search terms. (In other words, to search for just a Product and Status on the Simple Search page.) The parameter is called',
    'specific_search_allow_empty_words' =>
      'specific_search_allow_empty_words',
    'If you attach a file that has a MIME-type of' =>
      'If you attach a file that has a MIME-type of',
    'text/x-patch' =>
      'text/x-patch',
    'text/x-diff' =>
      'text/x-diff',
    ', it will automatically be treated as a patch by $terms.Bugzilla. (' =>
      ', it will automatically be treated as a patch by $terms.Bugzilla. (',
    'Dependency Graphs now work correctly on all mod_perl installations. There should now be no remaining signficant problems with running $terms.Bugzilla under mod_perl. (' =>
      'Dependency Graphs now work correctly on all mod_perl installations. There should now be no remaining signficant problems with running $terms.Bugzilla under mod_perl. (',
    'If moving $terms.abug between products would remove groups from the $terms.bug, you are now warned. (' =>
      'If moving $terms.abug between products would remove groups from the $terms.bug, you are now warned. (',
    'On IIS, whenever $terms.Bugzilla threw a warning, it would actually appear on the web page. Now warnings are suppressed, unless you have a file in the' =>
      'On IIS, whenever $terms.Bugzilla threw a warning, it would actually appear on the web page. Now warnings are suppressed, unless you have a file in the',
    'data' =>
      'data',
    'directory called' =>
      'directory called',
    'errorlog' =>
      'errorlog',
    ', in which case warnings will be printed there. (' =>
      ', in which case warnings will be printed there. (',
    'If you used' =>
      'If you used',
    'to edit $terms.abug that was protected by groups, all of the groups would be cleared. (' =>
      'to edit $terms.abug that was protected by groups, all of the groups would be cleared. (',
    'PostgreSQL users: New Charts were failing to collect data over time. They will now start collecting data correctly. (' =>
      'PostgreSQL users: New Charts were failing to collect data over time. They will now start collecting data correctly. (',
    'Some flag mails didn\'t specify who the requestee was. (' =>
      'Some flag mails didn\'t specify who the requestee was. (',
    'Instead of throwing real errors,' =>
      'Instead of throwing real errors,',
    'collectstats.pl' =>
      'collectstats.pl',
    'would just say that it couldn\'t find' =>
      'would just say that it couldn\'t find',
    'ThrowUserError' =>
      'ThrowUserError',
    'Logging into $terms.Bugzilla from the home page works again with IIS5. (' =>
      'Logging into $terms.Bugzilla from the home page works again with IIS5. (',
    'If you were using SMTP for sending email, sometimes emails would be missing the' =>
      'If you were using SMTP for sending email, sometimes emails would be missing the',
    'Date' =>
      'Date',
    'header. (' =>
      'header. (',
    'In the XML-RPC WebService,' =>
      'In the XML-RPC WebService,',
    'now correctly returns values for custom fields if you request values for custom fields. (' =>
      'now correctly returns values for custom fields if you request values for custom fields. (',
    'The "$terms.Bug-Writing Guidelines" page has been shortened and re-written. (' =>
      'The "$terms.Bug-Writing Guidelines" page has been shortened and re-written. (',
    'If your' =>
      'If your',
    'urlbase' =>
      'urlbase',
    'parameter included a port number, like' =>
      'parameter included a port number, like',
    'www.domain.com:8080' =>
      'www.domain.com:8080',
    ', SMTP might have failed. (' =>
      ', SMTP might have failed. (',
    'For SMTP users, there is a new parameter,' =>
      'For SMTP users, there is a new parameter,',
    'smtp_debug' =>
      'smtp_debug',
    '. Turning on this parameter will log the full information about every SMTP session to your web server\'s error log, to help with debugging issues with SMTP. (' =>
      '. Turning on this parameter will log the full information about every SMTP session to your web server\'s error log, to help with debugging issues with SMTP. (',
    'If you are a "global watcher" (you get all mails from every $terms.bug), you can now see that in your Email Preferences. (' =>
      'If you are a "global watcher" (you get all mails from every $terms.bug), you can now see that in your Email Preferences. (',
    'The Status and Resolution of $terms.bugs are now correctly localized in CSV search results. (' =>
      'The Status and Resolution of $terms.bugs are now correctly localized in CSV search results. (',
    'The "Subject" line of an email was being mangled if it contained non-Latin characters. (' =>
      'The "Subject" line of an email was being mangled if it contained non-Latin characters. (',
    'Editing the "languages" parameter using' =>
      'Editing the "languages" parameter using',
    'would sometimes fail, causing $terms.Bugzilla to throw an error. (' =>
      'would sometimes fail, causing $terms.Bugzilla to throw an error. (',
    'Any requirements that are new since 2.22 will look like' =>
      'Any requirements that are new since 2.22 will look like',
    'v<strong>5.8.0</strong>' =>
      'v<strong>5.8.0</strong>',
    '(non-Windows platforms)' =>
      '(non-Windows platforms)',
    'Perl v<strong>5.8.1</strong> (Windows platforms)' =>
      'Perl v<strong>5.8.1</strong> (Windows platforms)',
    'MySQL' =>
      'MySQL',
    'v4.1.2' =>
      'v4.1.2',
    '<strong>perl module:</strong> DBD::mysql v2.9003' =>
      '<strong>perl module:</strong> DBD::mysql v2.9003',
    'Custom Fields' =>
      'Custom Fields',
    'mod_perl Support' =>
      'mod_perl Support',
    'Shared Saved Searches' =>
      'Shared Saved Searches',
    'Attachments and Flags on New $terms.Bugs' =>
      'Attachments and Flags on New $terms.Bugs',
    'Custom Resolutions' =>
      'Custom Resolutions',
    'Per-Product Permissions' =>
      'Per-Product Permissions',
    'User Interface Improvements' =>
      'User Interface Improvements',
    'Skins' =>
      'Skins',
    'Unchangeable Fields Appear Unchangeable' =>
      'Unchangeable Fields Appear Unchangeable',
    'All Emails in Templates' =>
      'All Emails in Templates',
    'No More Double-Filed $terms.Bugs' =>
      'No More Double-Filed $terms.Bugs',
    'Default CC List for Components' =>
      'Default CC List for Components',
    'File/Modify $terms.Bugs By Email' =>
      'File/Modify $terms.Bugs By Email',
    'Users Who Get All $terms.Bug Notifications' =>
      'Users Who Get All $terms.Bug Notifications',
    'Automatic Update Notification' =>
      'Automatic Update Notification',
    'Welcome Page for New Installs' =>
      'Welcome Page for New Installs',
    '$terms.Bugzilla now includes very basic support for custom fields.' =>
      '$terms.Bugzilla now includes very basic support for custom fields.',
    'Users in the' =>
      'Users in the',
    'admin' =>
      'admin',
    'group can add plain-text or drop-down custom fields. You can edit the values available for drop-down fields using the &quot;Field Values&quot; control panel.' =>
      'group can add plain-text or drop-down custom fields. You can edit the values available for drop-down fields using the &quot;Field Values&quot; control panel.',
    'Don\'t add too many custom fields! It can make $terms.Bugzilla very difficult to use. Try your best to get along with the default fields, and then if you find that you can\'t live without custom fields after a few weeks of using $terms.Bugzilla, only then should you start your custom fields.' =>
      'Don\'t add too many custom fields! It can make $terms.Bugzilla very difficult to use. Try your best to get along with the default fields, and then if you find that you can\'t live without custom fields after a few weeks of using $terms.Bugzilla, only then should you start your custom fields.',
    '$terms.Bugzilla 3.0 supports mod_perl, which allows for extremely enhanced page-load performance. mod_perl trades memory usage for performance, allowing near-instantaneous page loads, but using much more memory.' =>
      '$terms.Bugzilla 3.0 supports mod_perl, which allows for extremely enhanced page-load performance. mod_perl trades memory usage for performance, allowing near-instantaneous page loads, but using much more memory.',
    'If you want to enable mod_perl for your $terms.Bugzilla, we recommend a minimum of 1.5GB of RAM, and for a site with heavy traffic, 4GB to 8GB.' =>
      'If you want to enable mod_perl for your $terms.Bugzilla, we recommend a minimum of 1.5GB of RAM, and for a site with heavy traffic, 4GB to 8GB.',
    'If performance isn\'t that critical on your installation, you don\'t have the memory, or you are running some other web server than Apache, $terms.Bugzilla still runs perfectly as a normal CGI application, as well.' =>
      'If performance isn\'t that critical on your installation, you don\'t have the memory, or you are running some other web server than Apache, $terms.Bugzilla still runs perfectly as a normal CGI application, as well.',
    'Users can now choose to &quot;share&quot; their saved searches with a certain group. That group will then be able to &quot;subscribe&quot; to those searches, and have them appear in their footer.' =>
      'Users can now choose to &quot;share&quot; their saved searches with a certain group. That group will then be able to &quot;subscribe&quot; to those searches, and have them appear in their footer.',
    'If the sharer can &quot;bless&quot; the group he\'s sharing to, (that is, if he can add users to that group), it\'s considered that he\'s a manager of that group, and his queries show up automatically in that group\'s footer (although they can unsubscribe from any particular search, if they want.)' =>
      'If the sharer can &quot;bless&quot; the group he\'s sharing to, (that is, if he can add users to that group), it\'s considered that he\'s a manager of that group, and his queries show up automatically in that group\'s footer (although they can unsubscribe from any particular search, if they want.)',
    'In order to allow a user to share their queries, they also have to be a member of the group specified in the' =>
      'In order to allow a user to share their queries, they also have to be a member of the group specified in the',
    'querysharegroup' =>
      'querysharegroup',
    'Users can control their shared and subscribed queries from the &quot;Preferences&quot; screen.' =>
      'Users can control their shared and subscribed queries from the &quot;Preferences&quot; screen.',
    'You can now add an attachment while you are filing a new $terms.bug.' =>
      'You can now add an attachment while you are filing a new $terms.bug.',
    'You can also set flags on the $terms.bug and on attachments, while filing a new $terms.bug.' =>
      'You can also set flags on the $terms.bug and on attachments, while filing a new $terms.bug.',
    'You can now customize the list of resolutions available in $terms.Bugzilla, including renaming the default resolutions.' =>
      'You can now customize the list of resolutions available in $terms.Bugzilla, including renaming the default resolutions.',
    'The resolutions' =>
      'The resolutions',
    'FIXED' =>
      'FIXED',
    'DUPLICATE' =>
      'DUPLICATE',
    'MOVED' =>
      'MOVED',
    'have a special meaning to $terms.Bugzilla, though, and cannot be renamed or deleted.' =>
      'have a special meaning to $terms.Bugzilla, though, and cannot be renamed or deleted.',
    'You can now grant users' =>
      'You can now grant users',
    'editbugs' =>
      'editbugs',
    'canconfirm' =>
      'canconfirm',
    'for only certain products. You can also grant users' =>
      'for only certain products. You can also grant users',
    'editcomponents' =>
      'editcomponents',
    'on a product, which means they will be able to edit that product including adding/removing components and other product-specific controls.' =>
      'on a product, which means they will be able to edit that product including adding/removing components and other product-specific controls.',
    'There has been some work on the user interface for $terms.Bugzilla 3.0, including:' =>
      'There has been some work on the user interface for $terms.Bugzilla 3.0, including:',
    'There is now navigation and a search box a the <em>top</em> of each page, in addition to the bar at the bottom of the page.' =>
      'There is now navigation and a search box a the <em>top</em> of each page, in addition to the bar at the bottom of the page.',
    'A re-designed &quot;Format for Printing&quot; page for $terms.bugs.' =>
      'A re-designed &quot;Format for Printing&quot; page for $terms.bugs.',
    'The layout of' =>
      'The layout of',
    '(the $terms.bug editing page) has been changed, and the attachment table has been redesigned.' =>
      '(the $terms.bug editing page) has been changed, and the attachment table has been redesigned.',
    '$terms.Bugzilla now has a Web Services interface using the XML-RPC protocol. It can be accessed by external applications by going to the' =>
      '$terms.Bugzilla now has a Web Services interface using the XML-RPC protocol. It can be accessed by external applications by going to the',
    'on your installation.' =>
      'on your installation.',
    'Documentation can be found in the' =>
      'Documentation can be found in the',
    '$terms.Bugzilla API Docs' =>
      '$terms.Bugzilla API Docs',
    ', in the various' =>
      ', in the various',
    'modules.' =>
      'modules.',
    '$terms.Bugzilla can have multiple &quot;skins&quot; installed, and users can pick between them. To write a skin, you just have to write several CSS files. See the' =>
      '$terms.Bugzilla can have multiple &quot;skins&quot; installed, and users can pick between them. To write a skin, you just have to write several CSS files. See the',
    'Custom Skins Documentation' =>
      'Custom Skins Documentation',
    'We currently don\'t have any alternate skins shipping with $terms.Bugzilla. If you write an alternate skin, please let us know!' =>
      'We currently don\'t have any alternate skins shipping with $terms.Bugzilla. If you write an alternate skin, please let us know!',
    'As long as you are logged in, when viewing $terms.abug, if you cannot change a field, it will not look like you can change it. That is, the value will just appear as plain text.' =>
      'As long as you are logged in, when viewing $terms.abug, if you cannot change a field, it will not look like you can change it. That is, the value will just appear as plain text.',
    'All outbound emails are now controlled by the templating system. What used to be the' =>
      'All outbound emails are now controlled by the templating system. What used to be the',
    'passwordmail' =>
      'passwordmail',
    'whinemail' =>
      'whinemail',
    'newchangedmail' =>
      'newchangedmail',
    'voteremovedmail' =>
      'voteremovedmail',
    'parameters are now all templates in the' =>
      'parameters are now all templates in the',
    'This means that it\'s now much easier to customize your outbound emails, and it\'s also possible for localizers to have more localized emails as part of their language packs, if they want.' =>
      'This means that it\'s now much easier to customize your outbound emails, and it\'s also possible for localizers to have more localized emails as part of their language packs, if they want.',
    'We also added a' =>
      'We also added a',
    'mailfrom' =>
      'mailfrom',
    'parameter to let you set who shows up in the' =>
      'parameter to let you set who shows up in the',
    'From' =>
      'From',
    'field on all emails that $terms.Bugzilla sends.' =>
      'field on all emails that $terms.Bugzilla sends.',
    'Users of $terms.Bugzilla will sometimes accidentally submit $terms.abug twice, either by going back in their web browser, or just by refreshing a page. In the past, this could file the same $terms.bug twice (or even three times) in a row, irritating developers and confusing users.' =>
      'Users of $terms.Bugzilla will sometimes accidentally submit $terms.abug twice, either by going back in their web browser, or just by refreshing a page. In the past, this could file the same $terms.bug twice (or even three times) in a row, irritating developers and confusing users.',
    'Now, if you try to submit $terms.abug twice from the same screen (by going back or by refreshing the page), $terms.Bugzilla will warn you about what you\'re doing, before it actually submits the duplicate $terms.bug.' =>
      'Now, if you try to submit $terms.abug twice from the same screen (by going back or by refreshing the page), $terms.Bugzilla will warn you about what you\'re doing, before it actually submits the duplicate $terms.bug.',
    'You can specify a list of users who will <em>always</em> be added to the CC list of new $terms.bugs in a component.' =>
      'You can specify a list of users who will <em>always</em> be added to the CC list of new $terms.bugs in a component.',
    'You can now file or modify $terms.bugs via email. Previous versions of $terms.Bugzilla included this feature only as an unsupported add-on, but it is now an official interface to $terms.Bugzilla.' =>
      'You can now file or modify $terms.bugs via email. Previous versions of $terms.Bugzilla included this feature only as an unsupported add-on, but it is now an official interface to $terms.Bugzilla.',
    'For more details see the' =>
      'For more details see the',
    'documentation for email_in.pl' =>
      'documentation for email_in.pl',
    'There is now a parameter called' =>
      'There is now a parameter called',
    'globalwatchers' =>
      'globalwatchers',
    '. This is a comma-separated list of $terms.Bugzilla users who will get all $terms.bug notifications generated by $terms.Bugzilla.' =>
      '. This is a comma-separated list of $terms.Bugzilla users who will get all $terms.bug notifications generated by $terms.Bugzilla.',
    'Group controls still apply, though, so users who can\'t see $terms.abug still won\'t get notifications about that $terms.bug.' =>
      'Group controls still apply, though, so users who can\'t see $terms.abug still won\'t get notifications about that $terms.bug.',
    '$terms.Bugzilla users running MySQL should now have excellent UTF-8 support if they turn on the' =>
      '$terms.Bugzilla users running MySQL should now have excellent UTF-8 support if they turn on the',
    'utf8' =>
      'utf8',
    'parameter. (New installs have this parameter on by default.) $terms.Bugzilla now correctly supports searching and sorting in non-English languages, including multi-bytes languages such as Chinese.' =>
      'parameter. (New installs have this parameter on by default.) $terms.Bugzilla now correctly supports searching and sorting in non-English languages, including multi-bytes languages such as Chinese.',
    'If you belong to the' =>
      'If you belong to the',
    'group, you will be notified when you log in if there is a new release of $terms.Bugzilla available to download.' =>
      'group, you will be notified when you log in if there is a new release of $terms.Bugzilla available to download.',
    'You can control these notifications by changing the' =>
      'You can control these notifications by changing the',
    'upgrade_notification' =>
      'upgrade_notification',
    'If your $terms.Bugzilla installation is on a machine that needs to go through a proxy to access the web, you may also have to set the' =>
      'If your $terms.Bugzilla installation is on a machine that needs to go through a proxy to access the web, you may also have to set the',
    'proxy_url' =>
      'proxy_url',
    'When you log in for the first time on a brand-new $terms.Bugzilla installation, you will be presented with a page that describes where you should go from here, and what parameters you should set.' =>
      'When you log in for the first time on a brand-new $terms.Bugzilla installation, you will be presented with a page that describes where you should go from here, and what parameters you should set.',
    'QuickSearch Plugin for IE7 and Firefox 2' =>
      'QuickSearch Plugin for IE7 and Firefox 2',
    'Firefox 2 users and Internet Explorer 7 users will be presented with the option to add $terms.Bugzilla to their search bar. This uses the' =>
      'Firefox 2 users and Internet Explorer 7 users will be presented with the option to add $terms.Bugzilla to their search bar. This uses the',
    'QuickSearch syntax' =>
      'QuickSearch syntax',
    'Enhancements That Affect $terms.Bugzilla Users' =>
      'Enhancements That Affect $terms.Bugzilla Users',
    'In comments, quoted text (lines that start with' =>
      'In comments, quoted text (lines that start with',
    ') will be a different color from normal text.' =>
      ') will be a different color from normal text.',
    'There is now a user preference that will add you to the CC list of any $terms.bug you modify. Note that it\'s <strong>on</strong> by default.' =>
      'There is now a user preference that will add you to the CC list of any $terms.bug you modify. Note that it\'s <strong>on</strong> by default.',
    '$terms.Bugs can now be filed with an initial state of' =>
      '$terms.Bugs can now be filed with an initial state of',
    'ASSIGNED' =>
      'ASSIGNED',
    ', if you are in the' =>
      ', if you are in the',
    'group.' =>
      'group.',
    'By default, comment fields will zoom large when you are typing in them, and become small when you move out of them. You can disable this in your user preferences.' =>
      'By default, comment fields will zoom large when you are typing in them, and become small when you move out of them. You can disable this in your user preferences.',
    'You can hide obsolete attachments on $terms.abug by clicking &quot;Hide Obsolete&quot; at the bottom of the attachment table.' =>
      'You can hide obsolete attachments on $terms.abug by clicking &quot;Hide Obsolete&quot; at the bottom of the attachment table.',
    'If $terms.abug has flags set, and you move it to a different product that has flags with the same name, the flags will be preserved.' =>
      'If $terms.abug has flags set, and you move it to a different product that has flags with the same name, the flags will be preserved.',
    'You now can\'t request a flag to be set by somebody who can\'t set it ($terms.Bugzilla will throw an error if you try).' =>
      'You now can\'t request a flag to be set by somebody who can\'t set it ($terms.Bugzilla will throw an error if you try).',
    'Many new headers have been added to outbound $terms.Bugzilla $terms.bug emails:' =>
      'Many new headers have been added to outbound $terms.Bugzilla $terms.bug emails:',
    'X-Bugzilla-Status' =>
      'X-Bugzilla-Status',
    'X-Bugzilla-Priority' =>
      'X-Bugzilla-Priority',
    'X-Bugzilla-Assigned-To' =>
      'X-Bugzilla-Assigned-To',
    'X-Bugzilla-Target-Milestone' =>
      'X-Bugzilla-Target-Milestone',
    'X-Bugzilla-Changed-Fields' =>
      'X-Bugzilla-Changed-Fields',
    'X-Bugzilla-Who' =>
      'X-Bugzilla-Who',
    '. You can look at an email to get an idea of what they contain.' =>
      '. You can look at an email to get an idea of what they contain.',
    'In addition to the old' =>
      'In addition to the old',
    'X-Bugzilla-Reason' =>
      'X-Bugzilla-Reason',
    'email header which tells you why you got an email, if you got an email because you were watching somebody, there is now an' =>
      'email header which tells you why you got an email, if you got an email because you were watching somebody, there is now an',
    'X-Bugzilla-Watch-Reason' =>
      'X-Bugzilla-Watch-Reason',
    'header that tells you who you were watching and what role they had.' =>
      'header that tells you who you were watching and what role they had.',
    'If you hover your mouse over a full URL (like' =>
      'If you hover your mouse over a full URL (like',
    'http://bugs.mycompany.com/show_bug.cgi?id=1212' =>
      'http://bugs.mycompany.com/show_bug.cgi?id=1212',
    ') that links to $terms.abug, you will see the title of the $terms.bug. Of course, this only works for $terms.bugs in your $terms.Bugzilla installation.' =>
      ') that links to $terms.abug, you will see the title of the $terms.bug. Of course, this only works for $terms.bugs in your $terms.Bugzilla installation.',
    'If your installation has user watching enabled, you will now see the users that you can remove from your watch-list as a multi-select box, much like the current CC list. (Previously it was just a text box.)' =>
      'If your installation has user watching enabled, you will now see the users that you can remove from your watch-list as a multi-select box, much like the current CC list. (Previously it was just a text box.)',
    'When a user creates their own account in $terms.Bugzilla, the account is now not actually created until they verify their email address by clicking on a link that is emailed to them.' =>
      'When a user creates their own account in $terms.Bugzilla, the account is now not actually created until they verify their email address by clicking on a link that is emailed to them.',
    'You can change $terms.abug\'s resolution without reopening it.' =>
      'You can change $terms.abug\'s resolution without reopening it.',
    'When you view the dependency tree on $terms.abug, resolved $terms.bugs will be hidden by default. (In previous versions, resolved $terms.bugs were shown by default.)' =>
      'When you view the dependency tree on $terms.abug, resolved $terms.bugs will be hidden by default. (In previous versions, resolved $terms.bugs were shown by default.)',
    'When viewing $terms.bug activity, fields that hold $terms.bug numbers (such as &quot;Blocks&quot;) will have the $terms.bug numbers displayed as links to those $terms.bugs.' =>
      'When viewing $terms.bug activity, fields that hold $terms.bug numbers (such as &quot;Blocks&quot;) will have the $terms.bug numbers displayed as links to those $terms.bugs.',
    'When viewing the &quot;Keywords&quot; field in $terms.abug list, it will be sorted alphabetically, so you can sanely sort a list on that field.' =>
      'When viewing the &quot;Keywords&quot; field in $terms.abug list, it will be sorted alphabetically, so you can sanely sort a list on that field.',
    'In most places, the Version field is now sorted using a version-sort (so 1.10 is greater than 1.2) instead of an alphabetical sort.' =>
      'In most places, the Version field is now sorted using a version-sort (so 1.10 is greater than 1.2) instead of an alphabetical sort.',
    'Options for flags will only appear if you can set them. So, for example, if you can\'t grant' =>
      'Options for flags will only appear if you can set them. So, for example, if you can\'t grant',
    'on a flag, that option won\'t appear for you.' =>
      'on a flag, that option won\'t appear for you.',
    'You can limit the product-related output of' =>
      'You can limit the product-related output of',
    'by specifying a' =>
      'by specifying a',
    'product=' =>
      'product=',
    'URL argument, containing the name of a product. You can specify the argument more than once for multiple products.' =>
      'URL argument, containing the name of a product. You can specify the argument more than once for multiple products.',
    'You can now search the boolean charts on whether or not a comment is private.' =>
      'You can now search the boolean charts on whether or not a comment is private.',
    'Administrators can now delete attachments, making them disappear entirely from $terms.Bugzilla.' =>
      'Administrators can now delete attachments, making them disappear entirely from $terms.Bugzilla.',
    'can now only be accessed by users in the' =>
      'can now only be accessed by users in the',
    'The &quot;Field Values&quot; control panel can now only be accessed by users in the' =>
      'The &quot;Field Values&quot; control panel can now only be accessed by users in the',
    'group. (Previously it was accessible to anybody in the' =>
      'group. (Previously it was accessible to anybody in the',
    'group.)' =>
      'group.)',
    'There is a new parameter' =>
      'There is a new parameter',
    'announcehtml' =>
      'announcehtml',
    ', that will allow you to enter some HTML that will be displayed at the top of every page, as an announcement.' =>
      ', that will allow you to enter some HTML that will be displayed at the top of every page, as an announcement.',
    'parameter now defaults to 0 for new installations, meaning that as long as somebody has the right login cookie, they can log in from any IP address. This makes life a lot easier for dial-up users or other users whose IP changes a lot. This could be done because the login cookie is now very random, and thus secure.' =>
      'parameter now defaults to 0 for new installations, meaning that as long as somebody has the right login cookie, they can log in from any IP address. This makes life a lot easier for dial-up users or other users whose IP changes a lot. This could be done because the login cookie is now very random, and thus secure.',
    'Classifications now have sortkeys, so they can be sorted in an order that isn\'t alphabetical.' =>
      'Classifications now have sortkeys, so they can be sorted in an order that isn\'t alphabetical.',
    'Authentication now supports LDAP over SSL (LDAPS) or TLS (using the STARTLS command) in addition to plain LDAP.' =>
      'Authentication now supports LDAP over SSL (LDAPS) or TLS (using the STARTLS command) in addition to plain LDAP.',
    'LDAP users can have their LDAP username be their email address, instead of having the LDAP' =>
      'LDAP users can have their LDAP username be their email address, instead of having the LDAP',
    'mail' =>
      'mail',
    'attribute be their email address. You may wish to set the' =>
      'attribute be their email address. You may wish to set the',
    'emailsuffix' =>
      'emailsuffix',
    'parameter if you do this.' =>
      'parameter if you do this.',
    'Administrators can now see what has changed in a user account, when using the &quot;Users&quot; control panel.' =>
      'Administrators can now see what has changed in a user account, when using the &quot;Users&quot; control panel.',
    'REMIND' =>
      'REMIND',
    'LATER' =>
      'LATER',
    'are no longer part of the default list of resolutions. Upgrading installations will not be affected--they will still have these resolutions.' =>
      'are no longer part of the default list of resolutions. Upgrading installations will not be affected--they will still have these resolutions.',
    'is now the default for the' =>
      'is now the default for the',
    'timetrackinggroup' =>
      'timetrackinggroup',
    'parameter, meaning that time-tracking will be on by default in a new installation.' =>
      'parameter, meaning that time-tracking will be on by default in a new installation.',
    ': Flags are not protected by "mid-air collision" detection. Nor are any attachment changes.' =>
      ': Flags are not protected by "mid-air collision" detection. Nor are any attachment changes.',
    ': If you are using Perl 5.8.0, you may get a lot of warnings in your Apache error_log about "deprecated pseudo-hashes." These are harmless--they are a b' =>
      ': If you are using Perl 5.8.0, you may get a lot of warnings in your Apache error_log about "deprecated pseudo-hashes." These are harmless--they are a b',
    'ug in Perl 5.8.0. Perl 5.8.1 and later do not have this problem.' =>
      'ug in Perl 5.8.0. Perl 5.8.1 and later do not have this problem.',
    '$terms.Bugzilla 3.0rc1 allowed custom field column names in the database to be mixed-case. $terms.Bugzilla 3.0 only allows lowercase column names. It will fix any column names that you have made mixed-case, but if you have custom fields that previously were mixed-case in any Saved Search, you will have to re-create that Saved Search yourself.' =>
      '$terms.Bugzilla 3.0rc1 allowed custom field column names in the database to be mixed-case. $terms.Bugzilla 3.0 only allows lowercase column names. It will fix any column names that you have made mixed-case, but if you have custom fields that previously were mixed-case in any Saved Search, you will have to re-create that Saved Search yourself.',
    'Security Updates in This Release' =>
      'Security Updates in This Release',
    '$terms.Bugzilla contains a minor security fix. For details, see the' =>
      '$terms.Bugzilla contains a minor security fix. For details, see the',
    '$terms.Bugzilla contains one security fix for' =>
      '$terms.Bugzilla contains one security fix for',
    '. For details, see the' =>
      '. For details, see the',
    '$terms.Bugzilla 3.0.4 contains three security fixes. For details, see the' =>
      '$terms.Bugzilla 3.0.4 contains three security fixes. For details, see the',
    'No security fixes in this release.' =>
      'No security fixes in this release.',
    '$terms.Bugzilla 3.0.1 had an important security fix that is critical for public installations with "requirelogin" turned on. For details, see the' =>
      '$terms.Bugzilla 3.0.1 had an important security fix that is critical for public installations with "requirelogin" turned on. For details, see the',
    '$terms.Bugzilla 3.0 had three security issues that have been fixed in this release: one minor information leak, one hole only exploitable by an admin or using' =>
      '$terms.Bugzilla 3.0 had three security issues that have been fixed in this release: one minor information leak, one hole only exploitable by an admin or using',
    ', and one in an uncommonly-used template. For details, see the' =>
      ', and one in an uncommonly-used template. For details, see the',
    'If you upgrade by CVS, there are several .cvsignore files that are now in CVS instead of being locally created by' =>
      'If you upgrade by CVS, there are several .cvsignore files that are now in CVS instead of being locally created by',
    '. This means that you will have to delete those files when CVS tells you there\'s a conflict, and then run' =>
      '. This means that you will have to delete those files when CVS tells you there\'s a conflict, and then run',
    'again.' =>
      'again.',
    'In this version of $terms.Bugzilla, the Summary field is now limited to 255 characters. When you upgrade, any Summary longer than that will be truncated, and the old summary will be preserved in a comment.' =>
      'In this version of $terms.Bugzilla, the Summary field is now limited to 255 characters. When you upgrade, any Summary longer than that will be truncated, and the old summary will be preserved in a comment.',
    'If you have the' =>
      'If you have the',
    'parameter turned on, at some point you will have to convert your database.' =>
      'parameter turned on, at some point you will have to convert your database.',
    'will tell you when this is, and it will give you certain instructions at that time, that you have to follow before you can complete the upgrade. Don\'t do the conversion yourself manually--follow the instructions of checksetup.pl.' =>
      'will tell you when this is, and it will give you certain instructions at that time, that you have to follow before you can complete the upgrade. Don\'t do the conversion yourself manually--follow the instructions of checksetup.pl.',
    'If you ever ran 2.23.3, 2.23.4, or 3.0rc1, you will have to run' =>
      'If you ever ran 2.23.3, 2.23.4, or 3.0rc1, you will have to run',
    'at the command line, because the data for your Old Charts is corrupted. This can take several days, so you may only want to run it if you use Old Charts.' =>
      'at the command line, because the data for your Old Charts is corrupted. This can take several days, so you may only want to run it if you use Old Charts.',
    'You should also read the Outstanding Issues sections of' =>
      'You should also read the Outstanding Issues sections of',
    'older release notes' =>
      'older release notes',
    'if you are upgrading from a version lower than 2.22.' =>
      'if you are upgrading from a version lower than 2.22.',
    '<strong>Packagers:</strong> Location Variables Have Moved' =>
      '<strong>Packagers:</strong> Location Variables Have Moved',
    'Hooks!' =>
      'Hooks!',
    'API Documentation' =>
      'API Documentation',
    'Elimination of globals.pl' =>
      'Elimination of globals.pl',
    'Cleaned Up Variable Scoping Issues' =>
      'Cleaned Up Variable Scoping Issues',
    'No More SendSQL' =>
      'No More SendSQL',
    'Auth Re-write' =>
      'Auth Re-write',
    'Bugzilla::Object' =>
      'Bugzilla::Object',
    'Bugzilla-&gt;request_cache' =>
      'Bugzilla-&gt;request_cache',
    'In previous versions of $terms.Bugzilla,' =>
      'In previous versions of $terms.Bugzilla,',
    'Bugzilla::Config' =>
      'Bugzilla::Config',
    'held all the paths for different things, such as the path to localconfig and the path to the' =>
      'held all the paths for different things, such as the path to localconfig and the path to the',
    'Now, all of this data is stored in a subroutine,' =>
      'Now, all of this data is stored in a subroutine,',
    'Bugzilla::Constants::bz_locations' =>
      'Bugzilla::Constants::bz_locations',
    'Also, note that for mod_perl,' =>
      'Also, note that for mod_perl,',
    'bz_locations' =>
      'bz_locations',
    'must return <em>absolute</em> (not relative) paths. There is already code in that subroutine to help you with this.' =>
      'must return <em>absolute</em> (not relative) paths. There is already code in that subroutine to help you with this.',
    '$terms.Bugzilla now supports a code hook mechanism. See the documentation for' =>
      '$terms.Bugzilla now supports a code hook mechanism. See the documentation for',
    'This gives $terms.Bugzilla very advanced plugin support. You can hook templates, hook code, add new parameters, and use the XML-RPC interface. So we\'d like to see some $terms.Bugzilla plugins written! Let us know on the' =>
      'This gives $terms.Bugzilla very advanced plugin support. You can hook templates, hook code, add new parameters, and use the XML-RPC interface. So we\'d like to see some $terms.Bugzilla plugins written! Let us know on the',
    'developers&#64;bugzilla.org' =>
      'developers&#64;bugzilla.org',
    'mailing list if you write a plugin.' =>
      'mailing list if you write a plugin.',
    'If you need more hooks, please' =>
      'If you need more hooks, please',
    'File a b' =>
      'File a b',
    'ug' =>
      'ug',
    '$terms.Bugzilla now ships with all of its perldoc built as HTML. Go ahead and read the' =>
      '$terms.Bugzilla now ships with all of its perldoc built as HTML. Go ahead and read the',
    'for all of the $terms.Bugzilla modules now! Even scripts like' =>
      'for all of the $terms.Bugzilla modules now! Even scripts like',
    'have HTML documentation.' =>
      'have HTML documentation.',
    'The old file' =>
      'The old file',
    'globals.pl' =>
      'globals.pl',
    'has been eliminated. Its code is now in various modules. Each function went to the module that was appropriate for it.' =>
      'has been eliminated. Its code is now in various modules. Each function went to the module that was appropriate for it.',
    'Usually we filed $terms.abug in' =>
      'Usually we filed $terms.abug in',
    'bugzilla.mozilla.org' =>
      'bugzilla.mozilla.org',
    'for each function we moved. You can search there for the old name of the function, and that should get you the information about what it\'s called now and where it lives.' =>
      'for each function we moved. You can search there for the old name of the function, and that should get you the information about what it\'s called now and where it lives.',
    'In normal perl, you can have code like this:' =>
      'In normal perl, you can have code like this:',
    'my $var = 0; sub y { $var++ }' =>
      'my $var = 0; sub y { $var++ }',
    'However, under mod_perl that doesn\'t work. So variables are no longer &quot;shared&quot; with subroutines--instead all variables that a subroutine needs must be declared inside the subroutine itself.' =>
      'However, under mod_perl that doesn\'t work. So variables are no longer &quot;shared&quot; with subroutines--instead all variables that a subroutine needs must be declared inside the subroutine itself.',
    'The old' =>
      'The old',
    'SendSQL' =>
      'SendSQL',
    'function and all of its companions are <strong>gone</strong>. Instead, we now use DBI for all database interaction.' =>
      'function and all of its companions are <strong>gone</strong>. Instead, we now use DBI for all database interaction.',
    'For more information about how to use' =>
      'For more information about how to use',
    'with $terms.Bugzilla, see the' =>
      'with $terms.Bugzilla, see the',
    'Developer\'s Guide Section About DBI' =>
      'Developer\'s Guide Section About DBI',
    'Bugzilla::Auth' =>
      'Bugzilla::Auth',
    'family of modules have been completely re-written. For details on how the new structure of authentication, read the' =>
      'family of modules have been completely re-written. For details on how the new structure of authentication, read the',
    'Bugzilla::Auth API docs' =>
      'Bugzilla::Auth API docs',
    'It should be very easy to write new authentication plugins, now.' =>
      'It should be very easy to write new authentication plugins, now.',
    'There is a new base class for most of our objects,' =>
      'There is a new base class for most of our objects,',
    '. It makes it really easy to create new objects based on things that are in the database.' =>
      '. It makes it really easy to create new objects based on things that are in the database.',
    'Bugzilla-&gt;request-cache' =>
      'Bugzilla-&gt;request-cache',
    'Bugzilla.pm' =>
      'Bugzilla.pm',
    'used to cache things like the database connection in package-global variables (like' =>
      'used to cache things like the database connection in package-global variables (like',
    '$_dbh' =>
      '$_dbh',
    '). That doesn\'t work in mod_perl, so instead now there\'s a hash that can be accessed through' =>
      '). That doesn\'t work in mod_perl, so instead now there\'s a hash that can be accessed through',
    'to store things for the rest of the current page request.' =>
      'to store things for the rest of the current page request.',
    'You shouldn\'t access' =>
      'You shouldn\'t access',
    'directly, but you should use it inside of' =>
      'directly, but you should use it inside of',
    'if you modify that. The only time you should be accessing it directly is if you need to reset one of the caches. Hash keys are always named after the function that they cache, so to reset the template object, you\'d do:' =>
      'if you modify that. The only time you should be accessing it directly is if you need to reset one of the caches. Hash keys are always named after the function that they cache, so to reset the template object, you\'d do:',
    'delete Bugzilla-&gt;request_cache-&gt;{template};' =>
      'delete Bugzilla-&gt;request_cache-&gt;{template};',
    'has been completely re-written, and most of its code moved into modules in the' =>
      'has been completely re-written, and most of its code moved into modules in the',
    'Bugzilla::Install' =>
      'Bugzilla::Install',
    'namespace. See the' =>
      'namespace. See the',
    'checksetup documentation' =>
      'checksetup documentation',
    'Instead of' =>
      'Instead of',
    'UserInGroup()' =>
      'UserInGroup()',
    ', all of $terms.Bugzilla now uses' =>
      ', all of $terms.Bugzilla now uses',
    'Bugzilla-&gt;user-&gt;in_group' =>
      'Bugzilla-&gt;user-&gt;in_group',
    'mod_perl doesn\'t like dependency loops in modules, so we now have a test for that detects dependency loops in modules when you run' =>
      'mod_perl doesn\'t like dependency loops in modules, so we now have a test for that detects dependency loops in modules when you run',
    'runtests.pl' =>
      'runtests.pl',
    'used to modify the environment variables, like' =>
      'used to modify the environment variables, like',
    'PATH' =>
      'PATH',
    '. That now happens in' =>
      '. That now happens in',
    'Templates can now link to the documentation more easily. See the' =>
      'Templates can now link to the documentation more easily. See the',
    'templates for examples. (Search for &quot;docslinks.&quot;)' =>
      'templates for examples. (Search for &quot;docslinks.&quot;)',
    'Parameters are accessed through' =>
      'Parameters are accessed through',
    'Bugzilla-&gt;params' =>
      'Bugzilla-&gt;params',
    'instead of using the' =>
      'instead of using the',
    'Param()' =>
      'Param()',
    'function, now.' =>
      'function, now.',
    'The variables from the' =>
      'The variables from the',
    'file are accessed through the' =>
      'file are accessed through the',
    'Bugzilla-&gt;localconfig' =>
      'Bugzilla-&gt;localconfig',
    'hash instead of through' =>
      'hash instead of through',
    'Bugzilla::BugMail::MessageToMTA()' =>
      'Bugzilla::BugMail::MessageToMTA()',
    'has moved into its own module, along with other mail-handling code, called' =>
      'has moved into its own module, along with other mail-handling code, called',
    'Bugzilla::Mailer' =>
      'Bugzilla::Mailer',
    'CheckCanChangeField()' =>
      'CheckCanChangeField()',
    'subroutine in' =>
      'subroutine in',
    'has been moved to' =>
      'has been moved to',
    'Bugzilla::Bug' =>
      'Bugzilla::Bug',
    ', and is now a method of $terms.abug object.' =>
      ', and is now a method of $terms.abug object.',
    'The code that used to be in the' =>
      'The code that used to be in the',
    'template is now in' =>
      'template is now in',
    '. The banner still exists, but the file is empty.' =>
      '. The banner still exists, but the file is empty.',
    'Release Notes For Previous Versions' =>
      'Release Notes For Previous Versions',
    'Release notes for versions of $terms.Bugzilla for versions prior to 3.0 are only available in text format:' =>
      'Release notes for versions of $terms.Bugzilla for versions prior to 3.0 are only available in text format:',
    'Release Notes for $terms.Bugzilla 2.22 and Earlier' =>
      'Release Notes for $terms.Bugzilla 2.22 and Earlier',
    'For' =>
      'For',
    'Users' =>
      'Users',
    'v' =>
      'v',
    '<strong>perl module:</strong>' =>
      '<strong>perl module:</strong>',
  },
  'pages/sudo.html.tmpl' => {
    'sudo: User Impersonation' =>
      'sudo: User Impersonation',
    '$terms.Bugzilla includes the ability to have one user impersonate another, in something called a <i>sudo session</i>, so long as the person doing the impersonating has the appropriate privileges.' =>
      '$terms.Bugzilla includes the ability to have one user impersonate another, in something called a <i>sudo session</i>, so long as the person doing the impersonating has the appropriate privileges.',
    'While a session is in progress, $terms.Bugzilla will act as if the impersonated user is doing everything. This is especially useful for testing, and for doing critical work when the impersonated user is unavailable. The impersonated user will receive an email from $terms.Bugzilla when the session begins; they will not be told anything else.' =>
      'While a session is in progress, $terms.Bugzilla will act as if the impersonated user is doing everything. This is especially useful for testing, and for doing critical work when the impersonated user is unavailable. The impersonated user will receive an email from $terms.Bugzilla when the session begins; they will not be told anything else.',
    'To use this feature, you must be a member of the appropriate group. The group includes all administrators by default. Other users, and members of other groups, can be given access to this feature on a case-by-case basis. To request access, contact the maintainer of this installation:' =>
      'To use this feature, you must be a member of the appropriate group. The group includes all administrators by default. Other users, and members of other groups, can be given access to this feature on a case-by-case basis. To request access, contact the maintainer of this installation:',
    'If you would like to be protected from impersonation, you should contact the maintainer of this installation to see if that is possible. People with access to this feature are protected automatically.' =>
      'If you would like to be protected from impersonation, you should contact the maintainer of this installation to see if that is possible. People with access to this feature are protected automatically.',
    'You are a member of the <b>bz_sudoers</b> group. You may use this feature to impersonate others.' =>
      'You are a member of the <b>bz_sudoers</b> group. You may use this feature to impersonate others.',
    'You are not a member of an appropriate group. You may not use this feature.' =>
      'You are not a member of an appropriate group. You may not use this feature.',
    'You are a member of the <b>bz_sudo_protect</b> group. Other people will not be able to use this feature to impersonate you.' =>
      'You are a member of the <b>bz_sudo_protect</b> group. Other people will not be able to use this feature to impersonate you.',
  },
  'pages/voting.html.tmpl' => {
    'Voting' =>
      'Voting',
    '$terms.Bugzilla has a "voting" feature. Each product allows users to have a certain number of votes. (Some products may not allow any, which means you can\'t vote on things in those products at all.) With your vote, you indicate which $terms.bugs you think are the most important and would like to see fixed. Note that voting is nowhere near as effective as providing a fix yourself.' =>
      '$terms.Bugzilla has a "voting" feature. Each product allows users to have a certain number of votes. (Some products may not allow any, which means you can\'t vote on things in those products at all.) With your vote, you indicate which $terms.bugs you think are the most important and would like to see fixed. Note that voting is nowhere near as effective as providing a fix yourself.',
    'Depending on how the administrator has configured the relevant product, you may be able to vote for the same $terms.bug more than once. Remember that you have a limited number of votes. When weighted voting is allowed and a limited number of votes are available to you, you will have to decide whether you want to distribute your votes among a large number of $terms.bugs indicating your minimal interest or focus on a few $terms.bugs indicating your strong support for them.' =>
      'Depending on how the administrator has configured the relevant product, you may be able to vote for the same $terms.bug more than once. Remember that you have a limited number of votes. When weighted voting is allowed and a limited number of votes are available to you, you will have to decide whether you want to distribute your votes among a large number of $terms.bugs indicating your minimal interest or focus on a few $terms.bugs indicating your strong support for them.',
    'To look at votes:' =>
      'To look at votes:',
    'Go to the query page. Do a normal query, but enter 1 in the "At least ___ votes" field. This will show you items that match your query that have at least one vote.' =>
      'Go to the query page. Do a normal query, but enter 1 in the "At least ___ votes" field. This will show you items that match your query that have at least one vote.',
    'To vote for $terms.abug:' =>
      'To vote for $terms.abug:',
    'Bring up the $terms.bug in question.' =>
      'Bring up the $terms.bug in question.',
    'Click on the "(vote)" link that appears on the right of the "Importance" fields. (If no such link appears, then voting may not be allowed in this $terms.bug\'s product.)' =>
      'Click on the "(vote)" link that appears on the right of the "Importance" fields. (If no such link appears, then voting may not be allowed in this $terms.bug\'s product.)',
    'Indicate how many votes you want to give this $terms.bug. This page also displays how many votes you\'ve given to other $terms.bugs, so you may rebalance your votes as necessary.' =>
      'Indicate how many votes you want to give this $terms.bug. This page also displays how many votes you\'ve given to other $terms.bugs, so you may rebalance your votes as necessary.',
    'You will automatically get email notifying you of any changes that occur on $terms.bugs you vote for.' =>
      'You will automatically get email notifying you of any changes that occur on $terms.bugs you vote for.',
    'You may review your votes at any time by clicking on the "' =>
      'You may review your votes at any time by clicking on the "',
    'My Votes' =>
      'My Votes',
    '" link in the page footer.' =>
      '" link in the page footer.',
  },
  'reports/chart.html.tmpl' => {
    'Chart' =>
      'Chart',
    'Graphical report results' =>
      'Graphical report results',
    'Taller' =>
      'Taller',
    'Thinner' =>
      'Thinner',
    'Fatter' =>
      'Fatter',
    'Shorter' =>
      'Shorter',
    'CSV' =>
      'CSV',
    'Edit this chart' =>
      'Edit this chart',
  },
  'reports/components.html.tmpl' => {
    'Components for' =>
      'Components for',
    'Components' =>
      'Components',
    'Select a component to see open $terms.bugs in that component:' =>
      'Select a component to see open $terms.bugs in that component:',
    'Description' =>
      'Description',
    'Default Assignee' =>
      'Default Assignee',
    'Default QA Contact' =>
      'Default QA Contact',
    'View other products of classification <b>' =>
      'View other products of classification <b>',
    'View other products' =>
      'View other products',
  },
  'reports/create-chart.html.tmpl' => {
    'Create Chart' =>
      'Create Chart',
    'Grand Total' =>
      'Grand Total',
    '<i>No data sets exist, or none are visible to you.</i>' =>
      '<i>No data sets exist, or none are visible to you.</i>',
    'Category' =>
      'Category',
    'Sub-category' =>
      'Sub-category',
    'Name' =>
      'Name',
    'Update --&gt;' =>
      'Update --&gt;',
    'Add To List' =>
      'Add To List',
    'List Of Data Sets To Plot' =>
      'List Of Data Sets To Plot',
    'Select' =>
      'Select',
    'Label' =>
      'Label',
    'Data Set' =>
      'Data Set',
    'Edit' =>
      'Edit',
    'Delete' =>
      'Delete',
    'Run Search' =>
      'Run Search',
    'Sum' =>
      'Sum',
    'Remove' =>
      'Remove',
    '<b>Cumulate</b>' =>
      '<b>Cumulate</b>',
    '<b>Date Range</b>' =>
      '<b>Date Range</b>',
    '<b>to</b>' =>
      '<b>to</b>',
    'Chart This List' =>
      'Chart This List',
    '<i>None</i>' =>
      '<i>None</i>',
    'Create New Data Set' =>
      'Create New Data Set',
    'You can either create a new data set based on one of your saved searches or start with a clean slate.' =>
      'You can either create a new data set based on one of your saved searches or start with a clean slate.',
    'Based on:' =>
      'Based on:',
    '(Clean slate)' =>
      '(Clean slate)',
    'Create a new data set' =>
      'Create a new data set',
  },
  'reports/delete-series.html.tmpl' => {
    'Delete Series' =>
      'Delete Series',
    'You are going to completely remove the <b>' =>
      'You are going to completely remove the <b>',
    '</b> series from the database. All data related to this series will be permanently deleted.' =>
      '</b> series from the database. All data related to this series will be permanently deleted.',
    'This series has been created by' =>
      'This series has been created by',
    'This series has been automatically created by $terms.Bugzilla' =>
      'This series has been automatically created by $terms.Bugzilla',
    'and is public.' =>
      'and is public.',
    'and is only visible by this user.' =>
      'and is only visible by this user.',
    'and cannot be displayed by anybody.' =>
      'and cannot be displayed by anybody.',
    'Are you sure you want to delete this series?' =>
      'Are you sure you want to delete this series?',
    'Yes, delete' =>
      'Yes, delete',
    'No, go back to the charts page' =>
      'No, go back to the charts page',
  },
  'reports/duplicates-simple.html.tmpl' => {
    'Most Frequently Reported $terms.Bugs for' =>
      'Most Frequently Reported $terms.Bugs for',
    'Most Frequently Reported $terms.Bugs' =>
      'Most Frequently Reported $terms.Bugs',
  },
  'reports/duplicates-table.html.tmpl' => {
    'Dupe<br />Count' =>
      'Dupe<br />Count',
    'Change in last<br />' =>
      'Change in last<br />',
    ' day(s)' =>
      ' day(s)',
    'No duplicate $terms.bugs found.' =>
      'No duplicate $terms.bugs found.',
  },
  'reports/duplicates.html.tmpl' => {
    'Most Frequently Reported $terms.Bugs for' =>
      'Most Frequently Reported $terms.Bugs for',
    'Most Frequently Reported $terms.Bugs' =>
      'Most Frequently Reported $terms.Bugs',
    'What is this data?' =>
      'What is this data?',
    'Change parameters' =>
      'Change parameters',
    'Change Parameters' =>
      'Change Parameters',
    'When sorting or restricting, work with:' =>
      'When sorting or restricting, work with:',
    'entire list' =>
      'entire list',
    'currently visible list' =>
      'currently visible list',
    'Restrict to products:' =>
      'Restrict to products:',
    'Max rows:' =>
      'Max rows:',
    'Change column is change in the last:' =>
      'Change column is change in the last:',
    'days' =>
      'days',
    'Open $terms.bugs only:' =>
      'Open $terms.bugs only:',
    'Change' =>
      'Change',
    '$terms.bug list' =>
      '$terms.bug list',
    'Or just give this to me as a' =>
      'Or just give this to me as a',
    '. (Note: the order may not be the same.)' =>
      '. (Note: the order may not be the same.)',
    'What are "Most Frequently Reported $terms.Bugs"?' =>
      'What are "Most Frequently Reported $terms.Bugs"?',
    'The Most Frequent $terms.Bugs page lists the known open $terms.bugs which are reported most frequently, counting the number of direct and indirect duplicates of $terms.bugs. This information is provided in order to assist in minimizing the amount of duplicate $terms.bugs entered into $terms.Bugzilla, which saves time for Quality Assurance engineers who have to triage the $terms.bugs.' =>
      'The Most Frequent $terms.Bugs page lists the known open $terms.bugs which are reported most frequently, counting the number of direct and indirect duplicates of $terms.bugs. This information is provided in order to assist in minimizing the amount of duplicate $terms.bugs entered into $terms.Bugzilla, which saves time for Quality Assurance engineers who have to triage the $terms.bugs.',
    '<b>How do I use this list?</b>' =>
      '<b>How do I use this list?</b>',
    'Review the most frequent $terms.bugs list.' =>
      'Review the most frequent $terms.bugs list.',
    'If your problem is listed:' =>
      'If your problem is listed:',
    'Click on the $terms.bug number to confirm that you have found the same $terms.bug, and comment if you have additional information or move on with your testing of the product.' =>
      'Click on the $terms.bug number to confirm that you have found the same $terms.bug, and comment if you have additional information or move on with your testing of the product.',
    'If your problem not listed:' =>
      'If your problem not listed:',
    'Try and locate a similar $terms.bug' =>
      'Try and locate a similar $terms.bug',
    'that has already been filed.' =>
      'that has already been filed.',
    'If you find your $terms.bug in $terms.Bugzilla, feel free to comment with any new or additional data you may have.' =>
      'If you find your $terms.bug in $terms.Bugzilla, feel free to comment with any new or additional data you may have.',
    'If you cannot find your problem already documented in $terms.Bugzilla,' =>
      'If you cannot find your problem already documented in $terms.Bugzilla,',
    'file a new $terms.bug' =>
      'file a new $terms.bug',
  },
  'reports/edit-series.html.tmpl' => {
    'Edit Series' =>
      'Edit Series',
    'Series updated.' =>
      'Series updated.',
    'Change Data Set' =>
      'Change Data Set',
    '<b>Creator</b>:' =>
      '<b>Creator</b>:',
    '(automatically created by $terms.Bugzilla)' =>
      '(automatically created by $terms.Bugzilla)',
    'Note: it is not yet possible to edit the search associated with this data set.' =>
      'Note: it is not yet possible to edit the search associated with this data set.',
    'View series search parameters' =>
      'View series search parameters',
    'Run series search' =>
      'Run series search',
  },
  'reports/keywords.html.tmpl' => {
    '$terms.Bugzilla Keyword Descriptions' =>
      '$terms.Bugzilla Keyword Descriptions',
    'Name' =>
      'Name',
    'Description' =>
      'Description',
    'Open $terms.Bugs' =>
      'Open $terms.Bugs',
    'Total $terms.Bugs' =>
      'Total $terms.Bugs',
    'Search' =>
      'Search',
    'none' =>
      'none',
    'Edit keywords' =>
      'Edit keywords',
  },
  'reports/menu.html.tmpl' => {
    'Reporting and Charting Kitchen' =>
      'Reporting and Charting Kitchen',
    '$terms.Bugzilla allows you to view and track the state of the $terms.bug database in all manner of exciting ways.' =>
      '$terms.Bugzilla allows you to view and track the state of the $terms.bug database in all manner of exciting ways.',
    'Current State' =>
      'Current State',
    'Search' =>
      'Search',
    '</strong> - list sets of $terms.bugs.' =>
      '</strong> - list sets of $terms.bugs.',
    'Tabular reports' =>
      'Tabular reports',
    '</strong> - tables of $terms.bug counts in 1, 2 or 3 dimensions, as HTML or CSV.' =>
      '</strong> - tables of $terms.bug counts in 1, 2 or 3 dimensions, as HTML or CSV.',
    'Graphical reports' =>
      'Graphical reports',
    '</strong> - line graphs, bar and pie charts.' =>
      '</strong> - line graphs, bar and pie charts.',
    'Change Over Time' =>
      'Change Over Time',
    'Old Charts' =>
      'Old Charts',
    '</strong> - plot the status and/or resolution of $terms.bugs against time, for each product in your database.' =>
      '</strong> - plot the status and/or resolution of $terms.bugs against time, for each product in your database.',
    'New Charts' =>
      'New Charts',
    '</strong> - plot any arbitrary search against time. Far more powerful.' =>
      '</strong> - plot any arbitrary search against time. Far more powerful.',
  },
  'reports/old-charts.html.tmpl' => {
    '$terms.Bug Charts' =>
      '$terms.Bug Charts',
    'Welcome to the $terms.Bugzilla Charting Kitchen' =>
      'Welcome to the $terms.Bugzilla Charting Kitchen',
    'Product:' =>
      'Product:',
    'Chart datasets:' =>
      'Chart datasets:',
    'Continue' =>
      'Continue',
  },
  'reports/report-simple.html.tmpl' => {
    '$terms.Bug Report' =>
      '$terms.Bug Report',
    'Total' =>
      'Total',
  },
  'reports/report-table.html.tmpl' => {
    'Total' =>
      'Total',
  },
  'reports/report.html.tmpl' => {
    'Report:' =>
      'Report:',
    '-total-' =>
      '-total-',
    'Total' =>
      'Total',
    'Graphical report results' =>
      'Graphical report results',
    'Pie' =>
      'Pie',
    'Bar' =>
      'Bar',
    'Line' =>
      'Line',
    'Table' =>
      'Table',
    'CSV' =>
      'CSV',
    'Taller' =>
      'Taller',
    'Thinner' =>
      'Thinner',
    'Fatter' =>
      'Fatter',
    'Shorter' =>
      'Shorter',
    'Remaining time' =>
      'Remaining time',
    'Estimated time' =>
      'Estimated time',
    'Actual time' =>
      'Actual time',
    'Estimated/Actual/Remaining' =>
      'Estimated/Actual/Remaining',
    'Number of $terms.bugs' =>
      'Number of $terms.bugs',
    'Edit this report' =>
      'Edit this report',
    'Forget this report' =>
      'Forget this report',
    'Remember report' =>
      'Remember report',
    'as' =>
      'as',
  },
  'reports/series.html.tmpl' => {
    'New (name below)' =>
      'New (name below)',
    'Category:' =>
      'Category:',
    'Sub-category:' =>
      'Sub-category:',
    'Name:' =>
      'Name:',
    'Update --&gt;' =>
      'Update --&gt;',
    'Run every' =>
      'Run every',
    'Visible to all' =>
      'Visible to all',
    '(within group restrictions)' =>
      '(within group restrictions)',
  },
  'request/email.txt.tmpl' => {
    ' for' =>
      ' for',
    ' to ' =>
      ' to ',
    '\'s request for' =>
      '\'s request for',
    ': [Attachment' =>
      ': [Attachment',
    'has reassigned' =>
      'has reassigned',
    'has' =>
      'has',
    'Attachment' =>
      'Attachment',
    '------- Additional Comments from' =>
      '------- Additional Comments from',
    '\'s request for <b>' =>
      '\'s request for <b>',
    'to' =>
      'to',
    'for' =>
      'for',
    '(prod:' =>
      '(prod:',
    ', pri:' =>
      ', pri:',
    ', sev:' =>
      ', sev:',
    ', miles:' =>
      ', miles:',
    'Additional Comments from' =>
      'Additional Comments from',
  },
  'request/queue.html.tmpl' => {
    'Request Queue' =>
      'Request Queue',
    'When you are logged in, only requests made by you or addressed to you are shown by default. You can change the criteria using the form below. When you are logged out, all pending requests that are not restricted to some group are shown by default.' =>
      'When you are logged in, only requests made by you or addressed to you are shown by default. You can change the criteria using the form below. When you are logged out, all pending requests that are not restricted to some group are shown by default.',
    'Requester:' =>
      'Requester:',
    'Requester' =>
      'Requester',
    'Product:' =>
      'Product:',
    'Any' =>
      'Any',
    'Flag:' =>
      'Flag:',
    'Requestee:' =>
      'Requestee:',
    'Requestee' =>
      'Requestee',
    'Component:' =>
      'Component:',
    'Group By:' =>
      'Group By:',
    'Flag' =>
      'Flag',
    'Product/Component' =>
      'Product/Component',
    'Status:' =>
      'Status:',
    'Filter' =>
      'Filter',
    'Status' =>
      'Status',
    'Attachment' =>
      'Attachment',
    'Created' =>
      'Created',
    'No requests.' =>
      'No requests.',
    'None' =>
      'None',
    'N/A' =>
      'N/A',
    '(view as $terms.bug list)' =>
      '(view as $terms.bug list)',
  },
  'scrum/cards.html.tmpl' => {
    'Печать SCRUM-карточек' =>
      'Печать SCRUM-карточек',
    'Карточек на листе:' =>
      'Карточек на листе:',
    'x' =>
      'x',
    'Размер шрифта:' =>
      'Размер шрифта:',
    'пунктов' =>
      'пунктов',
    'Размер листа:' =>
      'Размер листа:',
    '(за вычетом полей)' =>
      '(за вычетом полей)',
    'Размер карточки:' =>
      'Размер карточки:',
    'Отступы от карточки:' =>
      'Отступы от карточки:',
    '(см.)' =>
      '(см.)',
    'Текст настроек:' =>
      'Текст настроек:',
    'Загрузить настройки &uarr;' =>
      'Загрузить настройки &uarr;',
    'Показать ' =>
      'Показать ',
    'Удалить все карточки ' =>
      'Удалить все карточки ',
    'Добавить баги:' =>
      'Добавить баги:',
    'Добавить ' =>
      'Добавить ',
    'Добавить пустой лист ' =>
      'Добавить пустой лист ',
    '(в конец списка)' =>
      '(в конец списка)',
    'Удалить' =>
      'Удалить',
    'Вырезать' =>
      'Вырезать',
    'Вставить' =>
      'Вставить',
    'В начало' =>
      'В начало',
    'Выделяйте карточки Ctrl+Click.' =>
      'Выделяйте карточки Ctrl+Click.',
    'Карточки можно перетаскивать.' =>
      'Карточки можно перетаскивать.',
    'Если вы хотите сохранить текущую ссылку как шаблон формы печати карточек, сначала нажмите "Показать", чтобы применить все изменения.' =>
      'Если вы хотите сохранить текущую ссылку как шаблон формы печати карточек, сначала нажмите "Показать", чтобы применить все изменения.',
  },
  'search/boolean-charts.html.tmpl' => {
    'Advanced Searching Using Boolean Charts:' =>
      'Advanced Searching Using Boolean Charts:',
    'OR' =>
      'OR',
    'NOT' =>
      'NOT',
    'AND' =>
      'AND',
  },
  'search/form.html.tmpl' => {
    'Words (full-text search):' =>
      'Words (full-text search):',
    '<u>S</u>ummary' =>
      '<u>S</u>ummary',
    'Classification' =>
      'Classification',
    '<u>P</u>roduct' =>
      '<u>P</u>roduct',
    'Co<u>m</u>ponent' =>
      'Co<u>m</u>ponent',
    'Version' =>
      'Version',
    'Target Milestone' =>
      'Target Milestone',
    'A&nbsp;<u>C</u>omment' =>
      'A&nbsp;<u>C</u>omment',
    'The&nbsp;<u>U</u>RL' =>
      'The&nbsp;<u>U</u>RL',
    '<u>W</u>hiteboard' =>
      '<u>W</u>hiteboard',
    '<u>K</u>eywords' =>
      '<u>K</u>eywords',
    'Dead<u>l</u>ine' =>
      'Dead<u>l</u>ine',
    'from' =>
      'from',
    'to' =>
      'to',
    '(YYYY-MM-DD or relative dates)' =>
      '(YYYY-MM-DD or relative dates)',
    'St<u>a</u>tus' =>
      'St<u>a</u>tus',
    '<u>R</u>esolution' =>
      '<u>R</u>esolution',
    'Severity' =>
      'Severity',
    'Pr<u>i</u>ority' =>
      'Pr<u>i</u>ority',
    '<u>H</u>ardware' =>
      '<u>H</u>ardware',
    '<u>O</u>S' =>
      '<u>O</u>S',
    'Email Addresses, $terms.Bug Numbers, and Votes' =>
      'Email Addresses, $terms.Bug Numbers, and Votes',
    'Email Addresses and $terms.Bug Numbers' =>
      'Email Addresses and $terms.Bug Numbers',
    'Any of:' =>
      'Any of:',
    'the $terms.bug assignee' =>
      'the $terms.bug assignee',
    'the reporter' =>
      'the reporter',
    'the QA contact' =>
      'the QA contact',
    'a CC list member' =>
      'a CC list member',
    'a commenter' =>
      'a commenter',
    'is not' =>
      'is not',
    'matches regexp' =>
      'matches regexp',
    'doesn\'t match regexp' =>
      'doesn\'t match regexp',
    'Only include' =>
      'Only include',
    'Exclude' =>
      'Exclude',
    '$terms.bugs numbered' =>
      '$terms.bugs numbered',
    '(comma-separated list)' =>
      '(comma-separated list)',
    'Only $terms.bugs with at least' =>
      'Only $terms.bugs with at least',
    'votes' =>
      'votes',
    '<strong>$terms.Bug Changes</strong>' =>
      '<strong>$terms.Bug Changes</strong>',
    'Only $terms.bugs changed between' =>
      'Only $terms.bugs changed between',
    'and' =>
      'and',
    'By user:' =>
      'By user:',
    '(user login)' =>
      '(user login)',
    'where one or more of the following changed' =>
      'where one or more of the following changed',
    'the new value was' =>
      'the new value was',
  },
  'search/knob.html.tmpl' => {
    'Reuse same sort as last time' =>
      'Reuse same sort as last time',
    '$terms.Bug Number' =>
      '$terms.Bug Number',
    'Importance' =>
      'Importance',
    'Assignee' =>
      'Assignee',
    'Last Changed' =>
      'Last Changed',
    'Relevance to full-text search' =>
      'Relevance to full-text search',
    'Sort results by' =>
      'Sort results by',
    'Custom: ' =>
      'Custom: ',
    'and remember these as my default search options' =>
      'and remember these as my default search options',
    'Set my default search back to the system default' =>
      'Set my default search back to the system default',
  },
  'search/search-advanced.html.tmpl' => {
    'Search for $terms.bugs' =>
      'Search for $terms.bugs',
    'Search' =>
      'Search',
    'Give me some help' =>
      'Give me some help',
    '(reloads page).' =>
      '(reloads page).',
    'For help, mouse over the page elements.' =>
      'For help, mouse over the page elements.',
    'Help initialization failed, no help available.' =>
      'Help initialization failed, no help available.',
  },
  'search/search-create-series.html.tmpl' => {
    'Create New Data Set' =>
      'Create New Data Set',
    'Run Search' =>
      'Run Search',
    'to see which $terms.bugs would be included in this data set.' =>
      'to see which $terms.bugs would be included in this data set.',
    'Data Set Parameters' =>
      'Data Set Parameters',
    'Create Data Set' =>
      'Create Data Set',
  },
  'search/search-help.html.tmpl' => {
    'The type of summary search you would like' =>
      'The type of summary search you would like',
    'The $terms.bug summary is a short sentence which succinctly
describes <br /> what the $terms.bug is about.' =>
      'The $terms.bug summary is a short sentence which succinctly
describes <br /> what the $terms.bug is about.',
    '$terms.Bugs are categorised into Classifications, Products and Components. classifications is the<br />
top-level categorisation.' =>
      '$terms.Bugs are categorised into Classifications, Products and Components. classifications is the<br />
top-level categorisation.',
    '$terms.Bugs are categorised into Products and Components. Select a Classification to narrow down this list' =>
      '$terms.Bugs are categorised into Products and Components. Select a Classification to narrow down this list',
    '$terms.Bugs are categorised into Products and Components. Product is
the<br />top-level categorisation.' =>
      '$terms.Bugs are categorised into Products and Components. Product is
the<br />top-level categorisation.',
    'Components are second-level categories; each belongs to a<br />
particular Product. Select a Product to narrow down this list.' =>
      'Components are second-level categories; each belongs to a<br />
particular Product. Select a Product to narrow down this list.',
    'The version field defines the version of the software the
$terms.bug<br />was found in.' =>
      'The version field defines the version of the software the
$terms.bug<br />was found in.',
    'The target_milestone field is used to define when the engineer<br />
the $terms.bug is assigned to expects to fix it.' =>
      'The target_milestone field is used to define when the engineer<br />
the $terms.bug is assigned to expects to fix it.',
    '$terms.Bugs have comments added to them by $terms.Bugzilla users.
You can<br />search for some text in those comments.' =>
      '$terms.Bugs have comments added to them by $terms.Bugzilla users.
You can<br />search for some text in those comments.',
    'The type of comment search you would like' =>
      'The type of comment search you would like',
    '$terms.Bugs can have a URL associated with them - for example, a
pointer<br />to a web site where the problem is seen.' =>
      '$terms.Bugs can have a URL associated with them - for example, a
pointer<br />to a web site where the problem is seen.',
    'The type of URL search you would like' =>
      'The type of URL search you would like',
    'Each $terms.bug has a free-form single line text entry box for
adding<br />tags and status information.' =>
      'Each $terms.bug has a free-form single line text entry box for
adding<br />tags and status information.',
    'The type of whiteboard search you would like' =>
      'The type of whiteboard search you would like',
    'You can add keywords from a defined list to $terms.bugs, in order
to<br />tag and group them.' =>
      'You can add keywords from a defined list to $terms.bugs, in order
to<br />tag and group them.',
    'The type of keyword search you would like' =>
      'The type of keyword search you would like',
    '$terms.Abug may be in any of a number of states.' =>
      '$terms.Abug may be in any of a number of states.',
    'If $terms.abug is in a resolved state, then one of these reasons
will<br />be given for its resolution.' =>
      'If $terms.abug is in a resolved state, then one of these reasons
will<br />be given for its resolution.',
    'How severe the $terms.bug is, or whether it\'s an enhancement.' =>
      'How severe the $terms.bug is, or whether it\'s an enhancement.',
    'Engineers prioritize their $terms.bugs using this field.' =>
      'Engineers prioritize their $terms.bugs using this field.',
    'The hardware platform the $terms.bug was observed on.' =>
      'The hardware platform the $terms.bug was observed on.',
    'The operating system the $terms.bug was observed on.' =>
      'The operating system the $terms.bug was observed on.',
    'Every $terms.bug has people associated with it in different
roles.<br />Here, you can search on what people are in what role.' =>
      'Every $terms.bug has people associated with it in different
roles.<br />Here, you can search on what people are in what role.',
    'You can limit your search to a specific set of $terms.bugs .' =>
      'You can limit your search to a specific set of $terms.bugs .',
    'Some $terms.bugs can be voted for, and you can limit your search to
$terms.bugs<br />with more than a certain number of votes.' =>
      'Some $terms.bugs can be voted for, and you can limit your search to
$terms.bugs<br />with more than a certain number of votes.',
    'You can search for specific types of change - this field define <br />
which field you are interested in changes for.' =>
      'You can search for specific types of change - this field define <br />
which field you are interested in changes for.',
    'Specify the start and end dates either in YYYY-MM-DD format<br />
(optionally followed by HH:mm, in 24 hour clock), or in relative<br />
dates such as 1h, 2d, 3w, 4m, 5y, which respectively mean one hour,<br />
two days, three weeks, four months, or five years ago. 0d is last<br />
midnight, and 0h, 0w, 0m, 0y is the beginning of this hour, week,<br />
month, or year.' =>
      'Specify the start and end dates either in YYYY-MM-DD format<br />
(optionally followed by HH:mm, in 24 hour clock), or in relative<br />
dates such as 1h, 2d, 3w, 4m, 5y, which respectively mean one hour,<br />
two days, three weeks, four months, or five years ago. 0d is last<br />
midnight, and 0h, 0w, 0m, 0y is the beginning of this hour, week,<br />
month, or year.',
    'The value the field defined above changed to during that time.' =>
      'The value the field defined above changed to during that time.',
  },
  'search/search-report-graph.html.tmpl' => {
    'Generate Graphical Report' =>
      'Generate Graphical Report',
    'Choose one or more fields as your axes, and then refine your set of $terms.bugs using the rest of the form.' =>
      'Choose one or more fields as your axes, and then refine your set of $terms.bugs using the rest of the form.',
    'Generate Report' =>
      'Generate Report',
    '<b>Vertical Axis:</b>' =>
      '<b>Vertical Axis:</b>',
    '(not for pie charts)' =>
      '(not for pie charts)',
    '<b>Plot Data Sets:</b>' =>
      '<b>Plot Data Sets:</b>',
    'Individually' =>
      'Individually',
    'Stacked' =>
      'Stacked',
    '<b>Multiple Images:</b>' =>
      '<b>Multiple Images:</b>',
    '<b>Format:</b>' =>
      '<b>Format:</b>',
    'Line Graph' =>
      'Line Graph',
    'Bar Chart' =>
      'Bar Chart',
    'Pie Chart' =>
      'Pie Chart',
    '<b>Horizontal Axis:</b>' =>
      '<b>Horizontal Axis:</b>',
    '<b>Vertical labels:</b>' =>
      '<b>Vertical labels:</b>',
  },
  'search/search-report-table.html.tmpl' => {
    'Generate Tabular Report' =>
      'Generate Tabular Report',
    'Choose one or more fields as your axes, and then refine your set of $terms.bugs using the rest of the form.' =>
      'Choose one or more fields as your axes, and then refine your set of $terms.bugs using the rest of the form.',
    'Generate Report' =>
      'Generate Report',
    '<b>Horizontal Axis:</b>' =>
      '<b>Horizontal Axis:</b>',
    '<b>Vertical Axis:</b>' =>
      '<b>Vertical Axis:</b>',
    '<b>Multiple Tables:</b>' =>
      '<b>Multiple Tables:</b>',
  },
  'search/search-specific.html.tmpl' => {
    'Simple Search' =>
      'Simple Search',
    'Find a specific $terms.bug by entering words that describe it. $terms.Bugzilla will search $terms.bug descriptions and comments for those words and return a list of matching $terms.bugs sorted by relevance.' =>
      'Find a specific $terms.bug by entering words that describe it. $terms.Bugzilla will search $terms.bug descriptions and comments for those words and return a list of matching $terms.bugs sorted by relevance.',
    'For example, if the $terms.bug you are looking for is a browser crash when you go to a secure web site with an embedded Flash animation, you might search for "crash secure SSL flash".' =>
      'For example, if the $terms.bug you are looking for is a browser crash when you go to a secure web site with an embedded Flash animation, you might search for "crash secure SSL flash".',
    'Status:' =>
      'Status:',
    'Open' =>
      'Open',
    'Closed' =>
      'Closed',
    'All' =>
      'All',
    'Product:' =>
      'Product:',
    'Words:' =>
      'Words:',
    'Search' =>
      'Search',
  },
  'search/tabs.html.tmpl' => {
    'Simple Search' =>
      'Simple Search',
    'Advanced Search' =>
      'Advanced Search',
  },
  'welcome-admin.html.tmpl' => {
    'Welcome to $terms.Bugzilla' =>
      'Welcome to $terms.Bugzilla',
    'version $constants.BUGZILLA_VERSION' =>
      'version $constants.BUGZILLA_VERSION',
    'Welcome,' =>
      'Welcome,',
    'You are seeing this page because some of the core parameters have not been set up yet. The goal of this page is to inform you about the last steps required to set up your installation correctly.' =>
      'You are seeing this page because some of the core parameters have not been set up yet. The goal of this page is to inform you about the last steps required to set up your installation correctly.',
    'As an administrator, you have access to all administrative pages, accessible from the' =>
      'As an administrator, you have access to all administrative pages, accessible from the',
    'Administration' =>
      'Administration',
    'link visible at the bottom of this page. This link will always be visible, on all pages. From there, you must visit at least the' =>
      'link visible at the bottom of this page. This link will always be visible, on all pages. From there, you must visit at least the',
    'Parameters' =>
      'Parameters',
    'page, from where you can set all important parameters for this installation; among others:' =>
      'page, from where you can set all important parameters for this installation; among others:',
    ', which is the URL pointing to this installation and which will be used in emails (which is also the reason you see this page: as long as this parameter is not set, you will see this page again and again).' =>
      ', which is the URL pointing to this installation and which will be used in emails (which is also the reason you see this page: as long as this parameter is not set, you will see this page again and again).',
    'is important for your browser to manage your cookies correctly.' =>
      'is important for your browser to manage your cookies correctly.',
    ', the person responsible for this installation if something is running wrongly.' =>
      ', the person responsible for this installation if something is running wrongly.',
    'Also important are the following parameters:' =>
      'Also important are the following parameters:',
    ', if turned on, will protect your installation from users having no account on this installation. In other words, users who are not explicitly authenticated with a valid account cannot see any data. This is what you want if you want to keep your data private.' =>
      ', if turned on, will protect your installation from users having no account on this installation. In other words, users who are not explicitly authenticated with a valid account cannot see any data. This is what you want if you want to keep your data private.',
    'defines which users are allowed to create an account on this installation. If set to ".*" (the default), everybody is free to create his own account. If set to "@mycompany.com$", only users having an account @mycompany.com will be allowed to create an account. If left blank, users will not be able to create accounts themselves; only an administrator will be able to create one for them. If you want a private installation, you must absolutely set this parameter to something different from the default.' =>
      'defines which users are allowed to create an account on this installation. If set to ".*" (the default), everybody is free to create his own account. If set to "@mycompany.com$", only users having an account @mycompany.com will be allowed to create an account. If left blank, users will not be able to create accounts themselves; only an administrator will be able to create one for them. If you want a private installation, you must absolutely set this parameter to something different from the default.',
    'defines the method used to send emails, such as sendmail or SMTP. You have to set it correctly to send emails.' =>
      'defines the method used to send emails, such as sendmail or SMTP. You have to set it correctly to send emails.',
    'After having set up all this, we recommend looking at $terms.Bugzilla\'s other parameters as well at some time so that you understand what they do and whether you want to modify their settings for your installation.' =>
      'After having set up all this, we recommend looking at $terms.Bugzilla\'s other parameters as well at some time so that you understand what they do and whether you want to modify their settings for your installation.',
  },
  'whine/mail.html.tmpl' => {
    'Click here to edit your whine schedule' =>
      'Click here to edit your whine schedule',
    'This search was scheduled by' =>
      'This search was scheduled by',
    'Total' =>
      'Total',
  },
  'whine/mail.txt.tmpl' => {
    'To edit your whine schedule, visit the following URL:' =>
      'To edit your whine schedule, visit the following URL:',
    'This search was scheduled by' =>
      'This search was scheduled by',
    'Priority:' =>
      'Priority:',
    'Severity:' =>
      'Severity:',
    'Platform:' =>
      'Platform:',
    'Assignee:' =>
      'Assignee:',
    'Status:' =>
      'Status:',
    'Resolution:' =>
      'Resolution:',
    'Summary:' =>
      'Summary:',
  },
  'whine/multipart-mime.txt.tmpl' => {
    'This is a MIME multipart message. It is possible that your mail program doesn\'t quite handle these properly. Some or all of the information in this message may be unreadable.' =>
      'This is a MIME multipart message. It is possible that your mail program doesn\'t quite handle these properly. Some or all of the information in this message may be unreadable.',
  },
  'whine/schedule.html.tmpl' => {
    'Set up whining' =>
      'Set up whining',
    '"Whining" is when $terms.Bugzilla executes a saved query at a regular interval and sends the resulting list of $terms.bugs via email.' =>
      '"Whining" is when $terms.Bugzilla executes a saved query at a regular interval and sends the resulting list of $terms.bugs via email.',
    'To set up a new whine event, click "Add a new event." Enter a subject line for the message that will be sent, along with a block of text that will accompany the $terms.bug list in the body of the message.' =>
      'To set up a new whine event, click "Add a new event." Enter a subject line for the message that will be sent, along with a block of text that will accompany the $terms.bug list in the body of the message.',
    'Schedules are added to an event by clicking on "Add a new schedule." A schedule consists of a day, a time of day or interval of times (e.g., every 15 minutes), and a target email address that may or may not be alterable, depending on your privileges. Events may have more than one schedule in order to run at multiple times or for different users.' =>
      'Schedules are added to an event by clicking on "Add a new schedule." A schedule consists of a day, a time of day or interval of times (e.g., every 15 minutes), and a target email address that may or may not be alterable, depending on your privileges. Events may have more than one schedule in order to run at multiple times or for different users.',
    'Searches come from saved searches, which are created by executing a' =>
      'Searches come from saved searches, which are created by executing a',
    'search' =>
      'search',
    ', then telling $terms.Bugzilla to remember the search under a particular name. Add a query by clicking "Add a new query", and select the desired saved search name under "Search" and add a title for the $terms.bug table. The optional number entered under "Sort" will determine the execution order (lowest to highest) if multiple queries are listed. If you check "One message per $terms.bug," each $terms.bug that matches the search will be sent in its own email message.' =>
      ', then telling $terms.Bugzilla to remember the search under a particular name. Add a query by clicking "Add a new query", and select the desired saved search name under "Search" and add a title for the $terms.bug table. The optional number entered under "Sort" will determine the execution order (lowest to highest) if multiple queries are listed. If you check "One message per $terms.bug," each $terms.bug that matches the search will be sent in its own email message.',
    'All times are server local time (' =>
      'All times are server local time (',
    'Update / Commit' =>
      'Update / Commit',
    'Event:' =>
      'Event:',
    'Remove Event' =>
      'Remove Event',
    'Email subject:' =>
      'Email subject:',
    'Description:' =>
      'Description:',
    '(email text)' =>
      '(email text)',
    'Send a message even if there are no $terms.bugs in the search result' =>
      'Send a message even if there are no $terms.bugs in the search result',
    'Schedule:' =>
      'Schedule:',
    'Not scheduled to run' =>
      'Not scheduled to run',
    'Add a new schedule' =>
      'Add a new schedule',
    'Interval' =>
      'Interval',
    'Mail to' =>
      'Mail to',
    'User' =>
      'User',
    'Group' =>
      'Group',
    'Remove' =>
      'Remove',
    'Searches:' =>
      'Searches:',
    'No searches' =>
      'No searches',
    'Add a new query' =>
      'Add a new query',
    'Sort' =>
      'Sort',
    'Search/Report' =>
      'Search/Report',
    'Title' =>
      'Title',
    'One message per $terms.bug' =>
      'One message per $terms.bug',
    'Add a new event' =>
      'Add a new event',
    'Report:' =>
      'Report:',
    'Please visit the' =>
      'Please visit the',
    'Search' =>
      'Search',
    'page and save a query' =>
      'page and save a query',
    'All' =>
      'All',
    'Each day' =>
      'Each day',
    'Monday through Friday' =>
      'Monday through Friday',
    'Sun' =>
      'Sun',
    'Sunday' =>
      'Sunday',
    'Mon' =>
      'Mon',
    'Monday' =>
      'Monday',
    'Tue' =>
      'Tue',
    'Tuesday' =>
      'Tuesday',
    'Wed' =>
      'Wed',
    'Wednesday' =>
      'Wednesday',
    'Thu' =>
      'Thu',
    'Thursday' =>
      'Thursday',
    'Fri' =>
      'Fri',
    'Friday' =>
      'Friday',
    'Sat' =>
      'Sat',
    'Saturday' =>
      'Saturday',
    'On the 1st of the month' =>
      'On the 1st of the month',
    'On the 2nd of the month' =>
      'On the 2nd of the month',
    'On the 3rd of the month' =>
      'On the 3rd of the month',
    'On the 4th of the month' =>
      'On the 4th of the month',
    'On the 5th of the month' =>
      'On the 5th of the month',
    'On the 6th of the month' =>
      'On the 6th of the month',
    'On the 7th of the month' =>
      'On the 7th of the month',
    'On the 8th of the month' =>
      'On the 8th of the month',
    'On the 9th of the month' =>
      'On the 9th of the month',
    'On the 10th of the month' =>
      'On the 10th of the month',
    'On the 11th of the month' =>
      'On the 11th of the month',
    'On the 12th of the month' =>
      'On the 12th of the month',
    'On the 13th of the month' =>
      'On the 13th of the month',
    'On the 14th of the month' =>
      'On the 14th of the month',
    'On the 15th of the month' =>
      'On the 15th of the month',
    'On the 16th of the month' =>
      'On the 16th of the month',
    'On the 17th of the month' =>
      'On the 17th of the month',
    'On the 18th of the month' =>
      'On the 18th of the month',
    'On the 19th of the month' =>
      'On the 19th of the month',
    'On the 20th of the month' =>
      'On the 20th of the month',
    'On the 21st of the month' =>
      'On the 21st of the month',
    'On the 22nd of the month' =>
      'On the 22nd of the month',
    'On the 23rd of the month' =>
      'On the 23rd of the month',
    'On the 24th of the month' =>
      'On the 24th of the month',
    'On the 25th of the month' =>
      'On the 25th of the month',
    'On the 26th of the month' =>
      'On the 26th of the month',
    'On the 27th of the month' =>
      'On the 27th of the month',
    'On the 28th of the month' =>
      'On the 28th of the month',
    'On the 29th of the month' =>
      'On the 29th of the month',
    'On the 30th of the month' =>
      'On the 30th of the month',
    'On the 31st of the month' =>
      'On the 31st of the month',
    'Last day of the month' =>
      'Last day of the month',
    'at midnight' =>
      'at midnight',
    'at 01:00' =>
      'at 01:00',
    'at 02:00' =>
      'at 02:00',
    'at 03:00' =>
      'at 03:00',
    'at 04:00' =>
      'at 04:00',
    'at 05:00' =>
      'at 05:00',
    'at 06:00' =>
      'at 06:00',
    'at 07:00' =>
      'at 07:00',
    'at 08:00' =>
      'at 08:00',
    'at 09:00' =>
      'at 09:00',
    'at 10:00' =>
      'at 10:00',
    'at 11:00' =>
      'at 11:00',
    'at 12:00' =>
      'at 12:00',
    'at 13:00' =>
      'at 13:00',
    'at 14:00' =>
      'at 14:00',
    'at 15:00' =>
      'at 15:00',
    'at 16:00' =>
      'at 16:00',
    'at 17:00' =>
      'at 17:00',
    'at 18:00' =>
      'at 18:00',
    'at 19:00' =>
      'at 19:00',
    'at 20:00' =>
      'at 20:00',
    'at 21:00' =>
      'at 21:00',
    'at 22:00' =>
      'at 22:00',
    'at 23:00' =>
      'at 23:00',
    'every hour' =>
      'every hour',
    'every 30 minutes' =>
      'every 30 minutes',
    'every 15 minutes' =>
      'every 15 minutes',
  },
  'worktime/dry-run.html.tmpl' => {
    'Тестовый прогон списания времени' =>
      'Тестовый прогон списания времени',
    'Закрыть окно' =>
      'Закрыть окно',
    'По багам:' =>
      'По багам:',
    '∑' =>
      '∑',
    'По пользователям:' =>
      'По пользователям:',
  },
  'worktime/supertime.html.tmpl' => {
    'Массовый ввод трудозатрат' =>
      'Массовый ввод трудозатрат',
    'Данная форма используется для массового ввода трудозатрат' =>
      'Данная форма используется для массового ввода трудозатрат',
    ', в том числе задним числом и от имени нескольких пользователей' =>
      ', в том числе задним числом и от имени нескольких пользователей',
    'Для введения трудозатрат задним числом и от имени других пользователей требуется членство в группе <b>worktimeadmin</b>.' =>
      'Для введения трудозатрат задним числом и от имени других пользователей требуется членство в группе <b>worktimeadmin</b>.',
    'за всех участников' =>
      'за всех участников',
    'Выборка трудозатрат:' =>
      'Выборка трудозатрат:',
    'Баг изменён: с' =>
      'Баг изменён: с',
    'по' =>
      'по',
    '&nbsp; &nbsp; пользователем:' =>
      '&nbsp; &nbsp; пользователем:',
    'Period Worktime: с' =>
      'Period Worktime: с',
    '&nbsp; &nbsp; пользователь:' =>
      '&nbsp; &nbsp; пользователь:',
    'Показать трудозатраты ' =>
      'Показать трудозатраты ',
    '$terms.bugs found.' =>
      '$terms.bugs found.',
    'Списать время' =>
      'Списать время',
    'Списать время:' =>
      'Списать время:',
    'На дату:' =>
      'На дату:',
    '&nbsp; За пользователя:' =>
      '&nbsp; За пользователя:',
    'На дату: <b>' =>
      'На дату: <b>',
    '</b> &nbsp; За пользователя: <b>' =>
      '</b> &nbsp; За пользователя: <b>',
    'Добавить комментарий:' =>
      'Добавить комментарий:',
    'Распределить пропорционально участию в одном баге:' =>
      'Распределить пропорционально участию в одном баге:',
    '(пропорционально участию в каждом, если пусто)' =>
      '(пропорционально участию в каждом, если пусто)',
    'Перенести время с указанного бага на баги в списке &ndash; на баги списка будет списано в сумме ровно столько часов, сколько было затрачено за заданный период на баг, с которого переносится время, пропорционально введённым значениям времени.' =>
      'Перенести время с указанного бага на баги в списке &ndash; на баги списка будет списано в сумме ровно столько часов, сколько было затрачено за заданный период на баг, с которого переносится время, пропорционально введённым значениям времени.',
    'Распределение часов по багам:' =>
      'Распределение часов по багам:',
    'Сумма:' =>
      'Сумма:',
    '&nbsp; минимум&nbsp;по:' =>
      '&nbsp; минимум&nbsp;по:',
    '(пропорционально / равномерно, будут добавлены к значениям в таблице)' =>
      '(пропорционально / равномерно, будут добавлены к значениям в таблице)',
    'Нечего распределять! Введите число, время в формате HH:MM, или в днях 1d, 2d, 3d и т.п.' =>
      'Нечего распределять! Введите число, время в формате HH:MM, или в днях 1d, 2d, 3d и т.п.',
  },
  'worktime/todaybugs.html.tmpl' => {
    'Today Worktime' =>
      'Today Worktime',
    'My Bugs for last' =>
      'My Bugs for last',
    'days.' =>
      'days.',
    'Bug' =>
      'Bug',
    'Prod/Comp' =>
      'Prod/Comp',
    'Summary' =>
      'Summary',
    'Hours Worked' =>
      'Hours Worked',
    'Comment' =>
      'Comment',
    'total hours' =>
      'total hours',
    'Worked/Left' =>
      'Worked/Left',
    '<b>&larr; Import worktime from text line-by-line.</b> Available formats:' =>
      '<b>&larr; Import worktime from text line-by-line.</b> Available formats:',
    'BUGID TIME COMMENT' =>
      'BUGID TIME COMMENT',
    'TIME is' =>
      'TIME is',
    'HH:MM' =>
      'HH:MM',
    'or simply a floating point number. Time also may be negative.' =>
      'or simply a floating point number. Time also may be negative.',
    'DD.MM.YYYY HH:MM - HH:MM classification - Bug BUGID COMMENT' =>
      'DD.MM.YYYY HH:MM - HH:MM classification - Bug BUGID COMMENT',
    '(start time - end time, "Bug" word is optional, this is old standard)' =>
      '(start time - end time, "Bug" word is optional, this is old standard)',
    'Hours Worked: <b>' =>
      'Hours Worked: <b>',
    'Worked Hours for the' =>
      'Worked Hours for the',
    'Last' =>
      'Last',
    'Days' =>
      'Days',
    'Today' =>
      'Today',
  },
};
