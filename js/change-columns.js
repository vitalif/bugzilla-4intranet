/* The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is the Bugzilla Bug Tracking System.
 *
 * The Initial Developer of the Original Code is Pascal Held.
 *
 * Contributor(s): Pascal Held <paheld@gmail.com>
 */

function initChangeColumns()
{
    window.onunload = unload;
    var av_select = document.getElementById("available_columns");
    var sel_select = document.getElementById("selected_columns");
    var l = ['avail_header', av_select, 'select_button',
         'deselect_button', 'up_button', 'down_button'];
    for (var i = 0; i < l.length; i++)
        removeClass(l[i], 'bz_default_hidden');
    switch_options(sel_select, av_select, false);
    sel_select.selectedIndex = -1;
    updateView();
}

function switch_options(from_box, to_box, selected)
{
    var sel = [];
    for (var i = 0; i < from_box.options.length; i++)
        sel[i] = from_box.options[i].selected;
    var newlist = [];
    for (var i = from_box.options.length-1; i >= 0; i--)
    {
        if (sel[i] == selected)
        {
            var opt = from_box.options[i];
            var newopt = new Option(opt.text, opt.value, opt.defaultselected, sel[i]);
            newlist.unshift(newopt);
            from_box.removeChild(opt);
            sel.splice(i, 1);
        }
    }
    for (var i in newlist)
        to_box.options.add(newlist[i]);
    for (var i in sel)
        from_box.options[i].selected = sel[i];
}

function move_select()
{
    var av_select = document.getElementById("available_columns");
    var sel_select = document.getElementById("selected_columns");
    switch_options(av_select, sel_select, true);
    updateView();
}

function move_deselect()
{
    var av_select = document.getElementById("available_columns");
    var sel_select = document.getElementById("selected_columns");
    switch_options(sel_select, av_select, true);
    updateView();
}

function move_up()
{
    var sel_select = document.getElementById("selected_columns");
    if (sel_select.options.length < 2)
        return;
    var newopt = [ sel_select.options[0] ];
    var sel = [ sel_select.options[0].selected ];
    for (var i = 1; i < sel_select.options.length; i++)
    {
        var opt = sel_select.options[i];
        if (opt.selected)
        {
            var n = newopt.pop();
            newopt.push(opt);
            newopt.push(n);
            sel.push(sel[i-1]);
            sel[i-1] = true;
        }
        else
        {
            sel.push(false);
            newopt.push(opt);
        }
    }
    while (sel_select.childNodes.length)
        sel_select.removeChild(sel_select.childNodes[0]);
    for (var i = 0; i < newopt.length; i++)
        sel_select.appendChild(newopt[i]);
    for (var i = 0; i < sel.length; i++)
        sel_select.options[i].selected = sel[i];
    updateView();
}

function move_down()
{
    var sel_select = document.getElementById("selected_columns");
    if (sel_select.options.length < 2)
        return;
    var newopt = [ sel_select.options[sel_select.options.length-1] ];
    var sel = [ sel_select.options[sel_select.options.length-1].selected ];
    for (var i = sel_select.options.length-2; i >= 0; i--)
    {
        var opt = sel_select.options[i];
        if (opt.selected)
        {
            newopt.unshift(newopt[0]);
            newopt[1] = opt;
            sel.unshift(sel[0]);
            sel[1] = opt.selected;
        }
        else
        {
            newopt.unshift(opt);
            sel.unshift(opt.selected);
        }
    }
    while (sel_select.childNodes.length)
        sel_select.removeChild(sel_select.childNodes[0]);
    for (var i = 0; i < newopt.length; i++)
        sel_select.appendChild(newopt[i]);
    for (var i = 0; i < sel.length; i++)
        sel_select.options[i].selected = sel[i];
    updateView();
}

function updateView()
{
    var select_button = document.getElementById("select_button");
    var deselect_button = document.getElementById("deselect_button");
    var up_button = document.getElementById("up_button");
    var down_button = document.getElementById("down_button");
    select_button.disabled = true;
    deselect_button.disabled = true;
    up_button.disabled = true;
    down_button.disabled = true;
    var av_select = document.getElementById("available_columns");
    var sel_select = document.getElementById("selected_columns");
    for (var i = 0; i < av_select.options.length; i++)
    {
        if (av_select.options[i].selected)
        {
            select_button.disabled = false;
            break;
        }
    }
    for (var i = 0; i < sel_select.options.length; i++)
    {
        if (sel_select.options[i].selected)
        {
            deselect_button.disabled = false;
            up_button.disabled = false;
            down_button.disabled = false;
            break;
        }
    }
    if (sel_select.options.length > 0)
    {
        if (sel_select.options[0].selected)
            up_button.disabled = true;
        if (sel_select.options[sel_select.options.length - 1].selected)
            down_button.disabled = true;
    }
}

function change_submit()
{
    var sel_select = document.getElementById("selected_columns");
    for (var i = 0; i < sel_select.options.length; i++)
        sel_select.options[i].selected = true;
    return false;
}

function unload()
{
    var sel_select = document.getElementById("selected_columns");
    for (var i = 0; i < sel_select.options.length; i++)
        sel_select.options[i].selected = true;
}
