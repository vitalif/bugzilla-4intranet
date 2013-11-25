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
 * Contributor(s):
 *   Guy Pyrzak <guy.pyrzak@gmail.com>
 *   Max Kanat-Alexander <mkanat@bugzilla.org>
 */

var mini_login_constants;

function show_mini_login_form( suffix )
{
    var login_link = document.getElementById('login_link' + suffix);
    var login_form = document.getElementById('mini_login' + suffix);
    var account_container = document.getElementById('new_account_container' + suffix);
    addClass(login_link, 'bz_default_hidden');
    removeClass(login_form, 'bz_default_hidden');
    addClass(account_container, 'bz_default_hidden');
    login_form._shown = true;
    return false;
}

function hide_mini_login_form( suffix )
{
    var login_link = document.getElementById('login_link' + suffix);
    var login_form = document.getElementById('mini_login' + suffix);
    var account_container = document.getElementById('new_account_container' + suffix);
    removeClass(login_link, 'bz_default_hidden');
    addClass(login_form, 'bz_default_hidden');
    removeClass(account_container, 'bz_default_hidden');
    return false;
}

function show_forgot_form( suffix )
{
    var forgot_link = document.getElementById('forgot_link' + suffix);
    var forgot_form = document.getElementById('forgot_form' + suffix);
    var login_container = document.getElementById('mini_login_container' + suffix);
    addClass(forgot_link, 'bz_default_hidden');
    removeClass(forgot_form, 'bz_default_hidden');
    addClass(login_container, 'bz_default_hidden');
    return false;
}

function hide_forgot_form( suffix )
{
    var forgot_link = document.getElementById('forgot_link' + suffix);
    var forgot_form = document.getElementById('forgot_form' + suffix);
    var login_container = document.getElementById('mini_login_container' + suffix);
    removeClass(forgot_link, 'bz_default_hidden');
    addClass(forgot_form, 'bz_default_hidden');
    removeClass(login_container, 'bz_default_hidden');
    return false;
}

function init_mini_login_form( suffix )
{
    var mini_login = document.getElementById('Bugzilla_login' +  suffix );
    var mini_password = document.getElementById('Bugzilla_password' +  suffix );
    var mini_dummy = document.getElementById(
        'Bugzilla_password_dummy' + suffix);
    // If the login and password are blank when the page loads, we display
    // "login" and "password" in the boxes by default.
    if (mini_login.value == "" && mini_password.value == "")
    {
        mini_login.value = mini_login_constants.login;
        addClass(mini_login, "bz_mini_login_help");
        addClass(mini_password, 'bz_default_hidden');
        removeClass(mini_dummy, 'bz_default_hidden');
    }
    else
        show_mini_login_form(suffix);
}

// Clear the words "login" and "password" from the form when you click
// in one of the boxes. We clear them both when you click in either box
// so that the browser's password-autocomplete can work.
function mini_login_on_focus(suffix)
{
    var mini_login = document.getElementById('Bugzilla_login' + suffix);
    var mini_password = document.getElementById('Bugzilla_password' + suffix);
    var mini_dummy = document.getElementById('Bugzilla_password_dummy' + suffix);

    removeClass(mini_login, "bz_mini_login_help");
    if (mini_login.value == mini_login_constants.login)
        mini_login.value = '';
    removeClass(mini_password, 'bz_default_hidden');
    addClass(mini_dummy, 'bz_default_hidden');
}

function check_mini_login_fields(suffix)
{
    var mini_login = document.getElementById('Bugzilla_login' + suffix);
    var mini_password = document.getElementById('Bugzilla_password' + suffix);
    if (mini_login.value != "" && mini_password.value != "" &&
        mini_login.value != mini_login_constants.login)
        return true;
    window.alert(mini_login_constants.warning);
    return false;
}

function set_language(value)
{
    setCookie('LANG', value, {
        expires: new Date('January 1, 2038'),
        path: BUGZILLA.param.cookie_path
    });
    window.location.reload();
}

// Convert user list from API format for SimpleAutocomplete
function convertUserList(u)
{
    var data = [];
    for (var i = 0; i < u.length; i++)
        data.push([
            '<span class="hintRealname">' + htmlspecialchars(u[i].real_name) +
            '</span><br /><span class="hintEmail">' + htmlspecialchars(u[i].email) + '</span>',
            u[i].email
        ]);
    return data;
}

// Data loader for user autocomplete
function userAutocomplete(hint, emptyOptions)
{
    if (!hint.input.value)
    {
        hint.emptyText = 'Type at least 3 letters';
        if (emptyOptions)
            hint.replaceItems(convertUserList(emptyOptions));
        else
            hint.replaceItems(null);
        return;
    }

    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=User.get&output=json&maxusermatches=20&excludedisabled=1';
    var l = hint.input.value.split(/[\s,]*,[\s,]*/);
    for (var i = 0; i < l.length; i++)
        u += '&match='+encodeURI(l[i]);

    AjaxLoader(u, function(x) {
        var r = {};
        try { eval('r = '+x.responseText+';'); } catch (e) { return; }
        if (r.status == 'ok')
        {
            var data = convertUserList(r.users);
            // FIXME "3" constant, messages: remove hardcode, also in Bugzilla::User::match()
            if (data.length == 0 && hint.input.value.length < 3)
                hint.emptyText = 'Type at least 3 letters';
            else
                hint.emptyText = 'No users found';
            hint.replaceItems(data);
        }
    });
}


// Convert keyword list from API format for SimpleAutocomplete
function convertSimpleList(k)
{
    var data = [];
    for (var i = 0; i < k.length; i++)
        data.push([
        '<span class="hintRealname">' + k[i].name +
        '</span>',
        k[i].name
        ]);
    return data;
} 

// Data loader for keyword autocomplete
function keywordAutocomplete(hint, emptyOptions)
{
    if (!hint.input.value)
    {
        hint.emptyText = 'Type at least 3 letters';
        if (emptyOptions)
            hint.replaceItems(convertSimpleList(emptyOptions));
        else
            hint.replaceItems(null);
        return;
    }

    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=Keyword.get&output=json&maxkeywordmatches=20';
    var l = hint.input.value.split(/[\s,]*,[\s,]*/);
    for (var i = 0; i < l.length; i++)
        u += '&match='+encodeURI(l[i]);

    AjaxLoader(u, function(x) {
        var r = {};
        try { eval('r = '+x.responseText+';'); } catch (e) { return; }
        if (r.status == 'ok')
        {
            var data = convertSimpleList(r.keywords);
            // FIXME "3" constant, messages: remove hardcode, also in Bugzilla::User::match()
            if (data.length == 0 && hint.input.value.length < 3)
                hint.emptyText = 'Type at least 3 letters';
            else
                hint.emptyText = 'No keywords found';
            hint.replaceItems(data);
        }
    });
} 

// Data loader for field in buglist autocomplete
function fieldBuglistAutocomplete(hint, field, emptyOptions)
{
    var u = window.location.href.replace(/[^\/]+$/, '');
    u += 'xml.cgi?method=Field.get_values&output=json&field=' + field;
    AjaxLoader(u, function(x) {
        var r = {};
        try { eval('r = '+x.responseText+';'); } catch (e) { return; }
        if (r.status == 'ok')
        {
            var data = convertSimpleList(r.values);
            hint.replaceItems(data);
        }
    });
} 

function showFullComment(oper_id)
{
    if (existElement("removed_" + oper_id))
    {
        document.getElementById("removed_" + oper_id).style.display = 'none';
        document.getElementById("text_removed_" + oper_id).style.display = '';
    }
    if (existElement("added_" + oper_id))
    {
        document.getElementById("added_" + oper_id).style.display = 'none';
        document.getElementById("text_added_" + oper_id).style.display = '';
    }
    document.getElementById("link_" + oper_id).style.display = 'none';
}

// This basically duplicates Bugzilla::Util::display_value for code that
// can't go through the template and has to be in JS.
function display_value(field, value) {
    var translated = BUGZILLA.value_descs[field][value];
    if (translated) return translated;
    return value;
}
