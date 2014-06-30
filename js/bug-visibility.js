/* Functions used to show/hide dependent bug fields and change their select options
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Author(s): Vitaliy Filippov <vitalif@mail.ru>
 */

// This is set to window.onload event from fieldvaluecontrol.cgi
function initControlledFields()
{
    // Initialise fields in correct order (from up-most controller fields)
    var initialised = {};
    var doInit = function(f)
    {
        if (f && !initialised[f])
        {
            initialised[f] = true;
            doInit(show_fields[f].visibility_field);
            doInit(show_fields[f].value_field);
            initControllerField(f);
        }
    };
    for (var i in show_fields)
    {
        doInit(i);
    }
}

function initControllerField(i)
{
    var f = document.getElementById(i);
    if (f)
    {
        if (document.forms['Create'])
        {
            // Find current value of field f by its name
            var control_id;
            for (var i in show_fields[f.id]['legal'])
            {
                if (f.value == show_fields[f.id]['legal'][i][1])
                {
                    control_id = show_fields[f.id]['legal'][i][0];
                    break;
                }
            }

            // Select default value in each controlled field
            for (var controlled_id in show_fields[f.id]['defaults'])
            {
                var controlled = document.getElementById(controlled_id);
                if (!controlled)
                {
                    continue;
                }
                var v = show_fields[f.id]['defaults'][controlled_id];
                if (controlled.nodeName == 'SELECT')
                {
                    for (var i in v)
                    {
                        i = document.getElementById('v' + v[i] + '_' + controlled_id);
                        if (i)
                            i.selected = true;
                    }
                }
                else
                {
                    controlled.value = v;
                }
            }
        }
        handleControllerField(document.forms['Create'] ? null : 'INITIAL', f);
        addListener(f, 'change', handleControllerField_this);
    }
}

function getSelectedIds(sel)
{
    var lm = sel.id.length+2;
    var opt = {};
    if (sel.type == 'hidden' && sel.name == 'product')
    {
        // product is a special case - it is preselected as hidden field on bug creation form
        opt[product_id] = true;
        return opt;
    }
    for (var i = 0; i < sel.options.length; i++)
    {
        if (sel.options[i].selected)
        {
            id = sel.options[i].id;
            opt[id.substr(1, id.length-lm)] = true;
        }
    }
    return opt;
}

function getSelectedNames(sel)
{
    var opt = {};
    if (sel.type != 'select' || !sel.multi)
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

function handleControllerField_this(e)
{
    return handleControllerField(e, this);
}

function checkValueVisibility(selected, visible)
{
    var vis = true;
    if (visible)
    {
        for (var value in visible)
        {
            vis = false;
            if (selected[value])
            {
                vis = true;
                break;
            }
        }
    }
    return vis;
}

// Turn on/off fields and values controlled by 'controller' argument
function handleControllerField(e, controller)
{
    var vis, field_container, id;
    var opt = getSelectedIds(controller);
    // Show/hide fields
    for (var controlled_id in show_fields[controller.id]['fields'])
    {
        vis = checkValueVisibility(opt, show_fields[controller.id]['fields'][controlled_id]);
        for (var i in { row: 1, container: 1, label: 1 })
        {
            field_container = document.getElementById('field_' + i + '_' + controlled_id);
            (vis ? removeClass : addClass)(field_container, 'bz_hidden_field');
        }
    }
    // Change select options
    if (e === 'INITIAL')
    {
        // Skip re-filling of fields on bug edit page load, because
        // the bug may include incorrect values that must not be hidden initially
        return;
    }
    var item, controlled, copt, controlled_value;
    for (var controlled_id in show_fields[controller.id]['values'])
    {
        // It is more correct to match selected values on name, because a
        // target_milestone/version/component with the same name may exist for a different product
        controlled = document.getElementById(controlled_id);
        copt = getSelectedNames(controlled);
        bz_clearOptions(controlled);
        if (show_fields[controlled.id].nullable && !controlled.multiple)
        {
            bz_createOptionInSelect(controlled, '---', '');
        }
        for (var i in show_fields[controlled.id]['legal'])
        {
            controlled_value = show_fields[controlled.id]['legal'][i];
            vis = checkValueVisibility(opt, show_fields[controller.id]['values'][controlled_id][controlled_value[0]]);
            if (vis)
            {
                item = bz_createOptionInSelect(controlled, controlled_value[1], controlled_value[1]);
                item.id = 'v'+controlled_value[0]+'_'+controlled_id;
                if (copt[controlled_value[1]])
                {
                    item.selected = true;
                }
            }
        }
    }
    // Enable/disable NULL in single-select fields
    for (var controlled_id in show_fields[controller.id]['null'])
    {
        controlled = document.getElementById(controlled_id);
        if (controlled && !controlled.multiple && show_fields[controlled.id] && show_fields[controlled.id].nullable)
        {
            vis = checkValueVisibility(opt, show_fields[controller.id]['null'][controlled_id]);
            item = controlled.options[0].value == '';
            if (vis && !item)
            {
                item = new Option('---', '');
                controlled.insertBefore(item, controlled.options[0]);
            }
            else if (!vis && item)
            {
                controlled.removeChild(controlled.options[0]);
            }
        }
    }
}
