function updateCommentPrivacy(checkbox, id) {
  var comment_elem = document.getElementById('comment_text_'+id).parentNode;
  if (checkbox.checked) {
    if (!comment_elem.className.match('bz_private')) {
      comment_elem.className = comment_elem.className.concat(' bz_private');
    }
  }
  else {
    comment_elem.className =
      comment_elem.className.replace(/(\s*|^)bz_private(\s*|$)/, '$2');
  }
}

/* The functions below expand and collapse comments  */

function toggle_comment_display(link, comment_id) {
  var comment = document.getElementById('comment_text_' + comment_id);
  var re = new RegExp(/\bcollapsed\b/);
  if (comment.className.match(re))
    expand_comment(link, comment);
  else
    collapse_comment(link, comment);
}

function toggle_all_comments(action, num_comments) {
  // If for some given ID the comment doesn't exist, this doesn't mean
  // there are no more comments, but that the comment is private and
  // the user is not allowed to view it.

  for (var id = 0; id < num_comments; id++) {
    var comment = document.getElementById('comment_text_' + id);
    if (!comment)
      continue;

    var link = document.getElementById('comment_link_' + id);
    if (action == 'collapse')
      collapse_comment(link, comment);
    else
      expand_comment(link, comment);
  }
}

function collapse_comment(link, comment) {
  link.innerHTML = "[+]";
  link.title = "Expand the comment.";
  YAHOO.util.Dom.addClass(comment, 'collapsed');
}

function expand_comment(link, comment) {
  link.innerHTML = "[-]";
  link.title = "Collapse the comment";
  YAHOO.util.Dom.removeClass(comment, 'collapsed');
}

/* This way, we are sure that browsers which do not support JS
 * won't display this link */

function addCollapseLink(count) {
  var e = document.getElementById('comment_act_'+count);
  if (!e)
    return;
  e.innerHTML +=
    ' <a href="#" class="bz_collapse_comment"' +
    ' id="comment_link_' + count +
    '" onclick="toggle_comment_display(this, ' + count +
    '); return false;" title="Collapse the comment.">[-]<\/a> ';
}

/* Outputs a link to call replyToComment(); used to reduce HTML output */

function addReplyLink(id, real_id) {
  var e = document.getElementById('comment_act_'+id);
  if (!e)
    return;
  var s = '[';
  if (user_settings.quote_replies != 'off')
  {
    s += '<a href="#add_comment" onclick="replyToComment(' +
      id + ',' + real_id + '); return false;">reply<' + '/a>';
  }
  s += ', clone to <a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;cloned_comment='+id+'">other</a>';
  s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.product)+'&amp;cloned_comment='+id+'">same</a>';
  /* CustIS Bug 69514 */
  if (bug_info.extprod)
    s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.extprod)+'&amp;cloned_comment='+id+'">ext</a>';
  else if (bug_info.intprod)
    s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.intprod)+'&amp;cloned_comment='+id+'">int</a>';
  s += ' product]';
  e.innerHTML += s;
}

function addActionLinks(indexes)
{
  for (var i in indexes)
  {
    addReplyLink(indexes[i][0], indexes[i][1]);
    addCollapseLink(indexes[i][0]);
  }
}

/* Adds the reply text to the `comment' textarea */
function replyToComment(id, real_id)
{
  var prefix = "(In reply to comment #" + id + ")\n";
  var replytext = "";
  if (user_settings.quote_replies == 'quoted_reply')
  {
    /* pre id="comment_name_N" */
    var text_elem = document.getElementById('comment_text_'+id);
    var text = getText(text_elem);

    /* make sure we split on all newlines -- IE or Moz use \r and \n
     * respectively.
     */
    text = text.split(/\r|\n/);

    var prev_ist = false, ist = false;
    for (var i = 0; i < text.length; i++)
    {
      /* CustIS Bug 55876 - ASCII pseudographic tables */
      ist = text[i].match('^(┌|│|└).*(┐|│|┘)$') ? true : false;
      if (!ist)
      {
        replytext += "> ";
        replytext += text[i];
        replytext += "\n"; 
      }
      else if (!prev_ist)
        replytext += "> (table cut off)\n";
      prev_ist = ist;
    }

    replytext = prefix + replytext + "\n";
  }
  else if (user_settings.quote_replies == 'simple_reply')
    replytext = prefix;

  if (user_settings.is_insider && document.getElementById('isprivate_' + real_id).checked)
    document.getElementById('newcommentprivacy').checked = 'checked';

  var textarea = document.getElementById('comment_textarea');
  textarea.value += replytext;

  textarea.focus();
}

function adjustRemainingTime()
{
  // subtracts time spent from remaining time
  var new_time;
  var wt = bzParseTime(document.changeform.work_time.value);
  if (wt === null || wt === undefined || wt != wt)
  {
    document.changeform.work_time.style.backgroundColor = '#FFC0C0';
    document.changeform.remaining_time.style.backgroundColor = '#FFC0C0';
    wt = 0;
  }
  else
  {
    document.changeform.work_time.style.backgroundColor = null;
    document.changeform.remaining_time.style.backgroundColor = null;
  }
  if (notimetracking)
    document.changeform.work_time.parentNode.style.backgroundColor = wt != 0 ? '#FFC0C0' : null;

  // prevent negative values if work_time > fRemainingTime
  new_time = Math.max(fRemainingTime - wt, 0.0);
  // get upto 2 decimal places
  document.changeform.remaining_time.value =
    Math.round(new_time * 100)/100;
}

function updateRemainingTime() {
  // if the remaining time is changed manually, update fRemainingTime
  fRemainingTime = bzParseTime(document.changeform.remaining_time.value);
}

function changeform_onsubmit()
{
  var wt = bzParseTime(document.changeform.work_time.value);
  var awt = wt;
  if (wt != wt)
    awt = 0;
  else if (user_settings.wants_worktime_reminder &&
    (wt === null || wt === undefined || wt != wt ||
    notimetracking && wt != 0 || !notimetracking && wt == 0))
  {
    awt = prompt("Please, verify working time:", !wt || wt != wt ? "0" : wt);
    if (awt === null || awt === undefined || (""+awt).length <= 0)
    {
      document.changeform.work_time.focus();
      return false;
    }
  }
  document.changeform.work_time.value = awt;
  adjustRemainingTime();
  return true;
}
