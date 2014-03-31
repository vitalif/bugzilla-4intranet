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
            for (var controlled_id in show_fields[f.id]['values'])
            {
                var controlled = document.getElementById(controlled_id);
                if (!controlled)
                {
                    continue;
                }

                var vals = show_fields[f.id]['values'][controlled_id];
                for (var value_id in vals)
                {
                    if (!vals[value_id][control_id])
                    {
                        continue;
                    }
                    if (vals[value_id][control_id].is_default == 1)
                    {
                        document.getElementById('v' + value_id + '_' + controlled_id).selected = true;
                    }
                }
            }
        }

        handleControllerField(null, f);
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

function handleControllerField_this(e)
{
    return handleControllerField(e, this);
}

// Turn on/off fields and values controlled by 'controller' argument
function handleControllerField(e, controller)
{
    var vis, label_container, field_container, id;
    var opt = getSelectedIds(controller);
    // Show/hide fields
    for (var controlled_id in show_fields[controller.id]['fields'])
    {
        vis = false;
        for (var value in show_fields[controller.id]['fields'][controlled_id])
        {
            if (opt[value])
            {
                vis = true;
                break;
            }
        }
        label_container = document.getElementById('field_label_' + controlled_id);
        field_container = document.getElementById('field_container_' + controlled_id);
        if (vis)
        {
            removeClass(label_container, 'bz_hidden_field');
            removeClass(field_container, 'bz_hidden_field');
        }
        else
        {
            addClass(label_container, 'bz_hidden_field');
            addClass(field_container, 'bz_hidden_field');
        }
    }
    // Change select options
    var item, controlled, copt, controlled_value;
    for (var controlled_id in show_fields[controller.id]['values'])
    {
        controlled = document.getElementById(controlled_id);
        copt = getSelectedIds(controlled);
        bz_clearOptions(controlled);
        for (var i in show_fields[controlled.id]['legal'])
        {
            controlled_value = show_fields[controlled.id]['legal'][i];
            vis = true;
            item = show_fields[controller.id]['values'][controlled_id][controlled_value[0]];
            if (item)
            {
                for (var value in item)
                {
                    vis = false;
                    if (opt[value])
                    {
                        vis = true;
                        break;
                    }
                }
            }
            if (vis)
            {
                item = bz_createOptionInSelect(controlled, controlled_value[1], controlled_value[1]);
                item.id = 'v'+controlled_value[0]+'_'+controlled_id;
                if (copt[controlled_value[0]])
                {
                    item.selected = true;
                }
            }
        }
    }
}
