#!/usr/bin/perl
# Internationalisation messages for English Bugzilla

package Bugzilla::Language::en;

use strict;
use Bugzilla::Constants;

my $terms = {
    bug => 'bug',
    Bug => 'Bug',
    abug => 'a bug',
    Abug => 'A bug',
    aBug => 'a Bug',
    ABug => 'A Bug',
    bugs => 'bugs',
    Bugs => 'Bugs',
    zeroSearchResults => 'Zarro Boogs found',
    Bugzilla => 'Bugzilla',
};

$Bugzilla::messages->{en} = {
    terms => $terms,
    operator_descs => {
        not            => 'NOT',
        noop           => '---',
        equals         => 'is equal to',
        notequals      => 'is not equal to',
        anyexact       => 'is equal to any of the strings',
        substring      => 'contains the string',
        notsubstring   => 'does not contain the string',
        casesubstring  => 'contains the string (exact case)',
        notcasesubstring => 'does not contain the string (exact case)',
        anywordssubstr => 'contains any of the strings',
        allwordssubstr => 'contains all of the strings',
        nowordssubstr  => 'contains none of the strings',
        regexp         => 'matches regular expression',
        notregexp      => 'does not match regular expression',
        lessthan       => 'is less than',
        lessthaneq     => 'is less than or equal to',
        greaterthan    => 'is greater than',
        greaterthaneq  => 'is greater than or equal to',
        anywords       => 'contains any of the words',
        allwords       => 'contains all of the words',
        nowords        => 'contains none of the words',
        matches        => 'matches',
        notmatches     => 'does not match',
        insearch       => 'matched by saved search',
        notinsearch    => 'not matched by saved search',
        changedbefore  => 'changed before',
        changedafter   => 'changed after',
        changedfrom    => 'changed from',
        changedto      => 'changed to',
        changedby      => 'changed by',
        # Names with other_ prefix are used with correlated search terms
        other_changedbefore => 'change $1 before',
        other_changedafter  => 'change $1 after',
        other_changedfrom   => 'change $1 from',
        other_changedto     => 'change $1 to',
        other_changedby     => 'change $1 by',
        desc_between        => 'between $1 and $2',
        desc_before         => 'before $2',
        desc_after          => 'after $1',
        desc_by             => 'by $1',
        desc_fields         => 'one of $1',
    },
    field_types => {
        FIELD_TYPE_UNKNOWN()       => 'Unknown Type',
        FIELD_TYPE_FREETEXT()      => 'Free Text',
        FIELD_TYPE_SINGLE_SELECT() => 'Drop Down',
        FIELD_TYPE_MULTI_SELECT()  => 'Multiple-Selection Box',
        FIELD_TYPE_TEXTAREA()      => 'Large Text Box',
        FIELD_TYPE_DATETIME()      => 'Date/Time',
        FIELD_TYPE_BUG_ID()        => $terms->{Bug}.' ID',
        FIELD_TYPE_BUG_URLS()      => $terms->{Bug}.' URLs',
        FIELD_TYPE_KEYWORDS()      => '(Invalid type) Keywords',
        FIELD_TYPE_NUMERIC()       => 'Numeric',
        FIELD_TYPE_EXTURL()        => 'External URL',
        FIELD_TYPE_BUG_ID_REV()    => $terms->{Bug}.' ID reverse',
    },
    control_options => {
        CONTROLMAPNA() => 'NA',
        CONTROLMAPSHOWN() => 'Shown',
        CONTROLMAPDEFAULT() => 'Default',
        CONTROLMAPMANDATORY() => 'Mandatory',
    },
    field_descs => {
        alias                     => 'Alias',
        assigned_to               => 'Assignee',
        blocked                   => 'Blocks',
        bug_file_loc              => 'URL',
        bug_group                 => 'Group',
        bug_id                    => $terms->{Bug}.' ID',
        bug_severity              => 'Severity',
        bug_status                => 'Status',
        cc                        => 'CC',
        classification            => 'Classification',
        cclist_accessible         => 'CC list accessible',
        component_id              => 'Component ID',
        component                 => 'Component',
        content                   => 'Content',
        comment                   => 'Comment',
        changes                   => 'Changed',
        '[Bug creation]'          => 'Creation date',
        opendate                  => 'Creation date',
        creation_ts               => 'Creation date',
        deadline                  => 'Deadline',
        changeddate               => 'Changed',
        delta_ts                  => 'Changed',
        dependson                 => 'Depends on',
        dup_id                    => 'Duplicate of',
        estimated_time            => 'Orig. Est.',
        everconfirmed             => 'Ever confirmed',
        keywords                  => 'Keywords',
        newcc                     => 'CC',
        op_sys                    => 'OS',
        owner_idle_time           => 'Time Since Assignee Touched',
        percentage_complete       => '% Complete',
        priority                  => 'Priority',
        product_id                => 'Product ID',
        product                   => 'Product',
        qa_contact                => 'QA Contact',
        remaining_time            => 'Hours Left',
        rep_platform              => 'Hardware',
        reporter                  => 'Reporter',
        reporter_accessible       => 'Reporter accessible',
        resolution                => 'Resolution',
        see_also                  => 'See Also',
        setting                   => 'Setting',
        settings                  => 'Settings',
        short_desc                => 'Summary',
        status_whiteboard         => 'Whiteboard',
        target_milestone          => 'Target Milestone',
        version                   => 'Version',
        votes                     => 'Votes',
        comment0                  => 'First Comment',
        interval_time             => 'Period Worktime',
        work_time                 => 'Hours Worked',
        actual_time               => 'Hours Worked',
        longdesc                  => 'Comment',
        commenter                 => 'Commenter',
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
        # Names with other_ prefix are to be used with correlated search terms
        other_work_time                 => 'Hours Worked $1',
        other_longdesc                  => 'Comment $1',
        other_commenter                 => 'Comment $1 author',
        'other_longdescs.isprivate'     => 'Comment $1 is private',
        'other_attachments.description' => 'Attachment $1 description',
        'other_attachments.filename'    => 'Attachment $1 filename',
        'other_attachments.mimetype'    => 'Attachment $1 mime type',
        'other_attachments.ispatch'     => 'Attachment $1 is patch',
        'other_attachments.isobsolete'  => 'Attachment $1 is obsolete',
        'other_attachments.isprivate'   => 'Attachment $1 is private',
        'other_attachments.submitter'   => 'Attachment $1 creator',
        'other_flagtypes.name'          => 'Flag $1 Type',
        'other_requestees.login_name'   => 'Flag $1 Requestee',
        'other_setters.login_name'      => 'Flag $1 Setter',
    },
    setting_descs => {
        'comment_sort_order'                => "When viewing $terms->{abug}, show comments in this order",
        'csv_colsepchar'                    => 'Field separator character for CSV files',
        'display_quips'                     => "Show a quip at the top of each $terms->{bug} list",
        'zoom_textareas'                    => 'Zoom textareas large when in use (requires JavaScript)',
        'newest_to_oldest'                  => 'Newest to Oldest',
        'newest_to_oldest_desc_first'       => 'Newest to Oldest, but keep Description at the top',
        'off'                               => 'Off',
        'oldest_to_newest'                  => 'Oldest to Newest',
        'on'                                => 'On',
        'post_bug_submit_action'            => "After changing $terms->{abug}",
        'next_bug'                          => "Show next $terms->{bug} in my list",
        'same_bug'                          => "Show the updated $terms->{bug}",
        'standard'                          => 'Classic',
        'skin'                              => "$terms->{Bugzilla}'s general appearance (skin)",
        'nothing'                           => 'Do Nothing',
        'state_addselfcc'                   => "Automatically add me to the CC list of $terms->{bugs} I change",
        'always'                            => 'Always',
        'never'                             => 'Never',
        'cc_unless_role'                    => 'Only if I have no role on them',
        'lang'                              => 'Language used in email',
        'quote_replies'                     => 'Quote the associated comment when you click on its reply link',
        'quoted_reply'                      => 'Quote the full comment',
        'simple_reply'                      => 'Reference the comment number only',
        'timezone'                          => 'Timezone used to display dates and times',
        'local'                             => 'Same as the server',
        'remind_me_about_worktime'          => 'Remind me to track worktime for each comment',
        'remind_me_about_worktime_newbug'   => 'Remind me to track worktime for new bugs',
        'remind_me_about_flags'             => 'Remind me about flag requests',
        'saved_searches_position'           => 'Position of Saved Searches bar',
        'footer'                            => 'Page footer',
        'header'                            => 'Page header',
        'both'                              => 'Both',
        'csv_charset'                       => 'Character set for CSV import and export',
        'silent_affects_flags'              => 'Do not send flag email under Silent mode',
        'send'                              => 'Send',
        'do_not_send'                       => 'Don\'t send',
        'showhide_comments'                 => 'Which comments can be marked as collapsed',
        'none'                              => 'None',
        'worktime'                          => 'With worktime only',
        'all'                               => 'All',
        'comment_width'                     => 'Show comments in the full screen width',
        'preview_long_comments'             => 'Fold long comments',
        'clear_requests_on_close'           => 'Clear flag requests when closing bugs',
    },
    system_groups => {
        admin               => 'Administrator group. Usually allows to access <b>all</b> administrative functions.',
        admin_index         => 'Allows to <a href="admin.cgi">enter Administration area</a>, granted automatically if you can access any of the administrative functions.',
        tweakparams         => 'Allows to <a href="editparams.cgi">change Parameters</a>.',
        editusers           => 'Allows to <a href="editusers.cgi">edit or disable users</a> and include/exclude them from <b>all</b> groups.',
        creategroups        => 'Allows to <a href="editgroups.cgi">create, destroy and edit groups</a>.',
        editclassifications => 'Allows to <a href="editclassifications.cgi">create, destroy and edit classifications</a>.',
        editcomponents      => 'Allows to <a href="editproducts.cgi">create, destroy and edit all products, components, versions and milestones</a>.',
        editkeywords        => 'Allows to <a href="editvalues.cgi?field=keywords">create, destroy and edit keywords</a>.',
        editbugs            => 'Allows to edit all fields of all bugs.',
        canconfirm          => 'Allows to confirm bugs or mark them as duplicates.',
        bz_canusewhineatothers => 'Allows to <a href="editwhines.cgi">configure whine reports for other users</a>.',
        bz_canusewhines     => 'Allows to <a href="editwhines.cgi">configure whine reports for self</a>.',
        bz_sudoers          => 'Allows to <a href="relogin.cgi?action=prepare-sudo">impersonate other users</a> and perform actions as them.',
        bz_sudo_protect     => 'Forbids other users to impersonate you.',
        bz_editcheckers     => 'Allows to <a href="editcheckers.cgi">edit Predicates</a> ("Correctness Checkers").',
        editfields          => 'Allows to <a href="editfields.cgi">create, destroy and edit properties of bug fields</a>.',
        editvalues          => 'Allows to <a href="editvalues.cgi">edit allowed values for all bug fields</a>.',
        importxls           => 'Allows to <a href="importxls.cgi">create or update many bugs at once using Excel and CSV files</a>.',
        worktimeadmin       => 'Allows to register working time for other users and for dates in the past (see "Fix Worktime" link under a bug list).',
        editflagtypes       => 'Allows to <a href="editflagtypes.cgi">create, destroy and edit flag types</a>.',
    },
};

__END__
