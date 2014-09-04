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

function fieldHintLoader(hint, value, more)
{
    if (value == hint.input.getAttribute('value'))
    {
        value = '';
    }
    var j, l = value.length ? value.trim().split(/[\s,]*,[\s,]*/) : [];
    for (j = 0; j < l.length; j++)
    {
        l[j] = l[j].toLowerCase();
    }
    // Get current IDs as hash
    var ids = hint.input.getAttribute('data-ids');
    ids = ids.length ? ids.split(',') : [];
    var idh = {};
    for (j = 0; j < ids.length; j++)
    {
        idh[ids[j]] = true;
    }
    // Get value visibility data, if applicable
    var vv, h;
    var m = field_metadata[hint.input.id];
    if (m.value_field && document.getElementById(m.value_field))
    {
        vv = getSelectedIds(m.value_field);
        h = field_metadata[m.value_field].values[hint.input.id];
    }
    // Create null option, if applicable
    var o = [];
    var nullable = m.nullable && !m.multiple;
    if (m.null_field && nullable)
    {
        nullable = checkValueVisibility(getSelectedIds(m.null_field), field_metadata[m.null_field]['null'][hint.input.id]);
    }
    if (nullable && !l.length)
    {
        o.push([ '<span class="hintRealname">---</span>', '' ]);
    }
    // Fill options
    for (var i in m.legal)
    {
        var kw = m.legal[i];
        var vis = m.multiple && idh[kw[0]]; // always show selected values
        if (!vis && (!vv || checkValueVisibility(vv, h[kw[0]])))
        {
            for (j = 0; j < l.length; j++)
            {
                // show matching values
                if (kw[1].toLowerCase().indexOf(l[j]) >= 0)
                {
                    break;
                }
            }
            vis = !l.length || j < l.length;
        }
        if (vis)
        {
            o.push([
                '<span class="hintRealname">' + htmlspecialchars(kw[1]) + '</span>',
                kw[1], false, idh[kw[0]], kw[0]
            ]);
        }
    }
    hint.replaceItems(o);
}

function fieldHintMakeInput(field, id, name)
{
    var a = document.getElementById('v'+item[4]+'_'+field.id);
    if (!a)
    {
        a = document.createElement('input');
        a.id = 'v'+item[4]+'_'+field.id;
        a.name = field.id;
        a.type = 'hidden';
        a.value = item[1];
        field.parentNode.insertBefore(a, field);
    }
}

function fieldHintRemoveInput(field, id)
{
    var a = document.getElementById('v'+id+'_'+field.id);
    if (a)
    {
        a.parentNode.removeChild(a);
    }
}

function fieldHintChangeListener(hint, index, item)
{
    var m = field_metadata[hint.input.id];
    var ids = hint.input.getAttribute('data-ids');
    if (m.multiple)
    {
        if (item[3])
        {
            hint.input.setAttribute('data-ids', ids+(ids.length ? ',' : '')+item[4]);
            fieldHintMakeInput(hint.input, item[4], item[1]);
        }
        else if (ids.length)
        {
            var a = ids.split(',');
            for (var i = a.length-1; i >= 0; i--)
            {
                if (a[i] == item[4])
                {
                    a.splice(i, 1);
                }
            }
            hint.input.setAttribute('data-ids', a.join(','));
            fieldHintRemoveInput(hint.input, item[4]);
        }
    }
    else
    {
        hint.input.setAttribute('data-ids', item[4]);
    }
    handleControllerField_this.apply(hint.input);
}

function initControlledField(id)
{
    var f = document.getElementById(id);
    if (f && field_metadata[id].use_combobox)
    {
        var p = {};
        if (field_metadata[id].multiple)
        {
            p.multipleListener = fieldHintChangeListener;
        }
        else
        {
            p.onChangeListener = fieldHintChangeListener;
        }
        var s = new SimpleAutocomplete(f, fieldHintLoader, p);
        if (field_metadata[id].multiple)
        {
            s.show = function()
            {
                if (SimpleAutocomplete.prototype.show.apply(s))
                {
                    f.value = '';
                    s.onChange(true);
                }
            };
            s.hide = function()
            {
                if (SimpleAutocomplete.prototype.hide.apply(s))
                {
                    var ids = f.getAttribute('data-ids');
                    ids = ids.length ? ids.split(',') : [];
                    for (var i = 0; i < ids.length; i++)
                        ids[i] = document.getElementById('v'+ids[i]+'_'+f.id).value;
                    f.value = ids.join(', ');
                }
            };
        }
    }
    if (f && document.forms['Create'] && field_metadata[id].default_value)
    {
        // Check if anything is selected initially on the entry form
        var copt = getSelectedValues(f);
        delete copt[''];
        var nonempty = false;
        for (var i in copt)
        {
            nonempty = true;
        }
        // Select global default value before selecting dependent ones
        if (!nonempty)
        {
            f._oldDefault = setFieldValue(f, field_metadata[id].default_value);
        }
        else
        {
            f._oldDefault = field_metadata[id].default_value;
            if (f.nodeName == 'SELECT')
            {
                f._oldDefault = f._oldDefault.split(',');
            }
            else
            {
                f._oldDefault = [ f._oldDefault ];
            }
        }
    }
    if (!f || f.nodeName != 'INPUT' || f.type != 'hidden')
    {
        handleControlledField(id, !document.forms['Create']);
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
    else if (field_metadata[f.id].use_combobox)
    {
        // new values
        var a = v.length ? v.split(',') : [];
        var h = {};
        var nh = 0;
        var nn = [];
        for (var i in a)
        {
            h[a[i]] = true;
            nh++;
        }
        a = f.getAttribute('data-ids');
        a = a.length ? a.split(',') : [];
        var ids = {};
        for (var i in a)
        {
            ids[a[i]] = true;
            if (!h[a[i]])
            {
                fieldHintRemoveInput(f, a[i]);
            }
            else
            {
                nn.push(document.getElementById('v'+a[i]+'_'+f.id).value);
                delete h[a[i]];
                nh--;
            }
        }
        if (nh)
        {
            var l = field_metadata[f.id].legal;
            // FIXME: Not good to iterate over all values to find names for given IDs...
            for (var i in l)
            {
                if (h[l[i][0]])
                {
                    nn.push(l[i][1]);
                    fieldHintMakeInput(f, l[i][0], l[i][1]);
                }
            }
        }
        f.setAttribute('data-ids', v);
        f.value = nn.join(', ');
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
    else if (m.use_combobox)
    {
        controlled.SimpleAutocomplete_input.onChange();
        return;
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
            nullable = nullable || controlled_id == 'component' && document.forms['Create'];
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
    if (m.default_field && document.getElementById(m.default_field) && 0)
    {
        var diff = false;
        if (controlled._oldDefault !== undefined)
        {
            // Check if the value is different from previous default
            if (controlled.nodeName == 'SELECT')
            {
                var copt = getSelectedIds(controlled);
                for (var i in controlled._oldDefault || {})
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
        v = v || null;
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
