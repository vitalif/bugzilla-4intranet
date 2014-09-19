/* Functions used to show/hide dependent bug fields and change their select options
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Author(s): Vitaliy Filippov <vitalif@mail.ru>
 */

onDomReady(initControlledFields);

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
            initControlledField(f);
        }
    };
    for (var i in field_metadata)
    {
        doInit(i);
    }
    reflowFieldColumns();
}

function initControlledField(i)
{
    var f = document.getElementById(i);
    if (f && document.forms['Create'] && field_metadata[i].default_value)
    {
        // Select global default value before selecting dependent ones
        f._oldDefault = setFieldValue(f, field_metadata[i].default_value);
    }
    if (!f || f.nodeName != 'INPUT' || f.type != 'hidden')
    {
        handleControlledField(i, !document.forms['Create']);
    }
    if (f)
    {
        addListener(f, 'change', handleControllerField_this);
    }
}

function handleControllerField_this(e, nonfirst)
{
    var m = field_metadata[this.id];
    if (!m)
    {
        return;
    }
    var f = {};
    for (var i in { 'fields': 1, 'values': 1, 'null': 1, 'defaults': 1 })
    {
        for (var j in m[i])
        {
            f[j] = true;
        }
    }
    for (var i in f)
    {
        handleControlledField(i);
    }
    // Cascade events
    for (var i in f)
    {
        handleControllerField_this.apply(document.getElementById(i), [ null, true ]);
    }
    if (!nonfirst)
    {
        reflowFieldColumns();
    }
}

function setFieldValue(f, v)
{
    if (f.nodeName == 'SELECT')
    {
        if (f.multiple)
        {
            f.selectedIndex = -1;
        }
        if (v)
        {
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
        else if (!f.multiple)
        {
            f.selectedIndex = 0;
        }
    }
    else if (f.type != 'hidden')
    {
        f.value = v;
    }
    return v;
}

function handleControlledField(controlled_id, is_initial_editform)
{
    var m = field_metadata[controlled_id];
    var controlled = document.getElementById(controlled_id);
    var vis;
    // Show/hide the field
    if (m.visibility_field && document.getElementById(m.visibility_field))
    {
        vis = checkValueVisibility(getSelectedIds(m.visibility_field), field_metadata[m.visibility_field]['fields'][controlled_id]);
        for (var i in { row: 1, container: 1, label: 1 })
        {
            var field_container = document.getElementById('field_' + i + '_' + controlled_id);
            (vis ? removeClass : addClass)(field_container, 'bz_hidden_field');
        }
    }
    if (!controlled)
    {
        // Maybe the field is not editable.
        return;
    }
    if (is_initial_editform)
    {
        // Skip re-filling of fields on bug edit page load, because
        // the bug may include incorrect values that must not be hidden initially.
        // Also remember, but do not select the default value in this case.
    }
    else if (controlled.nodeName == 'SELECT')
    {
        // Change select options
        if (m.value_field && document.getElementById(m.value_field))
        {
            // It is more correct to match selected values on name, because a
            // target_milestone/version/component with the same name may exist for a different product
            var copt = getSelectedValues(controlled);
            bz_clearOptions(controlled);
            var nullable = m.nullable && !controlled.multiple;
            if (m.null_field && nullable && document.getElementById(m.null_field))
            {
                nullable = checkValueVisibility(getSelectedIds(m.null_field), field_metadata[m.null_field]['null'][controlled_id]);
            }
            if (nullable)
            {
                bz_createOptionInSelect(controlled, '---', '');
            }
            var opt = getSelectedIds(m.value_field), controlled_value;
            var vh = field_metadata[m.value_field]['values'][controlled_id];
            for (var i in m.legal)
            {
                controlled_value = m.legal[i];
                vis = checkValueVisibility(opt, vh[controlled_value[0]]);
                if (vis)
                {
                    var item = bz_createOptionInSelect(controlled, controlled_value[1], controlled_value[1]);
                    item.id = 'v'+controlled_value[0]+'_'+controlled_id;
                    if (copt[controlled_value[1]])
                    {
                        item.selected = true;
                    }
                }
            }
        }
        else if (m.nullable && !controlled.multiple && m.null_field && document.getElementById(m.null_field))
        {
            // Just enable/disable empty value
            var nullable = checkValueVisibility(getSelectedIds(m.null_field), field_metadata[m.null_field]['null'][controlled_id]);
            var has_null = controlled.options[0].value == '';
            if (nullable && !has_null)
            {
                controlled.insertBefore(new Option('---', ''), controlled.options[0]);
            }
            else if (!nullable && has_null)
            {
                controlled.removeChild(controlled.options[0]);
            }
        }
    }
    // Select and/or remember default value
    if (m.default_field && document.getElementById(m.default_field))
    {
        var diff = false;
        if (controlled._oldDefault)
        {
            // Check if the value is different from previous default
            if (controlled.nodeName == 'SELECT')
            {
                var copt = getSelectedIds(controlled);
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
        // Remember default value for the new controller
        var v = m.default_value;
        if (field_metadata[m.default_field]['defaults'][controlled_id])
        {
            for (var i in getSelectedIds(m.default_field))
            {
                v = field_metadata[m.default_field]['defaults'][controlled_id][i];
            }
        }
        controlled._oldDefault = v;
        if (!diff && !is_initial_editform)
        {
            setFieldValue(controlled, v);
        }
    }
}

// FIXME: Remove partially duplicated code with query-visibility.js:reflowFieldRows()
function reflowFieldColumns()
{
    var cols = [];
    var fields = [];
    var visible = 0;
    for (var i = 1, e; e = document.getElementById('bz_custom_column_'+i); i++)
    {
        cols.push(e);
        for (var j = 0; j < e.childNodes.length; j++)
        {
            if (hasClass(e.childNodes[j], 'bug_field'))
            {
                var v = hasClass(e.childNodes[j], 'bz_hidden_field') ? 0 : 1;
                fields.push([ e.childNodes[j], v ]);
                visible += v;
            }
        }
    }
    var changed = false;
    for (var cur_col = 0, j = 0, pushed = 0; cur_col < 4; cur_col++)
    {
        var per_col = Math.ceil((visible-pushed)/(4-cur_col));
        var v = 0;
        for (; j < fields.length; v += fields[j][1], j++)
        {
            if ((v + Math.ceil(fields[j][1]/2)) > per_col)
            {
                break;
            }
            if (changed || fields[j][0].parentNode != cols[cur_col])
            {
                cols[cur_col].appendChild(fields[j][0]);
                changed = true;
            }
        }
        pushed += v;
    }
}
