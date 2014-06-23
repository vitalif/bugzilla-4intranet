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
  }
  else
  {
    value_field.disabled = true;
    document.getElementById('value_field_row').style.display = 'none';
  }
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
  document.getElementById('add_to_deps').style.display
    = document.getElementById('add_to_deps_title').style.display
    = type_field.value == constants.FIELD_TYPE_BUG_ID ? '' : 'none';
  var u = document.getElementById('nullable');
  u.disabled = type_field.value != constants.FIELD_TYPE_SINGLE_SELECT;
  if (u.disabled)
    u.checked = false;
  u = type_field.value == constants.FIELD_TYPE_EXTURL;
  document.getElementById('url_row').style.display
    = u ? '' : 'none';
}
