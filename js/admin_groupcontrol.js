/* JS for new group control UI
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Andrey Krasilnikov, Vitaliy Filippov
 */

var exist_changes = false;

function helpToggle(btn_id, div_id)
{
    var b = document.getElementById(btn_id);
    var d = document.getElementById(div_id);
    if (d.style.display == 'none')
    {
        b.value = L('Hide \u25B4');
        d.style.display = '';
    }
    else
    {
        b.value = L('Show \u25BE');
        d.style.display = 'none';
    }
}

function copySelect(prefix, suffix)
{
    var o = document.getElementById(prefix+'new');
    var e = document.createElement('select');
    e.id = e.name = prefix+suffix;
    e.innerHTML = o.innerHTML;
    e.selectedIndex = o.selectedIndex;
    return e;
}

function flashItem(e)
{
    var i = 0;
    clearTimeout(e.flashIntervalId);
    e.style.background = 'red';
    e.flashIntervalId = setInterval(function()
    {
        if (++i < 6)
            e.style.background = e.style.backgroundColor == 'red' ? '' : 'red';
        else
            clearTimeout(e.flashIntervalId);
    }, 100);
}

function addListGroup(list_name)
{
    var group_select = document.getElementById('add_'+list_name);
    var group_id = group_select.value;
    var group_name = group_select.options[group_select.selectedIndex].text;
    var added_li = document.getElementById('li_'+list_name+'_'+group_id);
    if (added_li)
    {
        // Flash the already added group entry
        document.getElementById(list_name+'_'+group_id).focus();
        flashItem(added_li);
        return;
    }
    added_li = document.getElementById('li_'+list_name+'_empty');
    if (added_li)
        added_li.parentNode.removeChild(added_li);
    added_li = document.createElement('li');
    added_li.id = 'li_'+list_name+'_'+group_id;
    var l = document.createElement('a');
    l.className = 'icon-delete';
    l.href = '#';
    l.setAttribute('onclick', 'deleteGroupCheckbox(\'' + list_name + '_' + group_id + '\'); return false;');
    added_li.appendChild(l);
    var e = document.createElement('input');
    e.type = 'checkbox';
    e.value = '1';
    e.checked = true;
    e.style.display = 'none';
    e.name = e.id = list_name+'_'+group_id;
    added_li.appendChild(e);
    e = document.createElement('label');
    e.htmlFor = list_name+'_'+group_id;
    e.appendChild(document.createTextNode(' ' + group_name));
    added_li.appendChild(e);
    var list = document.getElementById(list_name+'_list');
    list.appendChild(added_li);
    highlightButton();
}

function clearSelectedOption(el)
{
    var aValue = el.getAttribute("data-lastvalue");
    el.setAttribute("data-lastvalue", el.value);
    var options = el.options;
    var length = options.length;
    for (var i = 0; i < length; i++)
    {
        if (options[i].value == aValue)
        {
            options[i].selected = true;
            options[i].setAttribute("selected", "selected");
        }
        else
        {
            options[i].selected = false;
            options[i].removeAttribute("selected");
        }
    }
}

function deleteGroup(el_link, grp_id)
{
    var el = document.getElementById('control_' + grp_id);
    var el_group = document.getElementById('group_' + grp_id);
    var el_membercontrol = document.getElementById('membercontrol_' + grp_id);
    var el_othercontrol = document.getElementById('othercontrol_' + grp_id);
    if (el.getAttribute("data-deleted") == null)
    {
        el.setAttribute("data-deleted", "1")
        el.style.textDecoration = 'line-through';
        el_group.setAttribute('disabled', true);
        el_membercontrol.setAttribute('disabled', true);
        el_othercontrol.setAttribute('disabled', true);
        clearSelectedOption(el_membercontrol);
        clearSelectedOption(el_othercontrol);
        el_link.innerHTML = L('Undo delete');
    }
    else
    {
        el.removeAttribute("data-deleted");
        el.style.textDecoration = 'none';
        el_group.removeAttribute('disabled');
        el_membercontrol.removeAttribute('disabled');
        el_othercontrol.removeAttribute('disabled');
        clearSelectedOption(el_membercontrol);
        clearSelectedOption(el_othercontrol);
        el_link.innerHTML = L('Delete');
    }
    highlightButton();
}

function addNewGroup()
{
    if (existElement("control_empty"))
    {
        var empty_el = document.getElementById('control_empty');
        empty_el.parentNode.removeChild(empty_el);
    }

    var etalon_control = document.getElementById('etalon_control');
    var table = document.getElementById('control_list')
    var row = table.insertRow(-1);
    row.id = 'control_' + count_rows;
    var cell_groups = row.insertCell(0);
    var cell_control_1 = row.insertCell(1);
    var cell_control_2 = row.insertCell(2);
    var cell_empty = row.insertCell(3);
    var cell_action = row.insertCell(4);

    cell_action.innerHTML = '<a href="#" class="icon-delete" onclick="deleteGroup(this, ' + count_rows + '); return false;">'+L('Delete')+'</a>';
    var etalon_group = document.getElementById('etalon_groups');
    var new_group = document.createElement('select');
    new_group.id = 'group_' + count_rows;
    new_group.name = 'group_' + count_rows;
    new_group.onchange = 'saveNewGroup(this.value)';
    new_group.innerHTML = '<option></option>' + etalon_group.innerHTML;
    cell_groups.appendChild(new_group);

    var new_control_1 = document.createElement('select');
    new_control_1.id = 'membercontrol_' + count_rows;
    new_control_1.name = 'membercontrol_' + count_rows;
    new_control_1.innerHTML = etalon_control.innerHTML;
    cell_control_1.appendChild(new_control_1);
    var new_control_2 = document.createElement('select');
    new_control_2.id = 'othercontrol_' + count_rows;
    new_control_2.name = 'othercontrol_' + count_rows;
    new_control_2.innerHTML = etalon_control.innerHTML;
    cell_control_2.appendChild(new_control_2);
    count_rows++;
    highlightButton();
}

function deleteGroupCheckbox(el_id)
{
    if (existElement("li_" + el_id))
    {
        var empty_el = document.getElementById("li_" + el_id);
        empty_el.parentNode.removeChild(empty_el);
    }
    var params_arr = el_id.split('_');
    var exsist_list = document.getElementById(params_arr[0] + '_list');
    if (exsist_list.getElementsByTagName('li').length == 0)
    {
        added_li = document.createElement('li');
        added_li.id = 'li_' + params_arr[0] + '_empty';
        added_li.className = 'group_empty';
        added_li.innerHTML = L('&lt;no groups&gt;');
        exsist_list.appendChild(added_li);
    }
    highlightButton();
}

function highlightButton()
{
    if (!exist_changes)
    {
        document.getElementById('submit_group_control').className = 'submit_highlight';
        exist_changes = true;
    }
}
