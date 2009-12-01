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
*
*/

var mini_login_constants;

function show_mini_login_form( suffix ) {
    var login_link = document.getElementById('login_link' + suffix);
    var login_form = document.getElementById('mini_login' + suffix);
    var account_container = document.getElementById('new_account_container'
                                                    + suffix);

    YAHOO.util.Dom.addClass(login_link, 'bz_default_hidden');
    YAHOO.util.Dom.removeClass(login_form, 'bz_default_hidden');
    YAHOO.util.Dom.addClass(account_container, 'bz_default_hidden');
    return false;
}

function hide_mini_login_form( suffix ) {
    var login_link = document.getElementById('login_link' + suffix);
    var login_form = document.getElementById('mini_login' + suffix);
    var account_container = document.getElementById('new_account_container'
                                                    + suffix);

    YAHOO.util.Dom.removeClass(login_link, 'bz_default_hidden');
    YAHOO.util.Dom.addClass(login_form, 'bz_default_hidden');
    YAHOO.util.Dom.removeClass(account_container, 'bz_default_hidden');
    return false;
}

function show_forgot_form( suffix ) {
    var forgot_link = document.getElementById('forgot_link' + suffix);
    var forgot_form = document.getElementById('forgot_form' + suffix);
    var login_container = document.getElementById('mini_login_container' 
                                                  + suffix);
    YAHOO.util.Dom.addClass(forgot_link, 'bz_default_hidden');
    YAHOO.util.Dom.removeClass(forgot_form, 'bz_default_hidden');
    YAHOO.util.Dom.addClass(login_container, 'bz_default_hidden');
    return false;
}

function hide_forgot_form( suffix ) {
    var forgot_link = document.getElementById('forgot_link' + suffix);
    var forgot_form = document.getElementById('forgot_form' + suffix);
    var login_container = document.getElementById('mini_login_container'
                                                  + suffix);
    YAHOO.util.Dom.removeClass(forgot_link, 'bz_default_hidden');
    YAHOO.util.Dom.addClass(forgot_form, 'bz_default_hidden');
    YAHOO.util.Dom.removeClass(login_container, 'bz_default_hidden');
    return false;
}

function init_mini_login_form( suffix ) {
    var mini_login = document.getElementById('Bugzilla_login' +  suffix );
    var mini_password = document.getElementById('Bugzilla_password' +  suffix );
    var mini_dummy = document.getElementById(
        'Bugzilla_password_dummy' + suffix);
    // If the login and password are blank when the page loads, we display
    // "login" and "password" in the boxes by default.
    if (mini_login.value == "" && mini_password.value == "") {
        mini_login.value = mini_login_constants.login;
        YAHOO.util.Dom.addClass(mini_login, "bz_mini_login_help");
        YAHOO.util.Dom.addClass(mini_password, 'bz_default_hidden');
        YAHOO.util.Dom.removeClass(mini_dummy, 'bz_default_hidden');
    }
    else {
        show_mini_login_form(suffix);
    }
}

// Clear the words "login" and "password" from the form when you click
// in one of the boxes. We clear them both when you click in either box
// so that the browser's password-autocomplete can work.
function mini_login_on_focus( suffix ) {
    var mini_login = document.getElementById('Bugzilla_login' +  suffix );
    var mini_password = document.getElementById('Bugzilla_password' +  suffix );
    var mini_dummy = document.getElementById(
        'Bugzilla_password_dummy' + suffix);

    YAHOO.util.Dom.removeClass(mini_login, "bz_mini_login_help");
    if (mini_login.value == mini_login_constants.login) {
        mini_login.value = '';
    }
    YAHOO.util.Dom.removeClass(mini_password, 'bz_default_hidden');
    YAHOO.util.Dom.addClass(mini_dummy, 'bz_default_hidden');
}

function check_mini_login_fields( suffix ) {
    var mini_login = document.getElementById('Bugzilla_login' +  suffix );
    var mini_password = document.getElementById('Bugzilla_password' +  suffix );
    if( (mini_login.value != "" && mini_password.value != "") 
         &&  mini_login.value != mini_login_constants.login )
    {
      return true;
    }
    window.alert( mini_login_constants.warning );
    return false;
}

/* template/en/global/menuforusers.html.tmpl */

function menuforusers_initcombo(id, multi)
{
  var sel = document.getElementById(id+"_s");
  var ed = document.getElementById(id);
  if (!sel || !ed)
    return;
  ed.style.width = (sel.offsetWidth-sel.offsetHeight+2)+'px';
  ed.style.borderWidth = 0;
  menuforusers_tocombo(id);
}

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
}

function menuforusers_tocombo(id, multi)
{
  var sel = document.getElementById(id+"_s");
  var ed = document.getElementById(id);
  if (!sel || !ed)
    return;
  var nv = [];
  var v = ed.value.split(/[\s,]+/);
  var i, j;
  for (i = 0; i < v.length; i++)
  {
    for (j = 0; j < sel.options.length; j++)
    {
      if (sel.options[i].value.toLowerCase().indexOf(v[i].toLowerCase()) >= 0 ||
          sel.options[i].text.toLowerCase().indexOf(v[i].toLowerCase()) >= 0)
      {
        sel.options[i].selected = true;
        nv.push(sel.options[i].value);
        break;
      }
    }
    if (j >= sel.options.length)
      nv.push(v[i]);
    if (!multi)
      break;
  }
  ed.value = nv.join(', ');
}

function menuforusers_fromcombo(id, multi)
{
  var sel = document.getElementById(id+"_s");
  var ed = document.getElementById(id);
  if (!sel || !ed)
    return;
  v = [];
  for (var i = 0; i < sel.options.length; i++)
    if (sel.options[i].selected)
      v.push(sel.options[i].value);
  ed.value = v.join(', ');
}

function menuforusers_showmulti(id)
{
  var sel = document.getElementById(id+"_s");
  var btn = document.getElementById(id+"_b");
  if (!sel || !btn)
    return;
  var show = sel.style.visibility == 'hidden' && !sel.disabled;
  sel.style.visibility = show ? '' : 'hidden';
  btn.src = 'images/dn' + (show ? 'push' : '') + '.gif';
}
