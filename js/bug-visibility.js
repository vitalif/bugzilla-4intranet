YAHOO.util.Event.addListener(window, 'load', initControlledFields);

function initControlledFields()
{
    for (var i in show_fields)
        initControlledField(i);
}

function initControlledField(i)
{
    var f = document.getElementById(i);
    YAHOO.util.Event.addListener(f, 'change', handleControllerField, f);
}

function getSelectedIds(sel)
{
    var lm = sel.id.length+2;
    var opt = {};
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

function handleControllerField(e, controller)
{
    var vis, label_container, field_container, id;
    var opt = getSelectedIds(controller);
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
            YAHOO.util.Dom.removeClass(label_container, 'bz_hidden_field');
            YAHOO.util.Dom.removeClass(field_container, 'bz_hidden_field');
        }
        else
        {
            YAHOO.util.Dom.addClass(label_container, 'bz_hidden_field');
            YAHOO.util.Dom.addClass(field_container, 'bz_hidden_field');
        }
    }
    var item, controlled, copt, controlled_value;
    for (var controlled_id in show_fields[controller.id]['values'])
    {
        controlled = document.getElementById(controlled_id);
        copt = getSelectedIds(controlled);
        bz_clearOptions(controlled);
        for (var i in show_fields[controlled.id]['legal'])
        {
            controlled_value = show_fields[controlled.id]['legal'][i];
            vis = false;
            item = show_fields[controller.id]['values'][controlled_id][controlled_value[0]];
            if (!item)
                vis = true;
            else
            {
                for (var value in item)
                {
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
                    item.selected = true;
            }
        }
    }
}
