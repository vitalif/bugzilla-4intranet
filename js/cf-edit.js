// Javascript for Custom Field creation/editing form
// License: Dual-license MPL 1.1+ or GPL 3.0+
// Author: Vitaliy Filippov <vitalif@mail.ru>

function onChangeType()
{
  var type_field = document.getElementById('type');
  var value_field = document.getElementById('value_field_id');
  if (type_field.value == constants.FIELD_TYPE_SINGLE_SELECT
      || type_field.value == constants.FIELD_TYPE_MULTI_SELECT)
    value_field.disabled = false;
  else
    value_field.disabled = true;
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

function onChangeEnterBug()
{
  var c = document.getElementById('new_bugmail');
  c.disabled = !document.getElementById('enter_bug').checked;
  if (c.disabled)
    c.checked = false;
}
