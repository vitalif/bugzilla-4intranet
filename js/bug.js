/* JS functions used on bug edit page
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

window.checkCommentOnUnload = true;

function updateCommentPrivacy(checkbox, id)
{
    var comment_elem = document.getElementById('comment_text_'+id).parentNode;
    var fn = checkbox.checked ? addClass : removeClass;
    fn(comment_elem, 'bz_private');
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
    link.innerHTML = show ? "[-]" : "[+]";
    link.title = L(show ? "Collapse the comment." : "Expand the comment.");
    if (show)
        removeClass(comment, 'collapsed');
    else
        addClass(comment, 'collapsed');
}

function showhide_comment_preview(comment_id)
{
    var link = document.getElementById('comment-preview-link-' + comment_id);
    var preview = document.getElementById('comment-preview-' + comment_id);
    var body = document.getElementById('comment-body-' + comment_id);
    var show = link.className.match(new RegExp(/\bshown\b/))
    if (show)
    {
        preview.style.display = 'block';
        body.style.display = 'none';
        removeClass(link, "shown");
    }
    else
    {
        preview.style.display = 'none';
        body.style.display = 'block';
        addClass(link, "shown");
    }
    link.innerHTML = L(!show ? "Hide full text" : "Show full text");
    return false;
}

function edit_wtonly(l, id)
{
    l.style.display = 'none';
    var e = document.getElementById('wtonly_' + id);
    e.name = e.id;
    e.style.display = '';
    e.focus();
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
        '); return false;" title="'+L(c ? 'Collapse the comment.' : 'Expand the comment.')+'">['+
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
            num + ', ' + id + '); return false;">'+L('reply')+'<' + '/a>';
    }
    s += ', clone to <a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;cloned_comment='+num+'">'+L('other')+'</a>';
    s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURIComponent(bug_info.product)+'&amp;cloned_comment='+num+'">'+L('same')+'</a>';
    // 4Intranet Bug 69514 - Clone to external product button
    if (bug_info.extprod)
        s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURIComponent(bug_info.extprod)+'&amp;cloned_comment='+num+'">'+L('ext')+'</a>';
    else if (bug_info.intprod)
        s += '/<a href="enter_bug.cgi?cloned_bug_id='+bug_info.id+'&amp;product='+encodeURIComponent(bug_info.intprod)+'&amp;cloned_comment='+num+'">'+L('int')+'</a>';
    s += L(' product')+']';
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
function getText(element)
{
    var child, text = "", prev, ct;
    for (var i = 0; i < element.childNodes.length; i++)
    {
        child = element.childNodes[i];
        var type = child.nodeType;
        if (type == Node.TEXT_NODE || type == Node.ENTITY_REFERENCE_NODE)
        {
            text += child.nodeValue;
        }
        else if (child.nodeName == 'BR')
        {
            text += "\n";
        }
        else
        {
            /* recurse into nodes of other types */
            if (child.nodeName == 'P')
            {
                text += "\n";
            }
            ct = getText(child);
            if (child.className == 'quote')
            {
                ct = ct.replace(/^/mg, '> ');
            }
            text += ct;
            if (child.nodeName == 'P')
            {
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
    var prefix = "(In reply to comment #"+num+")\n";
    var replytext = "";
    if (user_settings.quote_replies == 'quoted_reply')
    {
        /* pre id="comment_name_N" */
        var text_elem = document.getElementById('comment-body-'+id);
        if (!text_elem)
        {
            text_elem = document.getElementById('comment_text_'+id);
        }
        var text = getText(text_elem);

        /* make sure we split on all newlines -- IE or Moz use \r and \n
         * respectively.
         */
        text = text.replace(/^\s*\n/, '')
        text = text.replace(/\s*$/, '')
        text = text.replace(/(Created attachment.*?\[details\])\s*?\[Online-view\]/, '$1');
        text = text.split(/\r|\n/);

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
                replytext += "> "+L("(table removed)")+"\n";
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
    if (check_new_keywords(document.changeform) == false)
        return false;

    var wtInput = document.changeform.work_time;
    if (!wtInput)
    {
        window.checkCommentOnUnload = false;
        return true;
    }
    var wt = bzParseTime(wtInput.value);
    var awt = wt;
    if (wt != wt)
        awt = 0;
    else if (user_settings.wants_worktime_reminder &&
        (wt === null || wt === undefined || wt != wt ||
        notimetracking && wt != 0 || !notimetracking && wt == 0))
    {
        awt = prompt(L("Please, verify working time:"), !wt || wt != wt ? "0" : wt);
        if (awt === null || awt === undefined || (""+awt).length <= 0)
        {
            wtInput.focus();
            return false;
        }
    }

    wtInput.value = awt;
    adjustRemainingTime();
    window.checkCommentOnUnload = false;
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
function search_filter_click(e)
{
    var field_name = this.attributes.id.nodeValue.substr(12);
    var el = document.getElementById(field_name);
    var field_current_value = el.value;
    if (field_current_value == '')
    {
        field_current_value = '---';
    }
    var href_parts = this.attributes.href.nodeValue.split('&' + field_name + '=');
    var new_href = href_parts[0] + '&' + field_name + '=' + field_current_value;
    this.href = new_href;
}

onDomReady(function()
{
    if (document.getElementById('form_bug_edit'))
    {
        var testCl = new RegExp("\\bsearch-link\\b");
        var form = document.getElementById('form_bug_edit');
        var all = form.getElementsByTagName ? form.getElementsByTagName('a') : form.all;
        var length = all.length;
        for (var i = 0; i < length; i++)
        {
            if (testCl.test(all[i].className))
            {
                addListener(all[i], 'click', search_filter_click);
            }
        }
    }
});

addListener(window, 'beforeunload', function(e)
{
    var ta = document.getElementById('comment_textarea');
    if (window.checkCommentOnUnload && ta && ta.value.trim() != '')
    {
        e = e || window.event;
        return (e.returnValue = L('Your comment will be lost. Leave page?'));
    }
});

(function()
{
    var lastSel;
    var selectComment = function()
    {
        var a = document.getElementsByName(window.location.hash.substr(1));
        if (a.length)
        {
            a = a[0];
            while (a && !/bz_comment($|\s)/.exec(a.className))
            {
                a = a.parentNode;
            }
            if (a)
            {
                if (lastSel)
                {
                    removeClass(lastSel, 'bz_comment_selected');
                }
                addClass(a, 'bz_comment_selected');
                lastSel = a;
            }
        }
    };
    onDomReady(selectComment);
    addListener(window, 'hashchange', selectComment);
})();

function showEditComment(comment_id)
{
    var el = document.getElementById('comment_text_' + comment_id);
    var parent = el.parentNode;

    var textarea = document.getElementById('edit_comment_' + comment_id);
    if (textarea !== null)
    {
        return false;
    }

    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=Bug.comments&output=json&comment_ids=' + comment_id;
    AjaxLoader(u, function(x)
    {
        var r = {};
        try { eval('r = '+x.responseText+';'); } catch (e) { return; }
        if (r.status == 'ok')
        {
            if (r.comments)
            {
                for (var key in r.comments)
                {
                    var comment = r.comments[key];
                    var textarea = document.createElement('textarea');
                    textarea.className = 'bz_textarea';
                    textarea.id = 'edit_comment_' + comment_id;
                    textarea.name = 'edit_comment[' + comment_id + ']';
                    textarea.innerHTML = comment.rawtext;
                    parent.appendChild(textarea);
                    var but_wrapper = document.createElement('div');
                    but_wrapper.className = 'edit_comment_submit';
                    var submit_but = document.createElement('input');
                    submit_but.type = 'submit';
                    submit_but.value = L('Save All Changes');
                    but_wrapper.appendChild(submit_but);
                    parent.appendChild(but_wrapper);
                    showhide_comment(key, false);
                    textarea.focus();
                }
            }
        }
    });
}

function toggle_obsolete_attachments(link)
{
    var table = document.getElementById("attachment_table");
    // Store current height for scrolling later
    var originalHeight = table.offsetHeight;

    var r0;
    var rs = table.tBodies[0];
    rs = rs.rows || rs.tRows;
    for (var i = 0; i < rs.length; i++)
        if (hasClass(rs[i], 'bz_tr_obsolete'))
            r0 = toggleClass(rs[i], 'bz_default_hidden');
    link.innerHTML = r0 ? L('Show Obsolete') : L('Hide Obsolete');

    var newHeight = table.offsetHeight;
    // This scrolling makes the window appear to not move at all.
    window.scrollBy(0, newHeight - originalHeight);

    return false;
}

function to_attachment_page(link)
{
    window.checkCommentOnUnload = false;
    var form = document.createElement('form');
    form.action = link.href;
    form.method = 'post';
    var e = document.createElement('input');
    e.type = 'hidden';
    e.name = 'comment';
    e.value = document.getElementById('comment_textarea').value;
    form.appendChild(e);
    var w = document.getElementById('work_time');
    if (w)
    {
        e = document.createElement('input');
        e.type = 'hidden';
        e.name = 'work_time';
        e.value = w.value;
        form.appendChild(e);
    }
    document.body.appendChild(form);
    form.submit();
    return false;
}
