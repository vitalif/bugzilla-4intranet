/* Functions for dynamically adding Boolean Charts fields
 * onto the Bugzilla Advanced Search Form.
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

function chart_add_second(btn)
{
    var n = btn.id.substr(5, btn.id.length-9);
    // Transform <div> to <fieldset>
    var d = document.getElementById('chart'+n);
    d.id = 'divchart'+n; // prevent id collisions
    btn.id = 'btnchart'+n; // prevent id collisions
    var op = (n != 'R' && n.indexOf('-') < 0 ? 'and' : 'or');
    // Create <fieldset>
    var f = document.createElement('fieldset');
    f.id = 'chart'+n;
    f.className = 'chart _'+op;
    var legend_html = op.toUpperCase() + ' ' +
        '<input type="button" value="+" class="chart_add_button" id="chart'+n+'-btn" onclick="chart_add(this.id)" />';
    // Create <legend>
    var l = document.createElement('legend');
    l.className = '_'+op;
    l.innerHTML = legend_html;
    f.appendChild(l);
    d.parentNode.insertBefore(f, d);
    btn.parentNode.removeChild(btn);
    d.parentNode.removeChild(d);
    while (d.childNodes.length)
        f.appendChild(d.childNodes[0]);
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
    d.appendChild(document.createTextNode(' '));
    d.appendChild(i);
}

// Find next available number for div with prefix 'n'
function chart_add_div(d, n)
{
    var i, nd;
    for (i = 0; document.getElementById(n+i); i++);
    nd = document.createElement('div');
    nd.id = n+i;
    nd.className = 'chart';
    d.appendChild(nd);
    return nd;
}

// Copy 'fieldx-x-x' or 'typex-x-x' selectbox
function chart_copy_select(cp_id, new_id)
{
    var s = document.createElement('select');
    s.id = s.name = new_id;
    var o = document.getElementById(cp_id).options;
    for (var i = 0; i < o.length; i++)
        bz_createOptionInSelect(s, o[i].text, o[i].value);
    s.selectedIndex = 0;
    return s;
}

// Add another term into chart when clicked on button with id=btnid
function chart_add(btnid)
{
    var d, i, add_and, add_or, n;
    d = document.getElementById(btnid.substr(0, btnid.length-4)); // chartN-btn
    if (d.id == 'chartR')
    {
        var clr = document.createElement('div');
        clr.style.clear = 'both';
        d.appendChild(clr);
        add_and = d = chart_add_div(d, 'chart');
    }
    if (d.id.indexOf('-') < 0)
        add_or = d = chart_add_div(d, d.id+'-');
    var cn = d.id.substr(5);
    for (i = 0; document.getElementById('field'+cn+'-'+i); i++);
    cn = cn+'-'+i;
    if (!add_or)
        d.appendChild(document.createElement('br'));
    // Append field-type-value inputs
    d.appendChild(chart_copy_select('field0-0-0', 'field'+cn));
    d.appendChild(chart_copy_select('type0-0-0', 'type'+cn));
    s = document.createElement('input');
    s.id = s.name = "value"+cn;
    s.size = 40;
    d.appendChild(s);
    if (add_and)
    {
        chart_add_btn(add_and, 'AND');
        // Add negate button
        var n = add_and.id.substr(5);
        var i = document.createElement('input');
        i.setAttribute('type', 'button');
        i.setAttribute('id', 'negate'+n+'-btn');
        i.setAttribute('onclick', 'chart_neg(this)');
        i.setAttribute('value', 'NOT');
        add_and.parentNode.appendChild(i);
        // Add hidden input for negate button
        i = document.createElement('input');
        i.type = 'hidden';
        i.name = i.id = 'negate'+n;
        document.getElementById('chartR').appendChild(i);
    }
    if (add_or)
        chart_add_btn(add_or, 'OR');
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
}

function chart_neg(btn)
{
    var chartid = /^negate(.*)-btn$/.exec(btn.id);
    chartid = chartid[1];
    document.getElementById('negate'+chartid).value = '1';
    btn.setAttribute('id', 'unneg'+chartid+'-btn');
    btn.setAttribute('onclick', 'chart_rm(this)');
    btn.setAttribute('value', '✘');
    btn.setAttribute('class', 'chart_rm_button');
    var fieldset = document.createElement('fieldset');
    fieldset.id = 'negchart'+chartid;
    fieldset.className = 'chart _neg';
    var l = document.createElement('legend');
    l.className = '_neg';
    l.appendChild(document.createTextNode(' NOT '));
    l.appendChild(btn);
    fieldset.appendChild(l);
    var c = document.getElementById('chart'+chartid);
    c.parentNode.insertBefore(fieldset, c);
    fieldset.appendChild(c);
}
