/* License: Dual-license GPL 3.0+ or MPL 1.1+
 * Contributor(s): Vitaliy Filippov <vitalif@mail.ru>
 */

/* This file provides JavaScript functions to be included when one wishes
 * to show/hide certain UI elements, and have the state of them being
 * shown/hidden stored in a cookie.
 *
 * TUI stands for Tweak UI.
 *
 * Rewritten without YAHOO UI, requires just js/util.js.
 *
 * See template/en/default/bug/create/create.html.tmpl for a usage example.
 */

var TUI_HIDDEN_CLASS = 'bz_tui_hidden';
var TUI_COOKIE_NAME = 'TUI';
var TUI_alternates = new Array();

/**
 * Hides a particular class of elements if they are shown,
 * or shows them if they are hidden. Then it stores whether that
 * class is now hidden or shown.
 *
 * @param className   The name of the CSS class to hide.
 */
function TUI_toggle_class(className)
{
    var hidden = toggleRule('tui_css', '.'+className, 'display: none !important');
    TUI_store(className, hidden ? '' : '1');
    TUI_toggle_control_link(className);
}

/**
 * Specifies that a certain class of items should be hidden by default,
 * if the user doesn't have a TUI cookie.
 *
 * @param className   The class to hide by default.
 */
function TUI_hide_default(className)
{
    addListener(window, 'load', function() {
        if (!getCookieHash(TUI_COOKIE_NAME)[className])
            TUI_toggle_class(className);
    });
}

function TUI_toggle_control_link(className)
{
    var link = document.getElementById(className + "_controller");
    if (!link) return;
    var original_text = link.innerHTML;
    link.innerHTML = TUI_alternates[className];
    TUI_alternates[className] = original_text;
}

function getCookieHash(name)
{
    var c = getCookie(name)||'';
    c = c.split('&');
    var h = {};
    var t;
    for (var i = 0; i < c.length; i++)
    {
        t = c[i].split('=', 2);
        if (t[0].length)
            h[t[0]] = t[1];
    }
    return h;
}

function TUI_store(aClass, state)
{
    var h = getCookieHash(TUI_COOKIE_NAME);
    h[aClass] = state;
    var c = [];
    for (var i in h)
        c.push(i+'='+h[i]);
    c = c.join('&');
    setCookie(TUI_COOKIE_NAME, c, {
        expires: new Date('January 1, 2038'),
        path: BUGZILLA.param.cookiepath
    });
}

function toggleRule(css_id, target, rule)
{
    var s;
    if (!(s = document.getElementById(css_id)))
    {
        s = document.createElement('style');
        document.getElementsByTagName('head')[0].appendChild(s);
        s.setAttribute('id', css_id);
    }
    ss = s.sheet||s;
    var f = false;
    var r = ss.rules||ss.cssRules;
    for (var i = r.length-1; i >= 0; i--)
    {
        if (r[i].selectorText == target)
        {
            if (ss.removeRule)
                ss.removeRule(i);
            else
                ss.deleteRule(i);
            f = true;
        }
    }
    if (f)
        return false;
    if (ss.addRule)
        ss.addRule(target, rule);
    else
        s.appendChild(document.createTextNode(target+' { '+rule+' }'));
    return true;
}
