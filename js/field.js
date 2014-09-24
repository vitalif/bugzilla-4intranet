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
        onDomReady(function(ev) {
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
 * var nofocus: do not focus the field
 *
 */
function showEditableField(e, ContainerInputArray, nofocus)
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
    if (inputs.length > 0 && !nofocus)
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
function checkForChangedFieldValues(e, ContainerInputArray)
{
    var el = document.getElementById(ContainerInputArray[2]);
    var unhide = false;
    if (el)
    {
        if (el.value != ContainerInputArray[3] ||
            el.value == "" && el.id != "alias")
        {
            unhide = true;
        }
        else
        {
            var set_default = document.getElementById("set_default_" + ContainerInputArray[2]);
            if (set_default && set_default.checked)
                unhide = true;
        }
    }
    if (unhide)
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
    onDomReady(function(ev) { return checkForChangedFieldValues(ev, bz_alias_check_array) });
}

function showPeopleOnChange(field_id_list)
{
    for (var i = 0; i < field_id_list.length; i++)
    {
        addListener(field_id_list[i], 'change',
            function(ev) { return showEditableField(ev, [ 'bz_qa_contact_edit_container', 'bz_qa_contact_input' ], true) });
        addListener(field_id_list[i], 'change',
            function(ev) { return showEditableField(ev, [ 'bz_assignee_edit_container', 'bz_assignee_input'], true) });
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
        function(ev) { return boldOnChange(ev, 'set_default_'+field_id) }
    );
    onDomReady(function(ev)
    {
        checkForChangedFieldValues(ev, [
            'bz_'+field_id+'_edit_container', 'bz_'+field_id+'_input',
            'set_default_'+field_id, '1' ]
        );
        boldOnChange(ev, 'set_default_'+field_id);
    });
}

function showHideStatusItems(is_duplicate, initial_status)
{
    var el = document.getElementById('bug_status');
    if (el)
    {
        // Make sure that fields whose visibility or values are controlled
        // by "resolution" behave properly when resolution is hidden.
        var resolution = document.getElementById('resolution');
        addClass('duplicate_display', 'bz_default_hidden');
        showDuplicateItem(el);
        if (el.options[el.selectedIndex].value == initial_status && is_duplicate == "is_duplicate" ||
            bz_isValueInArray(close_status_array, el.options[el.selectedIndex].value))
        {
            removeClass('resolution_settings', 'bz_default_hidden');
            removeClass('resolution_settings_warning', 'bz_default_hidden');
            // Remove the blank resolution option
            if (resolution && resolution.options[0].value == '')
            {
                if (resolution.bz_lastSelected)
                {
                    resolution.selectedIndex = resolution.bz_lastSelected;
                }
                resolution.removeChild(resolution.options[0]);
            }
        }
        else
        {
            addClass('resolution_settings', 'bz_default_hidden');
            addClass('resolution_settings_warning', 'bz_default_hidden');
            // Add the blank resolution option back
            if (resolution && resolution.options[0].value != '' &&
                resolution.options[0].value != '--do_not_change--')
            {
                var emptyOption = new Option('---', '');
                resolution.insertBefore(emptyOption, resolution.options[0]);
            }
            resolution.bz_lastSelected = resolution.selectedIndex;
            resolution.options[0].selected = true;
        }
        if (resolution)
        {
            bz_fireEvent(resolution, 'change');
        }
    }
}

function showDuplicateItem(e)
{
    var resolution = document.getElementById('resolution');
    var bug_status = document.getElementById('bug_status');
    var dup_id = document.getElementById('dup_id');
    if (resolution && dup_id)
    {
        // FIXME remove name hardcode
        if (resolution.options[resolution.selectedIndex].value == 'DUPLICATE' &&
            bz_isValueInArray(close_status_array, bug_status.options[bug_status.selectedIndex].value))
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
    if (e.preventDefault)
        e.preventDefault();
    return false;
}

function setDefaultCheckbox(e, field_id)
{
    var el = document.getElementById(field_id);
    var elLabel = document.getElementById(field_id + "_label");
    if (el && elLabel)
    {
        el.checked = "true";
        elLabel.style.fontWeight = 'bold';
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

function getSelectedIds(sel)
{
    if (typeof sel == "string")
    {
        sel = document.getElementById(sel);
    }
    var opt = {};
    var lm = sel.id.length+2;
    if (sel.nodeName != 'SELECT')
    {
        if (sel.name == 'product')
        {
            // product is a special case - it is preselected as hidden field on bug creation form
            opt[product_id] = true;
        }
        return opt;
    }
    for (var i = 0; i < sel.options.length; i++)
    {
        if (sel.options[i].selected)
        {
            id = sel.options[i].id;
            if (!id && sel.options[i].value)
                opt.UNKNOWN = true;
            else
                opt[id ? id.substr(1, id.length-lm) : 0] = true;
        }
    }
    return opt;
}

function getSelectedValues(sel)
{
    var opt = {};
    if (sel.nodeName != 'SELECT' || !sel.multiple)
    {
        opt[sel.value] = true;
        return opt;
    }
    for (var i = 0; i < sel.options.length; i++)
    {
        if (sel.options[i].selected)
        {
            opt[sel.options[i].value] = true;
        }
    }
    return opt;
}

function checkValueVisibility(selected, visible_for)
{
    var vis = false;
    if (visible_for)
    {
        for (var value in visible_for)
        {
            if (selected[value])
            {
                vis = true;
                break;
            }
        }
    }
    return vis;
}

// Data loader for keyword autocomplete (offline, using field_metadata)
function keywordAutocomplete(hint)
{
    var l = hint.input.value.length ? hint.input.value.trim().split(/[\s,]*,[\s,]*/) : [];
    var vv, h;
    if (field_metadata.keywords.value_field)
    {
        vv = getSelectedIds(document.getElementById(field_metadata.keywords.value_field));
        h = field_metadata[field_metadata.keywords.value_field].values.keywords;
    }
    var o = [];
    for (var i in field_metadata.keywords.legal)
    {
        var kw = field_metadata.keywords.legal[i];
        if (!vv || checkValueVisibility(vv, h[kw[0]]))
        {
            var j;
            for (j = 0; j < l.length; j++)
            {
                if (l[j].toLowerCase() == kw[1].substr(0, l[j].length).toLowerCase())
                {
                    break;
                }
            }
            if (!l.length || j < l.length)
            {
                o.push([ '<span class="hintRealname">' + htmlspecialchars(kw[1]) + '</span>', kw[1] ]);
            }
        }
    }
    hint.replaceItems(o);
}

function addKeywordsAutocomplete()
{
    new SimpleAutocomplete("keywords", keywordAutocomplete,
        { emptyText: L('No keywords found'), multipleDelimiter: "," });
}

// CustIS bug 66910 - check new keywords and requery description for it
function check_new_keywords(form)
{
    if (!form.keywords)
    {
        return true;
    }
    var input_kw = form.keywords.value.trim();
    input_kw = input_kw.length ? input_kw.split(/[,\s]*,[,\s]*/) : [];
    var kw_hash = {};
    for (var i = 0; i < field_metadata.keywords.legal.length; i++)
    {
        kw_hash[field_metadata.keywords.legal[i][1].toLowerCase()] = true;
    }
    var non_exist_keywords = [];
    for (var i = 0; i < input_kw.length; i++)
    {
        if (!kw_hash[input_kw[i].toLowerCase()])
        {
            non_exist_keywords.push(input_kw[i]);
        }
    }
    if (non_exist_keywords.length > 0)
    {
        var keywords_submit = true;
        var kd_container = document.getElementById("keywords_description_container");

        var desc_html = "";
        for (var i = 0; i < non_exist_keywords.length; i++)
        {
            var this_value = "";
            if (document.getElementById('kd_' + i) && document.getElementById('kd_' + i).value != "" &&
                document.getElementById('kd_' + i).getAttribute('data-key') == non_exist_keywords[i])
            {
                this_value = document.getElementById('kd_' + i).value;
            }
            desc_html += "<div style='margin-top: 8px'><label>"+L("Describe new keyword")+" <b>" + htmlspecialchars(non_exist_keywords[i]) +
                "</b>:</label><br /><input type=\"text\" value=\"" + htmlspecialchars(this_value) + "\" class=\"text_input\" name=\"kd\" id=\"kd_" +
                i + "\" data-key=\"" + htmlspecialchars(non_exist_keywords[i]) + "\" style=\"border: solid 1px red;\" /></div>";
        }
        kd_container.innerHTML = desc_html;

        var kd_descriptions_val = "";
        var kd_descriptions = kd_container.getElementsByTagName("INPUT");
        for (var i = 0; i < kd_descriptions.length; i++)
        {
            if (kd_descriptions[i].value != "")
            {
                if (kd_descriptions_val != "")
                {
                    kd_descriptions_val += "&";
                }
                var this_key = kd_descriptions[i].getAttribute('data-key');
                kd_descriptions_val += encodeURIComponent(this_key) + "=" + encodeURIComponent(kd_descriptions[i].value);
            }
            else
            {
                keywords_submit = false;
            }
        }
        if (kd_descriptions_val != "")
        {
            kd_container.innerHTML = kd_container.innerHTML + "<input type=\"hidden\" value=\"" + kd_descriptions_val + "\" name=\"keywords_description\" />"
        }
        else
        {
            keywords_submit = false;
        }
        document.getElementById('keywords').focus();
        document.getElementById('kd_0').focus();
        return keywords_submit;
    }
    return true;
}
