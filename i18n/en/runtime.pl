{
	install_strings => {
		any               => 'any',
		blacklisted       => '(blacklisted)',
		checking_for      => 'Checking for',
		checking_dbd      => 'Checking available perl DBD modules...',
		checking_optional => 'The following Perl modules are optional:',
		checking_modules  => 'Checking perl modules...',
		chmod_failed      => '##path##: Failed to change permissions: ##error##',
		chown_failed      => '##path##: Failed to change ownership: ##error##',
		commands_dbd      => <<EOT,
YOU MUST RUN ONE OF THE FOLLOWING COMMANDS (depending on which database
you use):
EOT
		commands_optional => 'COMMANDS TO INSTALL OPTIONAL MODULES:',
		commands_required => <<EOT,
COMMANDS TO INSTALL REQUIRED MODULES (You *must* run all these commands
and then re-run this script):
EOT
		done => 'done.',
		extension_must_return_name => <<END,
##file## returned ##returned##, which is not a valid name for an extension.
Extensions must return their name, not <code>1</code> or a number. See
the documentation of Bugzilla::Extension for details.
END
		feature_auth_ldap         => 'LDAP Authentication',
		feature_auth_radius       => 'RADIUS Authentication',
		feature_graphical_reports => 'Graphical Reports',
		feature_inbound_email     => 'Inbound Email',
		feature_jobqueue          => 'Mail Queueing',
		feature_jsonrpc           => 'JSON-RPC Interface',
		feature_new_charts        => 'New Charts',
		feature_old_charts        => 'Old Charts',
		feature_mod_perl          => 'mod_perl',
		feature_moving            => 'Move Bugs Between Installations',
		feature_patch_viewer      => 'Patch Viewer',
		feature_rand_security     => 'Improve cookie and token security',
		feature_smtp_auth         => 'SMTP Authentication',
		feature_updates           => 'Automatic Update Notifications',
		feature_xmlrpc            => 'XML-RPC Interface',
		feature_fulltext_stem     => 'Snowball stemmers in full-text search',

		header => '* This is Bugzilla ##bz_ver## on perl ##perl_ver##
* Running on ##os_name## ##os_ver##',
		install_all => <<EOT,

To attempt an automatic install of every required and optional module
with one command, do:

	##perl## install-module.pl --all

EOT
		install_data_too_long => <<EOT,
WARNING: Some of the data in the ##table##.##column## column is longer than
its new length limit of ##max_length## characters. The data that needs to be
fixed is printed below with the value of the ##id_column## column first and
then the value of the ##column## column that needs to be fixed:

EOT
		install_module => 'Installing ##module## version ##version##...',
		installation_failed => '*** Installation aborted. Read the messages above. ***',
		max_allowed_packet => <<EOT,
WARNING: You need to set the max_allowed_packet parameter in your MySQL
configuration to at least ##needed##. Currently it is set to ##current##.
You can set this parameter in the [mysqld] section of your MySQL
configuration file.
EOT
		min_version_required => 'Minimum version required: ',
		modules_message_db => <<EOT,
***********************************************************************
* DATABASE ACCESS                                                     *
***********************************************************************
* In order to access your database, Bugzilla requires that the        *
* correct "DBD" module be installed for the database that you are     *
* running. See below for the correct command to run to install the    *
* appropriate module for your database.                               *
EOT
		modules_message_optional => <<EOT,
***********************************************************************
* OPTIONAL MODULES                                                    *
***********************************************************************
* Certain Perl modules are not required by Bugzilla, but by           *
* installing the latest version you gain access to additional         *
* features.                                                           *
*                                                                     *
* The optional modules you do not have installed are listed below,    *
* with the name of the feature they enable. Below that table are the  *
* commands to install each module.                                    *
EOT
		modules_message_required => <<EOT,
***********************************************************************
* REQUIRED MODULES                                                    *
***********************************************************************
* Bugzilla requires you to install some Perl modules which are either *
* missing from your system, or the version on your system is too old. *
* See below for commands to install these modules.                    *
EOT
		module_found => 'found v##ver##',
		module_not_found => 'not found',
		module_ok => 'ok',
		module_unknown_version => 'found unknown version',
		no_such_module => 'There is no Perl module on CPAN named ##module##.',
		ppm_repo_add => <<EOT,
***********************************************************************
* Note For Windows Users                                              *
***********************************************************************
* In order to install the modules listed below, you first have to run *
* the following command as an Administrator:                          *
*                                                                     *
*   ppm repo add theory58S ##theory_url##
EOT
		ppm_repo_up => <<EOT,
*                                                                     *
* Then you have to do (also as an Administrator):                     *
*                                                                     *
*   ppm repo up theory58S                                             *
*                                                                     *
* Do that last command over and over until you see "theory58S" at the *
* top of the displayed list.                                          *
EOT
		template_precompile => 'Precompiling templates...',
		template_removal_failed => <<END,
WARNING: The directory '##datadir##/template' could not be removed.
		     It has been moved into '##datadir##/deleteme', which should be
		     deleted manually to conserve disk space.
END
		template_removing_dir => 'Removing existing compiled templates...',
	},
	terms => {
		bug => 'bug',
		Bug => 'Bug',
		abug => 'a bug',
		Abug => 'A bug',
		aBug => 'a Bug',
		ABug => 'A Bug',
		bugs => 'bugs',
		Bugs => 'Bugs',
		bugmail => 'bugmail',
		Bugmail => 'Bugmail',
		zeroSearchResults => 'Zarro Boogs found',
		Bugzilla => 'Bugzilla',
	},
	operator_descs => {
		not                 => 'NOT',
		noop                => '---',
		equals              => 'is equal to',
		notequals           => 'is not equal to',
		anyexact            => 'is equal to any of the strings',
		substring           => 'contains the string',
		notsubstring        => 'does not contain the string',
		casesubstring       => 'contains the string (exact case)',
		notcasesubstring    => 'does not contain the string (exact case)',
		anywordssubstr      => 'contains any of the strings',
		allwordssubstr      => 'contains all of the strings',
		nowordssubstr       => 'contains none of the strings',
		regexp              => 'matches regular expression',
		notregexp           => 'does not match regular expression',
		lessthan            => 'is less than',
		lessthaneq          => 'is less than or equal to',
		greaterthan         => 'is greater than',
		greaterthaneq       => 'is greater than or equal to',
		anywords            => 'contains any of the words',
		allwords            => 'contains all of the words',
		nowords             => 'contains none of the words',
		matches             => 'matches',
		notmatches          => 'does not match',
		insearch            => 'matched by saved search',
		notinsearch         => 'not matched by saved search',
		changedbefore       => 'changed before',
		changedafter        => 'changed after',
		changedfrom         => 'changed from',
		changedto           => 'changed to',
		changedby           => 'changed by',
		desc_between        => 'between $1 and $2',
		desc_before         => 'before $2',
		desc_after          => 'after $1',
		desc_by             => 'by $1',
		desc_fields         => 'one of $1',
	},
	field_types => {
		UNKNOWN        => 'Unknown Type',
		FREETEXT       => 'Free Text',
		SINGLE_SELECT  => 'Drop Down',
		MULTI_SELECT   => 'Multiple-Selection Box',
		TEXTAREA       => 'Large Text Box',
		DATETIME       => 'Date/Time',
		BUG_ID         => '$terms.Bug ID',
		BUG_URLS       => '$terms.Bug URLs',
		KEYWORDS       => '(Invalid type) Keywords',
		NUMERIC        => 'Numeric',
		EXTURL         => 'External URL',
		BUG_ID_REV     => '$terms.Bug ID reverse',
	},
	field_descs => {
		alias                   => 'Alias',
		assigned_to             => 'Assignee',
		blocked                 => 'Blocks',
		bug_file_loc            => 'URL',
		bug_group               => 'Group',
		bug_id                  => '$terms.Bug ID',
		bug_severity            => 'Severity',
		bug_status              => 'Status',
		cc                      => 'CC',
		classification          => 'Classification',
		cclist_accessible       => 'CC list accessible',
		component_id            => 'Component ID',
		component               => 'Component',
		content                 => 'Content',
		comment                 => 'Comment',
		changes                 => 'Changed',
		'[Bug creation]'        => 'Creation date',
		opendate                => 'Creation date',
		creation_ts             => 'Creation date',
		deadline                => 'Deadline',
		changeddate             => 'Changed',
		delta_ts                => 'Changed',
		dependson               => 'Depends on',
		dup_id                  => 'Duplicate of',
		estimated_time          => 'Orig. Est.',
		everconfirmed           => 'Ever confirmed',
		keywords                => 'Keywords',
		newcc                   => 'CC',
		op_sys                  => 'OS',
		owner_idle_time         => 'Time Since Assignee Touched',
		days_elapsed            => 'Days since bug changed',
		percentage_complete     => '% Complete',
		priority                => 'Priority',
		product_id              => 'Product ID',
		product                 => 'Product',
		qa_contact              => 'QA Contact',
		remaining_time          => 'Hours Left',
		rep_platform            => 'Hardware',
		reporter                => 'Reporter',
		reporter_accessible     => 'Reporter accessible',
		resolution              => 'Resolution',
		see_also                => 'See Also',
		setting                 => 'Setting',
		settings                => 'Settings',
		short_desc              => 'Summary',
		status_whiteboard       => 'Whiteboard',
		target_milestone        => 'Target Milestone',
		version                 => 'Version',
		votes                   => 'Votes',
		comment0                => 'First Comment',
		interval_time           => 'Period Worktime',
		work_time               => 'Hours Worked',
		actual_time             => 'Hours Worked',
		longdesc                => 'Comment',
		commenter               => 'Commenter',
		'longdescs.isprivate'     => 'Comment is private',
		'attachments.description' => 'Attachment description',
		'attachments.filename'    => 'Attachment filename',
		'attachments.mimetype'    => 'Attachment mime type',
		'attachments.ispatch'     => 'Attachment is patch',
		'attachments.isobsolete'  => 'Attachment is obsolete',
		'attachments.isprivate'   => 'Attachment is private',
		'attachments.submitter'   => 'Attachment creator',
		'flagtypes.name'          => 'Flags and Requests',
		'requestees.login_name'   => 'Flag Requestee',
		'setters.login_name'      => 'Flag Setter',
	},
	setting_descs => {
		comment_sort_order                => 'When viewing $terms.abug, show comments in this order',
		csv_colsepchar                    => 'Field separator character for CSV files',
		display_quips                     => 'Show a quip at the top of each $terms.bug list',
		zoom_textareas                    => 'Zoom textareas large when in use (requires JavaScript)',
		newest_to_oldest                  => 'Newest to Oldest',
		newest_to_oldest_desc_first       => 'Newest to Oldest, but keep Description at the top',
		off                               => 'Off',
		oldest_to_newest                  => 'Oldest to Newest',
		on                                => 'On',
		post_bug_submit_action            => 'After changing $terms.abug',
		next_bug                          => 'Show next $terms.bug in my list',
		same_bug                          => 'Show the updated $terms.bug',
		standard                          => 'Classic',
		skin                              => '$terms.Bugzilla\'s general appearance (skin)',
		nothing                           => 'Do Nothing',
		state_addselfcc                   => 'Automatically add me to the CC list of $terms.bugs I change',
		always                            => 'Always',
		never                             => 'Never',
		cc_unless_role                    => 'Only if I have no role on them',
		lang                              => 'Default language for UI and emails',
		quote_replies                     => 'Quote the associated comment when you click on its reply link',
		quoted_reply                      => 'Quote the full comment',
		simple_reply                      => 'Reference the comment number only',
		timezone                          => 'Timezone used to display dates and times',
		local                             => 'Same as the server',
		remind_me_about_worktime          => 'Remind me to track worktime for each comment',
		remind_me_about_worktime_newbug   => 'Remind me to track worktime for new bugs',
		remind_me_about_flags             => 'Remind me about flag requests',
		saved_searches_position           => 'Position of Saved Searches bar',
		footer                            => 'Page footer',
		header                            => 'Page header',
		both                              => 'Both',
		csv_charset                       => 'Character set for CSV import and export',
		silent_affects_flags              => 'Do not send flag email under Silent mode',
		send                              => 'Send',
		do_not_send                       => 'Don\'t send',
		showhide_comments                 => 'Which comments can be marked as collapsed',
		none                              => 'None',
		worktime                          => 'With worktime only',
		all                               => 'All',
		comment_width                     => 'Show comments in the full screen width',
		preview_long_comments             => 'Fold long comments',
		clear_requests_on_close           => 'Clear flag requests when closing bugs',
		show_gravatars                    => 'Show avatar images (Gravatars)',
	},
	system_groups => {
		admin                  => 'Administrator group. Usually allows to access <b>all</b> administrative functions.',
		admin_index            => 'Allows to <a href="admin.cgi">enter Administration area</a>, granted automatically if you can access any of the administrative functions.',
		tweakparams            => 'Allows to <a href="editparams.cgi">change Parameters</a>.',
		editusers              => 'Allows to <a href="editusers.cgi">edit or disable users</a> and include/exclude them from <b>all</b> groups.',
		creategroups           => 'Allows to <a href="editgroups.cgi">create, destroy and edit groups</a>.',
		editclassifications    => 'Allows to <a href="editclassifications.cgi">create, destroy and edit classifications</a>.',
		editcomponents         => 'Allows to <a href="editproducts.cgi">create, destroy and edit all products, components, versions and milestones</a>.',
		editkeywords           => 'Allows to <a href="editvalues.cgi?field=keywords">create, destroy and edit keywords</a>.',
		editbugs               => 'Allows to edit all fields of all bugs.',
		canconfirm             => 'Allows to confirm bugs or mark them as duplicates.',
		bz_canusewhineatothers => 'Allows to <a href="editwhines.cgi">configure whine reports for other users</a>.',
		bz_canusewhines        => 'Allows to <a href="editwhines.cgi">configure whine reports for self</a>.',
		bz_sudoers             => 'Allows to <a href="relogin.cgi?action=prepare-sudo">impersonate other users</a> and perform actions as them.',
		bz_sudo_protect        => 'Forbids other users to impersonate you.',
		bz_editcheckers        => 'Allows to <a href="editcheckers.cgi">edit Predicates</a> ("Correctness Checkers").',
		editfields             => 'Allows to <a href="editfields.cgi">create, destroy and edit properties of bug fields</a>.',
		editvalues             => 'Allows to <a href="editvalues.cgi">edit allowed values for all bug fields</a>.',
		importxls              => 'Allows to <a href="importxls.cgi">create or update many bugs at once using Excel and CSV files</a>.',
		worktimeadmin          => 'Allows to register working time for other users and for dates in the past (see "Fix Worktime" link under a bug list).',
		editflagtypes          => 'Allows to <a href="editflagtypes.cgi">create, destroy and edit flag types</a>.',
	},
};
