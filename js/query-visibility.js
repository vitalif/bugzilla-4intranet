/* JavaScript code to hide and show values of select fields on the query form */

var qfHandling = {};
YAHOO.util.Event.addListener(window, 'load', initQueryformFields);

function initQueryformFields()
{
  for (var i in qfVisibility)
  {
    if (!qfHandling[i])
      handleQueryformField(null, document.getElementById(i));
    initQueryformField(i);
  }
}

function initQueryformField(i)
{
  var f = document.getElementById(i);
  YAHOO.util.Event.addListener(f, 'change', handleQueryformField, f);
}

function getQueryformSelectedIds(sel)
{
  var opt = {};
  var a;
  var has_selected;
  var l2 = sel.id+4;
  for (var i = 0; i < sel.options.length; i++)
  {
    if (sel.options[i].selected)
    {
      has_selected = true;
      break;
    }
  }
  for (var i = 0; i < sel.options.length; i++)
  {
    if (sel.options[i].selected || !has_selected)
    {
      a = qfVisibility[sel.id]['name2id'][sel.options[i].value];
      if (sel.options[i].id)
        a = sel.options[i].id.substr(l2).split('_');
      for (var j in a)
        opt[a[j]] = true;
    }
  }
  return opt;
}

function getPlainSelectedIds(sel)
{
  var o = {};
  for (var i = 0; i < sel.options.length; i++)
    if (sel.options[i].selected)
      o[sel.options[i].value] = true;
  return o;
}

function handleQueryformField(e, controller)
{
  var visibility_selected = getQueryformSelectedIds(controller);
  var controlled, controlled_selected;
  var opt, vis, vislist, value_id, item;
  qfHandling[controller.id] = true;
  for (var controlled_id in qfVisibility[controller.id].values)
  {
    controlled = document.getElementById(controlled_id);
    if (!controlled)
      continue;
    controlled_selected = getPlainSelectedIds(controlled);
    bz_clearOptions(controlled);
    for (var i in qfVisibility[controlled_id]['legal'])
    {
      controlled_value = qfVisibility[controlled_id]['legal'][i];
      vislist = [];
      for (var j in qfVisibility[controlled_id]['name2id'][controlled_value])
      {
        value_id = qfVisibility[controlled_id]['name2id'][controlled_value][j];
        item = qfVisibility[controller.id]['values'][controlled_id][value_id];
        vis = true;
        if (item && visibility_selected)
        {
          for (var value in item)
          {
            if (vis)
              vis = false;
            if (visibility_selected[value])
            {
              vis = true;
              break;
            }
          }
        }
        if (vis)
          vislist.push(value_id);
      }
      if (vislist.length)
      {
        item = bz_createOptionInSelect(controlled, controlled_value, controlled_value);
        /* Save particular selected IDs for the same name
           for cascade selection of such fields.
           At the moment, only component, version and target_milestone fields
           can have many values with the same name, and they do not affect the
           case of cascade selection. */
        item.id = 'qf_'+controlled_id+'_'+vislist.join('_');
        if (controlled_selected[controlled_value])
          item.selected = true;
      }
    }
    handleQueryformField(e, controlled);
    /* Show/Hide field */
    item = document.getElementById(controlled_id+'_cont');
    if (item)
      item.style.display = controlled.options.length ? '' : 'none';
  }
}
