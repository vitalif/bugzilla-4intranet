// JS for the query form
// License: Dual-license GPL 3.0+ or MPL 1.1+
// Author(s): Vitaliy Filippov <vitalif@mail.ru>

// Requires global vars: queryform, allKeywords, checkwidths, userAutocomplete
addListener(window, 'load', function()
{
  document.forms[queryform].content.focus();
  new SimpleAutocomplete("keywords",
    function(h) { keywordAutocomplete(h, allKeywords); },
    { emptyText: 'No keywords found', multipleDelimiter: "," }
  );
  if (document.getElementById('deadlinefrom'))
  {
    Calendar.set('deadlinefrom');
    Calendar.set('deadlineto');
  }
  new SimpleAutocomplete("email1", userAutocomplete, { emptyText: 'No users found' });
  new SimpleAutocomplete("email2", userAutocomplete, { emptyText: 'No users found' });
  Calendar.set('chfieldfrom');
  Calendar.set('chfieldto');
  new SimpleAutocomplete("chfieldwho", userAutocomplete, { emptyText: 'No users found' });

  var lim = 250;
  function checkw(e)
  {
    var s = document.getElementById(e);
    s.style.minWidth = '100%';
    if (s && s.offsetWidth > lim)
    {
      s.style.width = lim+'px';
      addListener(s, 'mouseover', function(e)
      {
        e = e || window.event;
        var f = e.relatedTarget || e.fromElement;
        if (f == s || f.parentNode == s || !s.style.width && s.offsetWidth <= lim)
          return;
        var c = s;
        while (c && c.nodeName != 'TABLE')
          c = c.parentNode;
        var w = (lim+c.parentNode.offsetWidth-c.offsetWidth);
        if (w > lim+10)
        {
          s.style.width = '';
          s.style.maxWidth = w + 'px';
        }
      });
      addListener(s, 'mouseout', function(e) {
        e = e || window.event;
        var t = e.relatedTarget || e.toElement;
        if (t == s || t.parentNode == s)
          return;
        s.style.width = lim+'px';
        s.style.maxWidth = '';
      });
    }
  }
  for (var i in checkwidths)
  {
    checkw(checkwidths[i]);
  }
});
