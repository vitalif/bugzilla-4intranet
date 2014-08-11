// Javascript for Custom Field creation/editing form
// License: Dual-license MPL 1.1+ or GPL 3.0+
// Author: Vitaliy Filippov <vitalif@mail.ru>

function onChangeType()
{
    var type_field = document.getElementById('type');
    var value_field = document.getElementById('value_field_id');
    if (type_field.value == constants.FIELD_TYPE_SINGLE_SELECT ||
        type_field.value == constants.FIELD_TYPE_MULTI_SELECT)
    {
        value_field.disabled = false;
        document.getElementById('value_field_row').style.display = '';
        if (document.getElementById('action').value == 'new')
        {
            document.getElementById('default_value_row').style.display = 'none';
            document.getElementById('value_class_span').style.display = '';
        }
    }
    else
    {
        value_field.disabled = true;
        document.getElementById('value_field_row').style.display = 'none';
        if (document.getElementById('action').value == 'new')
        {
            document.getElementById('default_value_row').style.display = '';
            document.getElementById('value_class_span').style.display = 'none';
        }
    }
    document.getElementById('default_value_row').style.display =
        type_field.value == constants.FIELD_TYPE_BUG_ID_REV ||
        type_field.value == constants.FIELD_TYPE_SINGLE_SELECT ||
        type_field.value == constants.FIELD_TYPE_MULTI_SELECT ? 'none' : '';
    var rev_value_field = document.getElementById('bug_id_rev_value_field_id');
    if (type_field.value == constants.FIELD_TYPE_BUG_ID_REV)
    {
        rev_value_field.name = 'value_field_id';
        value_field.name = '';
        document.getElementById('bug_id_rev_row').style.display = '';
    }
    else
    {
        rev_value_field.name = '';
        value_field.name = 'value_field_id';
        document.getElementById('bug_id_rev_row').style.display = 'none';
    }
    document.getElementById('add_to_deps_row').style.display
        = type_field.value == constants.FIELD_TYPE_BUG_ID ? '' : 'none';
    var u = document.getElementById('nullable');
    u.disabled = type_field.value == constants.FIELD_TYPE_MULTI_SELECT ||
        type_field.value == constants.FIELD_TYPE_BUG_ID_REV;
    if (u.disabled)
        u.checked = false;
    u = type_field.value == constants.FIELD_TYPE_EXTURL;
    document.getElementById('url_row').style.display = u ? '' : 'none';
    onChangeNullable();
}

function onChangeNullable()
{
    var u = document.getElementById('nullable');
    var n = document.getElementById('allow_null_in_row');
    var c = document.getElementById('null_field_id_row');
    c.style.display = u.checked ? '' : 'none';
    if (n)
        n.style.display = c.style.display;
}

function onChangeCloned()
{
    var u = document.getElementById('clone_bug');
    var n = document.getElementById('allow_clone_in_row');
    var c = document.getElementById('clone_field_id_row');
    c.style.display = u.checked ? '' : 'none';
    if (n)
        n.style.display = c.style.display;
}

function onChangeSortkey()
{
    var s = parseInt(document.getElementById('sortkey').value);
    s = s && s == s ? (s < 4000 ? 1+Math.floor(s/1000) : 4) : 1;
    for (var i = 1; i <= 4; i++)
    {
        var e = document.getElementById('sortkey_col'+i);
        if (e)
        {
            e.style.display = i == s ? '' : 'none';
        }
    }
}
