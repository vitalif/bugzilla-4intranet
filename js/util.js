/* Utility functions for Bugzilla scripts
 * Rewritten without YAHOO UI
 * License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

// Get the position of 'obj' from the page top
// Returns [x, y], in pixels
function findPos(obj)
{
    if (obj.offsetParent)
    {
        var r = [ 0, 0 ];
        while (obj)
        {
            r[0] += obj.offsetLeft;
            r[1] += obj.offsetTop;
            obj = obj.offsetParent;
        }
        return r;
    }
    else if (obj.y)
        return [ obj.x, obj.y ];
}

// Escape special HTML/XML characters
function htmlspecialchars(s)
{
    s = s.replace(/&/g, '&amp;'); //&
    s = s.replace(/</g, '&lt;'); //<
    s = s.replace(/>/g, '&gt;'); //>
    s = s.replace(/"/g, '&quot;'); //"
    return s;
}

// Checks if a specified value 'val' is in the specified array 'arr'
function bz_isValueInArray(arr, val)
{
    for (var i = arr.length-1; i >= 0; i--)
        if (arr[i] == val)
            return true;
    return false;
}

/**
 * Create wanted options in a select form control.
 *
 * @param  aSelect        Select form control to manipulate.
 * @param  aValue         Value attribute of the new option element.
 * @param  aTextValue     Value of a text node appended to the new option
 *                        element.
 * @return                Created option element.
 */
function bz_createOptionInSelect(aSelect, aTextValue, aValue)
{
    var myOption = new Option(aTextValue, aValue);
    aSelect.options[aSelect.length] = myOption;
    return myOption;
}

/**
 * Clears all options from a select form control.
 *
 * @param  aSelect    Select form control of which options to clear.
 */
function bz_clearOptions(aSelect)
{
    var length = aSelect.options.length;
    for (var i = 0; i < length; i++)
        aSelect.removeChild(aSelect.options[0]);
}

/**
 * Takes an array and moves all the values to an select.
 *
 * @param aSelect         Select form control to populate. Will be cleared
 *                        before array values are created in it.
 * @param aArray          Array with values to populate select with.
 */
function bz_populateSelectFromArray(aSelect, aArray)
{
    // Clear the field
    bz_clearOptions(aSelect);
    for (var i = 0; i < aArray.length; i++)
    {
        var item = aArray[i];
        bz_createOptionInSelect(aSelect, item[1], item[0]);
    }
}

/**
 * Tells you whether or not a particular value is selected in a select,
 * whether it's a multi-select or a single-select. The check is 
 * case-sensitive.
 *
 * @param aSelect        The select you're checking.
 * @param aValue         The value that you want to know about.
 */
function bz_valueSelected(aSelect, aValue)
{
    var options = aSelect.options;
    for (var i = 0; i < options.length; i++)
        if (options[i].selected && options[i].value == aValue)
            return true;
    return false;
}

/**
 * Tells you where (what index) in a <select> a particular option is.
 * Returns -1 if the value is not in the <select>
 *
 * @param aSelect       The select you're checking.
 * @param aValue        The value you want to know the index of.
 */
function bz_optionIndex(aSelect, aValue)
{
    for (var i = 0; i < aSelect.options.length; i++)
        if (aSelect.options[i].value == aValue)
            return i;
    return -1;
}

/**
 * Used to fire an event programmatically.
 *
 * @param anElement      The element you want to fire the event of.
 * @param anEvent        The name of the event you want to fire, 
 *                       without the word "on" in front of it.
 */
function bz_fireEvent(anElement, anEvent)
{
    // IE
    if (document.createEventObject)
    {
        var evt = document.createEventObject();
        return anElement.fireEvent('on' + anEvent, evt);
    }
    // Firefox, etc.
    var evt = document.createEvent("HTMLEvents");
    evt.initEvent(anEvent, true, true); // event type, bubbling, cancelable
    return !anElement.dispatchEvent(evt);
}

/* map { $_ => 1 } %h */
function array_hash(ar)
{
    var h = {};
    if (ar.length == 1 && ar[0].length == 0)
        return h;
    for (i in ar)
        h[ar[i]] = 1;
    return h;
}

/* Calculates the difference between two arrays.
     from, to ---> added, removed
     [a,b,c], [d,b] ---> {d:1},{a:1,c:1} */
function diff_arrays(a1, a2)
{
    var h1 = array_hash(a1);
    var h2 = array_hash(a2);
    var add = {}, rem = {};
    for (i in a1)
        if (!h2[a1[i]])
            rem[a1[i]] = 1;
    for (i in a2)
        if (!h1[a2[i]])
            add[a2[i]] = 1;
    return [ add, rem ];
}

/* join ",", grep { $h{$_} } keys %h */
function hash_join(h)
{
    var a = [];
    for (i in h)
        if (h[i])
            a.push(i);
    return a.join(", ");
}

/* CustIS Bug 64559 - Submit form on Ctrl-Enter */
function ctrlEnter(event, formElem)
{
    if (event.ctrlKey && (event.keyCode == 0xA || event.keyCode == 0xD))
    {
        formElem.commit.click();
        return false;
    }
    return true;
}

if (typeof Node == 'undefined') {
    /* MSIE doesn't define Node, so provide a compatibility object */
    window.Node = {
        TEXT_NODE: 3,
        ENTITY_REFERENCE_NODE: 5
    };
}

/* Concatenates all text from element's childNodes. This is used
 * instead of innerHTML because we want the actual text (and
 * innerText is non-standard).
 */
function getText(element) {
    var child, text = "";
    for (var i=0; i < element.childNodes.length; i++) {
        child = element.childNodes[i];
        var type = child.nodeType;
        if (type == Node.TEXT_NODE || type == Node.ENTITY_REFERENCE_NODE) {
            text += child.nodeValue;
        } else if (child.nodeName.toLowerCase() == 'br') {
            text += "\n";
        } else {
            /* recurse into nodes of other types */
            text += getText(child);
        }
    }
    return text;
}

/* Functions for comment preview */

// pseudo-ajax through form submit to an invisible iframe
// probably this could be replaced with conventional AJAX (jQuery...)
// but this also works good
window.iframeajax_call = 0;
window.iframeajax = function(url, data)
{
    var f = document.createElement('form');
    var i = document.createElement('iframe');
    f.target = i.name = i.id = 'iframeajax_'+(window.iframeajax_call++);
    f.method = 'POST';
    f.action = url;
    var d = document.createElement('div');
    d.id = 'div_'+i.id;
    data['iframeajaxid'] = i.id.substr(11);
    for (var k in data)
    {
        var n = document.createElement('input');
        n.type = 'hidden';
        n.name = k;
        n.value = data[k];
        f.appendChild(n);
    }
    d.style.display = 'none';
    d.appendChild(f);
    d.appendChild(i);
    document.body.appendChild(d);
    window.frames[i.id].name = i.id;
    addListener(i, 'load', function() {
        i.contentWindow.loaded();
        i.parentNode.removeChild(i);
    });
    f.submit();
};

window.addListener = function(obj, event, handler)
{
    if (typeof(obj) == 'string')
        obj = document.getElementById(obj);
    if (!obj)
        return;
    if (obj.addEventListener)
        obj.addEventListener(event, handler, false);
    else if (obj.attachEvent)
    {
        obj._attached = obj._attached || {};
        obj._attached[handler] = function() { handler.call(obj, window.event) };
        obj.attachEvent('on'+event, obj._attached[handler]);
    }
};
window.removeListener = function(obj, event, handler)
{
    if (typeof(obj) == 'string')
        obj = document.getElementById(obj);
    if (!obj)
        return;
    if (obj.addEventListener)
        obj.removeEventListener(event, handler, false);
    else if (obj.attachEvent && obj._attached && obj._attached[handler])
    {
        obj.detachEvent('on'+event, obj._attached[handler]);
        obj._attached[handler] = null;
    }
};
window.eventTarget = function(ev)
{
    if (!ev) var ev = window.event;
    var t = ev.target;
    if (!t) t = ev.srcElement;
    if (t && t.nodeType == 3) t = t.parentNode;
    return t;
};

/**
 * addClass     : add CSS class to an element
 *                returns (void)
 * removeClass  : remove CSS class from element
 *                returns (modified => true)
 * hasClass     : check if element has the specified CSS class
 *                returns (has class => true)
 * toggleClass  : add / remove CSS class if object doesn't have it / has it.
 *                returns (has class after toggle => true)
 * FIXME all have jQuery alternatives
 *
 * @param anElement/obj  The element to toggle the class on
 * @param aClass/c       The name of the CSS class to toggle.
 */
window.addClass = function(obj, c)
{
    if (typeof(obj) == 'string')
        obj = document.getElementById(obj);
    if (obj)
        obj.className = obj.className+' '+c;
};
window.removeClass = function(obj, c)
{
    if (typeof(obj) == 'string')
        obj = document.getElementById(obj);
    if (!obj)
        return false;
    var l = obj.className.split(/\s+/);
    var l1 = [];
    for (var i = l.length-1; i >= 0; i--)
        if (l[i] != c)
            l1.push(l[i]);
    obj.className = l1.length ? l1.join(' ') : '';
    return l1.length != l.length;
};
window.hasClass = function(obj, c)
{
    if (typeof(obj) == 'string')
        obj = document.getElementById(obj);
    var l = obj.className.split(/\s+/);
    for (var i = l.length-1; i >= 0; i--)
        if (l[i] == c)
            return true;
    return false;
};
window.toggleClass = function(anElement, aClass)
{
    if (typeof(anElement) == 'string')
        anElement = document.getElementById(anElement);
    if (hasClass(anElement, aClass))
    {
        removeClass(anElement, aClass);
        return false;
    }
    else
    {
        addClass(anElement, aClass);
        return true;
    }
};

window.scrollDocTo = function(obj) { window.scroll(0, findPos(obj)[1]); }
window.scrTo = function(id) { scrollDocTo(document.getElementById(id)); }
window.hidepreview = function()
{
    document.getElementById('wrapcommentpreview').style.display = 'none';
};
window.showcommentpreview = function(textarea_id)
{
    document.getElementById('wrapcommentpreview').style.display = '';
    iframeajax('page.cgi?id=previewcomment.html', { 'comment': document.getElementById(textarea_id || 'comment_textarea').value });
    scrTo('wrapcommentpreview');
};

RegExp.escape = function(text) {
    if (!arguments.callee.sRE) {
        var specials = [
            '/', '.', '*', '+', '?', '|',
            '(', ')', '[', ']', '{', '}', '\\'
        ];
        arguments.callee.sRE = new RegExp(
            '(\\' + specials.join('|\\') + ')', 'g'
        );
    }
    return text.replace(arguments.callee.sRE, '\\$1');
};

/* Parse time in hours:
     "1,5" or "1:30" (HH:MM) = 1.5,
     "1.5d" (days) = 12 */
function bzParseTime(time)
{
    time = time+"";
    time = time.replace(',','.');
    if (m = time.match(/^\s*(-?)(\d+):(\d+)\s*$/))
    {
        for (var i = 2; i < 5; i++)
        {
            if (!m[i]) m[i] = 0;
            else m[i] = parseInt(m[i]);
        }
        if (!m[1]) m[1] = '';
        time = Math.floor(parseFloat(m[1] + (m[2] + m[3]/60))*100+0.5)/100;
    }
    else if (m = time.match(/^\s*(-?\d+(?:\.\d+)?)d\s*$/))
        time = parseFloat(m[1])*8;
    else
        time = parseFloat(time);
    return time;
};

/* Gets named cookie */
window.getCookie = function(name)
{
    var matches = document.cookie.match(new RegExp(
        "(?:^|; )" + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, '\\$1') + "=([^;]*)"
    ));
    return matches ? decodeURIComponent(matches[1]) : undefined;
};

/* Sets a new cookie name=value
     props: {expires:, path:, domain:, secure:, httponly:} */
window.setCookie = function(name, value, props)
{
    props = props || {};
    var exp = props.expires;
    if (typeof exp == "number" && exp)
    {
        var d = new Date();
        d.setTime(d.getTime() + exp*1000);
        exp = props.expires = d;
    }
    if (exp && exp.toUTCString)
        props.expires = exp.toUTCString();

    value = encodeURIComponent(value);
    var updatedCookie = name + "=" + value;
    for (var propName in props)
    {
        updatedCookie += "; " + propName;
        var propValue = props[propName];
        if (propValue !== true)
            updatedCookie += "=" + propValue;
    }
    document.cookie = updatedCookie;
};

/* Removes named cookie */
window.deleteCookie = function(name)
{
    setCookie(name, null, { expires: -1 });
};
