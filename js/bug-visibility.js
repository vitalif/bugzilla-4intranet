/* Functions used to show/hide dependent bug fields and change their select options
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Author(s): Vitaliy Filippov <vitalif@mail.ru>
 */

addListener(window, 'load', initControlledFields);

function initControlledFields()
{
    // Initialise fields in correct order (starting with top-most controller fields)
    var initialised = {};
    var doInit = function(f)
    {
        if (f && !initialised[f])
        {
            initialised[f] = true;
            doInit(field_metadata[f].visibility_field);
            doInit(field_metadata[f].value_field);
            doInit(field_metadata[f].null_field);
            doInit(field_metadata[f].default_field);
            initControllerField(f);
        }
    };
    for (var i in field_metadata)
    {
        doInit(i);
    }
}

function initControllerField(i)
{
    var f = document.getElementById(i);
    if (f)
    {
        if (document.forms['Create'] && field_metadata[i].default_value)
        {
            // Select global default value before selecting dependent ones
            f._oldDefault = setFieldValue(f, field_metadata[i].default_value);
        }
        if (f.nodeName == 'SELECT' || f.name == 'product' && f.nodeName == 'INPUT' && f.type == 'hidden')
        {
            handleControllerField(document.forms['Create'] ? null : 'INITIAL', f);
        }
        addListener(f, 'change', handleControllerField_this);
    }
}

function getSelectedIds(sel)
{
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
            opt[id ? id.substr(1, id.length-lm) : 0] = true;
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
    var vis = false;
    if (visible)
    {
        for (var value in visible)
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

function setFieldValue(f, v)
{
    if (f.nodeName == 'SELECT')
    {
        f.selectedIndex = -1;
        v = v.split(',');
        for (var i in v)
        {
            i = document.getElementById('v' + v[i] + '_' + f.id);
            if (i)
            {
                i.selected = true;
            }
        }
    }
    else if (f.type != 'hidden')
    {
        f.value = v;
    }
    return v;
}

// Turn on/off fields and values controlled by 'controller' argument
function handleControllerField(e, controller)
{
    var vis, field_container, id;
    var opt = getSelectedIds(controller);
    // Show/hide fields
    for (var controlled_id in field_metadata[controller.id]['fields'])
    {
        vis = checkValueVisibility(opt, field_metadata[controller.id]['fields'][controlled_id]);
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
    for (var controlled_id in field_metadata[controller.id]['values'])
    {
        // It is more correct to match selected values on name, because a
        // target_milestone/version/component with the same name may exist for a different product
        controlled = document.getElementById(controlled_id);
        if (controlled.nodeName != 'SELECT')
        {
            continue;
        }
        copt = getSelectedNames(controlled);
        bz_clearOptions(controlled);
        if (field_metadata[controlled.id].nullable && !controlled.multiple)
        {
            bz_createOptionInSelect(controlled, '---', '');
        }
        for (var i in field_metadata[controlled.id].legal)
        {
            controlled_value = field_metadata[controlled.id].legal[i];
            vis = checkValueVisibility(opt, field_metadata[controller.id].values[controlled_id][controlled_value[0]]);
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
    for (var controlled_id in field_metadata[controller.id]['null'])
    {
        controlled = document.getElementById(controlled_id);
        if (controlled && !controlled.multiple && field_metadata[controlled.id] && field_metadata[controlled.id].nullable)
        {
            vis = checkValueVisibility(opt, field_metadata[controller.id]['null'][controlled_id]);
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
    // Select default values in controlled fields
    var v;
    for (var controlled_id in field_metadata[controller.id]['defaults'])
    {
        controlled = document.getElementById(controlled_id);
        if (!controlled)
        {
            continue;
        }
        var diff = false;
        if (controlled._oldDefault)
        {
            // Check if the value is different from previous default
            if (controlled.nodeName == 'SELECT')
            {
                copt = getSelectedIds(controlled);
                for (var i in controlled._oldDefault)
                {
                    if (copt[controlled._oldDefault[i]])
                    {
                        delete copt[controlled._oldDefault[i]];
                    }
                    else
                    {
                        diff = true;
                        break;
                    }
                }
                for (var i in copt)
                {
                    diff = true;
                    break;
                }
            }
            else
            {
                diff = controlled.value != controlled._oldDefault;
            }
        }
        // else means we are on creation form, so also select
        if (!diff)
        {
            v = field_metadata[controller.id].default_value;
            for (var i in opt)
            {
                v = field_metadata[controller.id]['defaults'][controlled_id][i];
            }
            if (v)
            {
                controlled._oldDefault = setFieldValue(controlled, v);
            }
        }
    }
}
