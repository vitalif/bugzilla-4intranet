# no 'use utf8' here!
{
  'account/auth/login-simple.html.tmpl' => {
    '^Bugzilla_(login|password|restrictlogin)$' =>
      '^Bugzilla_(login|password|restrictlogin)$',
  },
  'account/auth/login-small.html.tmpl' => {
    '-relative' =>
      '-relative',
    '-query' =>
      '-query',
    '^token.cgi' =>
      '^token.cgi',
    'GoAheadAndLogIn=1' =>
      'GoAheadAndLogIn=1',
    '[x]' =>
      '[x]',
  },
  'account/auth/login.html.tmpl' => {
    'document.forms[\'login\'].Bugzilla_login.focus()' =>
      'document.forms[\'login\'].Bugzilla_login.focus()',
    '^Bugzilla_(login|password|restrictlogin)$' =>
      '^Bugzilla_(login|password|restrictlogin)$',
  },
  'account/cancel-token.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: admin' =>
      'X-Bugzilla-Type: admin',
    '%Y-%m-%d %H:%M:%S %Z' =>
      '%Y-%m-%d %H:%M:%S %Z',
  },
  'account/create.html.tmpl' => {
    'document.forms[\'account_creation_form\'].login.focus();' =>
      'document.forms[\'account_creation_form\'].login.focus();',
  },
  'account/email/change-new.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'X-Bugzilla-Type: admin' =>
      'X-Bugzilla-Type: admin',
    '&a=cfmem' =>
      '&a=cfmem',
    '&a=cxlem' =>
      '&a=cxlem',
    '%B %e, %Y at %H:%M %Z' =>
      '%B %e, %Y at %H:%M %Z',
  },
  'account/email/change-old.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'Importance: High X-MSMail-Priority: High X-Priority: 1 X-Bugzilla-Type: admin' =>
      'Importance: High X-MSMail-Priority: High X-Priority: 1 X-Bugzilla-Type: admin',
    '&a=cxlem' =>
      '&a=cxlem',
    '%B %e, %Y at %H:%M %Z' =>
      '%B %e, %Y at %H:%M %Z',
  },
  'account/email/confirm-new.html.tmpl' => {
    'document.forms[\'confirm_account_form\'].realname.focus();' =>
      'document.forms[\'confirm_account_form\'].realname.focus();',
    '%B %e, %Y at %H:%M %Z' =>
      '%B %e, %Y at %H:%M %Z',
  },
  'account/email/request-new.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: admin' =>
      'X-Bugzilla-Type: admin',
    '%B %e, %Y at %H:%M %Z' =>
      '%B %e, %Y at %H:%M %Z',
    '&a=request_new_account' =>
      '&a=request_new_account',
    '&a=cancel_new_account' =>
      '&a=cancel_new_account',
  },
  'account/password/forgotten-password.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: admin' =>
      'X-Bugzilla-Type: admin',
    '&a=cfmpw' =>
      '&a=cfmpw',
    '&a=cxlpw' =>
      '&a=cxlpw',
    '%B %e, %Y at %H:%M %Z' =>
      '%B %e, %Y at %H:%M %Z',
  },
  'account/prefs/email.html.tmpl' => {
    'email-$constants.REL_ANY-$constants.EVT_FLAG_REQUESTED' =>
      'email-$constants.REL_ANY-$constants.EVT_FLAG_REQUESTED',
    'email-$constants.REL_ANY-$constants.EVT_REQUESTED_FLAG' =>
      'email-$constants.REL_ANY-$constants.EVT_REQUESTED_FLAG',
    ' checked' =>
      ' checked',
  },
  'account/prefs/prefs.html.tmpl' => {
    'account/prefs/${current_tab.name}.html.tmpl' =>
      'account/prefs/${current_tab.name}.html.tmpl',
  },
  'account/prefs/saved-searches.html.tmpl' => {
    '%userid%' =>
      '%userid%',
    ' selected="selected"' =>
      ' selected="selected"',
    ' disabled' =>
      ' disabled',
    '^$q.shared_with_group.id\\$' =>
      '^$q.shared_with_group.id\\$',
    ' checked' =>
      ' checked',
  },
  'account/prefs/settings.html.tmpl' => {
    '-isdefault' =>
      '-isdefault',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'admin/admin.html.tmpl' => {
    'sanitycheck.pl' =>
      'sanitycheck.pl',
  },
  'admin/components/edit.html.tmpl' => {
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'admin/components/list.html.tmpl' => {
    'editcomponents.cgi?action=edit&amp;product=' =>
      'editcomponents.cgi?action=edit&amp;product=',
    '&amp;component=%%name%%' =>
      '&amp;component=%%name%%',
    'editcomponents.cgi?action=del&amp;product=' =>
      'editcomponents.cgi?action=del&amp;product=',
    'buglist.cgi?component=%%name%%&amp;product=' =>
      'buglist.cgi?component=%%name%%&amp;product=',
  },
  'admin/confirm-action.html.tmpl' => {
    '^(Bugzilla_login|Bugzilla_password)$' =>
      '^(Bugzilla_login|Bugzilla_password)$',
  },
  'admin/custom_fields/edit.html.tmpl' => {
    ' selected="selected"' =>
      ' selected="selected"',
    'multiple size=3' =>
      'multiple size=3',
    ' selected' =>
      ' selected',
    '-custom-fields' =>
      '-custom-fields',
    ' checked' =>
      ' checked',
  },
  'admin/custom_fields/list.html.tmpl' => {
    'editfields.cgi?action=del&amp;name=%%name%%' =>
      'editfields.cgi?action=del&amp;name=%%name%%',
    'editfields.cgi?action=edit&amp;name=%%name%%' =>
      'editfields.cgi?action=edit&amp;name=%%name%%',
  },
  'admin/edit-checkers.html.tmpl' => {
    '#ddf' =>
      '#ddf',
    '#fdd' =>
      '#fdd',
    ' selected=\'selected\'' =>
      ' selected=\'selected\'',
    ' checked=\'checked\'' =>
      ' checked=\'checked\'',
    ' style=\'display: none\'' =>
      ' style=\'display: none\'',
  },
  'admin/fieldvalues/list.html.tmpl' => {
    'editvalues.cgi?action=edit&amp;field=' =>
      'editvalues.cgi?action=edit&amp;field=',
    '&amp;value=%%name%%' =>
      '&amp;value=%%name%%',
    'editvalues.cgi?action=del&amp;field=' =>
      'editvalues.cgi?action=del&amp;field=',
  },
  'admin/fieldvalues/control-list-common.html.tmpl' => {
    ' checked' =>
      ' checked',
    ' selected' =>
      ' selected',
  },
  'admin/fieldvalues/control-list.html.tmpl' => {
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'admin/fieldvalues/edit.html.tmpl' => {
    'checked="checked"' =>
      'checked="checked"',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'admin/flag-type/edit.html.tmpl' => {
    '
table#form th { text-align: right; vertical-align: baseline; white-space: nowrap; }
table#form td { text-align: left; vertical-align: baseline; }
' =>
      '
table#form th { text-align: right; vertical-align: baseline; white-space: nowrap; }
table#form td { text-align: left; vertical-align: baseline; }
',
    'var f = document.forms[0]; selectProduct(f.product, f.component, null, null, \'__Any__\');' =>
      'var f = document.forms[0]; selectProduct(f.product, f.component, null, null, \'__Any__\');',
    '__Any__' =>
      '__Any__',
    ' checked' =>
      ' checked',
    ' selected' =>
      ' selected',
  },
  'admin/flag-type/list.html.tmpl' => {
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
    '__Any__' =>
      '__Any__',
    ' selected' =>
      ' selected',
  },
  'admin/flag-type/list.html.tmpl' => {
    'checked="checked"' =>
      'checked="checked"',
  },
  'admin/groups/edit.html.tmpl' => {
    'checked="checked"' =>
      'checked="checked"',
    '${name}_add' =>
      '${name}_add',
    '${name}_remove' =>
      '${name}_remove',
  },
  'admin/milestones/edit.html.tmpl' => {
    'document.forms[\'f\'].milestone.select()' =>
      'document.forms[\'f\'].milestone.select()',
    'checked="checked"' =>
      'checked="checked"',
  },
  'admin/milestones/list.html.tmpl' => {
    'editmilestones.cgi?action=edit&amp;product=' =>
      'editmilestones.cgi?action=edit&amp;product=',
    '&amp;milestone=%%name%%' =>
      '&amp;milestone=%%name%%',
    'editmilestones.cgi?action=del&amp;product=' =>
      'editmilestones.cgi?action=del&amp;product=',
    'buglist.cgi?target_milestone=%%name%%&amp;product=' =>
      'buglist.cgi?target_milestone=%%name%%&amp;product=',
  },
  'admin/params/bugmove.html.tmpl' => {
    'move-enabled' =>
      'move-enabled',
    'move-button-text' =>
      'move-button-text',
    'move-to-url' =>
      'move-to-url',
    'move-to-address' =>
      'move-to-address',
    'moved-from-address' =>
      'moved-from-address',
    'moved-default-product' =>
      'moved-default-product',
    'moved-default-component' =>
      'moved-default-component',
  },
  'admin/params/common.html.tmpl' => {
    'checked="checked"' =>
      'checked="checked"',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'admin/params/editparams.html.tmpl' => {
    'admin/params/${panel.name}.html.tmpl' =>
      'admin/params/${panel.name}.html.tmpl',
  },
  'admin/products/confirm-delete.html.tmpl' => {
    'additional-product-values' =>
      'additional-product-values',
  },
  'admin/products/create.html.tmpl' => {
    ' checked' =>
      ' checked',
  },
  'admin/products/edit-common.html.tmpl' => {
    ' class="bz_default_hidden"' =>
      ' class="bz_default_hidden"',
    ' selected="selected"' =>
      ' selected="selected"',
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'admin/products/footer.html.tmpl' => {
    '&amp;classification=' =>
      '&amp;classification=',
    'classification=' =>
      'classification=',
  },
  'admin/products/groupcontrol/confirm-edit.html.tmpl' => {
    '^Bugzilla_(login|password)$' =>
      '^Bugzilla_(login|password)$',
  },
  'admin/products/groupcontrol/edit.html.tmpl' => {
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'admin/products/list-classifications.html.tmpl' => {
    'editproducts.cgi?action=add&amp;classification=%%name%%' =>
      'editproducts.cgi?action=add&amp;classification=%%name%%',
  },
  'admin/products/list.html.tmpl' => {
    '&amp;classification=' =>
      '&amp;classification=',
    'editproducts.cgi?action=edit&amp;product=%%name%%' =>
      'editproducts.cgi?action=edit&amp;product=%%name%%',
    'editproducts.cgi?action=del&amp;product=%%name%%' =>
      'editproducts.cgi?action=del&amp;product=%%name%%',
  },
  'admin/settings/edit.html.tmpl' => {
    ' checked="checked"' =>
      ' checked="checked"',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'admin/users/create.html.tmpl' => {
    'document.forms[\'f\'].login.focus()' =>
      'document.forms[\'f\'].login.focus()',
  },
  'admin/users/edit.html.tmpl' => {
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'admin/users/list.html.tmpl' => {
    'editusers.cgi?action=edit&amp;userid=%%userid%%' =>
      'editusers.cgi?action=edit&amp;userid=%%userid%%',
    'editusers.cgi?action=activity&amp;userid=%%userid%%' =>
      'editusers.cgi?action=activity&amp;userid=%%userid%%',
    'editusers.cgi?action=del&amp;userid=%%userid%%' =>
      'editusers.cgi?action=del&amp;userid=%%userid%%',
    'bz_inactive missing' =>
      'bz_inactive missing',
  },
  'admin/users/search.html.tmpl' => {
    'document.forms[\'f\'].matchstr.focus()' =>
      'document.forms[\'f\'].matchstr.focus()',
  },
  'admin/versions/edit.html.tmpl' => {
    'document.getElementById(\'version\').focus()' =>
      'document.getElementById(\'version\').focus()',
    'checked="checked"' =>
      'checked="checked"',
  },
  'admin/versions/list.html.tmpl' => {
    'editversions.cgi?action=edit&amp;product=' =>
      'editversions.cgi?action=edit&amp;product=',
    '&amp;version=%%name%%' =>
      '&amp;version=%%name%%',
    'editversions.cgi?action=del&amp;product=' =>
      'editversions.cgi?action=del&amp;product=',
    'buglist.cgi?version=%%name%%&amp;product=' =>
      'buglist.cgi?version=%%name%%&amp;product=',
  },
  'admin/workflow/comment.html.tmpl' => {
    ' open-status' =>
      ' open-status',
    ' closed-status' =>
      ' closed-status',
    'open-status' =>
      'open-status',
    'closed-status' =>
      'closed-status',
    ' checked' =>
      ' checked',
    ' checked=\'checked\'' =>
      ' checked=\'checked\'',
  },
  'admin/workflow/edit.html.tmpl' => {
    'checked=\'checked\'' =>
      'checked=\'checked\'',
    ' checked' =>
      ' checked',
    'disabled=\'disabled\'' =>
      'disabled=\'disabled\'',
    ' open-status' =>
      ' open-status',
    ' closed-status' =>
      ' closed-status',
    'open-status' =>
      'open-status',
    'closed-status' =>
      'closed-status',
  },
  'attachment/choose.html.tmpl' => {
    'document.forms[\'choose-id\'].id.focus()' =>
      'document.forms[\'choose-id\'].id.focus()',
  },
  'attachment/create.html.tmpl' => {
    '${terms.bug} ${bug.dup_id}' =>
      '${terms.bug} ${bug.dup_id}',
    'width: 100%' =>
      'width: 100%',
  },
  'attachment/diff-file.html.tmpl' => {
    ' checked' =>
      ' checked',
  },
  'attachment/diff-header.html.tmpl' => {
    'restore_all(); document.checkboxform.restore_indicator.checked = true' =>
      'restore_all(); document.checkboxform.restore_indicator.checked = true',
    '&amp;action=edit' =>
      '&amp;action=edit',
    '&amp;action=diff' =>
      '&amp;action=diff',
  },
  'attachment/edit.html.tmpl' => {
    '$terms.Bug ${attachment.bug_id}' =>
      '$terms.Bug ${attachment.bug_id}',
    'checked="checked"' =>
      'checked="checked"',
    ' bz_hidden_option' =>
      ' bz_hidden_option',
    'editFrame' =>
      'editFrame',
    'height: 400px; width: 100%; display: none' =>
      'height: 400px; width: 100%; display: none',
    '^text\\/' =>
      '^text\\/',
    '(.*\\n|.+)' =>
      '(.*\\n|.+)',
    '$terms.bug ${attachment.bug_id}' =>
      '$terms.bug ${attachment.bug_id}',
  },
  'attachment/midair.html.tmpl' => {
    '$terms.bug $attachment.bug_id' =>
      '$terms.bug $attachment.bug_id',
    '^Bugzilla_(login|password)$' =>
      '^Bugzilla_(login|password)$',
  },
  'bug/activity/table.html.tmpl' => {
    '</tr><tr class=\'' =>
      '</tr><tr class=\'',
    'flagtypes.name' =>
      'flagtypes.name',
  },
  'bug/comments.html.tmpl' => {
    ' style="width: 100%"' =>
      ' style="width: 100%"',
    'Mozilla' =>
      'Mozilla',
    ' bz_private' =>
      ' bz_private',
    ' bz_comment_hilite' =>
      ' bz_comment_hilite',
    ' bz_first_comment' =>
      ' bz_first_comment',
    ' selected' =>
      ' selected',
    ' checked="checked"' =>
      ' checked="checked"',
    's=40&d=' =>
      's=40&d=',
    '/images/noavatar40.png' =>
      '/images/noavatar40.png',
    ' collapsed' =>
      ' collapsed',
    ' bz_fullscreen_comment' =>
      ' bz_fullscreen_comment',
    's=80' =>
      's=80',
  },
  'bug/create/comment-guided.txt.tmpl' => {
    '^1\\.\\s*2\\.\\s*3\\.\\s*$' =>
      '^1\\.\\s*2\\.\\s*3\\.\\s*$',
    '^\\s*$' =>
      '^\\s*$',
  },
  'bug/create/confirm-create-dupe.html.tmpl' => {
    '^(Bugzilla_login|Bugzilla_password|token)$' =>
      '^(Bugzilla_login|Bugzilla_password|token)$',
  },
  'bug/create/create-guided.html.tmpl' => {
    'PutDescription()' =>
      'PutDescription()',
    '#somebugs { width: 100%; height: 500px }' =>
      '#somebugs { width: 100%; height: 500px }',
    '#FFFFCC' =>
      '#FFFFCC',
    'product=Mozilla%20Application%20Suite&amp;product=Firefox' =>
      'product=Mozilla%20Application%20Suite&amp;product=Firefox',
    'Thunderbird' =>
      'Thunderbird',
    'product=Mozilla%20Application%20Suite&amp;product=Thunderbird' =>
      'product=Mozilla%20Application%20Suite&amp;product=Thunderbird',
    'product=' =>
      'product=',
    'about:buildconfig' =>
      'about:buildconfig',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'bug/create/create.html.tmpl' => {
    'show_attach_multi(this);' =>
      'show_attach_multi(this);',
    ' selected="selected"' =>
      ' selected="selected"',
    'width: 40em' =>
      'width: 40em',
    'min-width: 20em; max-width: 40em' =>
      'min-width: 20em; max-width: 40em',
    'width: 27em' =>
      'width: 27em',
    'width: 100%' =>
      'width: 100%',
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'bug/dependency-tree.html.tmpl' => {
    ' b_open' =>
      ' b_open',
    'onclick="return doToggle(this, event)"' =>
      'onclick="return doToggle(this, event)"',
    '0 && maxdepth' =>
      '0 && maxdepth',
    '= realdepth %]>' =>
      '= realdepth %]>',
  },
  'bug/dependency-graph.html.tmpl' => {
    'selected="selected"' =>
      'selected="selected"',
  },
  'bug/edit.html.tmpl' => {
    '\\D+' =>
      '\\D+',
    '${terms.bug} ${bug.dup_id}' =>
      '${terms.bug} ${bug.dup_id}',
    ' size="$size"' =>
      ' size="$size"',
    ' maxlength="$maxlength"' =>
      ' maxlength="$maxlength"',
    ' spellcheck="$spellcheck"' =>
      ' spellcheck="$spellcheck"',
    ' checked="checked"' =>
      ' checked="checked"',
    ' checked' =>
      ' checked',
    ' disabled="disabled"' =>
      ' disabled="disabled"',
    ' accesskey="$accesskey"' =>
      ' accesskey="$accesskey"',
    ' style="margin-top: 0.5em"' =>
      ' style="margin-top: 0.5em"',
    '^\\s+|\\s+$' =>
      '^\\s+|\\s+$',
    ':\\d\\d$' =>
      ':\\d\\d$',
    ':\\d\\d ' =>
      ':\\d\\d ',
    'width: 100%' =>
      'width: 100%',
    ' colspan="$colspan"' =>
      ' colspan="$colspan"',
    'move-button-text' =>
      'move-button-text',
  },
  'bug/field.html.tmpl' => {
    'size="' =>
      'size="',
    '" multiple="multiple"' =>
      '" multiple="multiple"',
    ' colspan="$value_span"' =>
      ' colspan="$value_span"',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'bug/format_comment.txt.tmpl' => {
    'X' =>
      'X',
    'move-to-url' =>
      'move-to-url',
  },
  'bug/knob.html.tmpl' => {
    '${terms.bug} ${bug.dup_id}' =>
      '${terms.bug} ${bug.dup_id}',
  },
  'bug/process/confirm-duplicate.html.tmpl' => {
    '^Bugzilla_(login|password)$' =>
      '^Bugzilla_(login|password)$',
    '$terms.bug $original_bug_id' =>
      '$terms.bug $original_bug_id',
  },
  'bug/process/midair.html.tmpl' => {
    '^Bugzilla_login|Bugzilla_password|delta_ts|token$' =>
      '^Bugzilla_login|Bugzilla_password|delta_ts|token$',
  },
  'bug/process/results.html.tmpl' => {
    '$terms.Bug $bug_id' =>
      '$terms.Bug $bug_id',
    '$terms.bug $bug_id' =>
      '$terms.bug $bug_id',
    'votes-removed' =>
      'votes-removed',
  },
  'bug/process/verify-field-values.html.tmpl' => {
    '^\\d+$' =>
      '^\\d+$',
    'bit-$group.group.id' =>
      'bit-$group.group.id',
    'checked="checked"' =>
      'checked="checked"',
  },
  'bug/process/verify-flags.html.tmpl' => {
    'requestee-$flag.id' =>
      'requestee-$flag.id',
    'X' =>
      'X',
    'selected="selected"' =>
      'selected="selected"',
  },
  'bug/process/verify-worktime.html.tmpl' => {
    '^work_time$' =>
      '^work_time$',
  },
  'bug/show-header.html.tmpl' => {
    '$terms.Bug $bug.bug_id – $bug.short_desc – ${bug.product_obj.name}/${bug.component_obj.name} – ${bug.bug_status_obj.name} ${bug.resolution_obj.name}' =>
      '$terms.Bug $bug.bug_id – $bug.short_desc – ${bug.product_obj.name}/${bug.component_obj.name} – ${bug.bug_status_obj.name} ${bug.resolution_obj.name}',
    '$terms.Bug&nbsp;$bug.bug_id' =>
      '$terms.Bug&nbsp;$bug.bug_id',
    'bz_status_${bug.bug_status_obj.name}' =>
      'bz_status_${bug.bug_status_obj.name}',
    'bz_product_${bug.product_obj.name}' =>
      'bz_product_${bug.product_obj.name}',
    'bz_component_${bug.component_obj.name}' =>
      'bz_component_${bug.component_obj.name}',
    'bz_bug_$bug.bug_id' =>
      'bz_bug_$bug.bug_id',
    'bz_group_$group.name' =>
      'bz_group_$group.name',
  },
  'bug/show-multiple.html.tmpl' => {
    'InvalidBugId' =>
      'InvalidBugId',
    'NotPermitted' =>
      'NotPermitted',
    'NotFound' =>
      'NotFound',
    ' colspan=3' =>
      ' colspan=3',
  },
  'bug/summarize-time.html.tmpl' => {
    '%.2f' =>
      '%.2f',
    '$global.owner_count.size developers @
$global.bug_count.size $terms.bugs' =>
      '$global.owner_count.size developers @
$global.bug_count.size $terms.bugs',
    '$global.bug_count.size $terms.bugs &
$global.owner_count.size developers' =>
      '$global.bug_count.size $terms.bugs &
$global.owner_count.size developers',
    'checked="checked"' =>
      'checked="checked"',
  },
  'bug/time.html.tmpl' => {
    '%.2f' =>
      '%.2f',
    '0\\Z' =>
      '0\\Z',
    '%.1f' =>
      '%.1f',
  },
  'bug/votes/list-for-bug.html.tmpl' => {
    '$terms.Bug <a href="show_bug.cgi?id=$bug_id">$bug_id</a>' =>
      '$terms.Bug <a href="show_bug.cgi?id=$bug_id">$bug_id</a>',
  },
  'bug/votes/list-for-user.html.tmpl' => {
    'document.forms[\'voting_form\'].bug_' =>
      'document.forms[\'voting_form\'].bug_',
    '.select();document.forms[\'voting_form\'].bug_' =>
      '.select();document.forms[\'voting_form\'].bug_',
    '.focus()' =>
      '.focus()',
    ' checked' =>
      ' checked',
  },
  'email/lockout.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    ') X-Bugzilla-Type: admin' =>
      ') X-Bugzilla-Type: admin',
  },
  'email/newchangedmail.txt.tmpl' => {
    'X-Bugzilla-' =>
      'X-Bugzilla-',
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Re: ' =>
      'Re: ',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Reason:' =>
      'X-Bugzilla-Reason:',
    'X-Bugzilla-Type:' =>
      'X-Bugzilla-Type:',
    'X-Bugzilla-Watch-Reason:' =>
      'X-Bugzilla-Watch-Reason:',
    'X-Bugzilla-Classification:' =>
      'X-Bugzilla-Classification:',
    'Importance: high X-Priority: 1' =>
      'Importance: high X-Priority: 1',
    'X-Bugzilla-Product:' =>
      'X-Bugzilla-Product:',
    'X-Bugzilla-Component:' =>
      'X-Bugzilla-Component:',
    'X-Bugzilla-Keywords:' =>
      'X-Bugzilla-Keywords:',
    'X-Bugzilla-Severity:' =>
      'X-Bugzilla-Severity:',
    'X-Bugzilla-Who:' =>
      'X-Bugzilla-Who:',
    'X-Bugzilla-Status:' =>
      'X-Bugzilla-Status:',
    'X-Bugzilla-Priority:' =>
      'X-Bugzilla-Priority:',
    'X-Bugzilla-Assigned-To:' =>
      'X-Bugzilla-Assigned-To:',
    'X-Bugzilla-Target-Milestone:' =>
      'X-Bugzilla-Target-Milestone:',
    'None' =>
      'None',
    'X-Bugzilla-Changed-Fields:' =>
      'X-Bugzilla-Changed-Fields:',
    'X-Bugzilla-Added-Comments:' =>
      'X-Bugzilla-Added-Comments:',
    'Content-Type: multipart/alternative; boundary=' =>
      'Content-Type: multipart/alternative; boundary=',
    'MIME-Version: 1.0' =>
      'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8 Content-Transfer-Encoding: quoted-printable' =>
      'Content-Type: text/plain; charset=utf-8 Content-Transfer-Encoding: quoted-printable',
    'userprefs.cgi?tab=email -------' =>
      'userprefs.cgi?tab=email -------',
    'Content-Type: text/html; charset=utf-8 Content-Transfer-Encoding: quoted-printable' =>
      'Content-Type: text/html; charset=utf-8 Content-Transfer-Encoding: quoted-printable',
  },
  'email/sanitycheck.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: sanitycheck' =>
      'X-Bugzilla-Type: sanitycheck',
  },
  'email/sudo.txt.tmpl' => {
    'Content-Type: text/plain From:' =>
      'Content-Type: text/plain From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: admin' =>
      'X-Bugzilla-Type: admin',
  },
  'email/votes-removed.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: voteremoved' =>
      'X-Bugzilla-Type: voteremoved',
  },
  'email/whine.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: whine' =>
      'X-Bugzilla-Type: whine',
  },
  'extensions/hook-readme.txt.tmpl' => {
    'Template hooks go in this directory. Template hooks are called in normal' =>
      'Template hooks go in this directory. Template hooks are called in normal',
    'templates like [' =>
      'templates like [',
    'Hook.process(\'some-hook\') %]. More information about them can be found in the documentation of B' =>
      'Hook.process(\'some-hook\') %]. More information about them can be found in the documentation of B',
    'ugzilla::Extension. (Do "perldoc B' =>
      'ugzilla::Extension. (Do "perldoc B',
    'ugzilla::Extension" from the main' =>
      'ugzilla::Extension" from the main',
    'directory to see that documentation.)' =>
      'directory to see that documentation.)',
  },
  'extensions/license.txt.tmpl' => {
    '# -*- Mode: perl; indent-tabs-mode: nil -*- # # The contents of this file are subject to the Mozilla Public # License Version 1.1 (the "License"); you may not use this file # except in compliance with the License. You may obtain a copy of # the License at http://www.mozilla.org/MPL/ # # Software distributed under the License is distributed on an "AS # IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or # implied. See the License for the specific language governing # rights and limitations under the License. # # The Original Code is the' =>
      '# -*- Mode: perl; indent-tabs-mode: nil -*- # # The contents of this file are subject to the Mozilla Public # License Version 1.1 (the "License"); you may not use this file # except in compliance with the License. You may obtain a copy of # the License at http://www.mozilla.org/MPL/ # # Software distributed under the License is distributed on an "AS # IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or # implied. See the License for the specific language governing # rights and limitations under the License. # # The Original Code is the',
    'Extension. # # The Initial Developer of the Original Code is YOUR NAME # Portions created by the Initial Developer are Copyright (C)' =>
      'Extension. # # The Initial Developer of the Original Code is YOUR NAME # Portions created by the Initial Developer are Copyright (C)',
    'the # Initial Developer. All Rights Reserved. # # Contributor(s): # YOUR NAME' =>
      'the # Initial Developer. All Rights Reserved. # # Contributor(s): # YOUR NAME',
  },
  'extensions/name-readme.txt.tmpl' => {
    'Normal templates go in this directory. You can load them in your code like this:' =>
      'Normal templates go in this directory. You can load them in your code like this:',
    'use B' =>
      'use B',
    'ugzilla::Error; my $template = B' =>
      'ugzilla::Error; my $template = B',
    'ugzilla->template; $template->process(\'' =>
      'ugzilla->template; $template->process(\'',
    '/some-template.html.tmpl\') or ThrowTemplateError($template->error());' =>
      '/some-template.html.tmpl\') or ThrowTemplateError($template->error());',
    'That would be how to load a file called some-template.html.tmpl that was in this directory.' =>
      'That would be how to load a file called some-template.html.tmpl that was in this directory.',
    'Note that you have to be careful that the full path of your template never conflicts with a template that exists in $terms.Bugzilla or in another extension, or your template might override that template. That\'s why we created this directory called \'' =>
      'Note that you have to be careful that the full path of your template never conflicts with a template that exists in $terms.Bugzilla or in another extension, or your template might override that template. That\'s why we created this directory called \'',
    '\' for you, so you can put your templates in here to help avoid conflicts.' =>
      '\' for you, so you can put your templates in here to help avoid conflicts.',
  },
  'flag/list.html.tmpl' => {
    'requestee-$flag.id' =>
      'requestee-$flag.id',
    'requestee_type-$type.id' =>
      'requestee_type-$type.id',
    'width: 100%' =>
      'width: 100%',
    ' disabled="disabled"' =>
      ' disabled="disabled"',
    ' selected' =>
      ' selected',
  },
  'global/code-error-page.html.tmpl' => {
    '\\n\\n' =>
      '\\n\\n',
  },
  'global/code-error.html.tmpl' => {
    'Bugzilla::Field::Choice' =>
      'Bugzilla::Field::Choice',
    'Bugzilla::Field::Choice-&gt;type(\'some_field\')' =>
      'Bugzilla::Field::Choice-&gt;type(\'some_field\')',
    'OPTIONAL_MODULES' =>
      'OPTIONAL_MODULES',
    'Bugzilla::Install::Requirements' =>
      'Bugzilla::Install::Requirements',
    'feature_$feature' =>
      'feature_$feature',
    'checksetup.pl' =>
      'checksetup.pl',
    '$init_value' =>
      '$init_value',
  },
  'global/common-links.html.tmpl' => {
    'link-row' =>
      'link-row',
  },
  'global/confirm-action.html.tmpl' => {
    '^(Bugzilla_login|Bugzilla_password|token)$' =>
      '^(Bugzilla_login|Bugzilla_password|token)$',
  },
  'global/confirm-user-match.html.tmpl' => {
    '^requestee' =>
      '^requestee',
  },
  'global/header.html.tmpl' => {
    '\\.css$' =>
      '\\.css$',
    '^skins/standard/' =>
      '^skins/standard/',
    'alternate ' =>
      'alternate ',
    'skins/contrib/$contrib_skin' =>
      'skins/contrib/$contrib_skin',
    'skins/contrib/$contrib_skin/' =>
      'skins/contrib/$contrib_skin/',
    'skins/custom/' =>
      'skins/custom/',
    '^https?://' =>
      '^https?://',
  },
  'global/js-products.html.tmpl' => {
    'var useclassification = false; // No classification level in use var first_load = true; // Is this the first time we load the page? var last_sel = []; // Caches last selection var cpts = new Array();' =>
      'var useclassification = false; // No classification level in use var first_load = true; // Is this the first time we load the page? var last_sel = []; // Caches last selection var cpts = new Array();',
    'cpts[\'' =>
      'cpts[\'',
  },
  'global/messages.html.tmpl' => {
    '$terms.bug $bug_id' =>
      '$terms.bug $bug_id',
  },
  'global/site-navigation.html.tmpl' => {
    'MSIE [1-6]' =>
      'MSIE [1-6]',
    'Mozilla/4' =>
      'Mozilla/4',
    '%userid%' =>
      '%userid%',
  },
  'global/useful-links.html.tmpl' => {
    '%userid%' =>
      '%userid%',
  },
  'global/user-error-page.html.tmpl' => {
    '^\\s*<[a-z]' =>
      '^\\s*<[a-z]',
    '\\n\\n' =>
      '\\n\\n',
  },
  'global/user-error.html.tmpl' => {
    'A b' =>
      'A b',
    'ug on launchpad.net' =>
      'ug on launchpad.net',
    'An issue on code.google.com.' =>
      'An issue on code.google.com.',
    'ug on b' =>
      'ug on b',
    'ugs.debian.org.' =>
      'ugs.debian.org.',
    'B' =>
      'B',
    'ugzilla/Migrate/' =>
      'ugzilla/Migrate/',
    'Bugzilla::User' =>
      'Bugzilla::User',
    'Bugzilla::Attachment' =>
      'Bugzilla::Attachment',
    'Bugzilla::Component' =>
      'Bugzilla::Component',
    'Bugzilla::Version' =>
      'Bugzilla::Version',
    'Bugzilla::Milestone' =>
      'Bugzilla::Milestone',
    'Bugzilla::Status' =>
      'Bugzilla::Status',
    'Bugzilla::Flag' =>
      'Bugzilla::Flag',
    'Bugzilla::FlagType' =>
      'Bugzilla::FlagType',
    'Bugzilla::Field' =>
      'Bugzilla::Field',
    'Bugzilla::Group' =>
      'Bugzilla::Group',
    'Bugzilla::Product' =>
      'Bugzilla::Product',
    'Bugzilla::Classification' =>
      'Bugzilla::Classification',
    'Bugzilla::Search::Saved' =>
      'Bugzilla::Search::Saved',
    '^Bugzilla::Field::Choice::(.+)' =>
      '^Bugzilla::Field::Choice::(.+)',
  },
  'global/userselect.html.tmpl' => {
    ', multipleDelimiter: ","' =>
      ', multipleDelimiter: ","',
  },
  'index.html.tmpl' => {
    'proxy_url' =>
      'proxy_url',
    'href="createaccount.cgi">' =>
      'href="createaccount.cgi">',
    'href="?GoAheadAndLogIn=1">' =>
      'href="?GoAheadAndLogIn=1">',
  },
  'list-of-mail-groups.html.tmpl' => {
    '<span class="bz_inactive">$thisuser.login_name</span>' =>
      '<span class="bz_inactive">$thisuser.login_name</span>',
  },
  'list/change-columns.html.tmpl' => {
    'initChangeColumns()' =>
      'initChangeColumns()',
    'checked=\'checked\'' =>
      'checked=\'checked\'',
  },
  'list/edit-multiple.html.tmpl' => {
    'move-enabled' =>
      'move-enabled',
  },
  'list/list.html.tmpl' => {
    'buglist.cgi?$urlquerypart&title=$title&ctype=atom' =>
      'buglist.cgi?$urlquerypart&title=$title&ctype=atom',
    '%a %b %e %Y %T %Z' =>
      '%a %b %e %Y %T %Z',
    '[&\\?]format=[^&]*' =>
      '[&\\?]format=[^&]*',
    '&order=$qorder' =>
      '&order=$qorder',
    '[&\\?](format|dotweak)[^&]*' =>
      '[&\\?](format|dotweak)[^&]*',
    'query_format=(advanced|simple)' =>
      'query_format=(advanced|simple)',
    '&amp;known_name=' =>
      '&amp;known_name=',
    '&amp;order=' =>
      '&amp;order=',
  },
  'list/quips.html.tmpl' => {
    'create-quips' =>
      'create-quips',
    'open' =>
      'open',
    'approve-quips' =>
      'approve-quips',
    ' checked="checked"' =>
      ' checked="checked"',
  },
  'list/table.html.tmpl' => {
    '\\b$id( DESC)?' =>
      '\\b$id( DESC)?',
    ' DESC' =>
      ' DESC',
    '\\b$id( DESC)?(,\\s*|\\$)' =>
      '\\b$id( DESC)?(,\\s*|\\$)',
    'bz_$bug.resolution' =>
      'bz_$bug.resolution',
    'bz_secure_mode_$bug.secure_mode' =>
      'bz_secure_mode_$bug.secure_mode',
    '_realname$' =>
      '_realname$',
    'OPEN ' =>
      'OPEN ',
    '_short$' =>
      '_short$',
    'OPEN product:' =>
      'OPEN product:',
    'http:' =>
      'http:',
    '((\\.\\d*[1-9])|\\.)0+$' =>
      '((\\.\\d*[1-9])|\\.)0+$',
  },
  'pages/previewcomment.html.tmpl' => {
    ' bz_fullscreen_comment' =>
      ' bz_fullscreen_comment',
  },
  'pages/quicksearch.html.tmpl' => {
    'document.forms[\'f\'].quicksearch.focus()' =>
      'document.forms[\'f\'].quicksearch.focus()',
    'cf_' =>
      'cf_',
    '^cf_' =>
      '^cf_',
  },
  'reports/chart.html.tmpl' => {
    '%Y-%m-%d %H:%M:%S' =>
      '%Y-%m-%d %H:%M:%S',
    '&amp;ctype=png&amp;action=plot&amp;width=' =>
      '&amp;ctype=png&amp;action=plot&amp;width=',
    '&amp;height=' =>
      '&amp;height=',
    '&amp;action=wrap' =>
      '&amp;action=wrap',
  },
  'reports/create-chart.html.tmpl' => {
    'catSelected();
subcatSelected();' =>
      'catSelected();
subcatSelected();',
    'subcatSelected()' =>
      'subcatSelected()',
    '%Y-%m-%d' =>
      '%Y-%m-%d',
    ' checked' =>
      ' checked',
  },
  'reports/duplicates-table.html.tmpl' => {
    '$param=$filtered_value' =>
      '$param=$filtered_value',
    'bug_id=$bug_ids_string' =>
      'bug_id=$bug_ids_string',
    '&amp;$base_args_string' =>
      '&amp;$base_args_string',
    ' class=\'resolved\'' =>
      ' class=\'resolved\'',
  },
  'reports/duplicates.html.tmpl' => {
    ' checked="checked"' =>
      ' checked="checked"',
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'reports/old-charts.html.tmpl' => {
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'reports/report-table.html.tmpl' => {
    '_type=[^&]*&?' =>
      '_type=[^&]*&?',
    '-total-' =>
      '-total-',
    '&amp;$tbl_vals' =>
      '&amp;$tbl_vals',
    '&amp;$col_vals' =>
      '&amp;$col_vals',
    '&amp;$row_vals' =>
      '&amp;$row_vals',
    '^\\s*$' =>
      '^\\s*$',
    '_type=regexp&amp;' =>
      '_type=regexp&amp;',
    '_type=equals&amp;' =>
      '_type=equals&amp;',
  },
  'reports/report.html.tmpl' => {
    '%Y-%m-%d %H:%M:%S' =>
      '%Y-%m-%d %H:%M:%S',
    '
.t1     { background-color: #ffffff } /* white       */
.t2     { background-color: #dfefff } /* light blue  */
.t3     { background-color: #dddddd } /* grey        */
.t4     { background-color: #c3d3ed } /* darker blue */
.ttotal { background-color: #cfffdf } /* light green */
' =>
      '
.t1     { background-color: #ffffff } /* white       */
.t2     { background-color: #dfefff } /* light blue  */
.t3     { background-color: #dddddd } /* grey        */
.t4     { background-color: #c3d3ed } /* darker blue */
.ttotal { background-color: #cfffdf } /* light green */
',
    '&amp;format=' =>
      '&amp;format=',
    '&amp;ctype=png&amp;action=plot&amp;' =>
      '&amp;ctype=png&amp;action=plot&amp;',
    'width=' =>
      'width=',
    '&amp;height=' =>
      '&amp;height=',
    'report.cgi?$switchbase&amp;width=$width&amp;height=$height&amp;action=wrap' =>
      'report.cgi?$switchbase&amp;width=$width&amp;height=$height&amp;action=wrap',
    '&amp;action=wrap&amp;format=' =>
      '&amp;action=wrap&amp;format=',
    '&amp;measure=' =>
      '&amp;measure=',
  },
  'reports/report-simple.html.tmpl' => {
    '-total-' =>
      '-total-',
  },
  'reports/series-common.html.tmpl' => {
    'multiple="multiple"' =>
      'multiple="multiple"',
    'disabled="disabled"' =>
      'disabled="disabled"',
    'onchange="$sel.onchange"' =>
      'onchange="$sel.onchange"',
    ' selected' =>
      ' selected',
  },
  'reports/series.html.tmpl' => {
    'catSelected()' =>
      'catSelected()',
    'checkNewState()' =>
      'checkNewState()',
    '&nbsp;day(s)' =>
      '&nbsp;day(s)',
    'checked=\'checked\'' =>
      'checked=\'checked\'',
  },
  'request/email.txt.tmpl' => {
    'X-Bugzilla-' =>
      'X-Bugzilla-',
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject:' =>
      'Subject:',
    'X-Bugzilla-Type: request' =>
      'X-Bugzilla-Type: request',
    'X-Bugzilla-Classification:' =>
      'X-Bugzilla-Classification:',
    'X-Bugzilla-Product:' =>
      'X-Bugzilla-Product:',
    'X-Bugzilla-Component:' =>
      'X-Bugzilla-Component:',
    'X-Bugzilla-Keywords:' =>
      'X-Bugzilla-Keywords:',
    'X-Bugzilla-Severity:' =>
      'X-Bugzilla-Severity:',
    'X-Bugzilla-Who:' =>
      'X-Bugzilla-Who:',
    'X-Bugzilla-Status:' =>
      'X-Bugzilla-Status:',
    'X-Bugzilla-Priority:' =>
      'X-Bugzilla-Priority:',
    'X-Bugzilla-Assigned-To:' =>
      'X-Bugzilla-Assigned-To:',
    'X-Bugzilla-QA-Contact:' =>
      'X-Bugzilla-QA-Contact:',
    'X-Bugzilla-Target-Milestone:' =>
      'X-Bugzilla-Target-Milestone:',
    'Content-Type: multipart/alternative; boundary=' =>
      'Content-Type: multipart/alternative; boundary=',
    'MIME-Version: 1.0' =>
      'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8 Content-Transfer-Encoding: quoted-printable' =>
      'Content-Type: text/plain; charset=utf-8 Content-Transfer-Encoding: quoted-printable',
    '&action=edit' =>
      '&action=edit',
    'Content-Type: text/html; charset=utf-8 Content-Transfer-Encoding: quoted-printable' =>
      'Content-Type: text/html; charset=utf-8 Content-Transfer-Encoding: quoted-printable',
  },
  'request/queue.html.tmpl' => {
    'var f = document.request_form; selectProduct(f.product, f.component, null, null, \'Any\');' =>
      'var f = document.request_form; selectProduct(f.product, f.component, null, null, \'Any\');',
    'cpts[\'' =>
      'cpts[\'',
    ' selected' =>
      ' selected',
    'display_$column' =>
      'display_$column',
  },
  'scrum/cards.html.tmpl' => {
    ' checked' =>
      ' checked',
  },
  'search/boolean-charts.html.tmpl' => {
    'field$C-$I-$J' =>
      'field$C-$I-$J',
    'type$C-$I-$J' =>
      'type$C-$I-$J',
    'value$C-$I-$J' =>
      'value$C-$I-$J',
    '\\s*\\n\\s*' =>
      '\\s*\\n\\s*',
  },
  'search/form.html.tmpl' => {
    ' checked' =>
      ' checked',
    ' selected' =>
      ' selected',
  },
  'search/knob.html.tmpl' => {
    ' selected=\'selected\'' =>
      ' selected=\'selected\'',
  },
  'search/search-advanced.html.tmpl' => {
    'var queryform = "queryform"' =>
      'var queryform = "queryform"',
    'enableHelp();' =>
      'enableHelp();',
    'dl.bug_changes dt {
margin-top: 15px;
}' =>
      'dl.bug_changes dt {
margin-top: 15px;
}',
  },
  'search/search-create-series.html.tmpl' => {
    'var queryform = "chartform";' =>
      'var queryform = "chartform";',
    'create-series' =>
      'create-series',
  },
  'search/search-report-graph.html.tmpl' => {
    'var queryform = "reportform"' =>
      'var queryform = "reportform"',
    'chartTypeChanged()' =>
      'chartTypeChanged()',
    ' checked' =>
      ' checked',
  },
  'search/search-report-select.html.tmpl' => {
    '&lt;none&gt;' =>
      '&lt;none&gt;',
    ' selected' =>
      ' selected',
  },
  'search/search-report-table.html.tmpl' => {
    'var queryform = "reportform"' =>
      'var queryform = "reportform"',
  },
  'search/search-specific.html.tmpl' => {
    ' selected' =>
      ' selected',
    '__${status.name}__' =>
      '__${status.name}__',
  },
  'welcome-admin.html.tmpl' => {
    'urlbase' =>
      'urlbase',
    'cookiepath' =>
      'cookiepath',
    'maintainer' =>
      'maintainer',
    'requirelogin' =>
      'requirelogin',
    'createemailregexp' =>
      'createemailregexp',
    'mail_delivery_method' =>
      'mail_delivery_method',
  },
  'whine/mail.html.tmpl' => {
    '<a([^>]*)href="([a-z_]+)\\.cgi' =>
      '<a([^>]*)href="([a-z_]+)\\.cgi',
    '<a$1href="' =>
      '<a$1href="',
    '$2.cgi' =>
      '$2.cgi',
    '-total-' =>
      '-total-',
  },
  'whine/multipart-mime.txt.tmpl' => {
    'From:' =>
      'From:',
    'To:' =>
      'To:',
    'Subject: [$terms.Bugzilla]' =>
      'Subject: [$terms.Bugzilla]',
    'MIME-Version: 1.0 Content-Type: multipart/alternative; boundary="' =>
      'MIME-Version: 1.0 Content-Type: multipart/alternative; boundary="',
    '" X-Bugzilla-Type: whine' =>
      '" X-Bugzilla-Type: whine',
    'Content-type:' =>
      'Content-type:',
  },
  'whine/schedule.html.tmpl' => {
    'event_${event.key}_body' =>
      'event_${event.key}_body',
  },
  'worktime/todaybugs.html.tmpl' => {
    ' selected="selected"' =>
      ' selected="selected"',
  },
  'worktime/supertime.html.tmpl' => {
    '(YYYY-MM-DD HH:MM:SS)' =>
      '(YYYY-MM-DD HH:MM:SS)',
  },
  'extensions/custishacks/email/newchangedmail.txt.tmpl' => {
    'СМ-ОК' =>
      'СМ-ОК',
    'СМ-RMS' =>
      'СМ-RMS',
    'СМ-View' =>
      'СМ-View',
    'СМ-МРТ' =>
      'СМ-МРТ',
    'СМ-Опт' =>
      'СМ-Опт',
    'Re: ' =>
      'Re: ',
    '[BLOCKER] ' =>
      '[BLOCKER] ',
    '[CRITICAL] ' =>
      '[CRITICAL] ',
    'Subject: .*' =>
      'Subject: .*',
    'Subject: ' =>
      'Subject: ',
  },
  'extensions/custishacks/hook/admin/fieldvalues/edit-fields.html.tmpl' => {
    'checked="checked"' =>
      'checked="checked"',
  },
};
