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
 * The Initial Developer of the Original Code is Everything Solved, Inc.
 * Portions created by Everything Solved are Copyright (C) 2007 Everything
 * Solved, Inc. All Rights Reserved.
 *
 * Contributor(s): Max Kanat-Alexander <mkanat@bugzilla.org>
 *                 Guy Pyrzak <guy.pyrzak@gmail.com>
 */

/* Hide input fields and show the text with (edit) next to it */
function hideEditableField( container, input, action, field_id, original_value )
{
    removeClass(container, 'bz_default_hidden');
    addClass(input, 'bz_default_hidden');
    addListener(action, 'click', function(ev) { return showEditableField(ev, [ container, input ]); });
    if (field_id != "")
        addListener(window, 'load', function(ev) {
            return checkForChangedFieldValues(ev, [ container, input, field_id, original_value ])
        });
}

/* showEditableField (e, ContainerInputArray)
 * Function hides the (edit) link and the text and displays the input
 *
 * var e: the event
 * var ContainerInputArray: An array containing the (edit) and text area and the input being displayed
 * var ContainerInputArray[0]: the conainer that will be hidden usually shows the (edit) text
 * var ContainerInputArray[1]: the input area and label that will be displayed
 *
 */
function showEditableField(e, ContainerInputArray)
{
    var inputs = new Array();
    var inputArea = ContainerInputArray[1];
    if (!inputArea)
    {
        if (e.preventDefault) e.preventDefault();
        return false;
    }
    if (typeof(inputArea) == 'string')
        inputArea = document.getElementById(inputArea);
    addClass(ContainerInputArray[0], 'bz_default_hidden');
    removeClass(inputArea, 'bz_default_hidden');
    if (inputArea.nodeName.toLowerCase() == 'input')
        inputs.push(inputArea);
    else
        inputs = inputArea.getElementsByTagName('input');
    if (inputs.length > 0)
    {
        // focus on the first field, this makes it easier to edit
        inputs[0].focus();
        inputs[0].select();
    }
    if (e.preventDefault) e.preventDefault();
    return false;
}

/* checkForChangedFieldValues(e, array )
 * Function checks if after the autocomplete by the browser if the values match the originals.
 *   If they don't match then hide the text and show the input so users don't get confused.
 *
 * var e: the event
 * var ContainerInputArray: An array containing the (edit) and text area and the input being displayed
 * var ContainerInputArray[0]: the conainer that will be hidden usually shows the (edit) text
 * var ContainerInputArray[1]: the input area and label that will be displayed
 * var ContainerInputArray[2]: the field that is on the page, might get changed by browser autocomplete
 * var ContainerInputArray[3]: the original value from the page loading.
 *
 */
function checkForChangedFieldValues(e, ContainerInputArray ) {
    var el = document.getElementById(ContainerInputArray[2]);
    var unhide = false;
    if ( el ) {
        if ( el.value != ContainerInputArray[3] ||
            ( el.value == "" && el.id != "alias") ) {
            unhide = true;
        }
        else {
            var set_default = document.getElementById("set_default_" +
                                                      ContainerInputArray[2]);
            if ( set_default ) {
                if(set_default.checked){
                    unhide = true;
                }
            }
        }
    }
    if(unhide)
    {
        addClass(ContainerInputArray[0], 'bz_default_hidden');
        removeClass(ContainerInputArray[1], 'bz_default_hidden');
    }
}

function hideAliasAndSummary(short_desc_value, alias_value)
{
    // check the short desc field
    hideEditableField(
        'summary_alias_container','summary_alias_input',
        'editme_action','short_desc', short_desc_value
    );
    // check that the alias hasn't changed
    var bz_alias_check_array = [
        'summary_alias_container', 'summary_alias_input', 'alias', alias_value
    ];
    addListener(window, 'load',
        function(ev) { return checkForChangedFieldValues(ev, bz_alias_check_array) }
    );
}

function showPeopleOnChange(field_id_list)
{
    for (var i = 0; i < field_id_list.length; i++)
    {
        addListener(field_id_list[i], 'change',
            function(ev) { return showEditableField(ev, [ 'bz_qa_contact_edit_container', 'bz_qa_contact_input' ]) });
        addListener(field_id_list[i], 'change',
            function(ev) { return showEditableField(ev, [ 'bz_assignee_edit_container', 'bz_assignee_input']) });
    }
}

function assignToDefaultOnChange(field_id_list)
{
    showPeopleOnChange(field_id_list);
    for (var i = 0; i < field_id_list.length; i++)
    {
        addListener(field_id_list[i], 'change',
            function(ev) { return setDefaultCheckbox(ev, 'set_default_assignee') });
        addListener(field_id_list[i], 'change',
            function(ev) { return setDefaultCheckbox(ev, 'set_default_qa_contact') });
    }
}

function initDefaultCheckbox(field_id)
{
    addListener('set_default_'+field_id, 'change',
        function(ev) { return boldOnChange(ev, 'set_default_'+field_id) });
    addListener(window, 'load',
        function(ev) { return checkForChangedFieldValues(ev, [
            'bz_'+field_id+'_edit_container', 'bz_'+field_id+'_input',
            'set_default_'+field_id, '1' ]) });
    addListener(window, 'load',
        function(ev) { return boldOnChange(ev, 'set_default_'+field_id) });
}

function showHideStatusItems(is_duplicate, initial_status)
{
    var el = document.getElementById('bug_status');
    if (el)
    {
        showDuplicateItem(el);
        // Make sure that fields whose visibility or values are controlled
        // by "resolution" behave properly when resolution is hidden.
        var resolution = document.getElementById('resolution');
        if (resolution && resolution.options[0].value != '' &&
            resolution.options[0].value != '--do_not_change--')
        {
            resolution.bz_lastSelected = resolution.selectedIndex;
            var emptyOption = new Option('', '');
            resolution.insertBefore(emptyOption, resolution.options[0]);
            emptyOption.selected = true;
        }
        addClass('resolution_settings', 'bz_default_hidden');
        if (document.getElementById('resolution_settings_warning'))
            addClass('resolution_settings_warning', 'bz_default_hidden');
        addClass('duplicate_display', 'bz_default_hidden');
        if (el.value == initial_status && is_duplicate == "is_duplicate" ||
            bz_isValueInArray(close_status_array, el.value))
        {
            removeClass('resolution_settings', 'bz_default_hidden');
            removeClass('resolution_settings_warning', 'bz_default_hidden');

            // Remove the blank option we inserted.
            if (resolution && resolution.options[0].value == '')
            {
                resolution.removeChild(resolution.options[0]);
                resolution.selectedIndex = resolution.bz_lastSelected;
            }
        }
        if (resolution)
            bz_fireEvent(resolution, 'change');
    }
}

function showDuplicateItem(e)
{
    var resolution = document.getElementById('resolution');
    var bug_status = document.getElementById('bug_status');
    var dup_id = document.getElementById('dup_id');
    if (resolution && dup_id)
    {
        if (resolution.value == 'DUPLICATE' && bz_isValueInArray(close_status_array, bug_status.value))
        {
            // hide resolution show duplicate
            removeClass('duplicate_settings', 'bz_default_hidden');
            addClass('dup_id_discoverable', 'bz_default_hidden');
            // check to make sure the field is visible or IE throws errors
            if (!hasClass(dup_id, 'bz_default_hidden'))
            {
                dup_id.focus();
                dup_id.select();
            }
        }
        else
        {
            addClass('duplicate_settings', 'bz_default_hidden');
            removeClass('dup_id_discoverable', 'bz_default_hidden');
            dup_id.blur();
        }
    }
    // Prevent the hyperlink from going to the url in the href:
    if (e.preventDefault) e.preventDefault();
    return false;
}

function setResolutionToDuplicate(duplicate_or_move_bug_status)
{
    var status = document.getElementById('bug_status');
    var resolution = document.getElementById('resolution');
    addClass('dup_id_discoverable', 'bz_default_hidden');
    status.value = duplicate_or_move_bug_status;
    bz_fireEvent(status, 'change');
    resolution.value = "DUPLICATE";
    bz_fireEvent(resolution, 'change');
    if (e.preventDefault) e.preventDefault();
    return false;
}

function setDefaultCheckbox(e, field_id)
{
    var el = document.getElementById(field_id);
    var elLabel = document.getElementById(field_id + "_label");
    if (el && elLabel)
    {
        el.checked = "true";
        elLabel.style.fontWeight = bold;
    }
}

function boldOnChange(e, field_id)
{
    var el = document.getElementById(field_id);
    var elLabel = document.getElementById(field_id + "_label");
    if (el && elLabel)
        elLabel.style.fontWeight = el.checked ? 'bold' : 'normal';
}

function updateCommentTagControl(checkbox, form)
{
    form.comment.className = checkbox.checked ? 'bz_private' : '';
}

// A convenience function to generate the "id" tag of an <option>
// based on the numeric id that Bugzilla uses for that value.
function _value_id(field_name, id)
{
    return 'v' + id + '_' + field_name;
}

// Convert user list from API format for SimpleAutocomplete
function convertUserList(u)
{
    var data = [];
    for (var i = 0; i < u.length; i++)
        data.push([
            '<span class="hintRealname">' + htmlspecialchars(u[i].real_name) +
            '</span><br /><span class="hintEmail">' + htmlspecialchars(u[i].email) + '</span>',
            u[i].email
        ]);
    return data;
}

// Data loader for user autocomplete
function userAutocomplete(hint, emptyOptions)
{
    if (!hint.input.value)
    {
        hint.emptyText = 'Type at least 3 letters';
        if (emptyOptions)
            hint.replaceItems(convertUserList(emptyOptions));
        else
            hint.replaceItems(null);
        return;
    }
    var x;
    if (window.XMLHttpRequest)
        x = new XMLHttpRequest();
    else
    {
        try { x = new ActiveXObject("Msxml2.XMLHTTP"); }
        catch (e) { x = new ActiveXObject("Microsoft.XMLHTTP"); }
    }
    x.onreadystatechange = function()
    {
        if (x.readyState == 4)
        {
            var r = {};
            try { eval('r = '+x.responseText+';'); } catch (e) { return; }
            if (r.status == 'ok')
            {
                var data = convertUserList(r.users);
                // FIXME "3" constant, messages: remove hardcode, also in Bugzilla::User::match()
                if (data.length == 0 && hint.input.value.length < 3)
                    hint.emptyText = 'Type at least 3 letters';
                else
                    hint.emptyText = 'No users found';
                hint.replaceItems(data);
            }
        }
    };
    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=User.get&output=json&maxusermatches=20';
    var l = hint.input.value.split(/[\s,]*,[\s,]*/);
    for (var i = 0; i < l.length; i++)
        u += '&match='+encodeURI(l[i]);
    x.open('GET', u);
    x.send(null);
}
