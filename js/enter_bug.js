/* Functions for the bug creation form (almost 100% rewritten)
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

var cc_rem = {}, cc_add = {};
var last_cc;
var last_initialowner;
var last_component;
var last_initialqacontact;

function component_change()
{
    // Based on the selected component, fill Assign To, CC and QA Contact
    // fields with default values, and enable flags for this component.

    var form = document.Create;
    var assigned_to = form.assigned_to.value;

    var selectedName = form.component.value;
    if (selectedName)
    {
        var c = component_data[selectedName];
        if (assigned_to == last_initialowner || assigned_to == c.default_assignee || !assigned_to)
        {
            form.assigned_to.value = c.default_assignee;
            last_initialowner = c.default_assignee;
        }

        /**
         * CustIS Bug 57457 & Bug 58657
         *
         * Infernal logic for High Usability
         * Remembers modifications entered by user (added and removed CC),
         * builds new CC list by applying them to the initial value
         * plus initial component CCs, preserving entry order.
         *
         * Адская логика для Высокого Юзабилити
         * Запоминает изменения, внесённые пользователем в список CC и
         * строит новый список CC, применяя их к объединению начального значения и
         * CC по умолчанию для компонента, да ещё и сохраняет порядок ввода.
         */
        if (!last_cc)
            last_cc = initial_cc;
        var cc_diff = diff_arrays(last_cc.split(/[\s,]+/), form.cc.value.split(/[\s,]+/));
        for (i in cc_rem)
            if (cc_rem[i] && !cc_diff[0][i])
                cc_diff[1][i] = 1;
        for (i in cc_add)
            if (cc_add[i] && !cc_diff[1][i])
                cc_diff[0][i] = 1;
        cc_add = cc_diff[0];
        cc_rem = cc_diff[1];
        var new_cc = array_hash(initial_cc.split(/[\s,]+/));;
        for (i in c.initial_cc)
            new_cc[c.initial_cc[i]] = 1;
        for (i in cc_add)
            new_cc[i] = 1;
        for (i in cc_rem)
            new_cc[i] = 0;
        last_cc = form.cc.value = hash_join(new_cc);

        document.getElementById('comp_desc').innerHTML = c.description;

        if (form.qa_contact)
        {
            var qa_contact = form.qa_contact.value;
            if (qa_contact == last_initialqacontact || qa_contact == c.default_qa_contact || !qa_contact)
            {
                form.qa_contact.value = c.default_qa_contact;
                last_initialqacontact = c.default_qa_contact;
            }
        }

        // Enable/disable flags
        for (var i = 0; i < product_flag_type_ids.length; i++)
        {
            flagField = document.getElementById('flag_type-' + product_flag_type_ids[i]);
            if (flagField)
            {
                // Do not enable flags the user cannot set nor request.
                flagField.disabled = !c.flags[product_flag_type_ids[i]] || flagField.options.length <= 1;
                toggleRequesteeField(flagField, 1);
            }
        }

        last_component = selectedName;
    }
}

function handleWantsAttachment(wants_attachment)
{
    var f = document.getElementById('attachment_false');
    var t = document.getElementById('attachment_true');
    var m = document.getElementById('attachment_multi');
    f.style.display = wants_attachment == 'none'   ? '' : 'none';
    t.style.display = wants_attachment == 'single' ? '' : 'none';
    m.style.display = wants_attachment == 'multi'  ? '' : 'none';
    if (wants_attachment != 'multi')
    {
        document.getElementById('att_multiple').innerHTML = '';
    }
    else
    {
        iframeajax('page.cgi?id=attach-multiple.html', {});
    }
}

function bug_status_change()
{
    showHideStatusItems();
    // FIXME Remove hardcode bug_status==ASSIGNED => assign to self
    if (this.value == "ASSIGNED")
    {
        document.Create.assigned_to.value = current_user_login;
    }
}

function checkWorktime(inp)
{
    if (noTimeTracking)
    {
        wt = bzParseTime(inp.value);
        inp.parentNode.style.backgroundColor = (wt != 0 ? '#FFC0C0' : null);
    }
}

function validateEntryForm(theform)
{
    if (!check_new_keywords(document.Create))
    {
        return false;
    }

    if (theform.short_desc.value == '')
    {
        alert('Please enter a summary sentence for this bug.');
        return false;
    }

    // Validate attachment
    var t = document.getElementById('attachment_true');
    if (t.style.display != 'none' && !validateAttachmentForm(theform))
        return false;
    else if (t.style.display == 'none')
    {
        // Clear attachment description so it won't be created
        theform.description.value = '';
    }

    // Validate worktime
    var wt = bzParseTime(theform.work_time.value);
    if (wt !== null && (wt === undefined || wt != wt))
        wt = null;
    else if (wt < 0)
        wt = 0;
    if (wantsReminder && (wt === null || noTimeTracking == (wt != 0)))
    {
        wt = prompt("Please, verify working time:", "0");
        if (wt == null || wt == undefined || (""+wt).length <= 0)
        {
            theform.work_time.focus();
            return false;
        }
    }
    if (wt === null)
        wt = 0;
    theform.work_time.value = wt;
    return true;
}

onDomReady(function()
{
    var f = document.getElementById('bug_status');
    addListener(f, 'change', bug_status_change);
    bug_status_change.apply(f);

    addListener('component', 'change', component_change);
    component_change();

    document.getElementById('short_desc').focus();
});
