/* Functions for dynamically adding Boolean Charts fields
 * onto the Bugzilla Advanced Search Form.
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

addListener(window, 'beforeunload', function()
{
    // Save boolean charts upon window unload
    document.getElementById('boolean_chart_form_save').value = document.getElementById('boolean_chart_form').innerHTML;
});
onDomReady(function()
{
    // Restore boolean charts on clicking "Back"
    var v = document.getElementById('boolean_chart_form_save').value;
    if (v)
        document.getElementById('boolean_chart_form').innerHTML = v;
});

function chart_add_second(btn)
{
    var n = btn.id.substr(5, btn.id.length-9);
    // Transform <div> to <fieldset>
    var d = document.getElementById('chart'+n);
    btn.parentNode.removeChild(btn);
    var op = (n != 'R' && n.indexOf('-') < 0 ? 'and' : 'or');
    // Create <fieldset>
    var f = document.createElement('fieldset');
    f.setAttribute('id', 'chart'+n);
    f.setAttribute('class', 'chart _'+op);
    var legend_html = op.toUpperCase() +
        ' <input type="button" value="+" id="chart'+n+'-btn" onclick="chart_add(this.id)" />' +
        ' <input type="button" value="&#x2718;" class="chart_rm_button" id="rm'+n+'-btn" onclick="chart_rm(this)" />';
    // Create <legend>
    var l = document.createElement('legend');
    l.setAttribute('class', '_'+op);
    l.innerHTML = legend_html;
    f.appendChild(l);
    d.parentNode.insertBefore(f, d);
    d.parentNode.removeChild(d);
    while (d.childNodes.length)
    {
        f.appendChild(d.childNodes[0]);
    }
    // Add an operand
    chart_add('chart'+n+'-btn');
}

function chart_add_btn(d, s)
{
    var i = document.createElement('input');
    i.setAttribute('type', 'button');
    i.setAttribute('id', d.id+'-btn');
    i.setAttribute('onclick', 'chart_add_second(this)');
    i.setAttribute('value', s);
    d.appendChild(i);
}

// Find next available number for div with prefix 'n'
function chart_add_div(d, n)
{
    var i, nd;
    for (i = 0; document.getElementById(n+i); i++) {}
    nd = document.createElement('div');
    nd.setAttribute('id', n+i);
    nd.setAttribute('class', 'chart');
    d.appendChild(nd);
    return nd;
}

// Copy 'fieldx-x-x' or 'typex-x-x' selectbox
function chart_copy_select(cp_id, new_id)
{
    var s = document.createElement('select');
    s.setAttribute('id', new_id);
    s.setAttribute('name', new_id);
    var o = document.getElementById(cp_id).options;
    for (var i = 0; i < o.length; i++)
    {
        bz_createOptionInSelect(s, o[i].text, o[i].value);
    }
    s.selectedIndex = 0;
    return s;
}

// Add another term into chart when clicked on button with id=btnid
function chart_add(btnid)
{
    var d, i, n;
    d = document.getElementById(btnid.substr(0, btnid.length-4)); // chartN-btn
    if (d.id == 'chartR')
    {
        var clr = document.createElement('div');
        clr.setAttribute('style', 'clear: both');
        d.appendChild(clr);
        d = chart_add_div(d, 'chart');
        // Add 'AND' button
        chart_add_btn(d, 'AND');
        // Add negate button
        var n = d.id.substr(5);
        var i = document.createElement('input');
        i.setAttribute('type', 'button');
        i.setAttribute('id', 'negate'+n+'-btn');
        i.setAttribute('onclick', 'chart_neg(this)');
        i.setAttribute('value', 'NOT');
        d.parentNode.appendChild(i);
        // Add hidden input for negate button
        i = document.createElement('input');
        i.setAttribute('type', 'hidden');
        i.setAttribute('name', 'negate'+n);
        i.setAttribute('id', 'negate'+n);
        document.getElementById('chartR').appendChild(i);
    }
    if (d.id.indexOf('-') < 0)
    {
        d = chart_add_div(d, d.id+'-');
        // Add 'OR' button
        chart_add_btn(d, 'OR');
    }
    d = chart_add_div(d, d.id+'-');
    var cn = d.id.substr(5);
    // Append field-type-value inputs
    d.appendChild(chart_copy_select('field0-0-0', 'field'+cn));
    d.appendChild(chart_copy_select('type0-0-0', 'type'+cn));
    s = document.createElement('input');
    s.setAttribute('id', 'value'+cn);
    s.setAttribute('name', 'value'+cn);
    s.setAttribute('size', '40');
    d.appendChild(s);
}

function chart_rm(btn)
{
    var m;
    if (m = /^unneg(.*)-btn$/.exec(btn.id))
    {
        // Remove negation group
        document.getElementById('negate'+m[1]).value = '';
        var e = document.getElementById('negchart'+m[1]);
        var c = document.getElementById('chart'+m[1]);
        btn.setAttribute('id', 'negate'+m[1]+'-btn');
        btn.setAttribute('onclick', 'chart_neg(this)');
        btn.setAttribute('value', 'NOT');
        btn.setAttribute('class', '');
        e.parentNode.insertBefore(c, e);
        e.parentNode.insertBefore(btn, e);
        e.parentNode.removeChild(e);
    }
    else if (m = /^rm(.*)-btn$/.exec(btn.id))
    {
        // Remove last part of current chart
        var chartid = m[1] == 'R' ? '' : m[1]+'-';
        var i;
        for (i = 0; document.getElementById('chart'+chartid+i); i++) {}
        i--;
        if (i >= 1)
        {
            var e = document.getElementById('negchart'+chartid+i)
                || document.getElementById('chart'+chartid+i);
            if (e.previousSibling.nodeName == 'DIV' &&
                e.previousSibling.style.clear == 'both' &&
                e.previousSibling.childNodes.length == 0)
            {
                // Remove <div style="clear: both"></div> divider
                e.parentNode.removeChild(e.previousSibling);
            }
            e.parentNode.removeChild(e);
            if (e = document.getElementById('negate'+chartid+i+'-btn'))
                e.parentNode.removeChild(e);
            if (e = document.getElementById('negate'+chartid+i))
                e.parentNode.removeChild(e);
            if (i == 1)
            {
                // Remove fieldset
                var d = document.createElement('div');
                d.setAttribute('id', 'chart'+m[1]);
                d.setAttribute('class', 'chart');
                var f = document.getElementById('chart'+m[1]);
                while (f.childNodes.length)
                {
                    if (f.childNodes[0].nodeName == 'LEGEND')
                        f.removeChild(f.childNodes[0]);
                    else
                        d.appendChild(f.childNodes[0]);
                }
                chart_add_btn(d, f.className.indexOf('_and') >= 0 ? 'AND' : 'OR');
                f.parentNode.insertBefore(d, f);
                f.parentNode.removeChild(f);
            }
        }
    }
}

function chart_neg(btn)
{
    var chartid = /^negate(.*)-btn$/.exec(btn.id);
    chartid = chartid[1];
    document.getElementById('negate'+chartid).value = '1';
    btn.setAttribute('id', 'unneg'+chartid+'-btn');
    btn.setAttribute('onclick', 'chart_rm(this)');
    btn.setAttribute('value', '✘');
    var fieldset = document.createElement('fieldset');
    fieldset.setAttribute('id', 'negchart'+chartid);
    fieldset.setAttribute('class', 'chart _neg');
    var l = document.createElement('legend');
    l.setAttribute('class', '_neg');
    l.appendChild(document.createTextNode(' NOT '));
    l.appendChild(btn);
    fieldset.appendChild(l);
    var c = document.getElementById('chart'+chartid);
    c.parentNode.insertBefore(fieldset, c);
    fieldset.appendChild(c);
}
