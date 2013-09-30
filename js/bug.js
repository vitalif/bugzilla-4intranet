/* JS functions used on bug edit page
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

function updateCommentPrivacy(checkbox, id)
{
    var comment_elem = document.getElementById('comment_text_'+id).parentNode;
    if (checkbox.checked)
    {
        if (!comment_elem.className.match('bz_private'))
            comment_elem.className = comment_elem.className.concat(' bz_private');
    }
    else
        comment_elem.className =
            comment_elem.className.replace(/(\s*|^)bz_private(\s*|$)/, '$2');
}

/* The functions below expand and collapse comments  */

function toggle_comment_display(comment_id)
{
    var comment = document.getElementById('comment_text_' + comment_id);
    var re = new RegExp(/\bcollapsed\b/);
    showhide_comment(comment_id, comment.className.match(re));
}

function toggle_all_comments(action, num_comments)
{
    var parent = document.getElementById('comments');
    var pre = parent.getElementsByTagName('div');
    for (var i = 0; i < pre.length; i++)
        if (pre[i].id.substr(0, 13) == 'comment_text_')
            showhide_comment(pre[i].id.substr(13), action != 'collapse');
}

function showhide_comment(comment_id, show)
{
    var link = document.getElementById('comment_link_' + comment_id);
    var comment = document.getElementById('comment_text_' + comment_id);
    var unmark = document.getElementById('unmark_wtonly_' + comment_id);
    link.innerHTML = show ? "[-]" : "[+]";
    link.title = (show ? "Collapse" : "Expand")+" the comment.";
    if (unmark)
        unmark.style.display = show ? '' : 'none';
    if (show)
        removeClass(comment, 'collapsed');
    else
        addClass(comment, 'collapsed');
}

// Mark comment as worktime-only or normal
function toggle_wtonly(id, initial_wtonly, img)
{
    var f = document.getElementById((initial_wtonly ? 'cmt_normal_' : 'cmt_worktime_') + id);
    var mark = f.value == '1';
    f.value = mark ? '' : '1';
    mark = initial_wtonly ? mark : !mark;
    img.src = 'images/clock' + (mark ? '' : 'x') + '.gif';
    img.alt = mark ?
        'Comment is marked worktime-only. Click to mark it as normal, then click Save Changes' :
        'Comment is marked as normal. Click to mark it as worktime-only, then click Save Changes';
    img.title = img.alt;
}

// This way, we are sure that browsers which do not support JS
// won't display this link
function addCollapseLink(id)
{
    var e = document.getElementById('comment_act_'+id);
    if (!e)
        return;
    var t = document.getElementById('comment_text_'+id);
    var c = !hasClass(t, 'collapsed');
    e.innerHTML +=
        ' <a href="#" class="bz_collapse_comment"'+
        ' id="comment_link_' + id +
        '" onclick="toggle_comment_display(' + id +
        '); return false;" title="'+(c ? 'Collapse' : 'Expand')+' the comment.">['+
        (c ? '-' : '+')+']<\/a> ';
}

// Outputs a link to call replyToComment(); used to reduce HTML output
function addReplyLink(num, id)
{
    var e = document.getElementById('comment_act_'+id);
    if (!e)
        return;
    var s = '[';
    if (user_settings.quote_replies != 'off')
    {
        s += '<a href="#add_comment" onclick="replyToComment(' +
            num + ', ' + id + '); return false;">reply<' + '/a>';
    }
    s += ', clone to <a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;cloned_comment='+num+'">other</a>';
    s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.product)+'&amp;cloned_comment='+num+'">same</a>';
    // 4Intranet Bug 69514 - Clone to external product button
    if (bug_info.extprod)
        s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.extprod)+'&amp;cloned_comment='+num+'">ext</a>';
    else if (bug_info.intprod)
        s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURI(bug_info.intprod)+'&amp;cloned_comment='+num+'">int</a>';
    s += ' product]';
    e.innerHTML += s;
}

/* indexes = [ [ number, id, add_reply ], ... ] for each comment
   generated by show_bug.cgi/comment_indexes */
function addActionLinks(indexes)
{
    for (var i in indexes)
    {
        if (indexes[i][2])
            addReplyLink(indexes[i][0], indexes[i][1]);
        addCollapseLink(indexes[i][1]);
    }
}

/**
 * Concatenates all text from element's childNodes, honoring citations.
 * This is used instead of innerHTML because we want the actual text (and
 * innerText is non-standard).
 */
function getText(element) {
    var child, text = "", prev, ct;
    for (var i = 0; i < element.childNodes.length; i++) {
        child = element.childNodes[i];
        var type = child.nodeType;
        if (type == Node.TEXT_NODE || type == Node.ENTITY_REFERENCE_NODE) {
            text += child.nodeValue;
        } else if (child.nodeName == 'BR') {
            text += "\n";
        } else {
            /* recurse into nodes of other types */
            if (child.nodeName == 'P') {
                text += "\n";
            }
            ct = getText(child);
            if (child.className == 'quote') {
                ct = ct.replace(/^/mg, '> ');
            }
            text += ct;
            if (child.nodeName == 'P') {
                text += "\n";
            }
        }
        prev = child;
    }
    text = text.replace(/^\n+|\n+$/g, '');
    return text;
}

/* Adds the reply text to the `comment' textarea */
function replyToComment(num, id)
{
    var prefix = "(In reply to comment #" + num + ")\n";
    var replytext = "";
    if (user_settings.quote_replies == 'quoted_reply')
    {
        /* pre id="comment_name_N" */
        var text_elem = document.getElementById('comment_text_'+id);
        var text = getText(text_elem);

        /* make sure we split on all newlines -- IE or Moz use \r and \n
         * respectively.
         */
        text = text.replace(/\s*$/, '').split(/\r|\n/);

        var prev_ist = false, ist = false;
        for (var i = 0; i < text.length; i++)
        {
            // 4Intranet Bug 55876 - ASCII pseudographic tables
            ist = text[i].match('^(┌|│|└).*(┐|│|┘)$') ? true : false;
            if (!ist)
            {
                replytext += "> ";
                replytext += text[i];
                replytext += "\n";
            }
            else if (!prev_ist)
                replytext += "> (table removed)\n";
            prev_ist = ist;
        }

        replytext = prefix + replytext + "\n";
    }
    else if (user_settings.quote_replies == 'simple_reply')
        replytext = prefix;

    if (user_settings.is_insider && id && document.getElementById('isprivate_' + id).checked)
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

function updateRemainingTime()
{
    // if the remaining time is changed manually, update fRemainingTime
    fRemainingTime = bzParseTime(document.changeform.remaining_time.value);
}

function changeform_onsubmit()
{
    if (check_new_keywords(document.changeform) == false) return false;

    var wtInput = document.changeform.work_time;
    if (!wtInput)
        return true;
    var wt = bzParseTime(wtInput.value);
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
            wtInput.focus();
            return false;
        }
    }

    wtInput.value = awt;
    adjustRemainingTime();
    return true;
}

// This function clears a row from multi-attachment upload form
function att_file_clear(e)
{
    e = document.getElementById(e);
    var ci = e.id.substr(5);
    e.parentNode.innerHTML = e.parentNode.innerHTML;
    document.getElementById('del_'+ci).style.display = 'none';
    document.getElementById('description_'+ci).value = '';
    document.getElementById('contenttypeselection_'+ci).selectedIndex = 0;
}

// 4Intranet Bug 68919 - Mass attachment upload
// This function handles change events of upload inputs on multi-attachment upload form
function att_file_onchange(e)
{
    var ci = e.id.substr(5);
    document.getElementById('del_'+ci).style.display = e.value ? '' : 'none';
    if (e.value)
    {
        // Fill description from file name if it wasn't changed by user
        var e1 = document.getElementById('description_'+ci);
        if (!e1._changed)
        {
            var p = e.value;
            var slash = p.lastIndexOf('/');
            var backslash = p.lastIndexOf('\\');
            var fname;
            if (slash == -1 && backslash == -1)
                fname = p;
            else if (slash > backslash)
                fname = p.substr(slash+1);
            else
                fname = p.substr(backslash+1);
            e1.value = fname;
        }
        // Add a new empty field if there are no empty fields
        var i = 0;
        var f;
        while (f = document.getElementById('data_'+i))
        {
            if (!f.value)
            {
                i = -1;
                break;
            }
            i++;
        }
        if (i > 0)
        {
            // Copy innerHTML of fileX
            // IE does not like setting innerHTML of regular elements, so create
            // a div with table and then copy its row
            var tmp = document.createElement('div');
            tmp.innerHTML =
                '<table id="file'+i+'table"><tbody><tr id="file'+i+'">'+
                document.getElementById('fileX').innerHTML.replace(/_XXX/g, '_'+i)+
                '</tr></tbody></table>';
            // div.table.tbody.tr
            document.getElementById('files').appendChild(tmp.childNodes[0].childNodes[0].childNodes[0]);
        }
    }
}

// Bug 129375 - Use search filter for all values in fields
function search_filter_click(e, el)
{
    var attr = el.attributes;
    var href = attr.href.nodeValue;
    var field_id = attr.id.nodeValue;
    var field_name = field_id.substr(12);
    var field_current_value = document.getElementById(field_name).value;
    if (field_current_value == '')
    {
        alert('Field must be filled!');
        if (preventDefault && e.preventDefault)
        {
            e.preventDefault();
        }
        else
        {
            return false;
        }
    }
    var href_parts = href.split('&' + field_name + '=');
    var new_href = href_parts[0] + '&' + field_name + '=' + field_current_value;
    el.href = new_href;
}

addListener(window, 'load', function() {
    if (document.getElementById('form_bug_edit'))
    {
        var testCl = new RegExp("\\bsearch-link\\b");
        var form = document.getElementById('form_bug_edit');
        var all = form.getElementsByTagName ? form.getElementsByTagName('a') : form.all;
        var length = all.length;
        for (var i = 0; i < length; i++) {
            if (testCl.test(all[i].className)) {
                (function(i) { 
                    addListener(i, 'click', function (e) { 
                        return search_filter_click(e, i); 
                    }); 
                })(all[i]);
            }
        }
    }
});

function showEditComment(comment_id) {
    var el_container = document.getElementById("bz_textarea_"+comment_id);

    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=Bug.comments&output=json&comment_ids=' + comment_id;
    AjaxLoader(u, function(x) {
        var r = {};
        try { eval('r = '+x.responseText+';'); } catch (e) { return; }
        if (r.status == 'ok')
        {
            if (r.comments)
            {
                for(var key in r.comments)
                {
                    var comment = r.comments[key];
                    el_container.innerHTML = '<textarea class="bz_textarea" name="edit_comment[' + comment_id + ']"> ' + comment.text + '</textarea>';
                }
            }
        }
    });
}

