# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code are the Bugzilla tests.
#
# The Initial Developer of the Original Code is Jacob Steenhagen.
# Portions created by Jacob Steenhagen are
# Copyright (C) 2001 Jacob Steenhagen. All
# Rights Reserved.
#
# Contributor(s): Gervase Markham <gerv@gerv.net>

# Important! The following classes of directives are excluded in the test,
# and so do not need to be added here. Doing so will cause warnings.
# See 008filter.t for more details.
#
# Comments                        - [%#...
# Directives                      - [% IF|ELSE|UNLESS|FOREACH...
# Assignments                     - [% foo = ...
# Simple literals                 - [% " selected" ...
# Values always used for numbers  - [% (i|j|k|n|count) %]
# Params                          - [% Param(...
# Safe functions                  - [% (time2str)...
# Safe vmethods                   - [% foo.size %] [% foo.length %]
#                                   [% foo.push() %]
# TT loop variables               - [% loop.count %]
# Already-filtered stuff          - [% wibble FILTER html %]
#   where the filter is one of html|csv|js|url_quote|quoteUrls|time|uri|xml|none

%::safe = (

'whine/schedule.html.tmpl' => [
  'event.key',
  'query.sort',
  'option.0',
  'option.1',
],

'flag/list.html.tmpl' => [
  'flag.status',
],

'search/boolean-charts.html.tmpl' => [
  'C',
  'I',
  'J',
],

'search/form.html.tmpl' => [
  'qv.name',
  'qv.description',
  'field.name',
  'field.description',
  'field.accesskey',
  'sel.name',
],

'search/search-specific.html.tmpl' => [
  'status.name',
],

'search/tabs.html.tmpl' => [
  'content',
],

'request/queue.html.tmpl' => [
  'column_headers.$group_field',
  'column_headers.$column',
  'request.status',
  'request.attach_id',
],

'reports/keywords.html.tmpl' => [
  'keyword.bug_count',
],

'reports/report-table.csv.tmpl' => [
  'data.$tbl.$col.$row',
  'colsepchar',
],

'reports/report-table.html.tmpl' => [
  '"&amp;$tbl_vals" IF tbl_vals',
  '"&amp;$col_vals" IF col_vals',
  '"&amp;$row_vals" IF row_vals',
  'classes.$row_idx.$col_idx',
  'urlbase',
  'data.$tbl.$col.$row',
  'row_total',
  'col_totals.$col',
  'grand_total',
],

'reports/report.html.tmpl' => [
  'width',
  'height',
  'imageurl',
  'formaturl',
  'other_format.name',
  'sizeurl',
  'switchbase',
  'format',
  'cumulate',
],

'reports/chart.html.tmpl' => [
  'width',
  'height',
  'imageurl',
  'sizeurl',
  'height + 100',
  'height - 100',
  'width + 100',
  'width - 100',
],

'reports/series-common.html.tmpl' => [
  'sel.name',
  '"onchange=\"$sel.onchange\"" IF sel.onchange',
],

'reports/chart.csv.tmpl' => [
  'data.$j.$i',
  'colsepchar',
],

'reports/create-chart.html.tmpl' => [
  'series.series_id',
  'newidx',
],

'reports/edit-series.html.tmpl' => [
  'default.series_id',
],

'list/list.rdf.tmpl' => [
  'template_version',
  'column',
],

'list/table.html.tmpl' => [
  'tableheader',
  'abbrev.$id.title || field_descs.$id || column.title',
],

'list/list.csv.tmpl' => [
  'colsepchar',
],

'global/choose-product.html.tmpl' => [
  'target',
],

# You are not permitted to add any values here. Everything in this file should
# be filtered unless there's an extremely good reason why not, in which case,
# use the "none" dummy filter.
'global/code-error.html.tmpl' => [
],

'global/header.html.tmpl' => [
  'javascript',
  'style',
  'onload',
  'title',
  '" &ndash; $header" IF header',
  'subheader',
  'header_addl_info',
  'message',
],

'global/messages.html.tmpl' => [
  'message_tag',
  'series.frequency * 2',
],

'global/tabs.html.tmpl' => [
  'content',
],

# You are not permitted to add any values here. Everything in this file should
# be filtered unless there's an extremely good reason why not, in which case,
# use the "none" dummy filter.
'global/user-error.html.tmpl' => [
],

'global/confirm-user-match.html.tmpl' => [
  'script',
  'fields.${field_name}.flag_type.name',
],

'global/site-navigation.html.tmpl' => [
  'bug.votes',
],

'bug/dependency-graph.html.tmpl' => [
  'image_map', # We need to continue to make sure this is safe in the CGI
  'image_url',
  'map_url',
  'bug_id',
],

'bug/dependency-tree.html.tmpl' => [
  'bugid',
  'maxdepth',
  'hide_resolved',
  'ids.join(",")',
  'maxdepth + 1',
  'maxdepth > 0 && maxdepth <= realdepth ? maxdepth : ""',
  'maxdepth == 1 ? 1
                       : ( maxdepth ? maxdepth - 1 : realdepth - 1 )',
],

'bug/edit.html.tmpl' => [
  'bug.deadline',
  'bug.remaining_time',
  'bug.delta_ts',
  'bug.votes',
  'group.bit',
  'dep.title',
  'dep.fieldname',
  'bug.${dep.fieldname}.join(\', \')',
  'selname',
  '" accesskey=\"$accesskey\"" IF accesskey',
  'inputname',
  '" colspan=\"$colspan\"" IF colspan',
  '" size=\"$size\"" IF size',
  '" maxlength=\"$maxlength\"" IF maxlength',
  '" spellcheck=\"$spellcheck\"" IF spellcheck',
],

'bug/show-multiple.html.tmpl' => [
  'flag.status',
],

'bug/show.xml.tmpl' => [
  'field',
],

'bug/summarize-time.html.tmpl' => [
  'global.grand_total FILTER format("%.2f")',
  'subtotal FILTER format("%.2f")',
  'work_time FILTER format("%.2f")',
  'global.total FILTER format("%.2f")',
  'global.remaining FILTER format("%.2f")',
  'global.estimated FILTER format("%.2f")',
  'bugs.$id.remaining_time FILTER format("%.2f")',
  'bugs.$id.estimated_time FILTER format("%.2f")',
],


'bug/time.html.tmpl' => [
  'time_unit FILTER format(\'%.1f\')',
  'time_unit FILTER format(\'%.2f\')',
],

'bug/votes/list-for-bug.html.tmpl' => [
  'voter.vote_count',
  'total',
],

'bug/votes/list-for-user.html.tmpl' => [
  'product.maxperbug',
  'bug.count',
  'product.total',
  'product.maxvotes',
],

'bug/process/results.html.tmpl' => [
  'title.$type',
  '"$terms.Bug $id" FILTER bug_link(id)',
  '"$terms.bug $id" FILTER bug_link(id)',
],

'bug/create/create.html.tmpl' => [
  'g.bit',
  'sel.name',
  'sel.description',
  'cloned_bug_id',
],

'bug/create/create-guided.html.tmpl' => [
  'tablecolour',
  'sel',
  'productstring',
],

'bug/activity/table.html.tmpl' => [
  'change.attachid',
],

'attachment/edit.html.tmpl' => [
  'a',
  'editable_or_hide',
],

'attachment/list.html.tmpl' => [
  'flag.status',
  'bugid',
  'obsolete_attachments',
],

'attachment/show-multiple.html.tmpl' => [
  'flag.status'
],

'attachment/diff-header.html.tmpl' => [
  'attachid',
  'id',
  'bugid',
  'oldid',
  'newid',
],

'attachment/diff-file.html.tmpl' => [
  'lxr_prefix',
  'file.minus_lines',
  'file.plus_lines',
  'bonsai_prefix',
  'section.old_start',
  'section_num',
  'current_line_old',
  'current_line_new',
],

'admin/admin.html.tmpl' => [
  'class'
],

'admin/table.html.tmpl' => [
  'link_uri'
],

'admin/params/common.html.tmpl' => [
  'sortlist_separator',
],

'admin/products/groupcontrol/confirm-edit.html.tmpl' => [
  'group.count',
],

'admin/products/list.html.tmpl' => [
  'classification_url_part',
],

'admin/products/footer.html.tmpl' => [
  'classification_url_part',
  'classification_text',
],

'admin/flag-type/confirm-delete.html.tmpl' => [
  'flag_type.flag_count',
],

'admin/flag-type/edit.html.tmpl' => [
  'action',
  'type.target_type',
  'type.sortkey || 1',
  'typeLabelLowerPlural',
  'typeLabelLowerSingular',
  'selname',
],

'admin/components/confirm-delete.html.tmpl' => [
  'comp.bug_count'
],

'admin/groups/delete.html.tmpl' => [
  'shared_queries'
],

'admin/users/confirm-delete.html.tmpl' => [
  'attachments',
  'reporter',
  'assignee_or_qa',
  'cc',
  'component_cc',
  'flags.requestee',
  'flags.setter',
  'longdescs',
  'quips',
  'votes',
  'series',
  'watch.watched',
  'watch.watcher',
  'whine_events',
  'whine_schedules',
],

'admin/components/edit.html.tmpl' => [
  'comp.bug_count'
],

'account/auth/login-small.html.tmpl' => [
  'qs_suffix',
],

'account/prefs/email.html.tmpl' => [
  'prefname',
],

'account/prefs/prefs.html.tmpl' => [
  'current_tab.label',
  'current_tab.name',
],

'config.rdf.tmpl' => [
  'escaped_urlbase',
],

);
