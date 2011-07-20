/* The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is the Bugzilla Bug Tracking System.
 *
 * The Initial Developer of the Original Code is Netscape Communications
 * Corporation. Portions created by Netscape are
 * Copyright (C) 1998 Netscape Communications Corporation. All
 * Rights Reserved.
 *
 * Contributor(s): Myk Melez <myk@mozilla.org>
 *                 Joel Peshkin <bugreport@peshkin.net>
 *                 Erik Stambaugh <erik@dasbistro.com>
 *                 Marc Schumann <wurblzap@gmail.com>
 */

function switch_aft(n)
{
    var f = document.getElementById('form_type_file'+n);
    var u = document.getElementById('form_type_url'+n);
    var t = document.getElementById('form_type_text'+n);
    document.getElementById('tr_file'+n).style.display = f && f.checked ? '' : 'none';
    document.getElementById('tr_text'+n).style.display = t && t.checked ? '' : 'none';
    if (u)
        document.getElementById('tr_url'+n).style.display = u.checked ? '' : 'none';
}

function validateAttachmentForm(theform)
{
    var desc = theform.description.value.replace(/^\s+|\s+$/, '');
    if (desc == '')
    {
        alert(BUGZILLA.string.attach_desc_required);
        return false;
    }
    return true;
}

function updateCommentPrivacy(checkbox)
{
    var text_elem = document.getElementById('comment');
    if (checkbox.checked)
        text_elem.className = 'bz_private';
    else
        text_elem.className = '';
}

function URLFieldHandler()
{
    var field_attachurl = document.getElementById("attachurl");
    var greyfields = [
        "data", "ispatch", "autodetect",
        "list", "manual", "bigfile",
        "contenttypeselection",
        "contenttypeentry"
    ];
    var i, thisfield;
    if (field_attachurl.value.match(/^\s*$/)) {
        for (i = 0; i < greyfields.length; i++) {
            thisfield = document.getElementById(greyfields[i]);
            if (thisfield)
                thisfield.removeAttribute("disabled");
        }
    } else {
        for (i = 0; i < greyfields.length; i++) {
            thisfield = document.getElementById(greyfields[i]);
            if (thisfield)
                thisfield.setAttribute("disabled", "disabled");
        }
    }
}

function DataFieldHandler(AllowAttachUrl)
{
    var field_data = document.getElementById("data");
    var fd_empty = field_data.value.match(/^\s*$/);
    var field_description = document.getElementById("description");
    if (!field_description._changed && !fd_empty)
    {
        l = field_data.value.lastIndexOf('/')+1;
        lw = field_data.value.lastIndexOf('\\')+1;
        if (lw > l)
            l = lw;
        field_description.value = field_data.value.substr(l);
    }
    if (!AllowAttachUrl)
        return;
    var greyfields = new Array("attachurl");
    var i, thisfield;
    if (fd_empty) {
        for (i = 0; i < greyfields.length; i++) {
            thisfield = document.getElementById(greyfields[i]);
            if (thisfield)
                thisfield.removeAttribute("disabled");
        }
    } else {
        for (i = 0; i < greyfields.length; i++) {
            thisfield = document.getElementById(greyfields[i]);
            if (thisfield)
                thisfield.setAttribute("disabled", "disabled");
        }
    }
}

function clearAttachmentFields() {
    var element;

    document.getElementById('data').value = '';
    DataFieldHandler();
    if ((element = document.getElementById('bigfile')))
        element.checked = '';
    if ((element = document.getElementById('attachurl'))) {
        element.value = '';
        URLFieldHandler();
    }
    document.getElementById('description').value = '';
    /* Fire onchange so that the disabled state of the content-type
     * radio buttons are also reset 
     */
    element = document.getElementById('ispatch');
    element.checked = '';
    bz_fireEvent(element, 'change');
    if ((element = document.getElementById('isprivate')))
        element.checked = '';
}

/* Functions used when viewing patches in Diff mode. */

function collapse_all() {
    var elem = document.checkboxform.firstChild;
    while (elem != null) {
        if (elem.firstChild != null) {
            var tbody = elem.firstChild.nextSibling;
            if (tbody.className == 'file') {
                tbody.className = 'file_collapse';
                twisty = get_twisty_from_tbody(tbody);
                twisty.firstChild.nodeValue = '(+)';
                twisty.nextSibling.checked = false;
            }
        }
        elem = elem.nextSibling;
    }
    return false;
}

function expand_all() {
    var elem = document.checkboxform.firstChild;
    while (elem != null) {
        if (elem.firstChild != null) {
            var tbody = elem.firstChild.nextSibling;
            if (tbody.className == 'file_collapse') {
                tbody.className = 'file';
                twisty = get_twisty_from_tbody(tbody);
                twisty.firstChild.nodeValue = '(-)';
                twisty.nextSibling.checked = true;
            }
        }
        elem = elem.nextSibling;
    }
    return false;
}

var current_restore_elem;

function restore_all() {
    current_restore_elem = null;
    incremental_restore();
}

function incremental_restore() {
    if (!document.checkboxform.restore_indicator.checked) {
        return;
    }
    var next_restore_elem;
    if (current_restore_elem) {
        next_restore_elem = current_restore_elem.nextSibling;
    } else {
        next_restore_elem = document.checkboxform.firstChild;
    }
    while (next_restore_elem != null) {
        current_restore_elem = next_restore_elem;
        if (current_restore_elem.firstChild != null) {
            restore_elem(current_restore_elem.firstChild.nextSibling);
        }
        next_restore_elem = current_restore_elem.nextSibling;
    }
}

function restore_elem(elem, alertme) {
    if (elem.className == 'file_collapse') {
        twisty = get_twisty_from_tbody(elem);
        if (twisty.nextSibling.checked) {
            elem.className = 'file';
            twisty.firstChild.nodeValue = '(-)';
        }
    } else if (elem.className == 'file') {
        twisty = get_twisty_from_tbody(elem);
        if (!twisty.nextSibling.checked) {
            elem.className = 'file_collapse';
            twisty.firstChild.nodeValue = '(+)';
        }
    }
}

function twisty_click(twisty) {
    tbody = get_tbody_from_twisty(twisty);
    if (tbody.className == 'file') {
        tbody.className = 'file_collapse';
        twisty.firstChild.nodeValue = '(+)';
        twisty.nextSibling.checked = false;
    } else {
        tbody.className = 'file';
        twisty.firstChild.nodeValue = '(-)';
        twisty.nextSibling.checked = true;
    }
    return false;
}

function get_tbody_from_twisty(twisty) {
    return twisty.parentNode.parentNode.parentNode.nextSibling;
}
function get_twisty_from_tbody(tbody) {
    return tbody.previousSibling.firstChild.nextSibling.firstChild.firstChild;
}

var prev_mode = 'raw';
var current_mode = 'raw';
var has_edited = 0;
var has_viewed_as_diff = 0;
function editAsComment(patchviewerinstalled)
{
    switchToMode('edit', patchviewerinstalled);
    has_edited = 1;
}
function undoEditAsComment(patchviewerinstalled)
{
    switchToMode(prev_mode, patchviewerinstalled);
}
function redoEditAsComment(patchviewerinstalled)
{
    switchToMode('edit', patchviewerinstalled);
}

function viewDiff(attachment_id, patchviewerinstalled)
{
    switchToMode('diff', patchviewerinstalled);

    // If we have not viewed as diff before, set the view diff frame URL
    if (!has_viewed_as_diff) {
        var viewDiffFrame = document.getElementById('viewDiffFrame');
        viewDiffFrame.src =
                'attachment.cgi?id=' + attachment_id + '&action=diff&headers=0';
        has_viewed_as_diff = 1;
    }
}

function viewRaw(patchviewerinstalled)
{
    switchToMode('raw', patchviewerinstalled);
}

function switchToMode(mode, patchviewerinstalled)
{
    if (mode == current_mode)
    {
        alert('switched to same mode! This should not happen.');
        return;
    }

    // Switch out of current mode
    if (current_mode == 'edit') {
        hideElementById('editFrame');
        hideElementById('undoEditButton');
    } else if (current_mode == 'raw') {
        hideElementById('viewFrame');
        if (patchviewerinstalled)
                hideElementById('viewDiffButton');
        hideElementById(has_edited ? 'redoEditButton' : 'editButton');
        hideElementById('smallCommentFrame');
    } else if (current_mode == 'diff') {
        if (patchviewerinstalled)
                hideElementById('viewDiffFrame');
        hideElementById('viewRawButton');
        hideElementById(has_edited ? 'redoEditButton' : 'editButton');
        hideElementById('smallCommentFrame');
    }

    // Switch into new mode
    if (mode == 'edit') {
        showElementById('editFrame');
        showElementById('undoEditButton');
    } else if (mode == 'raw') {
        showElementById('viewFrame');
        if (patchviewerinstalled) 
                showElementById('viewDiffButton');

        showElementById(has_edited ? 'redoEditButton' : 'editButton');
        showElementById('smallCommentFrame');
    } else if (mode == 'diff') {
        if (patchviewerinstalled) 
            showElementById('viewDiffFrame');

        showElementById('viewRawButton');
        showElementById(has_edited ? 'redoEditButton' : 'editButton');
        showElementById('smallCommentFrame');
    }

    prev_mode = current_mode;
    current_mode = mode;
}

function hideElementById(id)
{
    var elm = document.getElementById(id);
    if (elm) {
        elm.style.display = 'none';
    }
}

function showElementById(id, val)
{
    var elm = document.getElementById(id);
    if (elm) {
        if (!val) val = 'inline';
        elm.style.display = val;
    }
}

function normalizeComments()
{
    // Remove the unused comment field from the document so its contents
    // do not get transmitted back to the server.

    var small = document.getElementById('smallCommentFrame');
    var big = document.getElementById('editFrame');
    if ( (small) && (small.style.display == 'none') )
    {
        small.parentNode.removeChild(small);
    }
    if ( (big) && (big.style.display == 'none') )
    {
        big.parentNode.removeChild(big);
    }
}
